"""Operation & review GUI server.

FastAPI app that starts agent runs, streams their events over SSE, resolves
human approvals (approval mode), and drives per-project GitHub pull/push.
Launch with `daedalus serve`.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from .agent import ApprovalRequest, run_agent
from .config import Mode, RunConfig, Spec
from .github_sync import GitHubConfig, GitHubSyncError, pull_repo, push_workspace

WEB_DIR = Path(__file__).parent / "web"


class StartRunBody(BaseModel):
    spec_yaml: str
    mode: str = "approval"
    workspace: str | None = None
    max_turns: int = 40
    model: str | None = None
    allow_destroy: bool = False
    security_scan: bool = True  # mandatory tfsec gate before apply
    pull: bool = False   # pull project repo into workspace before the run
    push: bool = False   # push workspace to project repo after a successful run


class ApprovalBody(BaseModel):
    approved: bool


class GitHubOpBody(BaseModel):
    spec_yaml: str
    workspace: str
    message: str | None = None


@dataclass
class RunHandle:
    id: str
    spec_name: str
    mode: str
    workspace: str
    status: str = "running"  # running | succeeded | failed | error
    started_at: str = ""
    events: list[dict[str, Any]] = field(default_factory=list)
    # approval_id -> {"request": ApprovalRequest, "future": Future[bool]}
    approvals: dict[str, dict[str, Any]] = field(default_factory=dict)
    cost_usd: float | None = None
    error: str | None = None

    def emit(self, kind: str, **data: Any) -> None:
        self.events.append({"ts": datetime.now(timezone.utc).isoformat(), "kind": kind, **data})

    def to_summary(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "spec_name": self.spec_name,
            "mode": self.mode,
            "workspace": self.workspace,
            "status": self.status,
            "started_at": self.started_at,
            "cost_usd": self.cost_usd,
            "error": self.error,
            "pending_approvals": [
                {
                    "approval_id": aid,
                    "command": entry["request"].command,
                    "reason": entry["request"].reason,
                    "context_tail": entry["request"].context_tail,
                }
                for aid, entry in self.approvals.items()
            ],
        }


class RunManager:
    def __init__(self) -> None:
        self.runs: dict[str, RunHandle] = {}

    @property
    def active(self) -> RunHandle | None:
        return next((h for h in self.runs.values() if h.status == "running"), None)


manager = RunManager()
app = FastAPI(title="daedalus", docs_url=None, redoc_url=None)


def _parse_spec(spec_yaml: str) -> Spec:
    try:
        return Spec.loads(spec_yaml)
    except (ValueError, Exception) as exc:  # yaml errors included
        raise HTTPException(status_code=400, detail=f"invalid spec: {exc}") from exc


async def _execute(handle: RunHandle, spec: Spec, config: RunConfig, body: StartRunBody) -> None:
    def on_event(record: dict[str, Any]) -> None:
        handle.events.append(record)
        if record.get("kind") == "result" and record.get("cost_usd") is not None:
            handle.cost_usd = record["cost_usd"]

    async def approver(request: ApprovalRequest) -> bool:
        approval_id = uuid.uuid4().hex[:10]
        future: asyncio.Future[bool] = asyncio.get_running_loop().create_future()
        handle.approvals[approval_id] = {"request": request, "future": future}
        handle.emit(
            "approval_pending",
            approval_id=approval_id,
            command=request.command,
            reason=request.reason,
            context_tail=request.context_tail,
            plan_summary=request.plan_summary,
            plan_counts=request.plan_counts,
        )
        try:
            return await future
        finally:
            handle.approvals.pop(approval_id, None)

    try:
        if config.security_scan and shutil.which("tfsec") is None:
            config.security_scan = False
            handle.emit(
                "warning",
                message="tfsec が見つからないため、セキュリティスキャン必須化を無効にして実行します"
                        "（導入: https://github.com/aquasecurity/tfsec）",
            )

        if body.pull and spec.github:
            cfg = GitHubConfig.from_spec(spec)
            handle.emit("github_pull_start", repo=f"{cfg.owner}/{cfg.repo}", branch=cfg.branch)
            files = await asyncio.to_thread(pull_repo, cfg, config.workspace)
            handle.emit("github_pull_done", files=len(files))

        result = await run_agent(spec, config, approver=approver, on_event=on_event)
        handle.status = "succeeded" if result.succeeded else "failed"
        if result.cost_usd is not None:
            handle.cost_usd = result.cost_usd

        if body.push and result.succeeded and spec.github:
            cfg = GitHubConfig.from_spec(spec)
            handle.emit("github_push_start", repo=f"{cfg.owner}/{cfg.repo}", branch=cfg.branch)
            info = await asyncio.to_thread(
                push_workspace, cfg, config.workspace,
                f"daedalus: {spec.name} ({handle.mode} run {handle.id})",
            )
            handle.emit("github_push_done", **info)
    except GitHubSyncError as exc:
        handle.status = "error"
        handle.error = str(exc)
        handle.emit("run_error", error=str(exc))
    except Exception as exc:  # surface agent/SDK failures to the GUI
        handle.status = "error"
        handle.error = f"{type(exc).__name__}: {exc}"
        handle.emit("run_error", error=handle.error)
    finally:
        # Reject anything still pending so the run task can't hang forever.
        for entry in list(handle.approvals.values()):
            if not entry["future"].done():
                entry["future"].set_result(False)
        handle.emit("stream_end", status=handle.status)


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/env")
async def env_status() -> dict[str, bool]:
    return {
        "anthropic_api_key": bool(os.environ.get("ANTHROPIC_API_KEY")),
        "github_token": bool(os.environ.get("GITHUB_TOKEN")),
        "github_owner": bool(os.environ.get("GITHUB_OWNER")),
    }


@app.post("/api/runs")
async def start_run(body: StartRunBody) -> dict[str, str]:
    if manager.active is not None:
        raise HTTPException(status_code=409, detail="a run is already in progress (v1 runs one at a time)")
    try:
        mode = Mode(body.mode)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"invalid mode: {body.mode} (plan|approval|auto)")
    spec = _parse_spec(body.spec_yaml)
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise HTTPException(status_code=400, detail="ANTHROPIC_API_KEY is not set on the server")

    workspace = Path(body.workspace) if body.workspace else Path("workspace") / spec.name
    config = RunConfig(
        workspace=workspace,
        mode=mode,
        allow_destroy=body.allow_destroy,
        security_scan=body.security_scan,
        max_turns=body.max_turns,
        model=body.model or None,
    )
    run_id = uuid.uuid4().hex[:10]
    handle = RunHandle(
        id=run_id,
        spec_name=spec.name,
        mode=mode.value,
        workspace=str(workspace),
        started_at=datetime.now(timezone.utc).isoformat(),
    )
    manager.runs[run_id] = handle
    asyncio.create_task(_execute(handle, spec, config, body))
    return {"run_id": run_id}


@app.get("/api/runs")
async def list_runs() -> list[dict[str, Any]]:
    return [h.to_summary() for h in sorted(manager.runs.values(), key=lambda h: h.started_at, reverse=True)]


@app.get("/api/runs/{run_id}")
async def get_run(run_id: str) -> dict[str, Any]:
    handle = manager.runs.get(run_id)
    if handle is None:
        raise HTTPException(status_code=404, detail="run not found")
    return handle.to_summary()


@app.get("/api/runs/{run_id}/events")
async def run_events(run_id: str) -> StreamingResponse:
    handle = manager.runs.get(run_id)
    if handle is None:
        raise HTTPException(status_code=404, detail="run not found")

    async def stream():
        index = 0
        while True:
            while index < len(handle.events):
                record = handle.events[index]
                index += 1
                yield f"data: {json.dumps(record, ensure_ascii=False, default=str)}\n\n"
                if record.get("kind") == "stream_end":
                    return
            if handle.status != "running" and index >= len(handle.events):
                yield f'data: {{"kind": "stream_end", "status": "{handle.status}"}}\n\n'
                return
            await asyncio.sleep(0.4)

    return StreamingResponse(stream(), media_type="text/event-stream")


@app.post("/api/approvals/{approval_id}")
async def resolve_approval(approval_id: str, body: ApprovalBody) -> dict[str, Any]:
    for handle in manager.runs.values():
        entry = handle.approvals.get(approval_id)
        if entry is not None:
            if not entry["future"].done():
                entry["future"].set_result(body.approved)
            return {"approval_id": approval_id, "approved": body.approved}
    raise HTTPException(status_code=404, detail="approval not found (already resolved?)")


@app.post("/api/github/pull")
async def github_pull(body: GitHubOpBody) -> dict[str, Any]:
    spec = _parse_spec(body.spec_yaml)
    try:
        cfg = GitHubConfig.from_spec(spec)
        files = await asyncio.to_thread(pull_repo, cfg, Path(body.workspace))
    except GitHubSyncError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"repo": f"{cfg.owner}/{cfg.repo}", "branch": cfg.branch, "files": len(files)}


@app.post("/api/github/push")
async def github_push(body: GitHubOpBody) -> dict[str, Any]:
    spec = _parse_spec(body.spec_yaml)
    try:
        cfg = GitHubConfig.from_spec(spec)
        info = await asyncio.to_thread(
            push_workspace, cfg, Path(body.workspace),
            body.message or f"daedalus: manual push ({spec.name})",
        )
    except GitHubSyncError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return {"repo": f"{cfg.owner}/{cfg.repo}", "branch": cfg.branch, **info}


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(WEB_DIR / "index.html")


app.mount("/static", StaticFiles(directory=str(WEB_DIR)), name="static")

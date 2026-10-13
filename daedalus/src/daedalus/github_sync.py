"""Per-project GitHub sync via the REST API (no git binary required).

Each spec can carry a ``github:`` section mapping the project to its own repo:

    github:
      repo: my-infra-project     # required
      owner: ${GITHUB_OWNER}     # optional; falls back to env GITHUB_OWNER
      branch: main               # optional; default "main"

Credentials and account IDs come from the environment only:
- GITHUB_TOKEN  (required; fine-grained PAT with contents:read/write)
- GITHUB_OWNER  (account/org name, if not set in the spec)
- GITHUB_API_URL (optional; defaults to https://api.github.com)

Pull = download the branch tarball and extract into the workspace.
Push = create blobs/tree/commit via the Git Data API on top of the current
branch head (add/update only — files are never deleted from the repo).
"""

from __future__ import annotations

import base64
import io
import os
import tarfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx

from .config import Spec

# Never pushed to the repo / never overwritten by pull cleanup.
_EXCLUDE_DIRS = {".terraform", ".daedalus", ".git", "__pycache__"}
_EXCLUDE_FILE_PATTERNS = (".tfstate", "crash.log", ".tfvars")


class GitHubSyncError(RuntimeError):
    pass


@dataclass
class GitHubConfig:
    owner: str
    repo: str
    branch: str
    token: str
    api_base: str = "https://api.github.com"

    @classmethod
    def from_spec(cls, spec: Spec) -> "GitHubConfig":
        gh = spec.github or {}
        repo = gh.get("repo")
        if not repo:
            raise GitHubSyncError(
                f"spec '{spec.name}' has no github.repo configured — add a `github:` section to the spec"
            )
        owner = gh.get("owner") or os.environ.get("GITHUB_OWNER")
        if not owner:
            raise GitHubSyncError("GitHub owner not set: define github.owner in the spec or export GITHUB_OWNER")
        token = os.environ.get("GITHUB_TOKEN")
        if not token:
            raise GitHubSyncError("GITHUB_TOKEN is not set — export a token with contents read/write access")
        return cls(
            owner=str(owner),
            repo=str(repo),
            branch=str(gh.get("branch", "main")),
            token=token,
            api_base=os.environ.get("GITHUB_API_URL", "https://api.github.com").rstrip("/"),
        )

    @property
    def repo_path(self) -> str:
        return f"/repos/{self.owner}/{self.repo}"

    def _client(self) -> httpx.Client:
        return httpx.Client(
            base_url=self.api_base,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
            follow_redirects=True,
            timeout=60.0,
        )


def _check(resp: httpx.Response, what: str) -> dict[str, Any]:
    if resp.status_code >= 400:
        raise GitHubSyncError(f"{what} failed: HTTP {resp.status_code} — {resp.text[:300]}")
    return resp.json() if resp.content else {}


def _is_excluded(rel: Path) -> bool:
    if any(part in _EXCLUDE_DIRS for part in rel.parts):
        return True
    return any(pat in rel.name for pat in _EXCLUDE_FILE_PATTERNS)


def pull_repo(cfg: GitHubConfig, workspace: str | Path) -> list[str]:
    """Download the branch tarball and extract it into the workspace.

    Returns the list of extracted file paths (relative to the workspace).
    """
    workspace = Path(workspace)
    workspace.mkdir(parents=True, exist_ok=True)
    extracted: list[str] = []

    with cfg._client() as client:
        resp = client.get(f"{cfg.repo_path}/tarball/{cfg.branch}")
        if resp.status_code >= 400:
            raise GitHubSyncError(
                f"pull failed: HTTP {resp.status_code} for "
                f"{cfg.owner}/{cfg.repo}@{cfg.branch} — {resp.text[:300]}"
            )

    with tarfile.open(fileobj=io.BytesIO(resp.content), mode="r:gz") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            # Strip the leading "<owner>-<repo>-<sha>/" component.
            parts = Path(member.name).parts[1:]
            if not parts:
                continue
            rel = Path(*parts)
            if _is_excluded(rel) or ".." in rel.parts:
                continue
            target = workspace / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            fh = tar.extractfile(member)
            if fh is None:
                continue
            target.write_bytes(fh.read())
            extracted.append(str(rel))
    return extracted


def collect_files(workspace: str | Path) -> list[Path]:
    """Workspace files eligible for push (state, caches and secrets excluded)."""
    workspace = Path(workspace)
    files: list[Path] = []
    for path in sorted(workspace.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(workspace)
        if _is_excluded(rel):
            continue
        files.append(rel)
    return files


def push_workspace(cfg: GitHubConfig, workspace: str | Path, message: str) -> dict[str, str]:
    """Commit the workspace files to the project repo via the Git Data API.

    Add/update only (the new tree is based on the branch head, so files absent
    from the workspace are kept, never deleted). Creates the branch if missing.
    Returns {"sha": ..., "url": ..., "files": "<count>"}.
    """
    workspace = Path(workspace)
    files = collect_files(workspace)
    if not files:
        raise GitHubSyncError(f"nothing to push: no eligible files in {workspace}")

    with cfg._client() as client:
        # Resolve the parent commit (branch head, or default branch head for a new branch).
        parent_sha: str | None = None
        base_tree: str | None = None
        new_branch = False
        ref_resp = client.get(f"{cfg.repo_path}/git/ref/heads/{cfg.branch}")
        if ref_resp.status_code == 200:
            parent_sha = ref_resp.json()["object"]["sha"]
        elif ref_resp.status_code == 404:
            new_branch = True
            repo_info = _check(client.get(cfg.repo_path), "repo lookup")
            default_branch = repo_info.get("default_branch", "main")
            head = client.get(f"{cfg.repo_path}/git/ref/heads/{default_branch}")
            if head.status_code == 200:
                parent_sha = head.json()["object"]["sha"]
            # else: empty repository — initial commit with no parent
        else:
            _check(ref_resp, "branch lookup")

        if parent_sha:
            commit_info = _check(
                client.get(f"{cfg.repo_path}/git/commits/{parent_sha}"), "parent commit lookup"
            )
            base_tree = commit_info["tree"]["sha"]

        # Build the tree. Text files go inline; binary files via blob + base64.
        tree_items: list[dict[str, Any]] = []
        for rel in files:
            data = (workspace / rel).read_bytes()
            item: dict[str, Any] = {"path": rel.as_posix(), "mode": "100644", "type": "blob"}
            try:
                item["content"] = data.decode("utf-8")
            except UnicodeDecodeError:
                blob = _check(
                    client.post(
                        f"{cfg.repo_path}/git/blobs",
                        json={"content": base64.b64encode(data).decode("ascii"), "encoding": "base64"},
                    ),
                    f"blob create ({rel})",
                )
                item["sha"] = blob["sha"]
            tree_items.append(item)

        tree_payload: dict[str, Any] = {"tree": tree_items}
        if base_tree:
            tree_payload["base_tree"] = base_tree
        tree = _check(client.post(f"{cfg.repo_path}/git/trees", json=tree_payload), "tree create")

        commit_payload: dict[str, Any] = {"message": message, "tree": tree["sha"]}
        if parent_sha:
            commit_payload["parents"] = [parent_sha]
        commit = _check(client.post(f"{cfg.repo_path}/git/commits", json=commit_payload), "commit create")

        if new_branch or ref_resp.status_code == 404:
            _check(
                client.post(
                    f"{cfg.repo_path}/git/refs",
                    json={"ref": f"refs/heads/{cfg.branch}", "sha": commit["sha"]},
                ),
                "branch create",
            )
        else:
            _check(
                client.patch(
                    f"{cfg.repo_path}/git/refs/heads/{cfg.branch}",
                    json={"sha": commit["sha"], "force": False},
                ),
                "ref update",
            )

    return {
        "sha": commit["sha"],
        "url": commit.get("html_url", ""),
        "files": str(len(files)),
    }

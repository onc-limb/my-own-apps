"""Per-run history: append-only JSONL plus a short markdown summary.

This is runtime history of agent runs, distinct from the repo-level `journal/`
that records design decisions.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class RunJournal:
    def __init__(self, workspace: str | Path, spec_name: str) -> None:
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        safe_name = "".join(c if c.isalnum() or c in "-_" else "-" for c in spec_name)
        self.run_id = f"{ts}-{safe_name}"
        self.dir = Path(workspace) / ".daedalus" / "runs"
        self.dir.mkdir(parents=True, exist_ok=True)
        self.jsonl_path = self.dir / f"{self.run_id}.jsonl"
        self.summary_path = self.dir / f"{self.run_id}.md"
        self._fh = self.jsonl_path.open("a", encoding="utf-8")

    def event(self, kind: str, **data: Any) -> None:
        record = {"ts": _now_iso(), "kind": kind, **data}
        self._fh.write(json.dumps(record, ensure_ascii=False, default=str) + "\n")
        self._fh.flush()

    def write_summary(self, lines: list[str]) -> None:
        self.summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def close(self) -> None:
        if not self._fh.closed:
            self._fh.close()

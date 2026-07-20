"""Spec (what to build) and RunConfig (how to run) models."""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

import yaml

_ENV_RE = re.compile(r"\$\{(\w+)\}")


def _expand_env(value: Any) -> Any:
    """Expand ${VAR} references in spec values from environment variables.

    Account IDs, owners etc. should live in the environment, not in the spec file.
    """
    if isinstance(value, str):
        def _rep(m: re.Match[str]) -> str:
            var = m.group(1)
            resolved = os.environ.get(var)
            if resolved is None:
                raise ValueError(f"environment variable not set: {var} (referenced in spec)")
            return resolved

        return _ENV_RE.sub(_rep, value)
    if isinstance(value, list):
        return [_expand_env(v) for v in value]
    if isinstance(value, dict):
        return {k: _expand_env(v) for k, v in value.items()}
    return value


class Mode(str, Enum):
    """Execution mode for a run.

    - PLAN: dry-run; `terraform plan` only, apply is denied (safe default).
    - APPROVAL: apply/destroy pause for human approval before executing.
    - AUTO: full autopilot — apply runs without human gating (sandbox accounts,
      building from scratch).
    """

    PLAN = "plan"
    APPROVAL = "approval"
    AUTO = "auto"


@dataclass
class Spec:
    """A high-level description of the infrastructure to build.

    Free-form natural language is allowed in ``description`` and ``constraints``;
    daedalus turns this into a task prompt rather than parsing it strictly.
    """

    name: str
    provider: str = "aws"
    region: str | None = None
    description: str = ""
    constraints: list[str] = field(default_factory=list)
    terraform: dict[str, Any] = field(default_factory=dict)
    github: dict[str, Any] = field(default_factory=dict)
    raw: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Spec":
        if not data.get("name"):
            raise ValueError("spec is missing required field: 'name'")
        data = _expand_env(data)
        return cls(
            name=str(data["name"]),
            provider=str(data.get("provider", "aws")),
            region=data.get("region"),
            description=str(data.get("description", "")).strip(),
            constraints=list(data.get("constraints", []) or []),
            terraform=dict(data.get("terraform", {}) or {}),
            github=dict(data.get("github", {}) or {}),
            raw=data,
        )

    @classmethod
    def load(cls, path: str | Path) -> "Spec":
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"spec file not found: {path}")
        return cls.loads(path.read_text(encoding="utf-8"))

    @classmethod
    def loads(cls, text: str) -> "Spec":
        data = yaml.safe_load(text) or {}
        if not isinstance(data, dict):
            raise ValueError(f"spec must be a YAML mapping, got: {type(data).__name__}")
        return cls.from_dict(data)


@dataclass
class RunConfig:
    """Runtime configuration for a single agent run.

    Safe by default: mode is PLAN and ``allow_destroy`` is off, so the agent only
    runs ``terraform plan`` until the caller opts in.
    """

    workspace: Path
    mode: Mode = Mode.PLAN
    allow_destroy: bool = False
    # Require a clean tfsec scan (zero CRITICAL/HIGH) before terraform apply.
    # Auto-disabled with a warning when the tfsec binary is missing.
    security_scan: bool = True
    max_turns: int = 40
    model: str | None = None

    def ensure_workspace(self) -> Path:
        self.workspace = Path(self.workspace).resolve()
        self.workspace.mkdir(parents=True, exist_ok=True)
        return self.workspace

    @property
    def apply_allowed(self) -> bool:
        return self.mode is not Mode.PLAN

    @property
    def mode_label(self) -> str:
        return {
            Mode.PLAN: "plan-only (dry-run)",
            Mode.APPROVAL: "approval (human gates apply)",
            Mode.AUTO: "auto (full autopilot)",
        }[self.mode]

"""Spec (what to build) and RunConfig (how to run) models."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


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
    raw: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Spec":
        if not data.get("name"):
            raise ValueError("spec is missing required field: 'name'")
        return cls(
            name=str(data["name"]),
            provider=str(data.get("provider", "aws")),
            region=data.get("region"),
            description=str(data.get("description", "")).strip(),
            constraints=list(data.get("constraints", []) or []),
            terraform=dict(data.get("terraform", {}) or {}),
            raw=data,
        )

    @classmethod
    def load(cls, path: str | Path) -> "Spec":
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"spec file not found: {path}")
        with path.open("r", encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}
        if not isinstance(data, dict):
            raise ValueError(f"spec file must be a YAML mapping, got: {type(data).__name__}")
        return cls.from_dict(data)


@dataclass
class RunConfig:
    """Runtime configuration for a single agent run.

    Safe by default: ``apply`` and ``allow_destroy`` are off, so the agent only
    runs ``terraform plan`` until the caller opts in.
    """

    workspace: Path
    apply: bool = False
    allow_destroy: bool = False
    max_turns: int = 40
    model: str | None = None

    def ensure_workspace(self) -> Path:
        self.workspace = Path(self.workspace).resolve()
        self.workspace.mkdir(parents=True, exist_ok=True)
        return self.workspace

    @property
    def mode(self) -> str:
        if not self.apply:
            return "plan-only (dry-run)"
        return "apply + destroy" if self.allow_destroy else "apply"

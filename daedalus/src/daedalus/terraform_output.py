"""Pure parsers for terraform / tfsec output text.

These power the human-facing plan summary (approval cards, live log) and the
security-scan gate. Parsing is deliberately deterministic — regex over the tool
output, no LLM call — so it is free, instant and reproducible.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

# Resource action lines in `terraform plan` human output.
_ACTION_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("replaced", re.compile(r"^\s*# ([^\s(]+) (?:must|will) be replaced", re.MULTILINE)),
    ("destroyed", re.compile(r"^\s*# ([^\s(]+) will be destroyed", re.MULTILINE)),
    ("created", re.compile(r"^\s*# ([^\s(]+) will be created", re.MULTILINE)),
    ("updated", re.compile(r"^\s*# ([^\s(]+) will be updated in-place", re.MULTILINE)),
]
_PLAN_LINE = re.compile(r"Plan:\s*(\d+) to add,\s*(\d+) to change,\s*(\d+) to destroy")
_NO_CHANGES = re.compile(r"No changes\.")
_HAS_ACTIONS = "Terraform will perform the following actions"

_MAX_LISTED = 12  # resources shown per action bucket in the formatted summary


def strip_ansi(text: str) -> str:
    return _ANSI_RE.sub("", text)


@dataclass
class PlanSummary:
    add: int = 0
    change: int = 0
    destroy: int = 0
    created: list[str] = field(default_factory=list)
    updated: list[str] = field(default_factory=list)
    destroyed: list[str] = field(default_factory=list)
    replaced: list[str] = field(default_factory=list)
    no_changes: bool = False

    @property
    def replace(self) -> int:
        return len(self.replaced)

    @property
    def dangerous(self) -> bool:
        """True when the plan removes or replaces existing resources."""
        return self.destroy > 0 or bool(self.replaced)

    def counts(self) -> dict[str, int]:
        return {"add": self.add, "change": self.change, "destroy": self.destroy, "replace": self.replace}


def parse_plan_output(text: str) -> PlanSummary | None:
    """Parse `terraform plan` human-readable output. Returns None if ``text``
    does not look like plan output (e.g. it is apply/init output)."""
    text = strip_ansi(text)
    plan_line = _PLAN_LINE.search(text)
    if not (plan_line or _HAS_ACTIONS in text or _NO_CHANGES.search(text)):
        return None

    summary = PlanSummary()
    for action, pattern in _ACTION_PATTERNS:
        getattr(summary, action).extend(pattern.findall(text))

    if plan_line:
        summary.add, summary.change, summary.destroy = (int(g) for g in plan_line.groups())
    else:
        summary.add = len(summary.created)
        summary.change = len(summary.updated)
        summary.destroy = len(summary.destroyed)

    if _NO_CHANGES.search(text) and not any(
        (summary.created, summary.updated, summary.destroyed, summary.replaced)
    ):
        summary.no_changes = True
    return summary


def format_plan_japanese(summary: PlanSummary) -> str:
    """Render a PlanSummary as a short human-friendly Japanese digest."""
    if summary.no_changes:
        return "変更なし — 実環境は構成と一致しています"

    lines = [
        f"追加 {summary.add} / 変更 {summary.change} / 削除 {summary.destroy} / 置換 {summary.replace}"
    ]
    buckets = [
        ("+", "作成", summary.created),
        ("~", "変更", summary.updated),
        ("-", "削除", summary.destroyed),
        ("±", "置換", summary.replaced),
    ]
    for symbol, _label, items in buckets:
        for resource in items[:_MAX_LISTED]:
            lines.append(f"  {symbol} {resource}")
        if len(items) > _MAX_LISTED:
            lines.append(f"  … 他 {len(items) - _MAX_LISTED} 件")
    if summary.dangerous:
        lines.append("⚠️ 削除/置換を含む変更です。対象リソースを必ず確認してください。")
    return "\n".join(lines)


# --- tfsec ---------------------------------------------------------------

_TFSEC_PROBLEMS = re.compile(r"(\d+)\s+potential problem")
_TFSEC_CRITICAL = re.compile(r"\bcritical\s+(\d+)\b", re.IGNORECASE)
_TFSEC_HIGH = re.compile(r"\bhigh\s+(\d+)\b", re.IGNORECASE)
_TFSEC_PASSED = re.compile(r"\bpassed\s+\d+\b", re.IGNORECASE)


def parse_tfsec_output(text: str) -> tuple[bool, str] | None:
    """Detect a tfsec scan result in command output.

    Returns (passed, detail) — passed means zero CRITICAL/HIGH findings —
    or None when the text does not look like tfsec output.
    """
    text = strip_ansi(text)
    if "No problems detected" in text:
        return True, "no problems detected"

    problems = _TFSEC_PROBLEMS.search(text)
    critical = _TFSEC_CRITICAL.search(text)
    high = _TFSEC_HIGH.search(text)

    if critical and high and (problems or _TFSEC_PASSED.search(text)):
        n_crit, n_high = int(critical.group(1)), int(high.group(1))
        return n_crit == 0 and n_high == 0, f"critical={n_crit} high={n_high}"
    if problems:
        count = int(problems.group(1))
        return count == 0, f"problems={count}"
    return None

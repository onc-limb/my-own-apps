"""Guardrail logic: gate terraform apply/destroy and block dangerous shell.

This is intentionally a *gate*, not an allowlist: terraform and ordinary shell
run freely; only apply/destroy (per RunConfig mode) and clearly dangerous
commands are stopped. Decisions:

- "allow"   — run as-is
- "deny"    — blocked outright
- "approve" — requires human approval before running (approval mode)

The actual PreToolUse hook wiring lives in ``agent.py``; this module holds the
pure decision logic so it is easy to test.
"""

from __future__ import annotations

import re

from .config import Mode, RunConfig

# Clearly dangerous shell patterns — denied regardless of mode.
_DANGEROUS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\brm\s+-[a-z]*r[a-z]*f|\brm\s+-[a-z]*f[a-z]*r|\brm\s+-rf|\brm\s+-fr|\brm\s+-r\b|\brm\s+-f\b"),
     "recursive/force remove"),
    (re.compile(r"\bsudo\b"), "sudo"),
    (re.compile(r"\bmkfs\b"), "mkfs"),
    (re.compile(r"\bdd\s+if="), "dd"),
    (re.compile(r":\s*\(\s*\)\s*\{"), "fork bomb"),
    (re.compile(r"\bchmod\s+-?R?\s*0?777\b"), "chmod 777"),
    (re.compile(r"(curl|wget)\b[^|]*\|\s*(sudo\s+)?(ba)?sh\b"), "pipe-to-shell"),
    (re.compile(r">\s*/dev/sd"), "write to block device"),
    (re.compile(r"\b(shutdown|reboot|halt|poweroff)\b"), "power control"),
]

# A terraform invocation up to the next shell separator.
_TF_SEGMENT = r"\bterraform\b[^&|;]*"


def classify_bash(command: str, config: RunConfig) -> tuple[str, str]:
    """Return ("allow"|"deny"|"approve", reason) for a Bash command string."""
    cmd = command.strip()

    for pattern, label in _DANGEROUS:
        if pattern.search(cmd):
            return "deny", f"blocked dangerous shell pattern: {label}"

    if re.search(r"\bterraform\b", cmd):
        if re.search(_TF_SEGMENT + r"\bdestroy\b", cmd):
            if not config.allow_destroy:
                return (
                    "deny",
                    "terraform destroy is disabled. Re-run daedalus with --allow-destroy "
                    "to permit it. Do not attempt to bypass this.",
                )
            if config.mode is Mode.APPROVAL:
                return "approve", "terraform destroy requires human approval (approval mode)"
            return "allow", ""
        if re.search(_TF_SEGMENT + r"\bapply\b", cmd):
            if config.mode is Mode.PLAN:
                return (
                    "deny",
                    "Dry-run mode: terraform apply is disabled. Run `terraform plan` only. "
                    "Re-run daedalus in approval or auto mode to deploy for real.",
                )
            if config.mode is Mode.APPROVAL:
                return "approve", "terraform apply requires human approval (approval mode)"
            return "allow", ""

    return "allow", ""

"""Drive headless Claude Code (via the Claude Agent SDK) to build Terraform.

daedalus does not implement the build/deploy loop itself — Claude Code runs the
tool-use loop. This module wires the spec into a prompt, attaches guardrail hooks,
streams the conversation, and records what happened.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

from .config import RunConfig, Spec
from .guardrails import classify_bash
from .journal import RunJournal
from .prompts import build_system_prompt, build_task_prompt


@dataclass
class RunState:
    bash_calls: int = 0
    denied_calls: int = 0
    plan_ok: bool = False
    apply_ok: bool = False
    errors: list[str] = field(default_factory=list)


@dataclass
class RunResult:
    state: RunState
    session_id: str | None = None
    cost_usd: float | None = None
    summary_text: str | None = None

    @property
    def succeeded(self) -> bool:
        # In apply mode success = apply completed; in dry-run success = plan is clean.
        return self.state.apply_ok or (self.state.plan_ok and not self.state.errors)


def _short(value: Any, limit: int = 160) -> str:
    text = value if isinstance(value, str) else str(value)
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def _tail(text: str, limit: int = 600) -> str:
    return text if len(text) <= limit else "…" + text[-limit:]


def _make_pre_hook(config: RunConfig, state: RunState, journal: RunJournal):
    async def pre_hook(input_data: dict, tool_use_id: Any, context: Any) -> dict:
        command = (input_data.get("tool_input") or {}).get("command", "")
        decision, reason = classify_bash(command, config)
        state.bash_calls += 1
        journal.event("bash_pre", command=_short(command, 400), decision=decision, reason=reason)
        if decision == "deny":
            state.denied_calls += 1
            print(f"  ⛔ denied: {reason}")
            return {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        return {}

    return pre_hook


def _make_post_hook(state: RunState, journal: RunJournal):
    async def post_hook(input_data: dict, tool_use_id: Any, context: Any) -> dict:
        output = input_data.get("tool_output", "")
        text = output if isinstance(output, str) else str(output)
        if "Apply complete!" in text:
            state.apply_ok = True
        if re.search(r"\bPlan:\s", text) or "No changes." in text or "Success!" in text:
            state.plan_ok = True
        for match in re.findall(r"^\s*Error:.*$", text, re.MULTILINE):
            state.errors.append(match.strip())
        journal.event("bash_post", output_tail=_tail(text))
        return {}

    return post_hook


async def run_agent(spec: Spec, config: RunConfig) -> RunResult:
    """Run one agent session and return the result."""
    # Imported here so missing optional deps produce a clear CLI error, not an
    # import error at module load.
    from claude_agent_sdk import (  # type: ignore
        AssistantMessage,
        ClaudeAgentOptions,
        HookMatcher,
        ResultMessage,
        TextBlock,
        ToolUseBlock,
        query,
    )

    workspace = config.ensure_workspace()
    journal = RunJournal(workspace, spec.name)
    state = RunState()

    journal.event(
        "run_start",
        spec=spec.name,
        provider=spec.provider,
        region=spec.region,
        mode=config.mode,
        workspace=str(workspace),
        max_turns=config.max_turns,
        model=config.model,
    )

    option_kwargs: dict[str, Any] = dict(
        system_prompt=build_system_prompt(config),
        cwd=str(workspace),
        allowed_tools=["Bash", "Read", "Write", "Edit", "Glob", "Grep", "TodoWrite"],
        permission_mode="acceptEdits",
        max_turns=config.max_turns,
        hooks={
            "PreToolUse": [HookMatcher(matcher="Bash", hooks=[_make_pre_hook(config, state, journal)])],
            "PostToolUse": [HookMatcher(matcher="Bash", hooks=[_make_post_hook(state, journal)])],
        },
    )
    if config.model:
        option_kwargs["model"] = config.model

    options = ClaudeAgentOptions(**option_kwargs)

    result = RunResult(state=state)
    task_prompt = build_task_prompt(spec)

    async for message in query(prompt=task_prompt, options=options):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    print(block.text)
                    journal.event("assistant_text", text=block.text)
                elif isinstance(block, ToolUseBlock):
                    print(f"  ⏵ {block.name}: {_short(block.input)}")
                    journal.event("tool_use", tool=block.name, input=_short(block.input, 400))
        elif isinstance(message, ResultMessage):
            result.session_id = getattr(message, "session_id", None)
            result.cost_usd = getattr(message, "total_cost_usd", None)
            result.summary_text = getattr(message, "result", None)
            journal.event(
                "result",
                session_id=result.session_id,
                cost_usd=result.cost_usd,
                usage=getattr(message, "usage", None),
            )

    journal.event(
        "run_end",
        succeeded=result.succeeded,
        plan_ok=state.plan_ok,
        apply_ok=state.apply_ok,
        bash_calls=state.bash_calls,
        denied_calls=state.denied_calls,
        error_count=len(state.errors),
    )
    journal.write_summary(_summary_lines(spec, config, result))
    journal.close()
    return result


def _summary_lines(spec: Spec, config: RunConfig, result: RunResult) -> list[str]:
    s = result.state
    lines = [
        f"# daedalus run — {spec.name}",
        "",
        f"- mode: {config.mode}",
        f"- provider/region: {spec.provider} / {spec.region or '(default)'}",
        f"- succeeded: {result.succeeded}",
        f"- plan ok: {s.plan_ok}  |  apply ok: {s.apply_ok}",
        f"- bash calls: {s.bash_calls}  |  denied: {s.denied_calls}",
        f"- session: {result.session_id or '(n/a)'}",
        f"- cost: {f'${result.cost_usd:.4f}' if result.cost_usd is not None else '(n/a)'}",
    ]
    if s.errors:
        lines += ["", "## Errors seen during the run", ""]
        lines += [f"- {e}" for e in s.errors[-20:]]
    if result.summary_text:
        lines += ["", "## Agent summary", "", result.summary_text]
    return lines

"""Drive headless Claude Code (via the Claude Agent SDK) to build Terraform.

daedalus does not implement the build/deploy loop itself — Claude Code runs the
tool-use loop. This module wires the spec into a prompt, attaches guardrail hooks
(including the human-approval gate), streams the conversation, and records what
happened.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

from .config import Mode, RunConfig, Spec
from .guardrails import classify_bash
from .journal import RunJournal
from .prompts import build_system_prompt, build_task_prompt


@dataclass
class ApprovalRequest:
    """A gated command waiting for a human decision (approval mode)."""

    command: str
    reason: str
    context_tail: str = ""  # tail of the latest terraform output (usually the plan)


# Returns True to approve, False to reject.
Approver = Callable[[ApprovalRequest], Awaitable[bool]]
EventListener = Callable[[dict[str, Any]], None]


@dataclass
class RunState:
    bash_calls: int = 0
    denied_calls: int = 0
    approvals_granted: int = 0
    approvals_rejected: int = 0
    plan_ok: bool = False
    apply_ok: bool = False
    last_output_tail: str = ""
    errors: list[str] = field(default_factory=list)


@dataclass
class RunResult:
    state: RunState
    succeeded: bool = False
    session_id: str | None = None
    cost_usd: float | None = None
    summary_text: str | None = None


def _short(value: Any, limit: int = 160) -> str:
    text = value if isinstance(value, str) else str(value)
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def _tail(text: str, limit: int = 600) -> str:
    return text if len(text) <= limit else "…" + text[-limit:]


def _make_pre_hook(config: RunConfig, state: RunState, journal: RunJournal, approver: Approver | None):
    async def pre_hook(input_data: dict, tool_use_id: Any, context: Any) -> dict:
        command = (input_data.get("tool_input") or {}).get("command", "")
        decision, reason = classify_bash(command, config)
        state.bash_calls += 1
        journal.event("bash_pre", command=_short(command, 400), decision=decision, reason=reason)

        if decision == "approve":
            if approver is None:
                decision, reason = "deny", "human approval required but no approver is available"
            else:
                request = ApprovalRequest(
                    command=command, reason=reason, context_tail=state.last_output_tail
                )
                journal.event("approval_request", command=_short(command, 400), reason=reason)
                approved = await approver(request)
                journal.event("approval_decision", approved=approved, command=_short(command, 400))
                if approved:
                    state.approvals_granted += 1
                    return {}
                state.approvals_rejected += 1
                decision, reason = "deny", (
                    "REJECTED by the human reviewer. Do not retry this command. "
                    "Stop applying, summarize the current state, and finish."
                )

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
        state.last_output_tail = _tail(text, 4000)
        if "Apply complete!" in text:
            state.apply_ok = True
        if re.search(r"\bPlan:\s", text) or "No changes." in text or "Success!" in text:
            state.plan_ok = True
        for match in re.findall(r"^\s*Error:.*$", text, re.MULTILINE):
            state.errors.append(match.strip())
        journal.event("bash_post", output_tail=_tail(text))
        return {}

    return post_hook


async def run_agent(
    spec: Spec,
    config: RunConfig,
    approver: Approver | None = None,
    on_event: EventListener | None = None,
) -> RunResult:
    """Run one agent session and return the result.

    ``approver`` is awaited whenever a gated command (apply/destroy in approval
    mode) needs a human decision; CLI passes a terminal prompt, the GUI server
    passes a future resolved by the review panel.
    """
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
    journal = RunJournal(workspace, spec.name, listener=on_event)
    state = RunState()

    journal.event(
        "run_start",
        spec=spec.name,
        provider=spec.provider,
        region=spec.region,
        mode=config.mode.value,
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
            "PreToolUse": [
                HookMatcher(matcher="Bash", hooks=[_make_pre_hook(config, state, journal, approver)])
            ],
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

    # In plan mode success = a clean plan; otherwise success = apply completed.
    result.succeeded = state.plan_ok if config.mode is Mode.PLAN else state.apply_ok

    journal.event(
        "run_end",
        succeeded=result.succeeded,
        plan_ok=state.plan_ok,
        apply_ok=state.apply_ok,
        bash_calls=state.bash_calls,
        denied_calls=state.denied_calls,
        approvals_granted=state.approvals_granted,
        approvals_rejected=state.approvals_rejected,
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
        f"- mode: {config.mode_label}",
        f"- provider/region: {spec.provider} / {spec.region or '(default)'}",
        f"- succeeded: {result.succeeded}",
        f"- plan ok: {s.plan_ok}  |  apply ok: {s.apply_ok}",
        f"- bash calls: {s.bash_calls}  |  denied: {s.denied_calls}"
        f"  |  approvals: +{s.approvals_granted}/-{s.approvals_rejected}",
        f"- session: {result.session_id or '(n/a)'}",
        f"- cost: {f'${result.cost_usd:.4f}' if result.cost_usd is not None else '(n/a)'}",
    ]
    if s.errors:
        lines += ["", "## Errors seen during the run", ""]
        lines += [f"- {e}" for e in s.errors[-20:]]
    if result.summary_text:
        lines += ["", "## Agent summary", "", result.summary_text]
    return lines

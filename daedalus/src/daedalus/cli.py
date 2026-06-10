"""Command-line entry point for daedalus."""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

from .config import Mode, RunConfig, Spec


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="daedalus",
        description="Cloud infrastructure construction agent (generate, deploy and self-repair Terraform).",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Build infrastructure from a spec file.")
    run.add_argument("spec", help="Path to the infrastructure spec YAML.")
    run.add_argument("--workspace", default="./workspace", help="Terraform working directory (default: ./workspace).")
    run.add_argument(
        "--mode", choices=[m.value for m in Mode], default=Mode.PLAN.value,
        help="plan: dry-run only / approval: human approves each apply / auto: full autopilot (default: plan).",
    )
    run.add_argument("--allow-destroy", action="store_true", help="Allow `terraform destroy`.")
    run.add_argument("--max-turns", type=int, default=40, help="Max agent iterations (default: 40).")
    run.add_argument("--model", default=None, help="Model: opus | sonnet | haiku (default: SDK default).")

    serve = sub.add_parser("serve", help="Start the operation & review GUI server.")
    serve.add_argument("--host", default="127.0.0.1", help="Bind address (default: 127.0.0.1).")
    serve.add_argument("--port", type=int, default=8420, help="Port (default: 8420).")

    pull = sub.add_parser("pull", help="Fetch the project's code from its GitHub repo into the workspace.")
    pull.add_argument("spec", help="Spec YAML containing the `github:` section.")
    pull.add_argument("--workspace", default="./workspace", help="Destination directory.")

    push = sub.add_parser("push", help="Push the workspace to the project's GitHub repo via the API.")
    push.add_argument("spec", help="Spec YAML containing the `github:` section.")
    push.add_argument("--workspace", default="./workspace", help="Source directory.")
    push.add_argument("-m", "--message", default=None, help="Commit message.")

    return parser


def _load_spec(path: str) -> Spec | None:
    try:
        return Spec.load(path)
    except (FileNotFoundError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return None


async def _terminal_approver(request) -> bool:
    """Approval-mode gate for CLI runs: ask on the terminal."""
    print("\n" + "=" * 60)
    print("⏸  承認が必要です (approval mode)")
    print(f"   コマンド: {request.command}")
    print(f"   理由:     {request.reason}")
    if request.context_tail:
        print("   --- 直前の terraform 出力 (tail) ---")
        print("   " + "\n   ".join(request.context_tail.splitlines()[-25:]))
    print("=" * 60)
    answer = await asyncio.to_thread(input, "実行を許可しますか? [y/N]: ")
    return answer.strip().lower() in ("y", "yes")


def _run(args: argparse.Namespace) -> int:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("error: ANTHROPIC_API_KEY is not set. Export it before running daedalus.", file=sys.stderr)
        return 2

    spec = _load_spec(args.spec)
    if spec is None:
        return 2

    mode = Mode(args.mode)
    config = RunConfig(
        workspace=Path(args.workspace),
        mode=mode,
        allow_destroy=args.allow_destroy,
        max_turns=args.max_turns,
        model=args.model,
    )

    try:
        from .agent import run_agent
    except ImportError as exc:
        print(
            f"error: failed to import the agent ({exc}).\n"
            "Install dependencies first: pip install -e .",
            file=sys.stderr,
        )
        return 2

    print(f"daedalus: building '{spec.name}' [{config.mode_label}] in {config.workspace}")
    if mode is Mode.AUTO:
        print("⚠️  auto mode — applies WITHOUT human approval. Use sandbox accounts.")
    elif mode is Mode.APPROVAL:
        print("⏸  approval mode — each apply will pause for your y/N on this terminal.")

    approver = _terminal_approver if mode is Mode.APPROVAL else None
    result = asyncio.run(run_agent(spec, config, approver=approver))

    print()
    print(f"result: {'✅ succeeded' if result.succeeded else '❌ not complete'} "
          f"(plan_ok={result.state.plan_ok}, apply_ok={result.state.apply_ok}, "
          f"denied={result.state.denied_calls}, "
          f"approvals=+{result.state.approvals_granted}/-{result.state.approvals_rejected})")
    if result.cost_usd is not None:
        print(f"cost: ${result.cost_usd:.4f}")
    return 0 if result.succeeded else 1


def _serve(args: argparse.Namespace) -> int:
    try:
        import uvicorn
        from .server import app
    except ImportError as exc:
        print(
            f"error: GUI server dependencies missing ({exc}).\n"
            "Install them first: pip install -e .  (needs fastapi, uvicorn)",
            file=sys.stderr,
        )
        return 2
    print(f"daedalus GUI: http://{args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port, log_level="warning")
    return 0


def _github(args: argparse.Namespace, op: str) -> int:
    spec = _load_spec(args.spec)
    if spec is None:
        return 2
    try:
        from .github_sync import GitHubConfig, GitHubSyncError, pull_repo, push_workspace
        cfg = GitHubConfig.from_spec(spec)
        if op == "pull":
            files = pull_repo(cfg, Path(args.workspace))
            print(f"⬇ pulled {len(files)} files from {cfg.owner}/{cfg.repo}@{cfg.branch} -> {args.workspace}")
        else:
            message = args.message or f"daedalus: manual push ({spec.name})"
            info = push_workspace(cfg, Path(args.workspace), message)
            print(f"⬆ pushed {info['files']} files to {cfg.owner}/{cfg.repo}@{cfg.branch} "
                  f"({info['sha'][:7]}) {info['url']}")
        return 0
    except ImportError as exc:
        print(f"error: missing dependency ({exc}). Install with: pip install -e .", file=sys.stderr)
        return 2
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "run":
        return _run(args)
    if args.command == "serve":
        return _serve(args)
    if args.command in ("pull", "push"):
        return _github(args, args.command)
    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

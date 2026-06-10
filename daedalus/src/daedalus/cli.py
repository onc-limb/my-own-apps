"""Command-line entry point for daedalus."""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

from .config import RunConfig, Spec


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="daedalus",
        description="Cloud infrastructure construction agent (generate, deploy and self-repair Terraform).",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Build infrastructure from a spec file.")
    run.add_argument("spec", help="Path to the infrastructure spec YAML.")
    run.add_argument("--workspace", default="./workspace", help="Terraform working directory (default: ./workspace).")
    run.add_argument("--apply", action="store_true", help="Allow `terraform apply` (default: plan only).")
    run.add_argument("--allow-destroy", action="store_true", help="Allow `terraform destroy`.")
    run.add_argument("--max-turns", type=int, default=40, help="Max agent iterations (default: 40).")
    run.add_argument("--model", default=None, help="Model: opus | sonnet | haiku (default: SDK default).")
    return parser


def _run(args: argparse.Namespace) -> int:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("error: ANTHROPIC_API_KEY is not set. Export it before running daedalus.", file=sys.stderr)
        return 2

    try:
        spec = Spec.load(args.spec)
    except (FileNotFoundError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    config = RunConfig(
        workspace=Path(args.workspace),
        apply=args.apply,
        allow_destroy=args.allow_destroy,
        max_turns=args.max_turns,
        model=args.model,
    )

    try:
        from .agent import run_agent
    except ImportError as exc:
        print(
            f"error: failed to import the agent ({exc}).\n"
            "Install dependencies first: pip install -e .  (needs claude-agent-sdk, pyyaml)",
            file=sys.stderr,
        )
        return 2

    print(f"daedalus: building '{spec.name}' [{config.mode}] in {config.workspace}")
    if config.apply:
        print("⚠️  apply is ENABLED — this can create real, billable cloud resources.")

    result = asyncio.run(run_agent(spec, config))

    print()
    print(f"result: {'✅ succeeded' if result.succeeded else '❌ not complete'} "
          f"(plan_ok={result.state.plan_ok}, apply_ok={result.state.apply_ok}, "
          f"denied={result.state.denied_calls})")
    if result.cost_usd is not None:
        print(f"cost: ${result.cost_usd:.4f}")
    return 0 if result.succeeded else 1


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "run":
        return _run(args)
    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

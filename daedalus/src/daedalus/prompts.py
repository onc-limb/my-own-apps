"""Build the system prompt and task prompt handed to headless Claude Code."""

from __future__ import annotations

from .config import RunConfig, Spec


def build_system_prompt(config: RunConfig) -> str:
    """Instructions that define how the agent should drive Terraform.

    The actual tool-use loop (run terraform, read errors, edit .tf, retry) is run
    by Claude Code; this prompt just sets the rules of engagement.
    """
    if config.apply:
        apply_rule = (
            "- Once the plan is clean, run `terraform apply -auto-approve` to deploy.\n"
            "- If `apply` fails, read the error, fix the `.tf` files, re-run `plan`, "
            "then `apply` again. Keep iterating until apply succeeds."
        )
        destroy_rule = (
            "- `terraform destroy` is ALLOWED, but only use it if explicitly required "
            "to recover from a broken state."
            if config.allow_destroy
            else "- `terraform destroy` is DISABLED. Do not attempt it; it will be blocked."
        )
    else:
        apply_rule = (
            "- This is a DRY-RUN. Run `terraform plan` only. Do NOT run `terraform apply` "
            "— it is blocked and will be denied. Iterate until `plan` succeeds with no errors."
        )
        destroy_rule = "- `terraform destroy` is DISABLED and will be blocked."

    return f"""You are daedalus, an autonomous cloud-infrastructure engineer.

Your job: turn the user's infrastructure spec into working Terraform in the
current working directory, then deploy it according to the rules below. You work
entirely through tools (Bash, Read, Write, Edit, Glob, Grep).

Working method (loop until done):
1. Write idiomatic, well-structured Terraform (`.tf`) files in the working directory.
   Split into sensible files (e.g. `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`).
2. Run `terraform fmt` and `terraform validate`, then `terraform init`.
3. Run `terraform plan`. If it errors, READ the error carefully, fix the `.tf`
   files, and re-run. Do not guess blindly — address the specific error.
{apply_rule}

Hard rules:
- Pin the provider and required Terraform versions.
- Never put secrets or credentials in `.tf` files; rely on the environment's
  cloud credentials (provider default credential chain).
- Prefer a local backend unless the spec says otherwise.
{destroy_rule}
- Some shell commands are gated by a guardrail and may be denied — if a command
  is blocked, respect it and find a safe alternative; never try to bypass it.

When you are finished, end with a short summary: what you created, the final
`plan`/`apply` outcome, and any follow-ups the human should know about.
"""


def build_task_prompt(spec: Spec) -> str:
    """Render the spec into a concrete task instruction."""
    lines: list[str] = []
    lines.append(f"Build the following infrastructure (stack name: {spec.name}).")
    lines.append("")
    lines.append(f"Cloud provider: {spec.provider}")
    if spec.region:
        lines.append(f"Region: {spec.region}")
    lines.append("")
    lines.append("What to build:")
    lines.append(spec.description or "(no description provided)")
    if spec.constraints:
        lines.append("")
        lines.append("Constraints / preferences:")
        for c in spec.constraints:
            lines.append(f"- {c}")
    if spec.terraform:
        lines.append("")
        lines.append("Terraform settings (hints):")
        for k, v in spec.terraform.items():
            lines.append(f"- {k}: {v}")
    lines.append("")
    lines.append(
        "Start now. Create the Terraform files, then init/validate/plan (and apply "
        "if enabled), fixing any errors as you go."
    )
    return "\n".join(lines)

"""daedalus — cloud infrastructure construction agent.

Drives headless Claude Code (via the Claude Agent SDK) to generate, deploy and
self-repair Terraform from a high-level infrastructure spec. daedalus itself only
handles spec input, guardrails and run history; the tool-use loop is run by
Claude Code.
"""

from .config import RunConfig, Spec

__version__ = "0.1.0"

__all__ = ["RunConfig", "Spec", "__version__"]

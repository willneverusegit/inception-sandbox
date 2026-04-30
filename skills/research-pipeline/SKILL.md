---
name: research-pipeline
description: "REDIRECT: Use agentic-os:research-pipeline instead. This is an alias to avoid duplication."
metadata:
  alias_for: "agentic-os:research-pipeline"
  pattern: "skill-alias-pattern (Option 2 — non-triggering redirect)"
---

# Research Pipeline (Alias)

This skill is an **explicit redirect** to `agentic-os:research-pipeline`. The
canonical implementation lives in the agentic-os plugin and is maintained there.

**Why this alias exists:** the `multi-model-orchestrator` plugin documents that
web research uses the Perplexity → NotebookLM → Claude pipeline. The alias keeps
the plugin self-describing without duplicating the skill body.

**Why it has no trigger phrases:** if the user types "research" or "find sources",
the resolver should match the canonical `agentic-os:research-pipeline`, not this
redirect. Three identical trigger sets across plugins caused multi-match noise
(see `~/wiki/wiki/concepts/skill-alias-pattern.md`).

## How to invoke

- Implicit: just say "research X" — the canonical agentic-os skill matches via
  its own triggers.
- Explicit: `Skill multi-model-orchestrator:research-pipeline` (rare; only useful
  if the user wants to confirm the alias is wired up).

## Fallback when agentic-os is not installed

The alias does **not** ship a usable implementation. If `agentic-os` is missing,
the user will see no research-pipeline skill at all and must:

1. Install agentic-os (`claude plugin install agentic-os --scope user`), or
2. Use NotebookLM directly via the standalone `notebooklm` skill (notebooklm-py
   Python API; the user-globale CLAUDE.md mandates this over plugin variants).

For NotebookLM operations always prefer the user skill `notebooklm`
(notebooklm-py) over plugin-side MCP variants.

---
name: research-pipeline
description: Token-optimierte Research-Pipeline via Perplexity → NotebookLM → Claude. Spart ~95% Claude-Tokens bei Web-Recherche.
triggers:
  - "research"
  - "recherchiere"
  - "find sources"
  - "quellen suchen"
  - "web research"
  - "deep research"
  - "recherche starten"
depends-on: agentic-os:research-pipeline (canonical version), notebooklm (user-skill, Python API)
---

# Research Pipeline

> **VERWEIS:** Dieser Skill ist ein Alias fuer `agentic-os:research-pipeline`.
> Die kanonische Version wird in agentic-os gepflegt.
> Siehe: `~/.claude/plugins/cache/agentic-os-marketplace/agentic-os/2.0.0/skills/research-pipeline/SKILL.md`

Nutze den Skill `agentic-os:research-pipeline` — er enthaelt die vollstaendige
Dokumentation der Token-optimierten Research-Pipeline (Perplexity → NotebookLM → Claude).

**Wichtig:** Fuer NotebookLM-Operationen den User-Skill `notebooklm` (notebooklm-py) verwenden,
nicht die Plugin-Skills.

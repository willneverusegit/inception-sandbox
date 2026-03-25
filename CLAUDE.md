# Multi-Model Orchestrator (Inception-Sandbox)

## Plugin-Info
Dieses Projekt ist ein eigenstaendiges Claude Code Plugin. Es kann in jedem Projekt
via `claude plugin install <pfad>` installiert und ueber `/orchestrate` aufgerufen werden.
Bestehende direkte Zugriffe (z.B. ueber `scripts/`, `skills/`) funktionieren weiterhin.

## Was ist das
Multi-Model-Orchestrierung via tmux + Git Worktrees. Claude Code und OpenAI Codex laufen lokal in separaten tmux-Sessions, isoliert durch Git Worktrees. Keine API-Keys noetig — nutzt OAuth (Claude Max Plan + Codex Desktop App).

## Architektur
- **Host:** Lokaler Rechner mit tmux
- **Claude Session** (tmux window "claude"): `claude -p --dangerously-skip-permissions`
- **Codex Session** (tmux window "codex"): `codex --approval-mode full-auto`
- **Isolation:** Git Worktrees — jeder Agent arbeitet in eigener Kopie des Repos
- **Kommunikation:** Dateisystem (PLAN.md, Ergebnisse) + tmux send-keys/capture-pane

## Multi-Model Routing

| Task-Typ | Agent | Warum |
|----------|-------|-------|
| Planung, Architektur | Claude | Besseres Reasoning |
| Code-Review, Security | Claude | Konservativer, gruendlicher |
| Implementierung, Refactoring | Codex | 2-3x token-effizienter |
| Test-Fix Loops, Linting | Codex | Full-auto, keine Rueckfragen |
| Feature (komplex) | Dual | Claude plant → Codex baut → Claude reviewed |

## Orchestrator-Modi
- `--mode single --agent claude` — Nur Claude (Default)
- `--mode single --agent codex` — Nur Codex
- `--mode dual` — Claude plant → Codex implementiert → Claude reviewed

## Voraussetzungen
- tmux installiert (WSL2 empfohlen auf Windows)
- `claude` CLI authentifiziert (Max Plan, OAuth)
- `codex` CLI authentifiziert (Desktop App, OAuth)
- Git Repo als Arbeitsverzeichnis

## Konventionen
- **Plugin-Manifest:** `plugin.json`
- **Plugin-Agents:** `agents/` (planner, implementer, reviewer, router)
- **Slash-Command:** `commands/orchestrate.md` → `/orchestrate`
- Orchestrator-Skripte in `scripts/` (weiterhin fuer Script-Modus)
- Skills in `skills/{name}/SKILL.md`
- Worktrees werden nach jedem Task-Zyklus geloescht (Amnesie-Prinzip)
- Ergebnisse in `output/` (plan, implementation, review, diff)

## Research-Workflow (Standard)
Web-Recherche IMMER ueber die Research-Pipeline ausfuehren:
1. **Perplexity** (Suche + Links) → 2. **NotebookLM** (Ingest + RAG) → 3. **Claude** (liest nur Ergebnis)
Ergebnisse in `research/<topic>-<date>.md` speichern. Siehe `skills/research-pipeline/SKILL.md`.

## Sicherheit
- Jeder Agent arbeitet in eigener Git Worktree — keine Cross-Pollution
- Worktrees sind detached HEAD — koennen den Main Branch nicht beschaedigen
- Ergebnisse muessen vom User reviewed werden bevor sie gemerged werden
- Kein Docker noetig — Isolation ueber Git, nicht Container

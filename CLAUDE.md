# Inception-Sandbox

## Was ist das
Multi-Model-Orchestrierung via tmux & Docker. Ein lokaler Claude-Code-Agent (Host) steuert Claude und Codex Agenten in isolierten Docker-Containern fern. Kommunikation laeuft ueber tmux send-keys / capture-pane.

## Architektur
- **Host-Agent:** Lokaler Claude Code als Orchestrator (liest/schreibt nur via tmux)
- **Claude Container** (`inception-claude`): Claude Code mit `--dangerously-skip-permissions`
- **Codex Container** (`inception-codex`): OpenAI Codex mit `--approval-mode full-auto`
- **Shared Workspace:** Docker Volume das beide Container sehen
- **Kommunikation:** `tmux send-keys` (Prompt senden) / `tmux capture-pane` (Output lesen)
- **Isolation:** Beide Container sind wegwerfbar — bei Fehler destroy + rebuild

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

## Tech Stack
- **Docker** (Container-Runtime, 2 Container: Claude + Codex)
- **tmux** (Terminal-Multiplexer fuer async Kommunikation)
- **Claude Code CLI** (`claude --dangerously-skip-permissions` im Container)
- **OpenAI Codex CLI** (`codex --approval-mode full-auto` im Container)
- **Plattform:** Windows + WSL2 / Git Bash

## Voraussetzungen
- Docker Desktop installiert und lauffaehig
- ANTHROPIC_API_KEY in `docker/.env`
- OPENAI_API_KEY in `docker/.env`
- WSL2 empfohlen fuer tmux auf Windows

## Konventionen
- Docker-Images in `docker/` (Dockerfile = Claude, Dockerfile.codex = Codex)
- Orchestrator-Skripte in `scripts/`
- Skills in `skills/{name}/SKILL.md`
- Container werden nach jedem Task-Zyklus zerstoert (Amnesie-Prinzip)
- Ergebnisse in `output/` (plan, implementation, review, workspace_snapshot)

## Research-Workflow (Standard)
Web-Recherche IMMER ueber die Research-Pipeline ausfuehren:
1. **Perplexity** (Suche + Links) → 2. **NotebookLM** (Ingest + RAG) → 3. **Claude** (liest nur Ergebnis)
Ergebnisse in `research/<topic>-<date>.md` speichern. Siehe `skills/research-pipeline/SKILL.md`.

## Sicherheit
- Host fuehrt NIEMALS Code aus, der aus dem Container kommt, ohne Review
- Container teilen nur /workspace Volume — kein Host-Dateisystem
- API-Keys via .env Datei, nie im Image
- Codex Container hat kein ANTHROPIC_API_KEY, Claude Container hat kein OPENAI_API_KEY

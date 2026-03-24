# Inception-Sandbox

## Was ist das
Multi-Model-Orchestrierung via tmux & Docker. Ein lokaler Claude-Code-Agent (Host) steuert einen oder mehrere KI-Agenten in isolierten Docker-Containern fern. Kommunikation laeuft ueber tmux send-keys / capture-pane.

## Architektur
- **Host-Agent:** Lokaler Claude Code als Orchestrator (liest/schreibt nur via tmux)
- **Container-Agent:** Claude Code mit `--dangerously-skip-permissions` in Docker
- **Kommunikation:** `tmux send-keys` (Prompt senden) / `tmux capture-pane` (Output lesen)
- **Isolation:** Jeder Container ist wegwerfbar — bei Fehler destroy + rebuild aus Basis-Image

## Use Cases
1. **Riskante Code-Experimente** — Refactoring, Migrationen, Bash-Skripte ohne Host-Risiko
2. **Multi-Modell-Zusammenarbeit** — Claude + Gemini CLI + OpenAI Codex parallel orchestrieren
3. **Selbst-Patching** — Agent patcht eigene CLI-Dateien im Container
4. **Integration mit Ralph-Wiggum-Loop** — Container als "Fabrik" fuer Phase 2 (Ausfuehrung)

## Tech Stack
- **Docker** (Container-Runtime)
- **tmux** (Terminal-Multiplexer fuer async Kommunikation)
- **Claude Code CLI** (`claude -p` auf Host, `claude --dangerously-skip-permissions` im Container)
- **Optional:** Gemini CLI, OpenAI Codex CLI
- **Plattform:** Windows + WSL2 / Git Bash

## Voraussetzungen
- Docker Desktop installiert und lauffaehig
- tmux im Container-Image installiert
- API-Keys fuer Claude (und optional Gemini/Codex) im Container verfuegbar
- WSL2 empfohlen fuer tmux auf Windows

## Konventionen
- Docker-Images leben in `docker/`
- Orchestrator-Skripte in `scripts/`
- Skills in `skills/{name}/SKILL.md`
- Container werden nach jedem Task-Zyklus zerstoert (Amnesie-Prinzip)
- Host-Agent schreibt Ergebnisse in `.agent-memory/` bevor Container stirbt
- Keine persistenten Volumes fuer Code — nur fuer Ergebnisse/Logs

## Sicherheit
- Host fuehrt NIEMALS Code aus, der aus dem Container kommt, ohne Review
- Container hat keinen Zugriff auf Host-Dateisystem (ausser explizite Mounts)
- API-Keys werden via Docker Secrets oder Env-Vars injiziert, nie im Image

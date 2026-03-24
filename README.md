# Inception-Sandbox

Multi-Model-Orchestrierung via tmux & Docker fuer Claude Code.

## Idee

Ein lokaler Claude-Code-Agent ("Host") steuert KI-Agenten in isolierten Docker-Containern fern.
Der Host sendet Prompts via `tmux send-keys` und liest Ergebnisse via `tmux capture-pane`.
Im Container laeuft Claude Code mit `--dangerously-skip-permissions` — voellig autonom, aber sicher isoliert.

```
┌─────────────────────────────────────────────────┐
│  HOST (lokales System)                          │
│                                                 │
│  Claude Code (Orchestrator)                     │
│    │                                            │
│    ├── tmux send-keys ──► Docker Container A    │
│    │                       └─ Claude Code       │
│    │                          (autonomous)      │
│    │                                            │
│    ├── tmux send-keys ──► Docker Container B    │
│    │                       └─ Gemini CLI        │
│    │                                            │
│    └── tmux capture-pane ◄── Output lesen       │
└─────────────────────────────────────────────────┘
```

## Projektstruktur

```
inception-sandbox/
├── CLAUDE.md              # Projekt-Instruktionen fuer Claude Code
├── README.md              # Diese Datei
├── docker/
│   ├── Dockerfile         # Basis-Image mit Claude CLI + tmux
│   └── docker-compose.yml # Container-Definitionen
├── scripts/
│   ├── orchestrator.sh    # Host-seitiger Orchestrator
│   ├── send-prompt.sh     # Prompt an Container senden
│   └── read-output.sh     # Output aus Container lesen
├── skills/                # Claude Code Skills
│   └── inception/
│       └── SKILL.md
└── .agent-memory/         # Persistente Ergebnisse/Logs
```

## Use Cases

| Use Case | Beschreibung |
|----------|-------------|
| Riskante Experimente | Refactoring, Migrationen — Fehler bleiben im Container |
| Multi-Modell | Claude + Gemini + Codex parallel orchestrieren |
| Selbst-Patching | Agent patcht eigene CLI-Dateien sicher |
| Ralph-Wiggum Phase 2 | Worker-Phase des Self-Improving-Loops |

## Voraussetzungen

- Docker Desktop (oder WSL2 + Docker Engine)
- tmux (im Container-Image)
- Claude Code API Key
- Optional: Gemini API Key, OpenAI API Key

## Status

**Phase: Planung** — Projektstruktur angelegt, Use Cases definiert. Naechster Schritt: Dockerfile + Orchestrator-Skript.

## Quellen

- YK: "32 Claude Code Tips" (Tipps 8, 10, 20)
- YK: "45 Claude Code Tips" (Tipps 9, 11, 21)
- NotebookLM Research: "Agentic AI & Self-Improving Workflows"

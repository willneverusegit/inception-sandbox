# Inception-Sandbox

Multi-Model-Orchestrierung: Claude Code + OpenAI Codex via tmux.

## Idee

Claude und Codex laufen lokal in separaten tmux-Sessions. Jeder Agent arbeitet
in einer eigenen Git Worktree fuer Isolation. Keine API-Keys noetig — OAuth reicht.

```
┌─────────────────────────────────────────────────┐
│  tmux session "inception"                       │
│                                                 │
│  Window "claude"          Window "codex"        │
│  ┌──────────────┐        ┌──────────────┐       │
│  │ claude -p     │        │ codex         │       │
│  │ --dangerously │        │ --full-auto   │       │
│  │ -skip-perms   │        │ --quiet       │       │
│  │              │        │              │       │
│  │ Worktree A   │        │ Worktree B   │       │
│  └──────────────┘        └──────────────┘       │
│         │                       │               │
│         └───── shared via ──────┘               │
│                file copy                        │
│                (PLAN.md, diffs)                  │
└─────────────────────────────────────────────────┘
```

## Projektstruktur

```
inception-sandbox/
├── CLAUDE.md              # Projekt-Instruktionen
├── README.md              # Diese Datei
├── scripts/
│   ├── orchestrator.sh    # Multi-Model Orchestrator (single/dual mode)
│   ├── send-prompt.sh     # Prompt an Agent senden via tmux
│   └── read-output.sh     # Output aus Agent lesen via tmux
├── skills/
│   ├── inception/SKILL.md
│   ├── codex-worker/SKILL.md
│   └── research-pipeline/SKILL.md
├── research/              # Perplexity/NotebookLM Recherche-Ergebnisse
└── output/                # Ergebnisse der Orchestrator-Laeufe
```

## Schnellstart

```bash
# Voraussetzungen: tmux, claude CLI (Max Plan), codex CLI (Desktop App)

# Einfach: Claude loest Task alleine
./scripts/orchestrator.sh --prompt "Fix the login bug"

# Codex fuer Bulk-Arbeit
./scripts/orchestrator.sh --agent codex --prompt "Refactore alle Tests zu pytest"

# Dual-Mode: Claude plant → Codex baut → Claude reviewed
./scripts/orchestrator.sh --mode dual --prompt "Add pagination to the API"

# Auf beliebigem Repo arbeiten
./scripts/orchestrator.sh --mode dual --repo ~/projects/myapp --prompt "Add auth"
```

## Modi

| Modus | Ablauf | Wann nutzen |
|-------|--------|-------------|
| `single --agent claude` | Claude alleine | Review, Planung, Security |
| `single --agent codex` | Codex alleine | Refactoring, Linting, Bulk |
| `dual` | Claude → Codex → Claude | Komplexe Features |

### Dual-Mode Ablauf

1. **Claude plant** → Erstellt `PLAN.md` mit Architektur + Schritten
2. **Codex implementiert** → Liest Plan, schreibt Code autonom
3. **Claude reviewed** → Prueft Code gegen Plan, gibt PASS/FAIL
4. **Amnesia** → Worktrees geloescht, Ergebnisse in `output/`

## Voraussetzungen

- **tmux** — `sudo apt install tmux` (WSL2) oder via Git Bash
- **Claude CLI** — authentifiziert ueber Max Plan (OAuth, kein API Key)
- **Codex CLI** — authentifiziert ueber Desktop App (OAuth, kein API Key)
- **Git** — fuer Worktree-Isolation

## Warum kein Docker?

Claude Max Plan und Codex Desktop App authentifizieren via OAuth/Browser,
nicht via API-Key. Docker-Container koennten sich nicht einloggen.
tmux + Git Worktrees bieten ausreichende Isolation fuer lokale Entwicklung.

## Quellen

- NotebookLM: "Multi-Model Orchestration & Sandboxed Agents"
- Perplexity Research: Codex CLI + Claude Code Integration
- Agent-of-Empires (aoe): tmux-basierter Session Manager

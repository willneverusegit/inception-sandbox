---
name: codex-swarm
description: >
  Spawnt N parallele Codex-Agents via tmux, orchestriert von Claude Opus 4.6.
  Jeder Agent laeuft in eigener Worktree mit konfigurierbarem Modell und Prompt.
triggers:
  - "codex swarm"
  - "spawn codex agents"
  - "parallel codex"
  - "multi codex"
  - "codex schwarm"
  - "viele agents spawnen"
  - "swarm orchestrate"
---

# Codex Swarm Skill

Claude Opus 4.6 als Oberagent orchestriert N parallele Codex-Agents.
Jeder Agent arbeitet isoliert in eigener Git Worktree via tmux (WSL2/Ubuntu).

## Architektur

```
┌──────────────────────────────────────────────────────┐
│  Claude Opus 4.6 (Oberagent)                         │
│  ────────────────────────────                        │
│  1. Task entgegennehmen + Konfiguration parsen       │
│  2. Task in N Sub-Tasks zerlegen (oder N identisch)  │
│  3. N tmux-Panes spawnen mit je einem Codex-Agent    │
│  4. Parallel warten auf Completion                   │
│  5. Ergebnisse sammeln + reviewen + mergen           │
├──────────────────────────────────────────────────────┤
│  tmux session: codex-swarm-<timestamp>               │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐    ┌─────────┐│
│  │ Agent 0 │ │ Agent 1 │ │ Agent 2 │ ...│ Agent N ││
│  │ WT: /0  │ │ WT: /1  │ │ WT: /2  │    │ WT: /N  ││
│  │ Model:  │ │ Model:  │ │ Model:  │    │ Model:  ││
│  │ 5.4-mini│ │ 5.3-cdx │ │ 5.4     │    │ 5.4-mini││
│  └─────────┘ └─────────┘ └─────────┘    └─────────┘│
└──────────────────────────────────────────────────────┘
```

## Konfiguration

Der Swarm wird ueber eine JSON-Konfiguration oder CLI-Flags gesteuert:

### CLI-Aufruf

```bash
# Einfach: N Agents mit gleichem Task
./scripts/codex-swarm.sh \
  --repo ~/projects/myapp \
  --agents 5 \
  --model gpt-5.4-mini \
  --prompt "Schreibe Unit-Tests fuer alle Dateien in src/utils/"

# Mit Reasoning-Level
./scripts/codex-swarm.sh \
  --repo ~/projects/myapp \
  --agents 3 \
  --model gpt-5.3-codex \
  --reasoning high \
  --prompt "Refactore alle Dateien in src/ zu async/await"

# Pro Agent eigener Task (via JSON-Config)
./scripts/codex-swarm.sh \
  --repo ~/projects/myapp \
  --config swarm-config.json

# Gemischt: verschiedene Modelle
./scripts/codex-swarm.sh \
  --repo ~/projects/myapp \
  --agents 3 \
  --models "gpt-5.4-mini,gpt-5.3-codex,gpt-5.4" \
  --prompt "Implementiere die TODO-Kommentare in diesem Repo"
```

### JSON-Config (swarm-config.json)

```json
{
  "repo": "/path/to/project",
  "timeout": 600,
  "agents": [
    {
      "name": "tests-utils",
      "model": "gpt-5.4-mini",
      "reasoning": "low",
      "prompt": "Write unit tests for src/utils/"
    },
    {
      "name": "tests-api",
      "model": "gpt-5.3-codex",
      "reasoning": "high",
      "prompt": "Write integration tests for src/api/"
    },
    {
      "name": "refactor-models",
      "model": "gpt-5.4",
      "reasoning": "medium",
      "prompt": "Refactor src/models/ to use dataclasses"
    },
    {
      "name": "docs",
      "model": "gpt-5.4-mini",
      "reasoning": "low",
      "prompt": "Generate docstrings for all public functions"
    }
  ]
}
```

## Ablauf im Detail

### Phase 1: Setup (Claude Opus 4.6)

1. Konfiguration parsen (CLI-Flags oder JSON)
2. Validierung: Repo existiert, tmux verfuegbar, codex CLI vorhanden
3. tmux-Session erstellen: `codex-swarm-<timestamp>`
4. N Git Worktrees erstellen (parallel)
5. Pro Agent: `safe.directory` konfigurieren

### Phase 2: Spawn (Parallel via tmux)

Fuer jeden Agent i=0..N-1:
```bash
tmux send-keys -t "codex-swarm-$TS:$i" \
  "cd $WORKTREE_DIR && codex exec --sandbox workspace-write \
   --model $MODEL '$PROMPT' > $OUTPUT_DIR/agent-$i.txt 2>&1; \
   echo DONE > $OUTPUT_DIR/agent-$i.done" Enter
```

### Phase 3: Wait (Polling)

```bash
# Warte bis alle .done Marker existieren
while [[ $(ls $OUTPUT_DIR/*.done 2>/dev/null | wc -l) -lt $N ]]; do
  sleep 10
done
```

Timeout: Standardmaessig 600s (10 min), konfigurierbar via `--timeout`.

### Phase 4: Collect (Claude Opus 4.6)

1. Diffs aus allen Worktrees extrahieren
2. Agent-Outputs sammeln
3. Ergebnisse in `output/swarm-<timestamp>/` ablegen:
   ```
   output/swarm-<timestamp>/
   ├── config.json              # Verwendete Konfiguration
   ├── agent-0.txt              # Stdout von Agent 0
   ├── agent-0.diff             # Git diff von Agent 0
   ├── agent-1.txt
   ├── agent-1.diff
   ├── ...
   └── summary.md               # Oberagent-Zusammenfassung
   ```

### Phase 5: Review + Merge (Claude Opus 4.6)

1. Alle Diffs reviewen auf Konflikte
2. Nicht-konfliktierende Changes automatisch mergen
3. Konflikte markieren fuer manuelles Review
4. `summary.md` mit Ergebnissen pro Agent erstellen

## Modell-Optionen

| Modell | Staerken | Empfehlung |
|--------|----------|------------|
| `gpt-5.4` | Neuestes Frontier-Modell, bestes Reasoning | Komplexe Features, Architektur-Tasks |
| `gpt-5.4-mini` | Schnell, guenstig, solides Reasoning | Tests, Docs, Linting, Boilerplate |
| `gpt-5.3-codex` | Coding-optimiert (Default) | Refactoring, Implementierung, Bug-Fixes |
| `gpt-5.2-codex` | Aelterer Codex, stabil | Fallback bei 5.3 Problemen |
| `gpt-5.2` | General-purpose | Nicht-Code Tasks |
| `gpt-5.1-codex-max` | Max-Kontext, grosse Codebases | Mono-Repo Refactoring |
| `gpt-5.1-codex-mini` | Minimal, nur medium/high | Budget-Option |

**Hinweis:** Mit ChatGPT-Abo (kein API-Key) — `o3`/`o4-mini` sind NICHT verfuegbar.

## Reasoning Levels

Alle Modelle unterstuetzen konfigurierbare Reasoning-Tiefe:

| Level | Beschreibung | Empfehlung |
|-------|-------------|------------|
| `low` | Schnell, minimales Reasoning | Mechanische Tasks (Linting, Docs, Boilerplate) |
| `medium` | Balanciert (Default) | Alltaegliche Coding-Tasks |
| `high` | Tiefes Reasoning | Komplexe Refactorings, Bug-Fixes |
| `xhigh` | Maximum Reasoning | Architektur-Entscheidungen, Security-Reviews |

CLI: `--reasoning <level>` oder per Agent in JSON-Config: `"reasoning": "high"`

## Voraussetzungen

- **WSL2/Ubuntu** mit tmux installiert
- `codex` CLI authentifiziert (OAuth via Desktop App)
- `claude` CLI authentifiziert (Max Plan)
- Git Repo als Zielverzeichnis

## Limits und Hinweise

- Jeder Agent = eigenes Codex-Kontextfenster + API-Call
- Bei N=10 Agents: 10x parallele Codex-Sessions
- tmux-Sessions bleiben nach Fehler bestehen → manuell killen: `tmux kill-session -t codex-swarm-*`
- Worktrees werden nach Completion geloescht (Amnesie)
- Bei Merge-Konflikten: Claude Opus markiert, User entscheidet
- Codex `--sandbox workspace-write` erlaubt nur Schreiben im Worktree, kein Netzwerk

## Wann diesen Skill nutzen

**JA — Swarm nutzen wenn:**
- Viele unabhaengige Tasks parallelisiert werden koennen
- Grosses Refactoring ueber viele Dateien/Module
- Test-Generierung fuer gesamtes Projekt
- Bulk-Operationen (Docs, Linting, Migration)

**NEIN — Einzelagent nutzen wenn:**
- Tasks voneinander abhaengen (sequentiell)
- Nur 1-2 Dateien betroffen
- Komplexes Reasoning noetig (→ Claude direkt)

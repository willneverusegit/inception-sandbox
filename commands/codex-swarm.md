---
name: codex-swarm
description: "Spawn N parallel Codex agents orchestrated by Claude Opus. Supports task decomposition, per-agent models, and automated review."
arguments:
  - name: prompt
    description: "High-level task for the swarm"
    required: true
  - name: agents
    description: "Number of parallel agents (default: 3)"
    required: false
  - name: model
    description: "Codex model for all agents (default: gpt-5.3-codex)"
    required: false
  - name: repo
    description: "Git repo to work on (default: current directory)"
    required: false
  - name: decompose
    description: "Let Claude split the task into sub-tasks (yes/no, default: yes)"
    required: false
---

# /codex-swarm — Parallel Codex Agent Swarm

Starte einen Codex Swarm fuer: **$ARGUMENTS.prompt**

## Konfiguration
- **Agents:** ${ARGUMENTS.agents:-3}
- **Modell:** ${ARGUMENTS.model:-gpt-5.3-codex}
- **Repository:** ${ARGUMENTS.repo:-aktuelles Verzeichnis}
- **Task-Zerlegung:** ${ARGUMENTS.decompose:-yes}

## Ausfuehrung

### Schritt 1: Vorbereitung

Stelle sicher, dass WSL2 mit tmux verfuegbar ist. Bestimme das Repo:
```bash
REPO="${ARGUMENTS.repo:-$(pwd)}"
```

### Schritt 2: Swarm starten

Fuehre das Script in WSL2 aus:

**Mit Task-Zerlegung (Standard):**
```bash
wsl bash -c "cd '$(wslpath -u "$REPO")' && bash '${CLAUDE_PLUGIN_ROOT}/scripts/codex-swarm.sh' \
  --repo '$(wslpath -u "$REPO")' \
  --agents ${ARGUMENTS.agents:-3} \
  --model '${ARGUMENTS.model:-gpt-5.3-codex}' \
  --decompose \
  --prompt '${ARGUMENTS.prompt}'"
```

**Ohne Task-Zerlegung (decompose=no):**
```bash
wsl bash -c "cd '$(wslpath -u "$REPO")' && bash '${CLAUDE_PLUGIN_ROOT}/scripts/codex-swarm.sh' \
  --repo '$(wslpath -u "$REPO")' \
  --agents ${ARGUMENTS.agents:-3} \
  --model '${ARGUMENTS.model:-gpt-5.3-codex}' \
  --prompt '${ARGUMENTS.prompt}'"
```

### Schritt 3: Ergebnisse praesentieren

Nach Abschluss:
1. Lies die `review.md` aus dem Output-Verzeichnis
2. Zeige dem User eine Zusammenfassung pro Agent
3. Liste Diffs die sicher gemerged werden koennen
4. Warne bei Konflikten oder fehlgeschlagenen Agents
5. Frage ob die Changes gemerged werden sollen

### Schritt 4: Merge (optional)

Wenn der User die Changes mergen will:
1. Lies die empfohlenen Diffs aus `review.md`
2. Wende die Patches an: `git apply <agent>.diff`
3. Erstelle einen Commit mit Swarm-Referenz

## Hinweise
- Erfordert WSL2/Ubuntu mit tmux und codex CLI
- Jeder Agent arbeitet in eigener Git Worktree (Isolation)
- Claude Opus reviewed automatisch alle Ergebnisse
- Bei --decompose zerlegt Claude den Task in unabhaengige Sub-Tasks

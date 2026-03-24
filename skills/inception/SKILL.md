---
name: inception
description: Run a task in an isolated Docker sandbox via tmux orchestration
triggers:
  - "run in sandbox"
  - "inception"
  - "isoliert ausfuehren"
  - "docker sandbox"
---

# Inception Sandbox Skill

Fuehre eine Aufgabe in einem isolierten Docker-Container aus.

## Ablauf

1. Starte einen frischen Container (`docker compose up -d --build`)
2. Sende den Task via `tmux send-keys` an den Container-Claude
3. Warte auf Ergebnis via `tmux capture-pane` polling
4. Extrahiere Ergebnisse aus `/output/`
5. Zerstoere den Container (Amnesie)

## Verwendung

```bash
# Via Orchestrator-Skript
./scripts/orchestrator.sh --prompt "Refactore main.py zu async"

# Via Task-Datei
./scripts/orchestrator.sh tasks/refactor-main.md

# Einzelne Schritte
./scripts/send-prompt.sh "Schreibe Tests fuer utils.py"
./scripts/read-output.sh --wait
```

## Sicherheitshinweise

- Der Container hat `--dangerously-skip-permissions` — das ist beabsichtigt
- Host-Dateisystem ist NICHT gemountet (ausser explizit konfiguriert)
- Container wird nach jedem Run zerstoert
- Ergebnisse muessen vom Host-Agent reviewed werden bevor sie uebernommen werden

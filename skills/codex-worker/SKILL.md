---
name: codex-worker
description: Route implementation tasks to OpenAI Codex in a sandboxed container for autonomous code churn
triggers:
  - "codex"
  - "codex implementieren"
  - "let codex handle"
  - "codex worker"
  - "implementierung an codex"
---

# Codex Worker Skill

Routet Implementierungs-Tasks an OpenAI Codex in einem isolierten Docker-Container.

## Wann Codex statt Claude nutzen

| Task-Typ | Bestes Modell | Warum |
|----------|--------------|-------|
| Architektur-Planung | **Claude** | Besseres Reasoning, Kontext-Verstaendnis |
| Code-Review / Security | **Claude** | Konservativer, sicherheitsbewusster |
| Mass-Refactoring | **Codex** | 2-3x token-effizienter, aggressiver |
| Test-and-Fix Loops | **Codex** | Full-auto, keine Rueckfragen |
| Boilerplate / Scaffolding | **Codex** | Schneller, billiger |
| Linter-Fixes anwenden | **Codex** | Mechanische Arbeit |
| Feature-Implementierung | **Dual** | Claude plant, Codex implementiert |

## Verwendung

### Single-Agent (nur Codex)
```bash
# Codex erledigt Task autonom
./scripts/orchestrator.sh --agent codex --prompt "Refactore alle Tests zu pytest"

# Oder direkt
./scripts/send-prompt.sh --agent codex "Rename all snake_case vars to camelCase"
```

### Dual-Mode (Claude + Codex)
```bash
# Claude plant → Codex implementiert → Claude reviewed
./scripts/orchestrator.sh --mode dual --prompt "Add pagination to the API"
```

### Ablauf im Dual-Mode
```
┌─────────────────────────────────────────────────┐
│  1. Claude (Planner)                            │
│     → Analysiert Task, erstellt PLAN.md         │
│                                                 │
│  2. Codex (Implementer)                         │
│     → Liest PLAN.md, schreibt Code, Tests       │
│     → Full-auto, keine Rueckfragen              │
│                                                 │
│  3. Claude (Reviewer)                           │
│     → Prueft Code gegen Plan                    │
│     → PASS/FAIL Verdict                         │
│                                                 │
│  4. Amnesia                                     │
│     → Beide Container zerstoert                 │
│     → Ergebnisse in output/                     │
└─────────────────────────────────────────────────┘
```

## Codex CLI Flags

| Flag | Wert | Erklaerung |
|------|------|-----------|
| `--approval-mode` | `full-auto` | Kein Rueckfragen, volle Autonomie |
| `--quiet` | — | Weniger Output-Noise |
| `--sandbox` | `docker` (implizit) | Container IST die Sandbox |
| `--model` | default | o3/o4-mini je nach OpenAI config |

## Kosten-Optimierung

- Codex ist **2-3x token-effizienter** fuer Code-Churn als Claude
- Dual-Mode: Claude Opus nur fuer Plan+Review (~2 kurze Aufrufe), Codex fuer den langen Impl-Part
- Bei reinem Refactoring/Linting: nur Codex nutzen, Claude ueberspringen

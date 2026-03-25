---
name: orchestrate
description: "Run a multi-model orchestration pipeline (single-agent, dual-mode, or auto-routed)"
arguments:
  - name: prompt
    description: "The task to execute"
    required: true
  - name: mode
    description: "Pipeline mode: single, dual, or auto (default: auto)"
    required: false
  - name: agent
    description: "Agent for single mode: claude or codex (default: claude)"
    required: false
  - name: repo
    description: "Git repo to work on (default: current directory)"
    required: false
---

# /orchestrate — Multi-Model Pipeline

Starte eine Multi-Model-Pipeline fuer: **$ARGUMENTS.prompt**

## Konfiguration
- **Modus:** ${ARGUMENTS.mode:-auto}
- **Agent:** ${ARGUMENTS.agent:-claude}
- **Repository:** ${ARGUMENTS.repo:-aktuelles Verzeichnis}

## Ausfuehrung

### Bei mode=auto:
1. Spawne den `model-router` Agent zur Analyse der Aufgabe
2. Router entscheidet: single, dual, oder custom
3. Fuehre die gewaehlte Pipeline aus

### Bei mode=single:
Fuehre das Script aus:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/orchestrator.sh \
  --mode single \
  --agent "${ARGUMENTS.agent:-claude}" \
  --repo "${ARGUMENTS.repo:-.}" \
  --prompt "${ARGUMENTS.prompt}"
```

### Bei mode=dual:
Fuehre das Script aus:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/orchestrator.sh \
  --mode dual \
  --repo "${ARGUMENTS.repo:-.}" \
  --prompt "${ARGUMENTS.prompt}"
```

Pipeline: `model-planner` → `model-implementer` → `model-reviewer`

## Nach Abschluss
- Plan: `output/plan_*.txt`
- Implementation: `output/implementation_*.txt`
- Review: `output/review_*.txt`
- Diff: `output/changes_*.diff`

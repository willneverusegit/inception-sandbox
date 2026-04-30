# CONSUMERS — multi-model-orchestrator

Plugins, die Skills aus diesem Plugin (`multi-model-orchestrator`) extern aufrufen.
**Bei Breaking Changes diese Konsumenten warnen** — die Skill-Namen und Aufruf-Schnittstellen
sind effektive Public-API.

> Stand 2026-04-30. Pflege-Hinweis: bei jeder Aenderung an `skills/codex-swarm/SKILL.md`,
> `skills/codex-worker/SKILL.md` oder `skills/inception/SKILL.md` (Frontmatter, Trigger,
> Output-Format) diese Tabelle als Pflichtchecks durchgehen.

## Konsumenten

### `agent-orchestrator-plugin` — Phase 3 Execution

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `multi-model-orchestrator:codex-swarm` |
| Wo aufgerufen | `agent-orchestrator-plugin/skills/agent-orchestrator/SKILL.md` (Phase 3 — Execution) |
| Kopplung | **hart** (Cross-Plugin-Hard-Dependency, dokumentiert in der Phase-3-Sektion seit 2026-04-30) |
| Erwartetes Verhalten | bis zu 5 parallele Codex-Instanzen, Modelle: gpt-5-4 / gpt-5.4-mini / gpt-5.3-codex-spark, mit `--decompose` automatische Subtask-Zerlegung, mit `--review` automatischer Opus-Review der Diffs |
| Fallback wenn nicht installiert | Inline-Opus-Self-Execution bei <3 Subtasks (gewollt). Bei ≥3 Subtasks: explizite Fehlermeldung an den User |
| Bei Breaking Change warnen? | JA — agent-orchestrator-Phase-3 hängt direkt am Output-Format |

### `dome-loop` — Make-Phase parallel mode

| Aspekt | Wert |
|---|---|
| Aufgerufener Skill | `multi-model-orchestrator:codex-swarm` (alternativ `codex:rescue`) |
| Wo aufgerufen | `dome-loop/skills/dome-loop/SKILL.md` Phase M, Mode `parallel` + `dome-loop/docs/ARCHITECTURE.md` Cross-Plugin-Tabelle |
| Kopplung | **weich** (Konsument hat dokumentierten sequenziellen Fallback) |
| Erwartetes Verhalten | mehrere Codex-Instanzen bauen Varianten der gleichen Idee, dome-loop vergleicht und wählt |
| Fallback wenn nicht installiert | sequentielle Implementierung — Claude baut alle Varianten nacheinander |
| Bei Breaking Change warnen? | JA, aber mit niedrigerer Prio — Fallback ist robust |

## Skills, die KEINE externen Konsumenten haben

- `skills/codex-worker/SKILL.md` — bisher nicht extern aufgerufen, kann frei iteriert werden
- `skills/inception/SKILL.md` — `optional-mode`-Skill ohne externe Konsumenten (siehe SKILL-Frontmatter); kann frei iteriert werden, solange der Docker-Pfad als Capability erhalten bleibt
- `skills/research-pipeline/SKILL.md` — Redirect-Alias auf `agentic-os:research-pipeline`,
  bewusst ohne Trigger (siehe `wiki/concepts/skill-alias-pattern.md`)

## Aenderungs-Checkliste bei Breaking Changes

Wenn die folgenden Aspekte am `codex-swarm` Skill geaendert werden, vor dem Commit eine
Issue/PR-Note in den Repos der Konsumenten oeffnen:

1. Frontmatter-Trigger (Erkennungs-Phrasen)
2. Output-Format (Was schreibt der Skill nach `output/` oder `.agent-memory/`?)
3. CLI-Flags (`--decompose`, `--review`, Anzahl-Limits)
4. Skill-Name selbst (Re-Naming bricht alle Konsumenten — bewusster Major-Bump erforderlich)
5. Modell-Naming (gpt-5-4 etc.) — nicht intern relevant, aber im Doku-Konsens-Ablauf erwaehnt

## Verwandte Dokumente

- `agent-orchestrator-plugin/skills/agent-orchestrator/SKILL.md` (Phase 3, hard-dep-Sektion)
- `dome-loop/docs/ARCHITECTURE.md` (Phase-Delegationen-Tabelle)
- `wiki/concepts/skill-alias-pattern.md` (research-pipeline-Alias-Mechanik)
- `wiki/todos/2026-04-30-cross-plugin-contract-callouts.md` (Quelle dieser Datei)

# Multi-Model Orchestrator

## Identitaet (klargestellt 2026-04-30)

| Aspekt | Wert | Hinweis |
|---|---|---|
| **Plugin-Name** (Public API) | `multi-model-orchestrator` | aus `.claude-plugin/plugin.json` `name`-Feld; das ist der einzige Name, den andere Plugins via `multi-model-orchestrator:codex-swarm` aufrufen |
| **Repo-Verzeichnis** | `inception-sandbox` | historischer Name, NICHT umbenannt: ein Repo-Rename wuerde Cache-Pfad, Marketplace-Eintrag, lokale Skript-Pfade und Submodule-Referenzen aus `self-improve/` (archiviert) brechen, ohne Public-API-Mehrwert (der Manifest-Name ist die externe API) |
| **Marketplace-Name** | `multi-model-orchestrator-marketplace` | aus `.claude-plugin/marketplace.json` |
| **Slash-Command** | `/orchestrate` (commands/orchestrate.md) und `/codex-swarm` (commands/codex-swarm.md) | |

Konsequenz: Wer das Plugin aufruft, sollte immer `multi-model-orchestrator:<skill>` schreiben.
Der Repo-Pfad `inception-sandbox/` ist Backstage-Implementierungsdetail.

## Was ist das

**Hauptmodus:** Multi-Model-Orchestrierung via **tmux + Git Worktrees**. Claude Code und OpenAI Codex laufen lokal in separaten tmux-Sessions, isoliert durch Git Worktrees. Keine API-Keys noetig — nutzt OAuth (Claude Max Plan + Codex Desktop App).

**Optionaler Docker-Sandbox-Modus** (`skills/inception/SKILL.md`): Fuer destruktive oder
sensible Tasks bietet das Plugin alternativ eine Container-basierte Isolation an, in der
Claude mit `--dangerously-skip-permissions` lauft (Container-Boundary statt Permission-System).
Dieser Modus ist **nicht Teil des aktuellen Standard-Flows** — `scripts/orchestrator.sh`
nutzt tmux+Worktrees, kein Docker. Der Skill bleibt im Plugin als dokumentierte
Alternative fuer Anwender, die die Docker-Schicht aktivieren wollen.

## Architektur
- **Host:** Lokaler Rechner mit tmux
- **Claude Session** (tmux window "claude"): `claude -p --dangerously-skip-permissions`
- **Codex Session** (tmux window "codex"): `codex --approval-mode full-auto`
- **Isolation:** Git Worktrees — jeder Agent arbeitet in eigener Kopie des Repos
- **Kommunikation:** Dateisystem (PLAN.md, Ergebnisse) + tmux send-keys/capture-pane

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

## Voraussetzungen
- tmux installiert (WSL2 empfohlen auf Windows)
- `claude` CLI authentifiziert (Max Plan, OAuth)
- `codex` CLI authentifiziert (Desktop App, OAuth)
- Git Repo als Arbeitsverzeichnis

## Konventionen
- **Plugin-Manifest:** `plugin.json`
- **Plugin-Agents:** `agents/` (planner, implementer, reviewer, router)
- **Slash-Commands:** `commands/orchestrate.md` → `/orchestrate`, `commands/codex-swarm.md` → `/codex-swarm`
- Orchestrator-Skripte in `scripts/` (weiterhin fuer Script-Modus)
- Skills in `skills/{name}/SKILL.md`
- Worktrees werden nach jedem Task-Zyklus geloescht (Amnesie-Prinzip)
- Ergebnisse in `output/` (plan, implementation, review, diff)

## Research-Workflow (Standard)
Web-Recherche IMMER ueber die Research-Pipeline ausfuehren:
1. **Perplexity** (Suche + Links) → 2. **NotebookLM** (Ingest + RAG) → 3. **Claude** (liest nur Ergebnis)
Ergebnisse in `research/<topic>-<date>.md` speichern. Siehe `skills/research-pipeline/SKILL.md`.

## Sicherheit (Hauptmodus)
- Jeder Agent arbeitet in eigener Git Worktree — keine Cross-Pollution
- Worktrees sind detached HEAD — koennen den Main Branch nicht beschaedigen
- Ergebnisse muessen vom User reviewed werden bevor sie gemerged werden
- **Hauptmodus braucht KEIN Docker** — Isolation ueber Git, nicht Container

## Sicherheit (optionaler Docker-Sandbox-Modus)
- Fuer den `skills/inception/`-Pfad: Container-Boundary statt Permission-System
- Container hat `--dangerously-skip-permissions` und kein Host-Filesystem-Mount (ausser `/output/`)
- Container wird nach jedem Run zerstoert (Amnesie); Ergebnisse nur ueber `/output/` extrahierbar
- **Wichtig:** das `--dangerously-skip-permissions`-Pattern ist NUR mit Container-Isolation sicher.
  Niemals auf dem Host oder in nicht-isolierten Umgebungen verwenden.

## Agent Learnings

<!-- Auto-maintained by wrap-up skill. Last updated: 2026-03-26 -->
- Codex in WSL braucht eigene Auth: `cp /mnt/c/Users/domes/.codex/{auth.json,config.toml} ~/.codex/`
- ChatGPT-Abo: nur gpt-5.x Modelle (5.4, 5.3-codex, 5.2-codex, etc.) — o3/o4-mini brauchen API-Key
- Codex MCP-Server in Swarm deaktivieren: `-c mcp_servers='{}'` vermeidet Auth-Noise
- Reasoning-Level per Agent: `-c model_reasoning_effort=low|medium|high|xhigh`
- Worktree Diff-Erfassung: erst `git add -A` dann `git diff --cached HEAD` fuer neue Files
- Research-Pipeline nutzt jetzt notebooklm-py CLI statt MCP-Plugin (zuverlaessiger, parallel-faehig)
- Codex Swarm Skill: `skills/codex-swarm/` + `scripts/codex-swarm.sh` (N parallele Agents via tmux/WSL2)
- Codex Swarm Slash-Command: `/codex-swarm` in `commands/codex-swarm.md`
- Codex Swarm `--decompose`: Claude zerlegt High-Level-Task automatisch in N unabhaengige Sub-Tasks
- Codex Swarm Review-Phase: Claude Opus reviewed alle Diffs automatisch nach Completion → `review.md`

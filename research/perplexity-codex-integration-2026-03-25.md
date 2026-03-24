# Perplexity Research: Codex CLI Integration with Claude Code
> Source: Perplexity AI, 2026-03-25
> Query: OpenAI Codex CLI integration with Claude Code multi-agent orchestration

---

## 1) Codex CLI Capabilities & Limits (2025-2026)

Codex CLI is a local terminal client for OpenAI's coding agents (o-series, GPT-5.x).

### Key Capabilities
- **Local terminal integration:** Runs as `codex` CLI in your working directory
- **3 Approval modes:**
  - `suggest` — proposes diffs, you confirm
  - `auto-edit` — auto-applies file edits, asks before risky commands
  - `full-auto` — reads/writes files + runs commands autonomously
- **Sandbox:** Optional Docker sandbox, network-restricted except OpenAI API
- **Parallel agents:** Backend supports multiple agents working on tasks in parallel
- **Model selection:** o3, o4-mini, GPT-5.x Codex variants

### Sandbox Matrix
| Sandbox | suggest | auto-edit | full-auto |
|---------|---------|-----------|-----------|
| docker | Safest | Practical default | Autonomous + isolated |
| none | Safe | Moderate | Maximum power, minimum safety |

### Limitations
- No built-in orchestrator — parallelism is DIY (tmux, scripts)
- Sandboxed I/O can't reach local services without explicit config
- Terminal-centric — for service-style use, drop to OpenAI API
- Safety modes add latency via confirmations

---

## 2) Running Codex alongside Claude Code

### a) Tmux Layout (simplest)
```bash
tmux new -s agents
# Pane 1: claude code --dangerously-skip-permissions (admin/planner)
# Pane 2: codex --approval-mode auto-edit --sandbox docker (implementer)
# Pane 3: claude code (reviewer)
```
Tell admin Claude: "Pane 2 = Codex implementer, Pane 3 = Claude reviewer. Coordinate via repo + TODO.md."

### b) Docker Isolation
- **Codex container:** Mount repo at /workspace, `--network none`, full-auto
- **Claude container:** Read-only /workspace access, proposes diffs, no direct commits
- Or: Claude on host, only Codex sandboxed

### c) Direct CLI Orchestration (Python/Shell)
- Spawn processes via `tmux new-session -d -s codex 'codex --approval-mode full-auto ...'`
- Use `tmux send-keys` to issue prompts, `tmux capture-pane` to read output
- Hybrid: Claude Code as high-level planner, Codex as autonomous worker

---

## 3) Where Codex Adds Value Beyond Claude Code

### a) Different Model Bias (Ensemble)
- **Codex:** Optimized for aggressive, autonomous edit-run cycles
- **Claude:** Prioritizes explanation, safety, instruction following
- **Best pattern:** Claude designs architecture → Codex implements → Claude reviews

### b) Autonomous "Janitor" Tasks
Codex full-auto is tuned for hands-off tasks:
- Mass refactors (rename symbols, change frameworks)
- Test-and-fix loops across monorepos
- Applying linters and fixing violations
- "Queue a task and let it run" — no conversational back-and-forth needed

### c) Parallel Implementation + Code Review
- Same task → both agents implement → diff and pick best parts
- Codex = implementer + test runner, Claude = critic + security reviewer
- GitHub Agent HQ supports running both in same repo

---

## 4) Tools for Managing Codex + Claude

### Agent-of-Empires (aoe)
- Rust-powered tmux manager for multiple agent sessions
- Launches Claude/Codex in Docker sandboxes
- Status overview, attach/detach, background agents

### codex-cli Claude Skill
- Published skill wrapping Codex CLI for Claude's MCP ecosystem
- Claude becomes planner, calls Codex as sub-agent
- Supports GPT-5.x Codex models

### GitHub Agent HQ
- Run Claude + Codex as repo-scoped agents
- Assign tasks via issues, review outputs as PRs
- Compare outputs from multiple agents on same task

---

## 5) Cost Comparison

### Subscription Tiers
| | Claude | Codex/OpenAI |
|---|---|---|
| Base | ~$20/mo (Pro), ~5h/week coding | ~$20/mo (Plus), GPT-5.x + Codex |
| Heavy | ~$100-200/mo (Max) | ~$200/mo (Pro) |

### Token Efficiency
- **Codex:** Often 2-3x more token-efficient per coding task
- **Claude:** Higher token consumption, especially in verbose thinking modes
- **API:** Claude Sonnet ~$3/M input, $15/M output. OpenAI o4-mini cheaper.

### Orchestration Implication
| Role | Best Model | Why |
|------|-----------|-----|
| Architecture/Risk | Claude Opus | Extra reasoning justified |
| Implementation/Churn | Codex full-auto | Efficient, cheaper |
| Review/Security | Claude Sonnet | Strong analysis |
| Mechanical/Bulk | Codex o4-mini | Cheapest option |

---

## 6) Real-World Repos & Implementations

- **Multi-agent Claude API repo:** Coordinator/Researcher/Implementer/Critic — swap Implementer to Codex
- **codex-cli Claude skill:** Production Codex+Claude integration via MCP
- **Agent-of-Empires:** Rust tmux manager for Claude/Codex Docker sessions
- **GitHub Agent HQ:** First-class multi-agent Claude+Codex support
- **Tmux automation guides:** Each pane = different agent, dedicate some to Codex

### Minimal DIY Architecture
```
Orchestrator (Python/Rust)
├── Anthropic API → Planning/Review (Claude)
├── OpenAI API or Codex CLI → Workers (Codex)
├── Execution: tmux sessions or Docker containers
├── Shared repo volume + task queue (JSON/GitHub issues)
└── Optional: aoe-style manager for observability
```

---

## Key Links
- Codex CLI Docs: https://openai.com/index/codex/
- codex-cli Claude Skill: https://agentskills.dev (search codex-cli)
- Agent-of-Empires: https://www.reddit.com/r/codex/comments/1qkrj1z/
- GitHub Agent HQ: https://github.blog/agent-hq/

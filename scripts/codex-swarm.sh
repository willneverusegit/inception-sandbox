#!/usr/bin/env bash
# Codex Swarm Orchestrator
# Spawns N parallel Codex agents via tmux, each in its own git worktree.
# Requires: WSL2/Ubuntu, tmux, codex CLI, git
#
# Usage:
#   ./codex-swarm.sh --repo ~/project --agents 5 --model gpt-5.4-mini --prompt "Write tests"
#   ./codex-swarm.sh --repo ~/project --config swarm-config.json
#   ./codex-swarm.sh --repo ~/project --agents 3 --model gpt-5.3-codex --reasoning high --prompt "Fix TODOs"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Defaults ---
REPO_DIR=""
NUM_AGENTS=0
MODEL="gpt-5.3-codex"
MODELS=""
REASONING="medium"
PROMPT=""
CONFIG_FILE=""
TIMEOUT=600
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_NAME="codex-swarm-${TIMESTAMP}"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)    REPO_DIR="$2"; shift 2 ;;
        --agents)  NUM_AGENTS="$2"; shift 2 ;;
        --model)   MODEL="$2"; shift 2 ;;
        --models)  MODELS="$2"; shift 2 ;;
        --prompt)    PROMPT="$2"; shift 2 ;;
        --reasoning) REASONING="$2"; shift 2 ;;
        --config)    CONFIG_FILE="$2"; shift 2 ;;
        --timeout)   TIMEOUT="$2"; shift 2 ;;
        *)         echo "Unknown argument: $1"; exit 1 ;;
    esac
done

REPO_DIR="${REPO_DIR:-$(pwd)}"
OUTPUT_DIR="$PROJECT_ROOT/output/swarm-${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# --- Config mode: read from JSON ---
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        exit 1
    fi

    if command -v jq &>/dev/null; then
        NUM_AGENTS=$(jq '.agents | length' "$CONFIG_FILE")
        REPO_DIR=$(jq -r '.repo // empty' "$CONFIG_FILE")
        REPO_DIR="${REPO_DIR:-$(pwd)}"
        TIMEOUT=$(jq -r '.timeout // 600' "$CONFIG_FILE")
    else
        echo "ERROR: jq required for JSON config parsing"
        exit 1
    fi
fi

# --- Validate ---
if [[ "$NUM_AGENTS" -lt 1 ]]; then
    cat <<'USAGE'
Usage: codex-swarm.sh [OPTIONS]

Options:
  --repo <path>         Git repo to work on (default: current dir)
  --agents <N>          Number of parallel agents
  --model <model>       Model for all agents (default: o4-mini)
  --models <m1,m2,...>  Per-agent models (comma-separated)
  --prompt <text>       Prompt for all agents
  --config <file.json>  JSON config with per-agent settings
  --timeout <seconds>   Max wait time per agent (default: 600)

Examples:
  ./codex-swarm.sh --repo ~/app --agents 5 --model o4-mini --prompt "Write tests"
  ./codex-swarm.sh --config swarm-config.json
  ./codex-swarm.sh --repo ~/app --agents 3 --model gpt-5.3-codex --reasoning high --prompt "Fix TODOs"
USAGE
    exit 1
fi

if ! command -v tmux &>/dev/null; then
    echo "ERROR: tmux not found. Install with: sudo apt install tmux"
    exit 1
fi

if ! command -v codex &>/dev/null; then
    echo "ERROR: codex CLI not found. Install from: https://github.com/openai/codex"
    exit 1
fi

# --- Split models if provided ---
IFS=',' read -ra MODEL_LIST <<< "${MODELS:-}"

get_model() {
    local idx="$1"
    if [[ ${#MODEL_LIST[@]} -gt 0 && -n "${MODEL_LIST[$idx]:-}" ]]; then
        echo "${MODEL_LIST[$idx]}"
    else
        echo "$MODEL"
    fi
}

# --- Get agent config from JSON ---
get_agent_config() {
    local idx="$1"
    local field="$2"
    if [[ -n "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
        jq -r ".agents[$idx].$field // empty" "$CONFIG_FILE"
    fi
}

echo "============================================"
echo " Codex Swarm Orchestrator"
echo " Agents: $NUM_AGENTS | Timeout: ${TIMEOUT}s"
echo " Repo: $REPO_DIR"
echo " Session: $SESSION_NAME"
echo "============================================"
echo ""

# --- Phase 1: Create worktrees ---
echo "[1/5] Creating $NUM_AGENTS worktrees..."
declare -a WORKTREES
for i in $(seq 0 $((NUM_AGENTS - 1))); do
    wt_dir="$REPO_DIR/.worktrees/swarm-${TIMESTAMP}-${i}"
    mkdir -p "$(dirname "$wt_dir")"

    if git -C "$REPO_DIR" worktree add "$wt_dir" HEAD --detach >/dev/null 2>&1; then
        git config --global --add safe.directory "$wt_dir" 2>/dev/null || true
    else
        echo "  WARN: worktree failed for agent $i, using copy" >&2
        mkdir -p "$wt_dir"
        cp -r "$REPO_DIR"/* "$wt_dir/" 2>/dev/null || true
    fi

    WORKTREES+=("$wt_dir")
    echo "  Agent $i: $wt_dir"
done

# --- Phase 2: Create tmux session + spawn agents ---
echo ""
echo "[2/5] Spawning $NUM_AGENTS agents in tmux..."
tmux new-session -d -s "$SESSION_NAME" -x 200 -y 50

for i in $(seq 0 $((NUM_AGENTS - 1))); do
    # Create window (first window already exists at i=0)
    if [[ $i -gt 0 ]]; then
        tmux new-window -t "$SESSION_NAME"
    fi
    tmux rename-window -t "$SESSION_NAME:$i" "agent-$i"

    # Determine model, reasoning, and prompt for this agent
    agent_model=$(get_model "$i")
    agent_reasoning="$REASONING"
    agent_prompt="$PROMPT"
    agent_name="agent-$i"

    if [[ -n "$CONFIG_FILE" ]]; then
        cfg_model=$(get_agent_config "$i" "model")
        cfg_prompt=$(get_agent_config "$i" "prompt")
        cfg_name=$(get_agent_config "$i" "name")
        cfg_reasoning=$(get_agent_config "$i" "reasoning")
        [[ -n "$cfg_model" ]] && agent_model="$cfg_model"
        [[ -n "$cfg_prompt" ]] && agent_prompt="$cfg_prompt"
        [[ -n "$cfg_name" ]] && agent_name="$cfg_name"
        [[ -n "$cfg_reasoning" ]] && agent_reasoning="$cfg_reasoning"
    fi

    wt_dir="${WORKTREES[$i]}"
    out_file="$OUTPUT_DIR/${agent_name}.txt"
    done_file="$OUTPUT_DIR/${agent_name}.done"

    echo "  Agent $i ($agent_name): model=$agent_model reasoning=$agent_reasoning"

    # Save agent config for reference
    cat > "$OUTPUT_DIR/${agent_name}.meta.json" <<METAEOF
{"index": $i, "name": "$agent_name", "model": "$agent_model", "reasoning": "$agent_reasoning", "worktree": "$wt_dir"}
METAEOF

    # Send command to tmux window
    # -c mcp_servers='{}': disable MCP servers (avoids auth noise in swarm)
    # -c model_reasoning_effort: set reasoning level per agent
    tmux send-keys -t "$SESSION_NAME:$i" \
        "cd '$wt_dir' && codex exec --sandbox workspace-write -c mcp_servers='{}' -c model_reasoning_effort='$agent_reasoning' --model '$agent_model' '$agent_prompt' > '$out_file' 2>&1; echo \$? > '$done_file'" Enter
done

# --- Phase 3: Wait for completion ---
echo ""
echo "[3/5] Waiting for all agents to complete (timeout: ${TIMEOUT}s)..."

elapsed=0
while true; do
    done_count=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.done" 2>/dev/null | wc -l)
    if [[ "$done_count" -ge "$NUM_AGENTS" ]]; then
        echo "  All $NUM_AGENTS agents completed."
        break
    fi

    if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
        echo "  TIMEOUT after ${TIMEOUT}s. $done_count/$NUM_AGENTS agents completed."
        echo "  Remaining agents will be left running in tmux session: $SESSION_NAME"
        break
    fi

    echo "  $done_count/$NUM_AGENTS done (${elapsed}s elapsed)..."
    sleep 10
    elapsed=$((elapsed + 10))
done

# --- Phase 4: Collect results ---
echo ""
echo "[4/5] Collecting results..."

for i in $(seq 0 $((NUM_AGENTS - 1))); do
    agent_name="agent-$i"
    if [[ -n "$CONFIG_FILE" ]]; then
        cfg_name=$(get_agent_config "$i" "name")
        [[ -n "$cfg_name" ]] && agent_name="$cfg_name"
    fi

    wt_dir="${WORKTREES[$i]}"
    diff_file="$OUTPUT_DIR/${agent_name}.diff"
    stat_file="$OUTPUT_DIR/${agent_name}.stat"

    # Extract git diff from worktree (add untracked files first so new files show in diff)
    if [[ -d "$wt_dir/.git" ]] || git -C "$wt_dir" rev-parse --git-dir &>/dev/null 2>&1; then
        git -C "$wt_dir" add -A 2>/dev/null || true
        git -C "$wt_dir" diff --cached HEAD > "$diff_file" 2>/dev/null || true
        git -C "$wt_dir" diff --cached HEAD --stat > "$stat_file" 2>/dev/null || true
    fi

    # Report
    done_file="$OUTPUT_DIR/${agent_name}.done"
    if [[ -f "$done_file" ]]; then
        exit_code=$(cat "$done_file")
        diff_lines=$(wc -l < "$diff_file" 2>/dev/null || echo 0)
        echo "  $agent_name: exit=$exit_code, diff=$diff_lines lines"
    else
        echo "  $agent_name: NOT COMPLETED (timeout)"
    fi
done

# --- Phase 5: Cleanup ---
echo ""
echo "[5/5] Cleanup..."
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
git -C "$REPO_DIR" worktree prune 2>/dev/null || true
rm -rf "$REPO_DIR/.worktrees/swarm-${TIMESTAMP}-"* 2>/dev/null || true

echo ""
echo "============================================"
echo " Swarm complete."
echo " Results: $OUTPUT_DIR/"
echo "============================================"
echo ""
ls -la "$OUTPUT_DIR/"

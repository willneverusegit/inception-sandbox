#!/usr/bin/env bash
# Inception-Sandbox Multi-Model Orchestrator (Local/tmux version)
# Runs Claude and Codex locally via tmux sessions + git worktrees for isolation.
# No API keys needed — uses OAuth (Claude Max Plan + Codex Desktop App).
#
# Usage: ./orchestrator.sh --prompt "Fix the bug in main.py"
# Usage: ./orchestrator.sh --mode dual --prompt "Implement feature X"
# Usage: ./orchestrator.sh --agent codex --prompt "Refactor all tests"
# Usage: ./orchestrator.sh <task-file.md>
#
# Modes:
#   single (default) — one agent handles the task
#   dual             — Claude plans, Codex implements, Claude reviews
#
# Prerequisites:
#   - tmux installed (WSL2 or Git Bash)
#   - claude CLI authenticated (Max Plan)
#   - codex CLI authenticated (Desktop App)
#   - git repo as working directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/output"
mkdir -p "$OUTPUT_DIR"

TMUX_SESSION="inception"
MODE="single"
AGENT="claude"
TASK=""
REPO_DIR=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)   MODE="$2"; shift 2 ;;
        --agent)  AGENT="$2"; shift 2 ;;
        --prompt) TASK="$2"; shift 2 ;;
        --repo)   REPO_DIR="$2"; shift 2 ;;
        *)
            if [[ -f "$1" ]]; then
                TASK=$(cat "$1"); shift
            else
                echo "Unknown argument: $1"; exit 1
            fi ;;
    esac
done

if [[ -z "$TASK" ]]; then
    cat <<'USAGE'
Usage: orchestrator.sh [OPTIONS] --prompt "task description"
       orchestrator.sh [OPTIONS] <task-file.md>

Options:
  --mode single|dual    Routing mode (default: single)
  --agent claude|codex  Agent for single mode (default: claude)
  --repo <path>         Git repo to work on (default: current dir)

Examples:
  ./orchestrator.sh --prompt "Fix the login bug"
  ./orchestrator.sh --agent codex --prompt "Refactor tests to pytest"
  ./orchestrator.sh --mode dual --prompt "Add pagination to the API"
  ./orchestrator.sh --mode dual --repo ~/projects/myapp --prompt "Add auth"
USAGE
    exit 1
fi

REPO_DIR="${REPO_DIR:-$(pwd)}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================"
echo " Inception-Sandbox Orchestrator (Local)"
echo " Mode: $MODE | Agent: $AGENT"
echo " Repo: $REPO_DIR"
echo "============================================"

# --- Helper: create git worktree for isolation ---
create_worktree() {
    local name="$1"
    local wt_dir="$REPO_DIR/.worktrees/inception-${name}-${TIMESTAMP}"
    mkdir -p "$(dirname "$wt_dir")"

    # Create worktree from current HEAD
    git -C "$REPO_DIR" worktree add "$wt_dir" HEAD --detach 2>/dev/null || {
        # Fallback: just copy the repo if worktree fails
        echo "      WARN: git worktree failed, using direct copy"
        mkdir -p "$wt_dir"
        cp -r "$REPO_DIR"/* "$wt_dir/" 2>/dev/null || true
    }
    echo "$wt_dir"
}

# --- Helper: cleanup worktrees ---
cleanup_worktrees() {
    echo "      Cleaning up worktrees..."
    git -C "$REPO_DIR" worktree prune 2>/dev/null || true
    rm -rf "$REPO_DIR/.worktrees/inception-"* 2>/dev/null || true
}

# --- Helper: send command to tmux pane and wait ---
send_and_wait() {
    local pane="$1"
    local cmd="$2"
    local output_file="$3"
    local marker="__INCEPTION_DONE_${RANDOM}__"

    # Send command with done-marker
    tmux send-keys -t "${TMUX_SESSION}:${pane}" \
        "${cmd} ; echo '${marker}'" Enter

    # Poll until marker appears
    echo "      Waiting for completion..."
    while true; do
        sleep 3
        local output
        output=$(tmux capture-pane -t "${TMUX_SESSION}:${pane}" -p -S -500 2>/dev/null || echo "")
        if echo "$output" | grep -q "$marker"; then
            # Save everything before the marker
            echo "$output" | sed "/${marker}/d" > "$output_file"
            return 0
        fi
    done
}

# --- Phase 1: Setup tmux session ---
echo ""
echo "[1/6] Setting up tmux session..."

# Kill old session if exists
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

if [[ "$MODE" == "dual" ]]; then
    # Create worktrees for isolation
    CLAUDE_DIR=$(create_worktree "claude")
    CODEX_DIR=$(create_worktree "codex")
    echo "      Claude worktree: $CLAUDE_DIR"
    echo "      Codex worktree:  $CODEX_DIR"

    # Create tmux session with 2 panes
    tmux new-session -d -s "$TMUX_SESSION" -c "$CLAUDE_DIR"
    tmux rename-window -t "${TMUX_SESSION}:0" "claude"
    tmux new-window -t "$TMUX_SESSION" -n "codex" -c "$CODEX_DIR"
    echo "      tmux session ready (2 windows: claude + codex)."

elif [[ "$MODE" == "single" ]]; then
    WORK_DIR=$(create_worktree "$AGENT")
    echo "      Worktree: $WORK_DIR"

    tmux new-session -d -s "$TMUX_SESSION" -c "$WORK_DIR"
    tmux rename-window -t "${TMUX_SESSION}:0" "$AGENT"
    echo "      tmux session ready (1 window: $AGENT)."
fi

# --- Route based on mode ---
if [[ "$MODE" == "single" ]]; then
    # ==================== SINGLE AGENT MODE ====================
    echo ""
    echo "[2/6] Sending task to $AGENT..."

    RESULT_FILE="$OUTPUT_DIR/result_${AGENT}_${TIMESTAMP}.txt"

    case "$AGENT" in
        claude)
            CMD="claude -p --dangerously-skip-permissions '$(echo "$TASK" | sed "s/'/'\\\\''/g")' 2>&1 | tee /dev/stderr"
            ;;
        codex)
            CMD="codex --approval-mode full-auto --quiet '$(echo "$TASK" | sed "s/'/'\\\\''/g")' 2>&1 | tee /dev/stderr"
            ;;
    esac

    send_and_wait "0" "$CMD" "$RESULT_FILE"

    echo ""
    echo "[3/6] Task complete."

elif [[ "$MODE" == "dual" ]]; then
    # ==================== DUAL MODE ====================

    # --- Phase 2: Claude plans ---
    echo ""
    echo "[2/6] Claude: Planning..."
    PLAN_PROMPT="You are a senior architect. Analyze this task and create a detailed, step-by-step implementation plan. Output ONLY the plan as a numbered list, no code. Be specific about files, functions, and changes needed.

TASK: $TASK"

    PLAN_FILE="$OUTPUT_DIR/plan_${TIMESTAMP}.txt"
    PLAN_CMD="claude -p --dangerously-skip-permissions '$(echo "$PLAN_PROMPT" | sed "s/'/'\\\\''/g")' 2>&1 | tee /dev/stderr"
    send_and_wait "claude" "$PLAN_CMD" "$PLAN_FILE"
    echo "      Plan saved to: $PLAN_FILE"

    # Copy plan to codex worktree
    cp "$PLAN_FILE" "$CODEX_DIR/PLAN.md"

    # --- Phase 3: Codex implements ---
    echo ""
    echo "[3/6] Codex: Implementing plan..."
    IMPL_PROMPT="Read PLAN.md in the current directory and implement every step. Write code, create files, run tests if possible. Work until all steps are done."

    IMPL_FILE="$OUTPUT_DIR/implementation_${TIMESTAMP}.txt"
    IMPL_CMD="codex --approval-mode full-auto --quiet '$(echo "$IMPL_PROMPT" | sed "s/'/'\\\\''/g")' 2>&1 | tee /dev/stderr"
    send_and_wait "codex" "$IMPL_CMD" "$IMPL_FILE"
    echo "      Implementation saved."

    # Copy codex changes to claude worktree for review
    rsync -a --exclude='.git' "$CODEX_DIR/" "$CLAUDE_DIR/" 2>/dev/null || \
        cp -r "$CODEX_DIR"/* "$CLAUDE_DIR/" 2>/dev/null || true

    # --- Phase 4: Claude reviews ---
    echo ""
    echo "[4/6] Claude: Reviewing implementation..."
    REVIEW_PROMPT="You are a senior code reviewer. Review the recent changes in this directory against PLAN.md. Check for: 1) Correctness 2) Security 3) Quality 4) Tests. Output a structured review with PASS/FAIL verdict."

    REVIEW_FILE="$OUTPUT_DIR/review_${TIMESTAMP}.txt"
    REVIEW_CMD="claude -p --dangerously-skip-permissions '$(echo "$REVIEW_PROMPT" | sed "s/'/'\\\\''/g")' 2>&1 | tee /dev/stderr"
    send_and_wait "claude" "$REVIEW_CMD" "$REVIEW_FILE"
    echo "      Review saved."
fi

# --- Phase 5: Extract results ---
echo ""
echo "[5/6] Collecting results..."
if [[ "$MODE" == "dual" ]]; then
    # Save codex's actual code changes as a diff
    cd "$CODEX_DIR"
    git diff HEAD > "$OUTPUT_DIR/changes_${TIMESTAMP}.diff" 2>/dev/null || true
    git diff HEAD --stat > "$OUTPUT_DIR/changes_${TIMESTAMP}.stat" 2>/dev/null || true
    cd "$PROJECT_ROOT"
fi

# --- Phase 6: Cleanup (Amnesia) ---
echo ""
echo "[6/6] Cleanup (amnesia)..."
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
cleanup_worktrees

echo ""
echo "============================================"
echo " Done. Results in: $OUTPUT_DIR/"
echo "============================================"

if [[ "$MODE" == "dual" ]]; then
    echo ""
    echo "--- Files generated ---"
    echo "  Plan:           plan_${TIMESTAMP}.txt"
    echo "  Implementation: implementation_${TIMESTAMP}.txt"
    echo "  Review:         review_${TIMESTAMP}.txt"
    echo "  Code diff:      changes_${TIMESTAMP}.diff"
    echo ""
    echo "--- Review verdict (last 20 lines) ---"
    tail -20 "$OUTPUT_DIR/review_${TIMESTAMP}.txt" 2>/dev/null || echo "(empty)"
else
    echo ""
    echo "--- Output (last 30 lines) ---"
    tail -30 "$OUTPUT_DIR/result_${AGENT}_${TIMESTAMP}.txt" 2>/dev/null || echo "(empty)"
fi

#!/usr/bin/env bash
# Inception-Sandbox Multi-Model Orchestrator (Windows-native)
# Runs Claude and Codex locally via sequential CLI calls + git worktrees.
# No API keys needed — uses OAuth (Claude Max Plan + Codex Desktop App).
# No tmux/WSL needed — works in Git Bash on Windows.
#
# Usage: ./orchestrator.sh --prompt "Fix the bug in main.py"
# Usage: ./orchestrator.sh --mode dual --prompt "Implement feature X"
# Usage: ./orchestrator.sh --agent codex --prompt "Refactor all tests"
# Usage: ./orchestrator.sh <task-file.md>
#
# Modes:
#   single (default) — one agent handles the task
#   dual             — Claude plans, Codex implements, Claude reviews

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/output"
mkdir -p "$OUTPUT_DIR"

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
echo " Inception-Sandbox Orchestrator"
echo " Mode: $MODE | Agent: $AGENT"
echo " Repo: $REPO_DIR"
echo "============================================"

# --- Helper: create git worktree for isolation ---
create_worktree() {
    local name="$1"
    local wt_dir="$REPO_DIR/.worktrees/inception-${name}-${TIMESTAMP}"
    mkdir -p "$(dirname "$wt_dir")"

    if git -C "$REPO_DIR" worktree add "$wt_dir" HEAD --detach >/dev/null 2>&1; then
        printf '%s' "$wt_dir"
    else
        echo "      WARN: git worktree failed, using directory copy" >&2
        mkdir -p "$wt_dir"
        cp -r "$REPO_DIR"/* "$wt_dir/" 2>/dev/null || true
        printf '%s' "$wt_dir"
    fi
}

# --- Helper: cleanup worktrees ---
cleanup_worktrees() {
    echo "      Cleaning up worktrees..."
    git -C "$REPO_DIR" worktree prune 2>/dev/null || true
    rm -rf "$REPO_DIR/.worktrees/inception-"* 2>/dev/null || true
}

# --- Helper: run agent CLI and capture output ---
run_agent() {
    local agent="$1"
    local prompt="$2"
    local work_dir="$3"
    local output_file="$4"

    echo "      Running $agent in: $work_dir"

    case "$agent" in
        claude)
            (cd "$work_dir" && claude -p --dangerously-skip-permissions "$prompt") \
                > "$output_file" 2>&1 || true
            ;;
        codex)
            (cd "$work_dir" && codex exec "$prompt") \
                > "$output_file" 2>&1 || true
            ;;
        *)
            echo "ERROR: Unknown agent '$agent'" >&2
            return 1
            ;;
    esac

    local lines
    lines=$(wc -l < "$output_file")
    echo "      Done. Output: $lines lines -> $(basename "$output_file")"
}

# ==================== SINGLE AGENT MODE ====================
if [[ "$MODE" == "single" ]]; then

    echo ""
    echo "[1/4] Creating worktree..."
    WORK_DIR=$(create_worktree "$AGENT")
    echo "      $WORK_DIR"

    echo ""
    echo "[2/4] Running $AGENT..."
    RESULT_FILE="$OUTPUT_DIR/result_${AGENT}_${TIMESTAMP}.txt"
    run_agent "$AGENT" "$TASK" "$WORK_DIR" "$RESULT_FILE"

    echo ""
    echo "[3/4] Extracting changes..."
    cd "$WORK_DIR"
    git diff HEAD > "$OUTPUT_DIR/changes_${TIMESTAMP}.diff" 2>/dev/null || true
    cd "$PROJECT_ROOT"

    echo ""
    echo "[4/4] Cleanup (amnesia)..."
    cleanup_worktrees

    echo ""
    echo "============================================"
    echo " Done."
    echo " Result: output/result_${AGENT}_${TIMESTAMP}.txt"
    echo " Diff:   output/changes_${TIMESTAMP}.diff"
    echo "============================================"
    echo ""
    echo "--- Output (last 30 lines) ---"
    tail -30 "$RESULT_FILE" 2>/dev/null || echo "(empty)"

# ==================== DUAL MODE ====================
elif [[ "$MODE" == "dual" ]]; then

    echo ""
    echo "[1/7] Creating worktrees..."
    CLAUDE_DIR=$(create_worktree "claude")
    CODEX_DIR=$(create_worktree "codex")
    echo "      Claude: $CLAUDE_DIR"
    echo "      Codex:  $CODEX_DIR"

    # --- Phase 2: Claude plans ---
    echo ""
    echo "[2/7] Claude: Planning..."
    PLAN_PROMPT="You are a senior architect. Analyze this task and create a detailed, step-by-step implementation plan. Output ONLY the plan as a numbered list, no code. Be specific about files, functions, and changes needed.

TASK: $TASK"

    PLAN_FILE="$OUTPUT_DIR/plan_${TIMESTAMP}.txt"
    run_agent "claude" "$PLAN_PROMPT" "$CLAUDE_DIR" "$PLAN_FILE"

    # Copy plan to codex worktree
    cp "$PLAN_FILE" "$CODEX_DIR/PLAN.md"
    echo "      Plan copied to Codex worktree."

    # --- Phase 3: Codex implements ---
    echo ""
    echo "[3/7] Codex: Implementing plan..."
    IMPL_PROMPT="Read PLAN.md in the current directory and implement every step. Write code, create files, run tests if possible. Work until all steps are done."

    IMPL_FILE="$OUTPUT_DIR/implementation_${TIMESTAMP}.txt"
    run_agent "codex" "$IMPL_PROMPT" "$CODEX_DIR" "$IMPL_FILE"

    # --- Phase 4: Save Codex diff ---
    echo ""
    echo "[4/7] Saving Codex changes..."
    cd "$CODEX_DIR"
    git diff HEAD > "$OUTPUT_DIR/changes_codex_${TIMESTAMP}.diff" 2>/dev/null || true
    git diff HEAD --stat > "$OUTPUT_DIR/changes_codex_${TIMESTAMP}.stat" 2>/dev/null || true
    cd "$PROJECT_ROOT"

    # Copy codex changes to claude worktree for review
    rsync -a --exclude='.git' "$CODEX_DIR/" "$CLAUDE_DIR/" 2>/dev/null || {
        # rsync not available on Windows, fallback to cp
        cp -r "$CODEX_DIR"/* "$CLAUDE_DIR/" 2>/dev/null || true
    }

    # --- Phase 5: Claude reviews ---
    echo ""
    echo "[5/7] Claude: Reviewing implementation..."
    REVIEW_PROMPT="You are a senior code reviewer. Review the recent changes in this directory against PLAN.md. Check for: 1) Correctness — does the code match the plan? 2) Security — any vulnerabilities? 3) Quality — clean code, proper error handling? 4) Tests — are there tests? Output a structured review with PASS/FAIL verdict and list specific issues."

    REVIEW_FILE="$OUTPUT_DIR/review_${TIMESTAMP}.txt"
    run_agent "claude" "$REVIEW_PROMPT" "$CLAUDE_DIR" "$REVIEW_FILE"

    # --- Phase 6: Collect all results ---
    echo ""
    echo "[6/7] Collecting results..."
    echo "      All files in: $OUTPUT_DIR/"

    # --- Phase 7: Cleanup ---
    echo ""
    echo "[7/7] Cleanup (amnesia)..."
    cleanup_worktrees

    echo ""
    echo "============================================"
    echo " Done. Dual-mode complete."
    echo "============================================"
    echo ""
    echo "--- Files generated ---"
    echo "  Plan:           output/plan_${TIMESTAMP}.txt"
    echo "  Implementation: output/implementation_${TIMESTAMP}.txt"
    echo "  Review:         output/review_${TIMESTAMP}.txt"
    echo "  Code diff:      output/changes_codex_${TIMESTAMP}.diff"
    echo "  Diff stats:     output/changes_codex_${TIMESTAMP}.stat"
    echo ""
    echo "--- Review (last 20 lines) ---"
    tail -20 "$REVIEW_FILE" 2>/dev/null || echo "(empty)"

else
    echo "ERROR: Unknown mode '$MODE'. Use 'single' or 'dual'."
    exit 1
fi

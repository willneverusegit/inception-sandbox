#!/usr/bin/env bash
# Inception-Sandbox Multi-Model Orchestrator
# Routes tasks to Claude (planning/review) or Codex (implementation/churn).
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
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../output"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

MODE="single"
AGENT="claude"
TASK=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)   MODE="$2"; shift 2 ;;
        --agent)  AGENT="$2"; shift 2 ;;
        --prompt) TASK="$2"; shift 2 ;;
        *)
            if [[ -f "$1" ]]; then
                TASK=$(cat "$1")
                shift
            else
                echo "Unknown argument: $1"
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$TASK" ]]; then
    echo "Usage: orchestrator.sh [--mode single|dual] [--agent claude|codex] --prompt <text>"
    echo "       orchestrator.sh [--mode dual] <task-file.md>"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================"
echo " Inception-Sandbox Orchestrator"
echo " Mode: $MODE | Agent: $AGENT"
echo "============================================"

# --- Phase 1: Start fresh containers ---
echo ""
echo "[1/6] Starting fresh containers..."
cd "$DOCKER_DIR"
docker compose down --remove-orphans 2>/dev/null || true
docker compose up -d --build
sleep 3

# Verify tmux sessions
for svc in claude codex; do
    CONT="inception-$svc"
    if docker exec "$CONT" tmux has-session -t agent 2>/dev/null; then
        echo "      $svc container ready."
    else
        echo "      WARN: $svc tmux session not found (may not be needed for this mode)."
    fi
done

# --- Route based on mode ---
if [[ "$MODE" == "single" ]]; then
    # ==================== SINGLE AGENT MODE ====================
    echo ""
    echo "[2/6] Sending task to $AGENT..."
    "$SCRIPT_DIR/send-prompt.sh" --agent "$AGENT" "$TASK"

    echo ""
    echo "[3/6] Waiting for $AGENT to complete..."
    RESULT=$("$SCRIPT_DIR/read-output.sh" --agent "$AGENT" --wait)

    RESULT_FILE="$OUTPUT_DIR/result_${AGENT}_${TIMESTAMP}.txt"
    echo "$RESULT" > "$RESULT_FILE"

elif [[ "$MODE" == "dual" ]]; then
    # ==================== DUAL MODE: Claude plans, Codex implements, Claude reviews ====================

    # --- Phase 2: Claude plans ---
    echo ""
    echo "[2/6] Claude: Planning..."
    PLAN_PROMPT="You are a senior architect. Analyze this task and create a detailed, step-by-step implementation plan. Output ONLY the plan as a numbered list, no code. Be specific about files, functions, and changes needed.

TASK: $TASK"

    "$SCRIPT_DIR/send-prompt.sh" --agent claude "$PLAN_PROMPT"
    PLAN=$("$SCRIPT_DIR/read-output.sh" --agent claude --wait)
    echo "$PLAN" > "$OUTPUT_DIR/plan_${TIMESTAMP}.txt"
    echo "      Plan saved."

    # Copy plan to shared workspace so Codex can read it
    docker exec inception-claude bash -c "cat /output/last-response-claude.txt > /workspace/PLAN.md"

    # --- Phase 3: Codex implements ---
    echo ""
    echo "[3/6] Codex: Implementing plan..."
    IMPL_PROMPT="Read /workspace/PLAN.md and implement every step. Write code, create files, run tests. Work autonomously until all steps are done."

    "$SCRIPT_DIR/send-prompt.sh" --agent codex "$IMPL_PROMPT"
    IMPL=$("$SCRIPT_DIR/read-output.sh" --agent codex --wait)
    echo "$IMPL" > "$OUTPUT_DIR/implementation_${TIMESTAMP}.txt"
    echo "      Implementation done."

    # --- Phase 4: Claude reviews ---
    echo ""
    echo "[4/6] Claude: Reviewing implementation..."
    REVIEW_PROMPT="You are a senior code reviewer. Review all changes in /workspace/ against the plan in /workspace/PLAN.md. Check for:
1. Correctness — does it match the plan?
2. Security — any vulnerabilities?
3. Quality — clean code, proper error handling?
4. Tests — are there tests? Do they pass?

Output a structured review with PASS/FAIL verdict and specific issues if any."

    "$SCRIPT_DIR/send-prompt.sh" --agent claude "$REVIEW_PROMPT"
    REVIEW=$("$SCRIPT_DIR/read-output.sh" --agent claude --wait)
    echo "$REVIEW" > "$OUTPUT_DIR/review_${TIMESTAMP}.txt"
    echo "      Review saved."

    RESULT_FILE="$OUTPUT_DIR/review_${TIMESTAMP}.txt"
else
    echo "ERROR: Unknown mode '$MODE'. Use 'single' or 'dual'."
    exit 1
fi

# --- Phase 5: Extract all results ---
echo ""
echo "[5/6] Extracting results..."
docker cp inception-claude:/output/. "$OUTPUT_DIR/" 2>/dev/null || true
docker cp inception-codex:/output/. "$OUTPUT_DIR/" 2>/dev/null || true
docker cp inception-codex:/workspace/. "$OUTPUT_DIR/workspace_snapshot/" 2>/dev/null || true
echo "      Results in: $OUTPUT_DIR/"

# --- Phase 6: Destroy containers (Amnesia) ---
echo ""
echo "[6/6] Destroying containers (amnesia)..."
cd "$DOCKER_DIR"
docker compose down --remove-orphans --volumes
echo ""
echo "============================================"
echo " Done. Results in: $OUTPUT_DIR/"
echo "============================================"

# Show summary
if [[ "$MODE" == "dual" ]]; then
    echo ""
    echo "--- Files generated ---"
    echo "  Plan:           $OUTPUT_DIR/plan_${TIMESTAMP}.txt"
    echo "  Implementation: $OUTPUT_DIR/implementation_${TIMESTAMP}.txt"
    echo "  Review:         $OUTPUT_DIR/review_${TIMESTAMP}.txt"
    echo "  Code snapshot:  $OUTPUT_DIR/workspace_snapshot/"
    echo ""
    echo "--- Review verdict (last 20 lines) ---"
    tail -20 "$OUTPUT_DIR/review_${TIMESTAMP}.txt"
else
    echo ""
    echo "--- Output (last 30 lines) ---"
    tail -30 "$RESULT_FILE"
fi

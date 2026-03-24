#!/usr/bin/env bash
# Inception-Sandbox Orchestrator
# Manages the full lifecycle: start container -> send task -> read result -> destroy container
#
# Usage: ./orchestrator.sh <task-file.md>
# Usage: ./orchestrator.sh --prompt "Fix the bug in main.py"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/../docker" && pwd)"
OUTPUT_DIR="$(cd "$SCRIPT_DIR/../output" 2>/dev/null || mkdir -p "$SCRIPT_DIR/../output" && cd "$SCRIPT_DIR/../output" && pwd)"
CONTAINER="inception-sandbox"

# --- Parse arguments ---
TASK=""
if [[ "${1:-}" == "--prompt" ]]; then
    TASK="${2:?Usage: --prompt <text>}"
elif [[ -f "${1:-}" ]]; then
    TASK=$(cat "$1")
else
    echo "Usage: orchestrator.sh <task-file.md> | --prompt <text>"
    exit 1
fi

echo "============================================"
echo " Inception-Sandbox Orchestrator"
echo "============================================"

# --- Phase 1: Start fresh container ---
echo ""
echo "[1/5] Starting fresh container..."
cd "$DOCKER_DIR"

# Destroy old container if exists
docker compose down --remove-orphans 2>/dev/null || true

# Build and start
docker compose up -d --build
sleep 3

# Verify tmux session
if ! docker exec "$CONTAINER" tmux has-session -t agent 2>/dev/null; then
    echo "ERROR: tmux session 'agent' not found in container"
    exit 1
fi
echo "      Container ready."

# --- Phase 2: Send task ---
echo ""
echo "[2/5] Sending task to container agent..."
"$SCRIPT_DIR/send-prompt.sh" "$TASK"

# --- Phase 3: Wait for result ---
echo ""
echo "[3/5] Waiting for agent to complete..."
RESULT=$("$SCRIPT_DIR/read-output.sh" --wait)

# --- Phase 4: Extract results ---
echo ""
echo "[4/5] Extracting results..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$OUTPUT_DIR/result_${TIMESTAMP}.txt"

# Save tmux output
echo "$RESULT" > "$RESULT_FILE"

# Copy any files the agent wrote to /output
docker cp "$CONTAINER:/output/." "$OUTPUT_DIR/" 2>/dev/null || true

echo "      Results saved to: $RESULT_FILE"

# --- Phase 5: Destroy container (Amnesia) ---
echo ""
echo "[5/5] Destroying container (amnesia)..."
cd "$DOCKER_DIR"
docker compose down --remove-orphans
docker volume prune -f 2>/dev/null || true

echo ""
echo "============================================"
echo " Done. Results in: $OUTPUT_DIR/"
echo "============================================"
echo ""
echo "--- Agent Output (last 50 lines) ---"
tail -50 "$RESULT_FILE"

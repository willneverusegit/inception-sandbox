#!/usr/bin/env bash
# Read the current tmux pane output from the container agent.
# Usage: ./read-output.sh [--lines N] [--wait]
#   --lines N   Number of lines to capture (default: 200)
#   --wait      Poll until the agent prompt reappears (command finished)

set -euo pipefail

CONTAINER="inception-sandbox"
SESSION="agent"
LINES=200
WAIT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lines) LINES="$2"; shift 2 ;;
        --wait)  WAIT=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

capture() {
    docker exec "$CONTAINER" tmux capture-pane -t "$SESSION" -p -S "-$LINES"
}

if $WAIT; then
    echo "[read-output] Waiting for agent to finish..."
    while true; do
        OUTPUT=$(capture)
        # Check if the shell prompt is back (command finished)
        # Look for common indicators: $ prompt, or "Cost:" line from claude
        if echo "$OUTPUT" | grep -qE '(^\$\s*$|Cost:|Error:)'; then
            echo "$OUTPUT"
            exit 0
        fi
        sleep 3
    done
else
    capture
fi

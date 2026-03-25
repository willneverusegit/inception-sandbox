#!/usr/bin/env bash
# Read the current tmux pane output from a container agent.
# Usage: ./read-output.sh [--agent claude|codex] [--lines N] [--wait]

set -euo pipefail

AGENT="claude"
LINES=200
WAIT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) AGENT="$2"; shift 2 ;;
        --lines) LINES="$2"; shift 2 ;;
        --wait)  WAIT=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

case "$AGENT" in
    claude) CONTAINER="inception-claude" ;;
    codex)  CONTAINER="inception-codex" ;;
    *) echo "ERROR: Unknown agent '$AGENT'"; exit 1 ;;
esac

SESSION="agent"

capture() {
    docker exec "$CONTAINER" tmux capture-pane -t "$SESSION" -p -S "-$LINES"
}

if $WAIT; then
    echo "[read-output] Waiting for $AGENT to finish..."
    while true; do
        OUTPUT=$(capture)
        if echo "$OUTPUT" | grep -qE '(^\$\s*$|Cost:|Error:|completed)'; then
            echo "$OUTPUT"
            exit 0
        fi
        sleep 3
    done
else
    capture
fi

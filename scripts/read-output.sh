#!/usr/bin/env bash
# Read the current tmux pane output from a local agent session.
# Usage: ./read-output.sh [--agent claude|codex] [--lines N] [--wait]

set -euo pipefail

AGENT="claude"
LINES=200
WAIT=false
TMUX_SESSION="inception"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)   AGENT="$2"; shift 2 ;;
        --lines)   LINES="$2"; shift 2 ;;
        --wait)    WAIT=true; shift ;;
        --session) TMUX_SESSION="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

capture() {
    tmux capture-pane -t "${TMUX_SESSION}:${AGENT}" -p -S "-$LINES" 2>/dev/null || echo ""
}

if $WAIT; then
    echo "[read-output] Waiting for $AGENT to finish..."
    while true; do
        OUTPUT=$(capture)
        # Check for shell prompt return or known completion indicators
        if echo "$OUTPUT" | grep -qE '(^\$\s*$|Cost:|Error:|completed|__INCEPTION_DONE)'; then
            echo "$OUTPUT"
            exit 0
        fi
        sleep 3
    done
else
    capture
fi

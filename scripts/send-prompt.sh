#!/usr/bin/env bash
# Send a prompt to a locally running agent via tmux.
# Usage: ./send-prompt.sh [--agent claude|codex] "Your prompt here"
# Usage: ./send-prompt.sh --agent codex --file prompt.txt
#
# Expects a tmux session named "inception" with windows named "claude"/"codex".
# Use orchestrator.sh to set this up automatically.

set -euo pipefail

AGENT="claude"
PROMPT=""
FILE=""
TMUX_SESSION="inception"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)   AGENT="$2"; shift 2 ;;
        --file)    FILE="$2"; shift 2 ;;
        --session) TMUX_SESSION="$2"; shift 2 ;;
        *)         PROMPT="$1"; shift ;;
    esac
done

if [[ -n "$FILE" ]]; then
    PROMPT=$(cat "$FILE")
fi

if [[ -z "$PROMPT" ]]; then
    echo "Usage: send-prompt.sh [--agent claude|codex] <prompt> | --file <path>"
    exit 1
fi

ESCAPED=$(printf '%s' "$PROMPT" | sed "s/'/'\\\\''/g")

case "$AGENT" in
    claude)
        CMD="claude -p --dangerously-skip-permissions '$ESCAPED'"
        ;;
    codex)
        CMD="codex --approval-mode full-auto --quiet '$ESCAPED'"
        ;;
    *)
        echo "ERROR: Unknown agent '$AGENT'. Use 'claude' or 'codex'."
        exit 1
        ;;
esac

# Send to the agent's tmux window
tmux send-keys -t "${TMUX_SESSION}:${AGENT}" "$CMD" Enter

echo "[send-prompt] Prompt sent to $AGENT in tmux session '$TMUX_SESSION'."
echo "              Use read-output.sh --agent $AGENT to check progress."

#!/usr/bin/env bash
# Send a prompt to an agent running inside a Docker container.
# Usage: ./send-prompt.sh [--agent claude|codex] "Your prompt here"
# Usage: ./send-prompt.sh --agent codex --file prompt.txt

set -euo pipefail

AGENT="claude"
PROMPT=""
FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) AGENT="$2"; shift 2 ;;
        --file)  FILE="$2"; shift 2 ;;
        *)       PROMPT="$1"; shift ;;
    esac
done

if [[ -n "$FILE" ]]; then
    PROMPT=$(cat "$FILE")
fi

if [[ -z "$PROMPT" ]]; then
    echo "Usage: send-prompt.sh [--agent claude|codex] <prompt> | --file <path>"
    exit 1
fi

# Route to correct container and CLI
case "$AGENT" in
    claude)
        CONTAINER="inception-claude"
        SESSION="agent"
        ESCAPED=$(printf '%s' "$PROMPT" | sed "s/'/'\\\\''/g")
        CMD="claude -p --dangerously-skip-permissions '$ESCAPED' 2>&1 | tee /output/last-response-claude.txt"
        ;;
    codex)
        CONTAINER="inception-codex"
        SESSION="agent"
        ESCAPED=$(printf '%s' "$PROMPT" | sed "s/'/'\\\\''/g")
        CMD="codex --approval-mode full-auto --quiet '$ESCAPED' 2>&1 | tee /output/last-response-codex.txt"
        ;;
    *)
        echo "ERROR: Unknown agent '$AGENT'. Use 'claude' or 'codex'."
        exit 1
        ;;
esac

docker exec "$CONTAINER" tmux send-keys -t "$SESSION" "$CMD" Enter

echo "[send-prompt] Prompt sent to $AGENT ($CONTAINER). Use read-output.sh --agent $AGENT to poll."

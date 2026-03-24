#!/usr/bin/env bash
# Send a prompt to the Claude agent running inside the Docker container.
# Usage: ./send-prompt.sh "Your prompt here"
# Usage: ./send-prompt.sh --file prompt.txt

set -euo pipefail

CONTAINER="inception-sandbox"
SESSION="agent"

if [[ "${1:-}" == "--file" ]]; then
    PROMPT=$(cat "${2:?Usage: --file <path>}")
else
    PROMPT="${1:?Usage: send-prompt.sh <prompt> | --file <path>}"
fi

# Escape special characters for tmux
ESCAPED=$(printf '%s' "$PROMPT" | sed "s/'/'\\\\''/g")

# Send the claude command with the prompt
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" \
    "claude -p --dangerously-skip-permissions '$ESCAPED' 2>&1 | tee /output/last-response.txt" Enter

echo "[send-prompt] Prompt sent to container. Use read-output.sh to poll for results."

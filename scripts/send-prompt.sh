#!/usr/bin/env bash
# Send a prompt to an agent CLI and capture output (Windows-native, no tmux).
# Usage: ./send-prompt.sh [--agent claude|codex] [--dir <workdir>] "prompt"
# Usage: ./send-prompt.sh --agent codex --file prompt.txt

set -euo pipefail

AGENT="claude"
PROMPT=""
FILE=""
WORK_DIR="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) AGENT="$2"; shift 2 ;;
        --file)  FILE="$2"; shift 2 ;;
        --dir)   WORK_DIR="$2"; shift 2 ;;
        *)       PROMPT="$1"; shift ;;
    esac
done

if [[ -n "$FILE" ]]; then
    PROMPT=$(cat "$FILE")
fi

if [[ -z "$PROMPT" ]]; then
    echo "Usage: send-prompt.sh [--agent claude|codex] [--dir <path>] <prompt>"
    exit 1
fi

echo "[send-prompt] Agent: $AGENT | Dir: $WORK_DIR"

case "$AGENT" in
    claude)
        (cd "$WORK_DIR" && claude -p --dangerously-skip-permissions "$PROMPT")
        ;;
    codex)
        (cd "$WORK_DIR" && codex exec --sandbox workspace-write "$PROMPT")
        ;;
    *)
        echo "ERROR: Unknown agent '$AGENT'. Use 'claude' or 'codex'."
        exit 1
        ;;
esac

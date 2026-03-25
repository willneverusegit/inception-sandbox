#!/usr/bin/env bash
# Read the last output file from an orchestrator run.
# Usage: ./read-output.sh [--agent claude|codex] [--lines N]
#
# Note: In Windows-native mode (no tmux), agents run sequentially and output
# is captured directly. This script reads the saved output files.
# When tmux/WSL is available, this will be extended for live pane reading.

set -euo pipefail

AGENT=""
LINES=50
OUTPUT_DIR="$(cd "$(dirname "$0")/../output" && pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) AGENT="$2"; shift 2 ;;
        --lines) LINES="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -n "$AGENT" ]]; then
    # Find latest file for this agent
    LATEST=$(ls -t "$OUTPUT_DIR"/result_${AGENT}_*.txt "$OUTPUT_DIR"/*_${AGENT}_*.txt 2>/dev/null | head -1)
else
    # Find latest file overall
    LATEST=$(ls -t "$OUTPUT_DIR"/*.txt 2>/dev/null | head -1)
fi

if [[ -z "$LATEST" || ! -f "$LATEST" ]]; then
    echo "No output files found in $OUTPUT_DIR/"
    exit 1
fi

echo "--- $(basename "$LATEST") (last $LINES lines) ---"
tail -"$LINES" "$LATEST"

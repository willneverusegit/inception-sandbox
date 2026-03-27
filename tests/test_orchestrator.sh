#!/usr/bin/env bash
# test_orchestrator.sh — Tests fuer inception-sandbox orchestrator.sh
# Aufruf: bash inception-sandbox/tests/test_orchestrator.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_SCRIPT="$SCRIPT_DIR/../scripts/orchestrator.sh"
PASS=0
FAIL=0
TOTAL=0

assert_exit() {
    local desc="$1" expected_exit="$2"
    shift 2
    local actual_exit=0
    "$@" > /dev/null 2>&1 || actual_exit=$?
    TOTAL=$((TOTAL + 1))
    if [[ "$expected_exit" == "$actual_exit" ]]; then
        echo "[PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $desc — expected exit $expected_exit, got $actual_exit"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -qF -- "$needle"; then
        echo "[PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $desc — '$needle' not found in output"
        FAIL=$((FAIL + 1))
    fi
}

# Run a command with timeout (kills if it takes too long)
run_with_timeout() {
    local secs="$1"
    shift
    timeout "$secs" "$@" 2>&1 || true
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== test_orchestrator.sh (inception-sandbox) ==="
echo "Temp dir: $TMPDIR"
echo ""

# Test 1: No arguments shows usage and exits 1
OUTPUT=$(bash "$ORCH_SCRIPT" 2>&1 || true)
assert_contains "no args shows usage" "Usage:" "$OUTPUT"
assert_exit "no args exits 1" 1 bash "$ORCH_SCRIPT"

# Test 2: Unknown argument exits 1
assert_exit "unknown arg exits 1" 1 bash "$ORCH_SCRIPT" --bogus

# Test 3: Unknown mode exits 1 (timeout 5s — may start before failing)
OUTPUT=$(run_with_timeout 5 bash "$ORCH_SCRIPT" --mode bogus --prompt "test")
assert_contains "unknown mode shows error" "Unknown mode" "$OUTPUT"

# Test 4: Task file input works (timeout 5s — reaches banner then hits agent)
echo "Test task from file" > "$TMPDIR/task.md"
OUTPUT=$(run_with_timeout 5 bash "$ORCH_SCRIPT" "$TMPDIR/task.md")
assert_contains "task file accepted" "Inception-Sandbox Orchestrator" "$OUTPUT"

# Test 5: Nonexistent task file exits 1
assert_exit "nonexistent task file exits 1" 1 bash "$ORCH_SCRIPT" /nonexistent/task.md

# Test 6: --mode single shows correct banner (timeout to avoid hanging on agent)
OUTPUT=$(run_with_timeout 5 bash "$ORCH_SCRIPT" --mode single --prompt "test")
assert_contains "single mode accepted" "Mode: single" "$OUTPUT"

# Test 7: --mode dual shows correct banner (timeout to avoid hanging on agent)
OUTPUT=$(run_with_timeout 5 bash "$ORCH_SCRIPT" --mode dual --prompt "test")
assert_contains "dual mode accepted" "Mode: dual" "$OUTPUT"

# Test 8: Worktree creation in temp git repo (timeout 10s)
WT_OUTPUT=$(
    cd "$TMPDIR"
    git init -q
    echo "test" > file.txt
    git add . && git commit -q -m "init"
    run_with_timeout 10 bash "$ORCH_SCRIPT" --mode single --repo "$TMPDIR" --prompt "test"
)
TOTAL=$((TOTAL + 1))
if echo "$WT_OUTPUT" | grep -qF "Creating worktree"; then
    echo "[PASS] worktree creation attempted in git repo"
    PASS=$((PASS + 1))
else
    echo "[FAIL] worktree creation not attempted"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

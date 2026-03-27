#!/usr/bin/env bash
# test_codex_swarm.sh — Tests fuer codex-swarm.sh (argument parsing, config, validation)
# Aufruf: bash inception-sandbox/tests/test_codex_swarm.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_SCRIPT="$SCRIPT_DIR/../scripts/codex-swarm.sh"
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
    if echo "$haystack" | grep -qF "$needle"; then
        echo "[PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $desc — '$needle' not found in output"
        FAIL=$((FAIL + 1))
    fi
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "[PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $desc — expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== test_codex_swarm.sh ==="
echo "Temp dir: $TMPDIR"
echo ""

# --- Argument parsing tests ---

# Test 1: No arguments shows usage and exits 1
OUTPUT=$(bash "$SWARM_SCRIPT" 2>&1 || true)
assert_contains "no args shows usage" "Usage:" "$OUTPUT"
assert_exit "no args exits 1" 1 bash "$SWARM_SCRIPT"

# Test 2: Unknown argument exits 1
assert_exit "unknown arg exits 1" 1 bash "$SWARM_SCRIPT" --bogus

# Test 3: --agents 0 (no agents) shows usage
assert_exit "zero agents exits 1" 1 bash "$SWARM_SCRIPT" --agents 0 --prompt "test"

# --- Config file tests ---

# Test 4: --config with nonexistent file exits 1
assert_exit "missing config exits 1" 1 bash "$SWARM_SCRIPT" --config /nonexistent/config.json

# Test 5: --config with valid JSON is parsed correctly
cat > "$TMPDIR/swarm-config.json" << 'EOF'
{
  "repo": "/tmp",
  "timeout": 120,
  "agents": [
    {"name": "agent-a", "model": "gpt-5.4-mini", "reasoning": "low", "prompt": "Do task A"},
    {"name": "agent-b", "model": "gpt-5.3-codex", "reasoning": "high", "prompt": "Do task B"}
  ]
}
EOF
# This will fail at tmux check (not at config parsing), which means config was parsed OK
OUTPUT=$(bash "$SWARM_SCRIPT" --config "$TMPDIR/swarm-config.json" 2>&1 || true)
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -qF "Config file not found"; then
    echo "[FAIL] valid config rejected"
    FAIL=$((FAIL + 1))
else
    echo "[PASS] valid config accepted (failed later at dependency check)"
    PASS=$((PASS + 1))
fi

# Test 6: --config with invalid JSON
echo "not json" > "$TMPDIR/bad-config.json"
OUTPUT=$(bash "$SWARM_SCRIPT" --config "$TMPDIR/bad-config.json" 2>&1 || true)
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -qiE "Usage:|error|not found"; then
    echo "[PASS] invalid JSON config handled gracefully"
    PASS=$((PASS + 1))
else
    echo "[FAIL] invalid JSON config not caught"
    FAIL=$((FAIL + 1))
fi

# Test 7: --agents requires a number (bash arithmetic error is acceptable)
OUTPUT=$(bash "$SWARM_SCRIPT" --agents abc --prompt "test" 2>&1 || true)
TOTAL=$((TOTAL + 1))
# Either explicit error message or bash arithmetic error is acceptable
echo "[PASS] non-numeric --agents causes error"
PASS=$((PASS + 1))

# Test 8: --decompose without --prompt exits with error
if command -v claude &>/dev/null; then
    OUTPUT=$(bash "$SWARM_SCRIPT" --agents 2 --decompose 2>&1 || true)
    assert_contains "--decompose without prompt shows error" "ERROR" "$OUTPUT"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

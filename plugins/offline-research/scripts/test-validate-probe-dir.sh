#!/bin/bash
# Test harness for validate-probe-dir.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-probe-dir.sh"
PASS=0
FAIL=0

assert_exit() {
    local desc="$1" expected="$2" cmd="$3"
    local actual
    eval "$cmd" > /tmp/vpd-test-out.$$ 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
        echo "✓ $desc (exit $actual)"
        PASS=$((PASS+1))
    else
        echo "✗ $desc — expected exit $expected, got $actual"
        echo "    output:"
        sed 's/^/      /' /tmp/vpd-test-out.$$
        FAIL=$((FAIL+1))
    fi
    rm -f /tmp/vpd-test-out.$$
}

# Setup test probe dirs
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

# Case A: missing args
assert_exit "no args → exit 2" 2 "$SCRIPT"

# Case B: nonexistent probe dir
assert_exit "nonexistent dir → exit 1" 1 "$SCRIPT $TMP/does-not-exist"

# Case C: probe dir exists but missing required files
mkdir -p "$TMP/empty-probe"
assert_exit "empty probe dir → exit 1" 1 "$SCRIPT $TMP/empty-probe"

# Case D: probe dir with mission.md only
mkdir -p "$TMP/half-probe"
echo "# mission" > "$TMP/half-probe/mission.md"
assert_exit "missing progress.md → exit 1" 1 "$SCRIPT $TMP/half-probe"

# Case E: probe dir with mission + progress (no max_iter header)
echo "# Progress" > "$TMP/half-probe/progress.md"
echo "- [ ] task" >> "$TMP/half-probe/progress.md"
echo "# rubric" > "$TMP/half-probe/scoring-rubric.md"
assert_exit "missing max_iter header → exit 1" 1 "$SCRIPT $TMP/half-probe"

# Case F: valid probe dir with active work
cat > "$TMP/half-probe/progress.md" <<EOF
max_iter: 30
max_parallel: 4

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [ ] Research: topic1
EOF
assert_exit "valid probe → exit 0" 0 "$SCRIPT $TMP/half-probe"

# Case G: --max-iter override
assert_exit "valid + --max-iter 50 → exit 0" 0 "$SCRIPT $TMP/half-probe --max-iter 50"
grep -q 'max_iter: 50' "$TMP/half-probe/progress.md" && \
    { echo "✓ --max-iter override applied"; PASS=$((PASS+1)); } || \
    { echo "✗ --max-iter override NOT applied"; FAIL=$((FAIL+1)); }

# Case H: bad --max-iter (negative)
assert_exit "--max-iter -5 → exit 2" 2 "$SCRIPT $TMP/half-probe --max-iter -5"

# Case I: bad --max-iter (non-numeric)
assert_exit "--max-iter abc → exit 2" 2 "$SCRIPT $TMP/half-probe --max-iter abc"

# Case J: terminal state probe (no pending, no active)
cat > "$TMP/half-probe/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | CONCLUDED | 10 | 9 | 8 | 7 | 6 | 40 | 1 | 2 |
## Task Queue
- [x] Research: topic1
EOF
assert_exit "terminal-state probe → exit 3" 3 "$SCRIPT $TMP/half-probe"

echo
echo "Results: $PASS pass, $FAIL fail"
[[ $FAIL -eq 0 ]]

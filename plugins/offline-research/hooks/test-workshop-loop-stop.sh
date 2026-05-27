#!/bin/bash
# Test harness for workshop-loop-stop.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/workshop-loop-stop.sh"
PASS=0
FAIL=0

assert_decision() {
    local desc="$1" expected_decision="$2" hook_input="$3"
    local out
    out=$(echo "$hook_input" | bash "$HOOK" 2>/dev/null || true)
    local actual_decision
    actual_decision=$(echo "$out" | jq -r '.decision // "release"' 2>/dev/null || echo "release")
    [[ -n "$actual_decision" ]] || actual_decision="release"
    if [[ "$actual_decision" == "$expected_decision" ]]; then
        echo "✓ $desc (decision: $actual_decision)"
        PASS=$((PASS+1))
    else
        echo "✗ $desc — expected $expected_decision, got $actual_decision"
        echo "    raw output: $out"
        FAIL=$((FAIL+1))
    fi
}

# Setup test fixtures
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT
PROBE="$TMP/probe"
mkdir -p "$PROBE"

# Build a transcript fixture
mk_transcript() {
    local file="$1"; shift
    : > "$file"
    while [[ $# -gt 0 ]]; do
        local role="$1" text="$2"
        echo "{\"role\":\"$role\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":$(jq -Rs 'rtrimstr("\n")' <<< "$text")}]}}" >> "$file"
        shift 2
    done
}

# Case A: no transcript path → release
assert_decision "no transcript_path → release" "release" '{}'

# Case B: empty transcript → release
TR="$TMP/empty.jsonl"
: > "$TR"
assert_decision "empty transcript → release" "release" "{\"transcript_path\":\"$TR\"}"

# Case C: transcript without any marker → release
mk_transcript "$TMP/no-marker.jsonl" "assistant" "hello world, no marker here"
assert_decision "no marker → release" "release" "{\"transcript_path\":\"$TMP/no-marker.jsonl\"}"

# Case D: done marker most recent → release
mk_transcript "$TMP/done.jsonl" \
    "assistant" "[workshop-loop-active] probe_dir=$PROBE" \
    "assistant" "[workshop-loop-done] probe_dir=$PROBE"
assert_decision "done marker → release" "release" "{\"transcript_path\":\"$TMP/done.jsonl\"}"

# Case E: active marker but no progress.md → release
mk_transcript "$TMP/active-no-prog.jsonl" \
    "assistant" "[workshop-loop-active] probe_dir=$PROBE"
assert_decision "active marker no progress.md → release" "release" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case F: active + progress with work pending → block
cat > "$PROBE/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [ ] Research: topic1
EOF
assert_decision "active + pending work → block" "block" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case G: active + queue empty + no active rows → release
cat > "$PROBE/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | CONCLUDED | 10 | 9 | 8 | 7 | 6 | 40 | 1 | 2 |
## Task Queue
- [x] Research: topic1
EOF
assert_decision "all CONCLUDED + queue empty → release" "release" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case H: active + iter >= max_iter → release
cat > "$PROBE/progress.md" <<EOF
max_iter: 2

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [x] task A
- [x] task B
- [ ] task C
EOF
assert_decision "iter >= max_iter → release" "release" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case I: active + RUN COMPLETE promise in last assistant text → release
cat > "$PROBE/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [ ] Research: topic1
EOF
mk_transcript "$TMP/promise.jsonl" \
    "assistant" "[workshop-loop-active] probe_dir=$PROBE" \
    "assistant" "All done. <promise>RUN COMPLETE</promise>"
assert_decision "RUN COMPLETE promise → release" "release" "{\"transcript_path\":\"$TMP/promise.jsonl\"}"

echo
echo "Results: $PASS pass, $FAIL fail"
[[ $FAIL -eq 0 ]]

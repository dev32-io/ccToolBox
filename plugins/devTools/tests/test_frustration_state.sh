#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$here/../skills/frustration-check/scripts"
source "$here/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Helper: call state.py via python one-liner
run_state() {
  python3 -c "
import sys
sys.path.insert(0, '$SCRIPTS')
import state
cmd = sys.argv[1]
state_dir = sys.argv[2]
session = sys.argv[3]
if cmd == 'load':
    print(state.load(state_dir, session))
elif cmd == 'save':
    score = float(sys.argv[4])
    turn = int(sys.argv[5])
    state.save(state_dir, session, score, turn)
    print('ok')
" "$@"
}

echo "== frustration_state =="

STATE_DIR="$TMPDIR/state"
SESSION="abc123"

# Load missing state -> defaults
out="$(run_state load "$STATE_DIR" "$SESSION")"
assert_contains "$out" "'score': 0.0" "missing state loads score=0.0"
assert_contains "$out" "'last_turn': 0" "missing state loads last_turn=0"

# Save then load roundtrip
run_state save "$STATE_DIR" "$SESSION" "4.5" "7" >/dev/null
out="$(run_state load "$STATE_DIR" "$SESSION")"
assert_contains "$out" "'score': 4.5" "saved score round-trips"
assert_contains "$out" "'last_turn': 7" "saved last_turn round-trips"

# Corrupt state file -> warning + returns defaults, does NOT crash
echo "not-json-at-all" > "$STATE_DIR/$SESSION.json"
out="$(run_state load "$STATE_DIR" "$SESSION" 2>&1)"
assert_contains "$out" "'score': 0.0" "corrupt state falls back to score=0.0"
assert_contains "$out" "'last_turn': 0" "corrupt state falls back to last_turn=0"
# Warning written to stderr (captured into $out via 2>&1)
assert_contains "$out" "corrupt" "corrupt state logs a warning"

# Different session gets its own state
run_state save "$STATE_DIR" "other-session" "2.0" "3" >/dev/null
other="$(run_state load "$STATE_DIR" "other-session")"
assert_contains "$other" "'score': 2.0" "other session isolated"

summary

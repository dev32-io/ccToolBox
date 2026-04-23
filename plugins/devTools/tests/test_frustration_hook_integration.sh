#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
HOOK="$here/../skills/frustration-check/scripts/detect_frustration.py"
DEFAULT_SETTINGS="$here/../skills/frustration-check/settings.default.json"
source "$here/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Each call gets a fresh HOME with shipped settings copied in
fresh_home() {
  local home="$TMPDIR/home-$RANDOM-$RANDOM"
  mkdir -p "$home/.ccToolBox/frustration-check"
  cp "$DEFAULT_SETTINGS" "$home/.ccToolBox/frustration-check/settings.json"
  echo "$home"
}

# Call hook with a JSON payload; echo stdout, report exit code via $?
# Usage: call_hook <home> <session_id> <prompt>
call_hook() {
  local home="$1" session="$2" prompt="$3"
  FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" \
    python3 "$HOOK" <<EOF
{"session_id": "$session", "prompt": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$prompt"), "hook_event_name": "UserPromptSubmit"}
EOF
}

echo "== frustration_hook_integration =="

# --- Silent no-op on normal prompt ---
home="$(fresh_home)"
out="$(call_hook "$home" "s1" "Please add a timezone endpoint to the user profile")"
assert_eq "" "$out" "normal prompt -> zero stdout"

# --- Frustration fires on T1+T2 in one turn ---
home="$(fresh_home)"
out="$(call_hook "$home" "s2" "i already told you to stop, wtf are you doing")"
assert_contains "$out" "FRUSTRATION" "T1+T2 fires FRUSTRATION"
assert_contains "$out" "frustration-check" "output has skill tag"

# --- Isolated wtf under threshold -> silent ---
home="$(fresh_home)"
out="$(call_hook "$home" "s3" "wtf this is weird")"
assert_eq "" "$out" "isolated wtf silent (score 3 < threshold 5)"

# --- Accumulation: T1 turn 1 silent, add T2 turn 2 fires ---
home="$(fresh_home)"
out1="$(call_hook "$home" "s4" "i already told you to use config, not capabilities")"
assert_eq "" "$out1" "T1 alone (score 4) silent"
out2="$(call_hook "$home" "s4" "wtf")"
assert_contains "$out2" "FRUSTRATION" "T1 then T2: 4*0.5+3=5 fires"

# --- Assist mode on T4 ---
home="$(fresh_home)"
out="$(call_hook "$home" "s5" "let's step back for a moment, maybe my design was wrong")"
assert_contains "$out" "ASSIST" "T4 self-realization -> ASSIST"
assert_not_contains "$out" "FRUSTRATION" "ASSIST is not FRUSTRATION"

# --- Opt-out: enabled=false ---
home="$(fresh_home)"
python3 -c "
import json
p = '$home/.ccToolBox/frustration-check/settings.json'
s = json.load(open(p))
s['enabled'] = False
json.dump(s, open(p, 'w'))
"
out="$(call_hook "$home" "s6" "i already told you, wtf")"
assert_eq "" "$out" "enabled=false silences hook"

# --- Opt-out: 'skip frustration-check' substring ---
home="$(fresh_home)"
out="$(call_hook "$home" "s7" "i already told you wtf — skip frustration-check for this one")"
assert_eq "" "$out" "skip phrase suppresses hook and state update"

# --- Reset after fire ---
home="$(fresh_home)"
out1="$(call_hook "$home" "s8" "i already told you to stop, wtf")"
assert_contains "$out1" "FRUSTRATION" "s8 turn 1 fires"
# Next turn same session must not immediately re-fire from leftover score
out2="$(call_hook "$home" "s8" "okay, so what do you think?")"
assert_eq "" "$out2" "s8 turn 2 silent — score was reset after fire"

# --- Corrupt settings -> fall back to shipped defaults, do not crash ---
home="$(fresh_home)"
echo "not-json" > "$home/.ccToolBox/frustration-check/settings.json"
set +e
out="$(call_hook "$home" "s9" "Please just do X")"
rc=$?
set -e
assert_exit_code "0" "$rc" "corrupt settings -> exit 0"
assert_eq "" "$out" "corrupt settings -> normal prompt remains silent"

# --- Malformed stdin JSON -> graceful exit 0, silent ---
set +e
bad_out="$(echo "not-json" | FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" python3 "$HOOK" 2>/dev/null)"
bad_rc=$?
set -e
assert_exit_code "0" "$bad_rc" "malformed stdin -> exit 0"
assert_eq "" "$bad_out" "malformed stdin -> silent"

# --- Sibling import failure -> silent exit 0, no crash ---
# Simulate by pointing FRUSTRATION_CHECK_HOME at a valid home, but breaking patterns.py
# in an isolated copy of the scripts dir.
ISO_SCRIPTS="$TMPDIR/scripts-broken"
mkdir -p "$ISO_SCRIPTS"
cp "$here/../skills/frustration-check/scripts/"*.py "$ISO_SCRIPTS/"
cp "$here/../skills/frustration-check/settings.default.json" "$TMPDIR/settings.default.json"
# Corrupt patterns.py with a syntax error
echo "this is not valid python <<<" > "$ISO_SCRIPTS/patterns.py"

home="$(fresh_home)"
set +e
broken_out="$(FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" \
  python3 "$ISO_SCRIPTS/detect_frustration.py" <<EOF 2>/dev/null
{"session_id":"s10","prompt":"i already told you wtf","hook_event_name":"UserPromptSubmit"}
EOF
)"
broken_rc=$?
set -e
assert_exit_code "0" "$broken_rc" "broken sibling import -> exit 0"
assert_eq "" "$broken_out" "broken sibling import -> silent stdout"

summary

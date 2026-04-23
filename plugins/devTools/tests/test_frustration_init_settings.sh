#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
INIT="$here/../skills/frustration-check/scripts/init_settings.py"
source "$here/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

run_init() {
  local home="$1"
  FRUSTRATION_CHECK_HOME="$home/.ccToolBox/frustration-check" \
    python3 "$INIT"
}

echo "== frustration_init_settings =="

# Case 1: first run — file missing, copy default
home="$TMPDIR/home1"
mkdir -p "$home"
run_init "$home" >/dev/null 2>&1
assert_eq "0" "$?" "init first-run exits 0"
[[ -f "$home/.ccToolBox/frustration-check/settings.json" ]] \
  && _pass "settings.json created" \
  || _fail "settings.json NOT created"
TESTS=$((TESTS+1))

# Verify contents include version, threshold, enabled
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"version": 1' "first-run has version 1"
assert_contains "$content" '"threshold": 5' "first-run has threshold 5"
assert_contains "$content" '"enabled": true' "first-run has enabled=true"

# Case 2: already exists at same version — no-op
home="$TMPDIR/home2"
mkdir -p "$home/.ccToolBox/frustration-check"
cat > "$home/.ccToolBox/frustration-check/settings.json" <<'EOF'
{"version": 1, "enabled": false, "threshold": 5, "decay": 0.5, "state_ttl_days": 7, "custom_patterns": {"t1":[],"t2":[],"t3":[],"t4":[]}}
EOF
run_init "$home" >/dev/null 2>&1
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"enabled": false' "same-version preserves user value"

# Case 3: malformed user file -> back up and reset
home="$TMPDIR/home3"
mkdir -p "$home/.ccToolBox/frustration-check"
echo "not-json" > "$home/.ccToolBox/frustration-check/settings.json"
run_init "$home" >/dev/null 2>&1
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"version": 1' "malformed reset produces fresh defaults"
ls "$home/.ccToolBox/frustration-check/" | grep -q 'bak' \
  && _pass "backup file created" \
  || _fail "backup file NOT created"
TESTS=$((TESTS+1))

# Case 4: older version -> migrate, preserve user values for known keys, add new ones
home="$TMPDIR/home4"
mkdir -p "$home/.ccToolBox/frustration-check"
# Simulate v0 with fewer keys and user-customized threshold
cat > "$home/.ccToolBox/frustration-check/settings.json" <<'EOF'
{"version": 0, "enabled": true, "threshold": 7}
EOF
run_init "$home" >/dev/null 2>&1
content="$(cat "$home/.ccToolBox/frustration-check/settings.json")"
assert_contains "$content" '"version": 1' "migrated to v1"
assert_contains "$content" '"threshold": 7' "user threshold preserved through migration"
assert_contains "$content" '"decay": 0.5' "new field 'decay' added"
assert_contains "$content" '"state_ttl_days": 7' "new field 'state_ttl_days' added"

summary

#!/bin/bash
# Test: check_rate_limit detects rate limit from exit code and output
set -euo pipefail

LAST_OUTPUT="/tmp/test-check-ratelimit-$$"
trap 'rm -f "$LAST_OUTPUT"' EXIT

check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}

# Non-zero exit code → rate limited
LAST_EXIT=1
echo 'normal output' > "$LAST_OUTPUT"
check_rate_limit || { echo "FAIL: non-zero exit should be rate limit"; exit 1; }

# Zero exit + rate_limit in output → rate limited
LAST_EXIT=0
echo '{"type":"rate_limit_event","status":"rejected"}' > "$LAST_OUTPUT"
check_rate_limit || { echo "FAIL: rate_limit in output should be detected"; exit 1; }

# Zero exit + normal output → not rate limited
LAST_EXIT=0
echo 'normal research output' > "$LAST_OUTPUT"
! check_rate_limit || { echo "FAIL: normal output should not be rate limit"; exit 1; }

#!/bin/bash
# Test: check_completed detects promise tag in output
set -euo pipefail

LAST_OUTPUT="/tmp/test-check-completed-$$"
trap 'rm -f "$LAST_OUTPUT"' EXIT

check_completed() {
    grep -q '<promise>TASK DONE</promise>' "$LAST_OUTPUT" 2>/dev/null
}

# Should detect completion
echo 'some output <promise>TASK DONE</promise> more output' > "$LAST_OUTPUT"
check_completed || { echo "FAIL: should detect promise tag"; exit 1; }

# Should not detect plain TASK DONE without tags
echo 'TASK DONE' > "$LAST_OUTPUT"
! check_completed || { echo "FAIL: should not detect plain TASK DONE"; exit 1; }

# Should not detect on empty file
echo '' > "$LAST_OUTPUT"
! check_completed || { echo "FAIL: should not detect on empty output"; exit 1; }

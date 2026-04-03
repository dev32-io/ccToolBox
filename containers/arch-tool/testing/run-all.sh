#!/bin/bash
# Run all tests in this directory
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

for test in "$DIR"/test_*.sh; do
    name="$(basename "$test" .sh)"
    if bash "$test" 2>&1; then
        printf "  ✅  %s\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  ❌  %s\n" "$name"
        FAIL=$((FAIL + 1))
    fi
done

echo
printf "  %d passed, %d failed\n\n" "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]

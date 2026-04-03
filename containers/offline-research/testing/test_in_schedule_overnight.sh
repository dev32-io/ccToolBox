#!/bin/bash
# Test: overnight window (23:00-07:00) correctly identifies times
set -euo pipefail

in_schedule() {
    local now="$1" TZ="UTC" RESEARCH_HOURS="23:00-07:00"
    local start end
    start="${RESEARCH_HOURS%%-*}"; end="${RESEARCH_HOURS##*-}"
    start="${start/:/}"; end="${end/:/}"
    if [[ "10#$start" -gt "10#$end" ]]; then
        [[ "10#$now" -ge "10#$start" || "10#$now" -lt "10#$end" ]]
    else
        [[ "10#$now" -ge "10#$start" && "10#$now" -lt "10#$end" ]]
    fi
}

# Inside window
in_schedule "2300" || { echo "FAIL: 23:00 should be in schedule"; exit 1; }
in_schedule "0200" || { echo "FAIL: 02:00 should be in schedule"; exit 1; }
in_schedule "0659" || { echo "FAIL: 06:59 should be in schedule"; exit 1; }

# Outside window
! in_schedule "0700" || { echo "FAIL: 07:00 should be outside schedule"; exit 1; }
! in_schedule "1200" || { echo "FAIL: 12:00 should be outside schedule"; exit 1; }
! in_schedule "2259" || { echo "FAIL: 22:59 should be outside schedule"; exit 1; }

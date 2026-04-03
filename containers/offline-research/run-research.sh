#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults (overridden by .env)
RESEARCH_HOURS="${RESEARCH_HOURS:-23:00-07:00}"
TZ="${TZ:-America/Vancouver}"
CONTAINER_NAME="${CONTAINER_NAME:-research-sandbox}"

# Load .env if present
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# Colors
DIM='\033[2m'
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'

# --- Functions ---

print_status() {
    local iter="$1" max="$2" workspace="$3" msg="${4:-}"
    printf "\n${BOLD}${CYAN}  research-runner${RESET}  ${DIM}iter %d/%d${RESET}  ${DIM}%s${RESET}" "$iter" "$max" "$workspace"
    [[ -n "$msg" ]] && printf "  ${YELLOW}%s${RESET}" "$msg"
    printf "\n\n"
}

run_iteration() {
    local workspace="$1"
    local prompt="Read ${workspace}/prompt.md for context. Read ${workspace}/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop."
    LAST_OUTPUT="/tmp/research-runner-output.$$"

    # Run interactively (full TUI visible), tee output for completion/rate-limit detection
    docker exec -it "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "$prompt" \
        2>&1 | tee "$LAST_OUTPUT"

    LAST_EXIT=${PIPESTATUS[0]}
}

check_completed() {
    grep -q '<promise>TASK DONE</promise>' "$LAST_OUTPUT" 2>/dev/null
}

check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}

probe_limit() {
    printf "  ${DIM}Probing if limit has reset...${RESET}\n"
    local probe_output="/tmp/research-probe-output.$$"
    docker exec "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "say hi" \
        --output-format json --max-turns 1 \
        < /dev/null > "$probe_output" 2>&1
    local code=$?
    if [[ $code -eq 0 ]] && ! grep -q 'rate_limit' "$probe_output" 2>/dev/null; then
        rm -f "$probe_output"
        return 0  # limit reset
    fi
    rm -f "$probe_output"
    return 1  # still limited
}

in_schedule() {
    local now start end
    now=$(TZ="$TZ" date +%H%M)
    start="${RESEARCH_HOURS%%-*}"
    end="${RESEARCH_HOURS##*-}"
    start="${start/:/}"
    end="${end/:/}"

    if [[ "10#$start" -gt "10#$end" ]]; then
        # Overnight window (e.g., 23:00-07:00)
        [[ "10#$now" -ge "10#$start" || "10#$now" -lt "10#$end" ]]
    else
        # Same-day window (e.g., 09:00-17:00)
        [[ "10#$now" -ge "10#$start" && "10#$now" -lt "10#$end" ]]
    fi
}

wait_for_reset() {
    if in_schedule; then
        printf "  ${YELLOW}Rate limited.${RESET} Inside research window — probing every hour.\n"
        while true; do
            sleep 3600
            if probe_limit; then
                printf "  ${GREEN}Limit reset!${RESET} Resuming.\n"
                return 0
            fi
            printf "  ${DIM}Still limited. Next probe in 1 hour.${RESET}\n"
        done
    else
        printf "  ${YELLOW}Rate limited.${RESET} Outside research window (${RESEARCH_HOURS}).\n"
        printf "  ${BOLD}Type 'continue' to resume:${RESET} "
        local input
        while true; do
            read -r input
            [[ "$input" == "continue" ]] && return 0
            printf "  ${DIM}Type 'continue' to resume:${RESET} "
        done
    fi
}

main() {
    local workspace="${1:?Usage: run-research.sh <workspace-path> [max-iterations]}"
    local max_iter="${2:-66}"
    local iter=0

    printf "\n${BOLD}${CYAN}  research-runner${RESET}\n"
    printf "  ${DIM}workspace:  %s${RESET}\n" "$workspace"
    printf "  ${DIM}max-iter:   %d${RESET}\n" "$max_iter"
    printf "  ${DIM}schedule:   %s (%s)${RESET}\n\n" "$RESEARCH_HOURS" "$TZ"

    while [[ $iter -lt $max_iter ]]; do
        iter=$((iter + 1))
        print_status "$iter" "$max_iter" "$workspace"

        run_iteration "$workspace"

        # Check for completion
        if check_completed; then
            printf "\n  ${GREEN}${BOLD}Research complete${RESET} after %d iterations.\n\n" "$iter"
            rm -f "$LAST_OUTPUT"
            break
        fi

        # Check for rate limit
        if check_rate_limit; then
            wait_for_reset
        fi

        rm -f "$LAST_OUTPUT"
        sleep 2
    done

    if [[ $iter -ge $max_iter ]]; then
        printf "\n  ${YELLOW}Max iterations reached${RESET} (%d).\n\n" "$max_iter"
    fi
}

main "$@"

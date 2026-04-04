#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults (overridden by .env)
RESEARCH_HOURS="${RESEARCH_HOURS:-23:00-07:00}"
TZ="${TZ:-America/Vancouver}"
CONTAINER_NAME="${CONTAINER_NAME:-research-sandbox}"
TAIL_LINES=10

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

# State
LAST_OUTPUT=""
LAST_EXIT=0
RUN_START=0

# ─── Formatting ───

fmt_duration() {
    local secs="$1"
    if [[ $secs -ge 3600 ]]; then
        printf "%dh%02dm%02ds" $((secs/3600)) $((secs%3600/60)) $((secs%60))
    elif [[ $secs -ge 60 ]]; then
        printf "%dm%02ds" $((secs/60)) $((secs%60))
    else
        printf "%ds" "$secs"
    fi
}

# ─── Progress parsing ───

QUEUE_DONE=0
QUEUE_TOTAL=0
NEXT_TASK=""

read_progress() {
    local workspace="$1"
    local content
    content=$(docker exec --user node "$CONTAINER_NAME" cat "${workspace}/progress.md" 2>/dev/null) || return 1
    QUEUE_DONE=$(echo "$content" | grep -c '^\- \[x\]' || true)
    QUEUE_TOTAL=$(echo "$content" | grep -c '^\- \[' || true)
    NEXT_TASK=$(echo "$content" | grep -m1 '^\- \[ \]' | sed 's/^- \[ \] //' || true)
}

# ─── Display ───

declare -a TAIL_BUFFER=()

redraw() {
    local iter="$1" max="$2" workspace="$3" iter_start="$4"
    local iter_elapsed=$((SECONDS - iter_start))
    local total_elapsed=$((SECONDS - RUN_START))

    printf '\033[2J\033[H'

    printf "  ${BOLD}${CYAN}research-runner${RESET}  ${DIM}iter %d/%d${RESET}  %s\n" \
        "$iter" "$max" "$workspace"
    printf "  ${DIM}elapsed:  %s iter  |  %s total${RESET}\n" \
        "$(fmt_duration $iter_elapsed)" "$(fmt_duration $total_elapsed)"
    printf "  ${DIM}queue:    %s/%s done${RESET}\n" "$QUEUE_DONE" "$QUEUE_TOTAL"
    printf "  ${DIM}next:     %s${RESET}\n" "$NEXT_TASK"
    printf "  ${DIM}─────────────────────────────────────${RESET}\n"

    local count=${#TAIL_BUFFER[@]}
    for ((i=0; i<TAIL_LINES; i++)); do
        if [[ $i -lt $count ]]; then
            printf "  ${DIM}%.120s${RESET}\n" "${TAIL_BUFFER[$i]}"
        else
            printf "\n"
        fi
    done
}

append_tail() {
    local line="$1"
    TAIL_BUFFER+=("$line")
    if [[ ${#TAIL_BUFFER[@]} -gt $TAIL_LINES ]]; then
        TAIL_BUFFER=("${TAIL_BUFFER[@]:1}")
    fi
}

# ─── Iteration ───

run_iteration() {
    local workspace="$1" iter="$2" max="$3"
    local prompt="Read ${workspace}/prompt.md for context. Read ${workspace}/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop."
    local iter_start=$SECONDS

    LAST_OUTPUT="/tmp/research-runner-output.$$"
    > "$LAST_OUTPUT"
    TAIL_BUFFER=()

    redraw "$iter" "$max" "$workspace" "$iter_start"

    docker exec --user node "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "$prompt" \
        > "$LAST_OUTPUT" 2>&1 &
    local claude_pid=$!

    local last_line_count=0
    while kill -0 "$claude_pid" 2>/dev/null; do
        local current_lines
        current_lines=$(wc -l < "$LAST_OUTPUT" 2>/dev/null || echo 0)
        if [[ $current_lines -gt $last_line_count ]]; then
            local skip=$((last_line_count))
            while IFS= read -r line; do
                append_tail "$line"
            done < <(tail -n "+$((skip + 1))" "$LAST_OUTPUT" 2>/dev/null | head -n "$((current_lines - last_line_count))")
            last_line_count=$current_lines
        fi

        redraw "$iter" "$max" "$workspace" "$iter_start"
        sleep 1
    done

    wait "$claude_pid" 2>/dev/null
    LAST_EXIT=$?

    while IFS= read -r line; do
        append_tail "$line"
    done < <(tail -n "+$((last_line_count + 1))" "$LAST_OUTPUT" 2>/dev/null)

    read_progress "$workspace" || true
    redraw "$iter" "$max" "$workspace" "$iter_start"
}

# ─── Completion checks ───

check_completed() {
    grep -q '<promise>TASK DONE</promise>' "$LAST_OUTPUT" 2>/dev/null
}

check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}

# ─── Rate limit handling ───

probe_limit() {
    printf "  ${DIM}Probing if limit has reset...${RESET}\n"
    local probe_output="/tmp/research-probe-output.$$"
    docker exec --user node "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "say hi" \
        --output-format json --max-turns 1 \
        < /dev/null > "$probe_output" 2>&1
    local code=$?
    if [[ $code -eq 0 ]] && ! grep -q 'rate_limit' "$probe_output" 2>/dev/null; then
        rm -f "$probe_output"
        return 0
    fi
    rm -f "$probe_output"
    return 1
}

in_schedule() {
    local now start end
    now=$(TZ="$TZ" date +%H%M)
    start="${RESEARCH_HOURS%%-*}"
    end="${RESEARCH_HOURS##*-}"
    start="${start/:/}"
    end="${end/:/}"

    if [[ "10#$start" -gt "10#$end" ]]; then
        [[ "10#$now" -ge "10#$start" || "10#$now" -lt "10#$end" ]]
    else
        [[ "10#$now" -ge "10#$start" && "10#$now" -lt "10#$end" ]]
    fi
}

wait_for_reset() {
    if in_schedule; then
        printf "\n  ${YELLOW}Rate limited.${RESET} Inside research window — probing every hour.\n"
        while true; do
            sleep 3600
            if probe_limit; then
                printf "  ${GREEN}Limit reset!${RESET} Resuming.\n"
                return 0
            fi
            printf "  ${DIM}Still limited. Next probe in 1 hour.${RESET}\n"
        done
    else
        printf "\n  ${YELLOW}Rate limited.${RESET} Outside research window (${RESEARCH_HOURS}).\n"
        printf "  ${BOLD}Type 'continue' to resume:${RESET} "
        local input
        while true; do
            read -r input
            [[ "$input" == "continue" ]] && return 0
            printf "  ${DIM}Type 'continue' to resume:${RESET} "
        done
    fi
}

# ─── Cleanup ───

cleanup() {
    rm -f "/tmp/research-runner-output.$$" "/tmp/research-probe-output.$$"
}
trap cleanup EXIT

# ─── Main ───

main() {
    local workspace="${1:?Usage: run-research.sh <workspace-path> [max-iterations]}"
    local max_iter="${2:-66}"
    local iter=0
    RUN_START=$SECONDS

    printf "\n${BOLD}${CYAN}  research-runner${RESET}\n"
    printf "  ${DIM}workspace:  %s${RESET}\n" "$workspace"
    printf "  ${DIM}max-iter:   %d${RESET}\n" "$max_iter"
    printf "  ${DIM}schedule:   %s (%s)${RESET}\n\n" "$RESEARCH_HOURS" "$TZ"

    while [[ $iter -lt $max_iter ]]; do
        iter=$((iter + 1))
        read_progress "$workspace" || true

        run_iteration "$workspace" "$iter" "$max_iter"

        if check_completed; then
            local total_elapsed=$((SECONDS - RUN_START))
            printf "\n  ${GREEN}${BOLD}Research complete${RESET} — %d iterations, %s\n\n" \
                "$iter" "$(fmt_duration $total_elapsed)"
            break
        fi

        if check_rate_limit; then
            wait_for_reset
        fi

        rm -f "$LAST_OUTPUT"
        sleep 2
    done

    if [[ $iter -ge $max_iter ]]; then
        local total_elapsed=$((SECONDS - RUN_START))
        printf "\n  ${YELLOW}Max iterations reached${RESET} (%d) after %s\n\n" \
            "$max_iter" "$(fmt_duration $total_elapsed)"
    fi
}

main "$@"

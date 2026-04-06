#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults (overridden by .env)
RESEARCH_HOURS="${RESEARCH_HOURS:-23:00-07:00}"
TZ="${TZ:-America/Vancouver}"
CONTAINER_NAME="${CONTAINER_NAME:-workshop-refactor-sandbox}"
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
CURRENT_TASK=""
NEXT_TASK=""

read_progress() {
    local content
    content=$(docker exec --user node "$CONTAINER_NAME" cat "/workspace/progress.md" 2>/dev/null) || return 1
    QUEUE_DONE=$(echo "$content" | grep -c '^\- \[x\]' || true)
    QUEUE_TOTAL=$(echo "$content" | grep -c '^\- \[' || true)
    CURRENT_TASK=$(echo "$content" | grep -m1 '^\- \[ \]' | sed 's/^- \[ \] //' || true)
    NEXT_TASK=$(echo "$content" | grep '^\- \[ \]' | sed -n '2p' | sed 's/^- \[ \] //' || true)
}

# ─── Display ───

declare -a TAIL_BUFFER=()

redraw() {
    local iter="$1" max="$2" iter_start="$3"
    local iter_elapsed=$((SECONDS - iter_start))
    local total_elapsed=$((SECONDS - RUN_START))

    # Clear screen, cursor to top
    printf '\033[2J\033[H'

    printf "  ${BOLD}${CYAN}refactor-runner${RESET}  ${DIM}iter %d/%d${RESET}\n" \
        "$iter" "$max"
    printf "  ${DIM}Elapsed:  %s iter  |  %s total${RESET}\n" \
        "$(fmt_duration $iter_elapsed)" "$(fmt_duration $total_elapsed)"
    printf "  ${DIM}Queue:    %s/%s done${RESET}\n" "$QUEUE_DONE" "$QUEUE_TOTAL"
    printf "  ${DIM}Current:  %s${RESET}\n" "$CURRENT_TASK"
    printf "  ${DIM}Next:     %s${RESET}\n" "${NEXT_TASK:---}"
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
    local iter="$1" max="$2"
    local prompt="Read /workspace/prompt.md for context. Read /workspace/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop."
    local iter_start=$SECONDS

    LAST_OUTPUT="/tmp/refactor-runner-output.$$"
    > "$LAST_OUTPUT"
    TAIL_BUFFER=()

    redraw "$iter" "$max" "$iter_start"

    # Start claude in background
    docker exec --user node "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "$prompt" \
        > "$LAST_OUTPUT" 2>&1 &
    local claude_pid=$!

    # Monitor loop: read new output lines + tick timer
    local last_line_count=0
    while kill -0 "$claude_pid" 2>/dev/null; do
        # Read any new lines from output
        local current_lines
        current_lines=$(wc -l < "$LAST_OUTPUT" 2>/dev/null || echo 0)
        if [[ $current_lines -gt $last_line_count ]]; then
            local skip=$((last_line_count))
            while IFS= read -r line; do
                append_tail "$line"
            done < <(tail -n "+$((skip + 1))" "$LAST_OUTPUT" 2>/dev/null | head -n "$((current_lines - last_line_count))")
            last_line_count=$current_lines
        fi

        redraw "$iter" "$max" "$iter_start"
        sleep 1
    done

    set +e
    wait "$claude_pid" 2>/dev/null
    LAST_EXIT=$?
    set -e

    # Final: read any remaining output
    while IFS= read -r line; do
        append_tail "$line"
    done < <(tail -n "+$((last_line_count + 1))" "$LAST_OUTPUT" 2>/dev/null)

    # Final render with updated progress
    read_progress || true
    redraw "$iter" "$max" "$iter_start"
}

# ─── Completion checks ───

check_completed() {
    grep -q '<promise>TASK DONE</promise>' "$LAST_OUTPUT" 2>/dev/null
}

check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    # Catches subagent limit errors that surface with different messages
    grep -qiE 'rate.?limit|too many requests|429|quota exceeded|capacity|overloaded|resource_exhausted' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}

check_errors() {
    local errors
    errors=$(grep -iE 'error|exception|panic|fatal|crash|ENOENT|ECONNREFUSED|ETIMEDOUT|spawn.*failed|subagent.*failed|tool_use_error|APIError|internal_error' \
        "$LAST_OUTPUT" 2>/dev/null || true)
    if [[ -n "$errors" ]]; then
        local ts log_file
        ts=$(date '+%Y-%m-%d %H:%M:%S')
        log_file="${PROBE_DIR:-.}/errors.log"
        echo "--- [$ts] iteration $iter (exit: $LAST_EXIT) ---" >> "$log_file"
        echo "$errors" >> "$log_file"
        echo "" >> "$log_file"
        printf "  ${YELLOW}Errors detected — see %s${RESET}\n" "$log_file"
    fi
}

# ─── Rate limit handling ───

probe_limit() {
    printf "  ${DIM}Probing if limit has reset...${RESET}\n"
    local probe_output="/tmp/refactor-probe-output.$$"
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
    printf "\n  ${YELLOW}Rate limited.${RESET}\n"
    if in_schedule; then
        printf "  Inside research window — probing every hour.\n"
        printf "  ${DIM}Or type 'resume' to retry now.${RESET}\n"
        while true; do
            read -t 3600 -r input 2>/dev/null || true
            if [[ "${input:-}" == "resume" ]]; then
                return 0
            fi
            if probe_limit; then
                printf "  ${GREEN}Limit reset!${RESET} Resuming.\n"
                return 0
            fi
            printf "  ${DIM}Still limited. Next probe in 1 hour.${RESET}\n"
        done
    else
        printf "  Outside research window (${RESEARCH_HOURS}).\n"
        printf "  ${BOLD}Type 'resume' to continue:${RESET} "
        local input
        while true; do
            read -r input
            [[ "$input" == "resume" ]] && return 0
            printf "  ${DIM}Type 'resume' to continue:${RESET} "
        done
    fi
}

# ─── Cleanup ───

cleanup() {
    rm -f "/tmp/refactor-runner-output.$$" "/tmp/refactor-probe-output.$$"
}
trap cleanup EXIT

# ─── Main ───

main() {
    local max_iter="${1:-75}"
    local iter=0
    RUN_START=$SECONDS

    printf "\n${BOLD}${CYAN}  refactor-runner${RESET}\n"
    printf "  ${DIM}max-iter:   %d${RESET}\n" "$max_iter"
    printf "  ${DIM}schedule:   %s (%s)${RESET}\n\n" "$RESEARCH_HOURS" "$TZ"

    while [[ $iter -lt $max_iter ]]; do
        iter=$((iter + 1))
        read_progress || true

        run_iteration "$iter" "$max_iter"

        check_errors

        if check_completed; then
            local total_elapsed=$((SECONDS - RUN_START))
            printf "\n  ${GREEN}${BOLD}Exploration complete${RESET} — %d iterations, %s\n\n" \
                "$iter" "$(fmt_duration $total_elapsed)"
            osascript -e 'display notification "Exploration complete!" with title "refactor-runner"' 2>/dev/null || true
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

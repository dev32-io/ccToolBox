# Research Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a host-side research runner script that `docker exec`s into the container, shows the full Claude TUI, and handles rate limits with schedule-aware auto-resume.

**Architecture:** `run-research.sh` runs on the host and loops: each iteration `docker exec`s Claude with the research prompt. On rate limit, it checks if current time is within allowed hours — if yes, probes hourly until limit resets; if no, waits for manual "continue". `launch.sh` gets subcommands (setup/run/shell). SKILL.md gets a third run option.

**Tech Stack:** Bash, Docker, jq

---

### Task 1: Create `.env.example`

**Files:**
- Create: `containers/offline-research/.env.example`

- [ ] **Step 1: Write `.env.example`**

```bash
# Research runner config — copy to .env and customize
RESEARCH_HOURS="23:00-07:00"
TZ="America/Vancouver"
CONTAINER_NAME="research-sandbox"
```

- [ ] **Step 2: Add `.env` to `.gitignore`**

Check if `containers/offline-research/.gitignore` exists. If not, create it. Add:

```
.env
```

- [ ] **Step 3: Commit**

```bash
git add containers/offline-research/.env.example containers/offline-research/.gitignore
git commit -m "feat(offline-research): add .env.example for runner config"
```

---

### Task 2: Create `run-research.sh`

**Files:**
- Create: `containers/offline-research/run-research.sh`

- [ ] **Step 1: Write the script**

```bash
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

    if [[ "$start" -gt "$end" ]]; then
        # Overnight window (e.g., 23:00-07:00)
        [[ "$now" -ge "$start" || "$now" -lt "$end" ]]
    else
        # Same-day window (e.g., 09:00-17:00)
        [[ "$now" -ge "$start" && "$now" -lt "$end" ]]
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x containers/offline-research/run-research.sh
```

- [ ] **Step 3: Commit**

```bash
git add containers/offline-research/run-research.sh
git commit -m "feat(offline-research): add research runner with schedule-aware auto-resume"
```

---

### Task 3: Update Dockerfile — add timezone

**Files:**
- Modify: `containers/offline-research/Dockerfile`

- [ ] **Step 1: Add TZ env var**

Add this line after the `ENV SHELL=/bin/bash` line:

```dockerfile
ENV TZ=America/Vancouver
```

- [ ] **Step 2: Commit**

```bash
git add containers/offline-research/Dockerfile
git commit -m "feat(offline-research): add default timezone to Dockerfile"
```

---

### Task 4: Rewrite `launch.sh` — subcommands (setup/run/shell)

**Files:**
- Modify: `containers/offline-research/launch.sh`

- [ ] **Step 1: Replace entire file contents**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# Defaults
IMAGE_NAME="offline-research"
WORKSPACE="${HOME}/offline-research"
CONTAINER_NAME="${CONTAINER_NAME:-research-sandbox}"
TZ="${TZ:-America/Vancouver}"
CONTAINER_HOME="${CLAUDE_CODE_RESEARCH_TOOL:?CLAUDE_CODE_RESEARCH_TOOL is not set}"
CLAUDE_PATH="${CONTAINER_HOME}/.claude"

# Colors
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'
FRAMES=('   ' '.  ' '.. ' '...')

spin() {
    local msg="$1" pid="$2" i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${DIM}${FRAMES[$((i % 4))]}${RESET} %s" "$msg"
        i=$((i + 1))
        sleep 0.3
    done
    wait "$pid"
    local exit_code=$?
    printf "\r  ${GREEN}ok${RESET}  %s\n" "$msg"
    return $exit_code
}

log_ok()   { printf "  ${GREEN}ok${RESET}  %b\n" "$1"; }
log_warn() { printf "  ${YELLOW}--${RESET}  %b\n" "$1"; }
log_dim()  { printf "  ${DIM}%b${RESET}\n" "$1"; }

build_image() {
    docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR" >/dev/null 2>&1 &
    spin "Building image" $!
}

ensure_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            docker start "$CONTAINER_NAME" >/dev/null
            log_ok "Started existing container"
        else
            log_ok "Container already running"
        fi
    else
        mkdir -p "$WORKSPACE" "$CLAUDE_PATH"
        local claude_json="${CONTAINER_HOME}/.claude.json"
        [ -f "$claude_json" ] || echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$claude_json"

        docker run -d \
            --name "$CONTAINER_NAME" \
            -v "$WORKSPACE:/workspace" \
            -v "${CLAUDE_PATH}:/home/node/.claude:rw" \
            -v "${CONTAINER_HOME}/.claude.json:/home/node/.claude.json:rw" \
            -e "TZ=${TZ}" \
            ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
            "$IMAGE_NAME" \
            tail -f /dev/null >/dev/null

        log_ok "Created container ${DIM}${CONTAINER_NAME}${RESET}"
    fi
}

cmd_setup() {
    printf "\n${BOLD}${CYAN}  offline-research setup${RESET}\n\n"
    build_image
    ensure_container
    echo
    log_dim "Dropping into container shell. Run 'claude login' to authenticate."
    echo
    docker exec -it "$CONTAINER_NAME" bash
}

cmd_run() {
    local workspace="${1:?Usage: launch.sh run <workspace-path> [max-iterations]}"
    local max_iter="${2:-66}"

    printf "\n${BOLD}${CYAN}  offline-research run${RESET}\n\n"
    build_image
    ensure_container
    echo
    exec "$SCRIPT_DIR/run-research.sh" "$workspace" "$max_iter"
}

cmd_shell() {
    printf "\n${BOLD}${CYAN}  offline-research shell${RESET}\n\n"
    ensure_container
    echo
    docker exec -it "$CONTAINER_NAME" bash
}

cmd_help() {
    printf "\n${BOLD}${CYAN}  offline-research${RESET}\n\n"
    printf "  ${BOLD}Usage:${RESET} launch.sh <command> [args]\n\n"
    printf "  ${BOLD}Commands:${RESET}\n"
    printf "    setup                          Create container and login\n"
    printf "    run <workspace> [max-iter]     Start research with auto-resume\n"
    printf "    shell                          Open container shell\n"
    echo
}

case "${1:-help}" in
    setup) cmd_setup ;;
    run)   shift; cmd_run "$@" ;;
    shell) cmd_shell ;;
    *)     cmd_help ;;
esac
```

- [ ] **Step 2: Commit**

```bash
git add containers/offline-research/launch.sh
git commit -m "feat(offline-research): rewrite launch.sh with setup/run/shell subcommands"
```

---

### Task 5: Update SKILL.md — add third run option

**Files:**
- Modify: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Replace the run options section**

Find the section starting with `**Present two run options (without showing commands yet):**` and replace everything from there down to (but not including) `Then ask:` with:

```
**Present three run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory (e.g. `2026-04-02-llm-safety`).

> **How do you want to run this research?**
> 1. In the offline research container with auto-resume (Recommended)
> 2. In the offline research container (manual)
> 3. Locally

After the user picks, print only the selected command:

- **Auto-resume command** (option 1):
  ```
  ./containers/offline-research/launch.sh run /workspace/<folder-name> <TOPIC_COUNT * 8 + 10>
  ```

- **Manual container command** (option 2, uses `/workspace/<folder-name>/` as the path):
  ```
  /ralph-loop:ralph-loop "Read /workspace/<folder-name>/prompt.md for context. Read /workspace/<folder-name>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 8 + 10> --completion-promise "TASK DONE"
  ```

- **Local command** (option 3, uses `<local-path>/` as the path):
  ```
  /ralph-loop:ralph-loop "Read <local-path>/prompt.md for context. Read <local-path>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 8 + 10> --completion-promise "TASK DONE"
  ```

Replace `<folder-name>` and `<local-path>` with actual values.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/skills/research-probe/SKILL.md
git commit -m "feat(offline-research): add auto-resume run option to research-probe"
```

---

### Task 6: Bump version to 2.2.0

**Files:**
- Modify: `plugins/offline-research/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump plugin.json**

Change `"version": "2.1.0"` to `"version": "2.2.0"`.

- [ ] **Step 2: Bump marketplace.json**

In the offline-research entry, change `"version": "2.1.0"` to `"version": "2.2.0"`.

- [ ] **Step 3: Commit and push**

```bash
git add plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(offline-research): bump to 2.2.0 — research runner with auto-resume"
git push origin main
```

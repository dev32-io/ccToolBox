#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# Defaults
IMAGE_NAME="arch-tool"
WORKSPACE="${HOME}/offline-research"
CONTAINER_NAME="${CONTAINER_NAME:-arch-sandbox}"
TZ="${TZ:-America/Vancouver}"

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
    if [[ $exit_code -eq 0 ]]; then
        printf "\r  ${GREEN}ok${RESET}  %s\n" "$msg"
    else
        printf "\r  ${RED}!!${RESET}  %s\n" "$msg"
    fi
    return $exit_code
}

log_ok()   { printf "  ${GREEN}ok${RESET}  %b\n" "$1"; }
log_err()  { printf "  ${RED}!!${RESET}  %b\n" "$1"; }
log_warn() { printf "  ${YELLOW}--${RESET}  %b\n" "$1"; }
log_dim()  { printf "  ${DIM}%b${RESET}\n" "$1"; }

build_image() {
    local build_log="/tmp/${IMAGE_NAME}-build-$$.log"
    docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR" >"$build_log" 2>&1 &
    if ! spin "Building image" $!; then
        cat "$build_log" >&2
        rm -f "$build_log"
        exit 1
    fi
    rm -f "$build_log"
}

ensure_container() {
    local CONTAINER_HOME="${CLAUDE_CODE_RESEARCH_TOOL:?CLAUDE_CODE_RESEARCH_TOOL is not set}"
    local CLAUDE_PATH="${CONTAINER_HOME}/.claude"

    # Always recreate from latest image — state lives on mounted volumes
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    mkdir -p "$WORKSPACE" "$CLAUDE_PATH"

    local claude_json="${CONTAINER_HOME}/.claude.json"
    [ -f "$claude_json" ] || echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$claude_json"

    docker run -d \
        --name "$CONTAINER_NAME" \
        --memory=4g --cpus=4 --pids-limit=200 \
        -v "$WORKSPACE:/workspace" \
        -v "${CLAUDE_PATH}:/home/node/.claude:rw" \
        -v "${CONTAINER_HOME}/.claude.json:/home/node/.claude.json:rw" \
        -e "TZ=${TZ}" \
        ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
        "$IMAGE_NAME" \
        tail -f /dev/null >/dev/null

    log_ok "Created container ${DIM}${CONTAINER_NAME}${RESET}"
}

cmd_setup() {
    printf "\n${BOLD}${CYAN}  arch-tool setup${RESET}\n\n"
    build_image
    ensure_container
    echo
    log_dim "Dropping into container shell. Run 'claude login' to authenticate."
    echo
    docker exec -it --user node "$CONTAINER_NAME" bash
}

cmd_run() {
    local topic_path="${1:?Usage: launch.sh run <topic-path> [max-iterations]}"
    local max_iter="${2:-75}"

    topic_path="$(cd "$topic_path" && pwd)"

    printf "\n${BOLD}${CYAN}  arch-tool run${RESET}\n\n"
    build_image
    WORKSPACE="$topic_path"
    ensure_container
    echo
    exec "$SCRIPT_DIR/run-arch.sh" "$max_iter"
}

cmd_shell() {
    printf "\n${BOLD}${CYAN}  arch-tool shell${RESET}\n\n"
    ensure_container
    echo
    docker exec -it --user node "$CONTAINER_NAME" bash
}

cmd_help() {
    printf "\n${BOLD}${CYAN}  arch-tool${RESET}\n\n"
    printf "  ${BOLD}Usage:${RESET} launch.sh <command> [args]\n\n"
    printf "  ${BOLD}Commands:${RESET}\n"
    printf "    setup                          Create container and login\n"
    printf "    run <topic-path> [max-iter]     Start architecture exploration with auto-resume\n"
    printf "    shell                          Open container shell\n"
    echo
}

case "${1:-help}" in
    setup) cmd_setup ;;
    run)   shift; cmd_run "$@" ;;
    shell) cmd_shell ;;
    *)     cmd_help ;;
esac

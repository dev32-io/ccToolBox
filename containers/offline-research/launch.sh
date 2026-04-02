#!/bin/bash
set -euo pipefail

IMAGE_NAME="offline-research"
WORKSPACE="${HOME}/offline-research"
CONTAINER_HOME="${CLAUDE_CODE_RESEARCH_TOOL:?CLAUDE_CODE_RESEARCH_TOOL is not set}"
CLAUDE_PATH="${CONTAINER_HOME}/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

setup_env() {
    local claude_json="${CONTAINER_HOME}/.claude.json"
    mkdir -p "$WORKSPACE" "$CLAUDE_PATH"
    [ -f "$claude_json" ] || echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$claude_json"

    log_ok "Workspace ${DIM}${WORKSPACE}${RESET}"
    log_ok "Credentials mounted"

    if [ -z "${GH_TOKEN:-}" ]; then
        log_warn "GH_TOKEN not set ${DIM}(GitHub API will be rate-limited)${RESET}"
    else
        log_ok "GH_TOKEN loaded"
    fi
}

launch() {
    log_dim "Launching container..."
    echo

    docker run -it --rm \
        -v "$WORKSPACE:/workspace" \
        -v "${CLAUDE_PATH}:/home/node/.claude:rw" \
        -v "${CONTAINER_HOME}/.claude.json:/home/node/.claude.json:rw" \
        ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
        "$IMAGE_NAME" "$@"
}

printf "\n${BOLD}${CYAN}  offline-research${RESET}\n\n"
build_image
setup_env
echo
launch "$@"

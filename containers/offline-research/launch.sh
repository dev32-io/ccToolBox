#!/bin/bash
set -euo pipefail

IMAGE_NAME="offline-research"
WORKSPACE="${HOME}/offline-research"
CONTAINER_HOME="${CLAUDE_CODE_RESEARCH_TOOL:?CLAUDE_CODE_RESEARCH_TOOL is not set}"
CLAUDE_PATH="${CONTAINER_HOME}/.claude"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Building $IMAGE_NAME image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

CLAUDE_JSON="${CONTAINER_HOME}/.claude.json"
mkdir -p "$WORKSPACE" "$CLAUDE_PATH"
[ -f "$CLAUDE_JSON" ] || echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$CLAUDE_JSON"

if [ -z "${GH_TOKEN:-}" ]; then
    echo "Warning: GH_TOKEN not set. GitHub API will be rate-limited."
fi

docker run -it --rm \
    -v "$WORKSPACE:/workspace" \
    -v "${CLAUDE_PATH}:/home/node/.claude:rw" \
    -v "${CLAUDE_JSON}:/home/node/.claude.json:rw" \
    ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
    "$IMAGE_NAME" "$@"

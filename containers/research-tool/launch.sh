#!/bin/bash
set -euo pipefail

IMAGE_NAME="claude-research"
WORKSPACE="${1:-$HOME/research}"
CONTAINER_NAME="research-sandbox"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Building $IMAGE_NAME image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

mkdir -p "$WORKSPACE"

# Resume existing container or create new one
if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
    echo "Resuming existing container..."
    docker start -ai "$CONTAINER_NAME"
else
    docker run -it --name "$CONTAINER_NAME" -v "$WORKSPACE:/workspace" "$IMAGE_NAME"
fi

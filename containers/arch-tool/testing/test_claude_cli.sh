#!/bin/bash
# Test: Claude CLI runs and reports a valid version (integration test, requires Docker)
set -euo pipefail

CONTAINER_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="arch-tool-test"

command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

docker build -q -t "$IMAGE_NAME" "$CONTAINER_DIR" >/dev/null 2>&1 || { echo "FAIL: docker build failed"; exit 1; }

# Verify claude --version outputs a version string (runs as node user via entrypoint)
version=$(docker run --rm --entrypoint bash --user node "$IMAGE_NAME" -c "claude --version 2>&1") || { echo "FAIL: claude --version exited non-zero"; exit 1; }

if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "PASS: claude version $version"
else
    echo "FAIL: unexpected version output: $version"
    exit 1
fi

docker rmi "$IMAGE_NAME" >/dev/null 2>&1 || true

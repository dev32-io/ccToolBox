#!/bin/bash
# Test: Docker image builds successfully and all tools exist (integration test, requires Docker)
set -euo pipefail

CONTAINER_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Check Docker is available
command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

# Build the image
docker build -q -t arch-tool-test "$CONTAINER_DIR" >/dev/null 2>&1 || { echo "FAIL: docker build failed"; exit 1; }

# Verify base tools
docker run --rm --entrypoint bash arch-tool-test -c "
    command -v claude >/dev/null || exit 1
    command -v python3 >/dev/null || exit 1
    command -v rg >/dev/null || exit 1
    command -v git >/dev/null || exit 1
    command -v jq >/dev/null || exit 1
    command -v gh >/dev/null || exit 1
    command -v tree >/dev/null || exit 1
    command -v sqlite3 >/dev/null || exit 1
" || { echo "FAIL: missing base tools in image"; exit 1; }

# Verify PoC dependencies
docker run --rm --entrypoint bash arch-tool-test -c "
    command -v bun >/dev/null || exit 1
    command -v rustc >/dev/null || exit 1
    command -v cargo >/dev/null || exit 1
    command -v go >/dev/null || exit 1
    command -v tsc >/dev/null || exit 1
    command -v tsx >/dev/null || exit 1
    command -v pnpm >/dev/null || exit 1
    command -v chromium >/dev/null || exit 1
" || { echo "FAIL: missing PoC dependencies in image"; exit 1; }

# Cleanup
docker rmi arch-tool-test >/dev/null 2>&1 || true

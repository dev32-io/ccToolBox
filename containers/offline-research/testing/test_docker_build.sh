#!/bin/bash
# Test: Docker image builds successfully (integration test, requires Docker)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Check Docker is available
command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

# Build the image
docker build -q -t offline-research-test "$SCRIPT_DIR" >/dev/null 2>&1 || { echo "FAIL: docker build failed"; exit 1; }

# Verify key tools are installed
docker run --rm --entrypoint bash offline-research-test -c "
    command -v claude >/dev/null || exit 1
    command -v python3 >/dev/null || exit 1
    command -v rg >/dev/null || exit 1
    command -v git >/dev/null || exit 1
    command -v jq >/dev/null || exit 1
    command -v gh >/dev/null || exit 1
    command -v tree >/dev/null || exit 1
    command -v sqlite3 >/dev/null || exit 1
" || { echo "FAIL: missing tools in image"; exit 1; }

# Cleanup
docker rmi offline-research-test >/dev/null 2>&1 || true

#!/bin/bash
# Test: poc user isolation — cannot access .private/ directory (integration test, requires Docker)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Check Docker is available
command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

# Check image exists (built by test_docker_build)
docker image inspect arch-tool-test >/dev/null 2>&1 || docker image inspect arch-tool >/dev/null 2>&1 || { echo "SKIP: arch-tool image not found (run test_docker_build first)"; exit 0; }

IMAGE=$(docker image inspect arch-tool-test >/dev/null 2>&1 && echo "arch-tool-test" || echo "arch-tool")
CONTAINER="arch-tool-sec-test-$$"
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

# Start container as root so we can use runuser
docker run -d --name "$CONTAINER" --user root --entrypoint bash "$IMAGE" -c "tail -f /dev/null" >/dev/null

# poc user exists
docker exec "$CONTAINER" id poc >/dev/null 2>&1 || { echo "FAIL: poc user does not exist"; exit 1; }

# .private/ is 700 owned by node
perms=$(docker exec "$CONTAINER" stat -c '%a %U' /home/node/.private)
[[ "$perms" == "700 node" ]] || { echo "FAIL: .private/ perms should be '700 node', got '$perms'"; exit 1; }

# Create dummy content inside .private/ so directory isn't empty
docker exec "$CONTAINER" bash -c "mkdir -p /home/node/.private/test-secret"

# poc user CANNOT traverse .private/
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- ls /home/node/.private/ 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc user should not be able to traverse .private/, got: $poc_output"; exit 1; }

# node user CAN access .private/
docker exec --user node "$CONTAINER" ls /home/node/.private/ >/dev/null 2>&1 || { echo "FAIL: node user should be able to access .private/"; exit 1; }

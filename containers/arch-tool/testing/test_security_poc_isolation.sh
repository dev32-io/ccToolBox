#!/bin/bash
# Test: poc user isolation — cannot access sensitive areas, can only write to /workspace/poc
set -euo pipefail

CONTAINER_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Check Docker is available
command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

# Check image exists (built by test_docker_build)
docker image inspect arch-tool-test >/dev/null 2>&1 || docker image inspect arch-tool >/dev/null 2>&1 || { echo "SKIP: arch-tool image not found (run test_docker_build first)"; exit 0; }

IMAGE=$(docker image inspect arch-tool-test >/dev/null 2>&1 && echo "arch-tool-test" || echo "arch-tool")
CONTAINER="arch-tool-sec-test-$$"
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

# Start container as root so we can use runuser
docker run -d --name "$CONTAINER" --user root --entrypoint bash "$IMAGE" -c "tail -f /dev/null" >/dev/null

# --- Basic poc user checks ---

# poc user exists
docker exec "$CONTAINER" id poc >/dev/null 2>&1 || { echo "FAIL: poc user does not exist"; exit 1; }

# .private/ is 700 owned by node
perms=$(docker exec "$CONTAINER" stat -c '%a %U' /home/node/.private)
[[ "$perms" == "700 node" ]] || { echo "FAIL: .private/ perms should be '700 node', got '$perms'"; exit 1; }

# node user CAN access .private/
docker exec --user node "$CONTAINER" ls /home/node/.private/ >/dev/null 2>&1 || { echo "FAIL: node user should be able to access .private/"; exit 1; }

# --- poc cannot access auth tokens ---

# Simulate mounted .claude/ inside .private/
docker exec "$CONTAINER" bash -c "mkdir -p /home/node/.private/.claude/sessions && echo 'SECRET_TOKEN' > /home/node/.private/.claude/sessions/auth.json"

# poc cannot traverse .private/
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- ls /home/node/.private/ 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc cannot traverse .private/, got: $poc_output"; exit 1; }

# poc cannot read auth tokens directly
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- cat /home/node/.private/.claude/sessions/auth.json 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc cannot read auth tokens, got: $poc_output"; exit 1; }

# poc cannot access .claude/ via symlink (simulating entrypoint behavior)
docker exec "$CONTAINER" bash -c "ln -sf /home/node/.private/.claude /home/node/.claude"
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- cat /home/node/.claude/sessions/auth.json 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc cannot follow .claude symlink to auth tokens, got: $poc_output"; exit 1; }

# --- poc cannot access node user's home ---

# poc cannot list node's home directory private files
docker exec "$CONTAINER" bash -c "chmod 700 /home/node/.private"  # ensure reset
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- ls /home/node/.private 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc cannot access node's .private dir, got: $poc_output"; exit 1; }

# --- poc cannot write to workspace seed files ---

# Simulate workspace with seed files
docker exec "$CONTAINER" bash -c "mkdir -p /workspace/test-project && echo 'seed prompt' > /workspace/test-project/prompt.md && chown -R node:node /workspace/test-project"

# poc cannot overwrite prompt.md (prompt injection vector)
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- bash -c 'echo INJECTED > /workspace/test-project/prompt.md' 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc should not be able to overwrite seed files, got: $poc_output"; exit 1; }

# poc cannot create files in workspace root (injection via new files)
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /workspace/test-project/malicious.md 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc should not be able to create files in workspace, got: $poc_output"; exit 1; }

# --- poc CAN write to /workspace/poc/ (designated sandbox) ---

docker exec "$CONTAINER" bash -c "mkdir -p /workspace/poc && chown poc:poc /workspace/poc && chmod 755 /workspace/poc"
docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /workspace/poc/test-file.js" || { echo "FAIL: poc should be able to write to /workspace/poc/"; exit 1; }

# --- node CANNOT write to /workspace/poc/ (bidirectional enforcement) ---
# Forces model to use "sudo -u poc" — can't skip the sandbox by running as node directly

node_output=$(docker exec --user node "$CONTAINER" bash -c "touch /workspace/poc/node-bypass.js 2>&1" || true)
echo "$node_output" | grep -q "Permission denied" || { echo "FAIL: node should not be able to write to /workspace/poc/, got: $node_output"; exit 1; }

# node CAN read from /workspace/poc/ (needs to read PoC results for scoring)
docker exec --user node "$CONTAINER" bash -c "cat /workspace/poc/test-file.js" >/dev/null 2>&1 || { echo "FAIL: node should be able to read from /workspace/poc/"; exit 1; }

# node CAN write to /workspace/poc/ via sudo -u poc (the intended path)
docker exec --user node "$CONTAINER" bash -c "sudo -u poc touch /workspace/poc/via-sudo.js" || { echo "FAIL: node should write to /workspace/poc/ via sudo -u poc"; exit 1; }

# --- poc cannot write to system paths ---

poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /usr/local/bin/evil 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied\|Read-only\|cannot touch" || { echo "FAIL: poc should not write to /usr/local/bin/, got: $poc_output"; exit 1; }

poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /etc/evil 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied\|Read-only\|cannot touch" || { echo "FAIL: poc should not write to /etc/, got: $poc_output"; exit 1; }

# --- sudo delegation: node can run commands as poc ---

# node user can delegate to poc via sudo (how Claude Code runs PoC code)
docker exec --user node "$CONTAINER" sudo -u poc whoami 2>/dev/null | grep -q "poc" || { echo "FAIL: node should be able to sudo -u poc"; exit 1; }

# node can execute code as poc in the sandbox
docker exec --user node "$CONTAINER" bash -c "sudo -u poc bash -c 'echo test > /workspace/poc/sudo-test.txt'" || { echo "FAIL: node should sudo -u poc to write in /workspace/poc/"; exit 1; }

# poc via sudo still cannot read auth tokens
poc_output=$(docker exec --user node "$CONTAINER" bash -c "sudo -u poc cat /home/node/.private/.claude/sessions/auth.json 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: sudo -u poc still cannot read auth tokens, got: $poc_output"; exit 1; }

# poc cannot sudo back to node (one-way delegation)
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- sudo -u node whoami 2>&1" || true)
echo "$poc_output" | grep -q "not allowed\|not permitted\|unknown user\|is not in the sudoers\|password is required" || { echo "FAIL: poc should not be able to sudo to node, got: $poc_output"; exit 1; }

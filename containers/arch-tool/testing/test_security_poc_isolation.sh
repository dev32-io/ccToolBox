#!/bin/bash
# Test: poc user isolation — cannot access sensitive areas, can only write to /workspace/poc
set -euo pipefail

CONTAINER_DIR="$(cd "$(dirname "$0")/.." && pwd)"

command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

docker image inspect arch-tool-test >/dev/null 2>&1 || docker image inspect arch-tool >/dev/null 2>&1 || { echo "SKIP: arch-tool image not found (run test_docker_build first)"; exit 0; }

IMAGE=$(docker image inspect arch-tool-test >/dev/null 2>&1 && echo "arch-tool-test" || echo "arch-tool")
CONTAINER="arch-tool-sec-test-$$"
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CONTAINER" --user root --entrypoint bash "$IMAGE" -c "tail -f /dev/null" >/dev/null

# ─── Basic poc user checks ───

docker exec "$CONTAINER" id poc >/dev/null 2>&1 || { echo "FAIL: poc user does not exist"; exit 1; }

# ─── Auth isolation (chmod 700 on ~/.claude) ───

# Simulate mounted .claude/ directory
docker exec "$CONTAINER" bash -c "
    mkdir -p /home/node/.claude/sessions
    echo 'TEST_PLACEHOLDER' > /home/node/.claude/sessions/auth.json
    chown -R node:node /home/node/.claude
    chmod 700 /home/node/.claude
"

# node CAN access .claude/
docker exec --user node "$CONTAINER" cat /home/node/.claude/sessions/auth.json >/dev/null 2>&1 || { echo "FAIL: node should be able to read .claude/"; exit 1; }

# poc CANNOT access .claude/ (blocked by chmod 700)
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- ls /home/node/.claude/ 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc cannot access .claude/, got: $poc_output"; exit 1; }

poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- cat /home/node/.claude/sessions/auth.json 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc cannot read auth tokens, got: $poc_output"; exit 1; }

# poc via sudo still cannot read auth tokens
poc_output=$(docker exec --user node "$CONTAINER" bash -c "sudo -u poc cat /home/node/.claude/sessions/auth.json 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: sudo -u poc still cannot read auth tokens, got: $poc_output"; exit 1; }

# ─── Workspace isolation ───

# Simulate entrypoint's workspace permission setup
docker exec "$CONTAINER" bash -c "
    mkdir -p /workspace/test-project
    echo 'seed prompt' > /workspace/test-project/prompt.md
    chown -R node:node /workspace/test-project
    chmod -R o-w /workspace/test-project
    chown node:node /workspace
    chmod 755 /workspace
"

# poc cannot overwrite seed files (prompt injection vector)
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- bash -c 'echo INJECTED > /workspace/test-project/prompt.md' 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc should not overwrite seed files, got: $poc_output"; exit 1; }

# poc cannot create files in workspace project dirs
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /workspace/test-project/malicious.md 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied" || { echo "FAIL: poc should not create files in workspace, got: $poc_output"; exit 1; }

# poc cannot create new dirs in /workspace root
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- mkdir /workspace/evil-project 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied\|cannot create" || { echo "FAIL: poc should not create dirs in /workspace, got: $poc_output"; exit 1; }

# poc CAN read workspace files (needed to reference research)
docker exec "$CONTAINER" bash -c "runuser -u poc -- cat /workspace/test-project/prompt.md" >/dev/null 2>&1 || { echo "FAIL: poc should be able to read workspace files"; exit 1; }

# ─── PoC sandbox ───

docker exec "$CONTAINER" bash -c "mkdir -p /workspace/poc && chown poc:poc /workspace/poc && chmod 755 /workspace/poc"

# poc CAN write to /workspace/poc/
docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /workspace/poc/test-file.js" || { echo "FAIL: poc should write to /workspace/poc/"; exit 1; }

# poc CAN create subdirs in /workspace/poc/
docker exec "$CONTAINER" bash -c "runuser -u poc -- mkdir -p /workspace/poc/my-poc && runuser -u poc -- touch /workspace/poc/my-poc/main.py" || { echo "FAIL: poc should create subdirs in /workspace/poc/"; exit 1; }

# node CANNOT write to /workspace/poc/ directly (bidirectional enforcement)
node_output=$(docker exec --user node "$CONTAINER" bash -c "touch /workspace/poc/node-bypass.js 2>&1" || true)
echo "$node_output" | grep -q "Permission denied" || { echo "FAIL: node should not write to /workspace/poc/ directly, got: $node_output"; exit 1; }

# node CAN read from /workspace/poc/ (needs to read PoC results)
docker exec --user node "$CONTAINER" bash -c "cat /workspace/poc/test-file.js" >/dev/null 2>&1 || { echo "FAIL: node should read from /workspace/poc/"; exit 1; }

# node CAN write to /workspace/poc/ via sudo -u poc (the intended path)
docker exec --user node "$CONTAINER" bash -c "sudo -u poc touch /workspace/poc/via-sudo.js" || { echo "FAIL: node should write via sudo -u poc"; exit 1; }

# ─── System path protection ───

poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /usr/local/bin/evil 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied\|Read-only\|cannot touch" || { echo "FAIL: poc should not write to /usr/local/bin/, got: $poc_output"; exit 1; }

poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- touch /etc/evil 2>&1" || true)
echo "$poc_output" | grep -q "Permission denied\|Read-only\|cannot touch" || { echo "FAIL: poc should not write to /etc/, got: $poc_output"; exit 1; }

# ─── Sudo delegation ───

# node can delegate to poc
docker exec --user node "$CONTAINER" sudo -u poc whoami 2>/dev/null | grep -q "poc" || { echo "FAIL: node should sudo -u poc"; exit 1; }

# poc cannot sudo back to node (one-way delegation)
poc_output=$(docker exec "$CONTAINER" bash -c "runuser -u poc -- sudo -u node whoami 2>&1" || true)
echo "$poc_output" | grep -q "not allowed\|not permitted\|unknown user\|is not in the sudoers\|password is required" || { echo "FAIL: poc should not sudo to node, got: $poc_output"; exit 1; }

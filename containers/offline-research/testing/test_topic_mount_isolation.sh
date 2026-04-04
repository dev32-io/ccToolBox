#!/bin/bash
# Test: topic dir is mounted directly to /workspace — isolated from other topics
set -euo pipefail

command -v docker >/dev/null 2>&1 || { echo "SKIP: docker not found"; exit 0; }

docker image inspect offline-research-test >/dev/null 2>&1 || docker image inspect offline-research >/dev/null 2>&1 || { echo "SKIP: offline-research image not found (run test_docker_build first)"; exit 0; }

IMAGE=$(docker image inspect offline-research-test >/dev/null 2>&1 && echo "offline-research-test" || echo "offline-research")
CONTAINER="research-mount-test-$$"
TOPIC_A="/tmp/research-mount-test-topic-a-$$"
TOPIC_B="/tmp/research-mount-test-topic-b-$$"

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$TOPIC_A" "$TOPIC_B"
}
trap cleanup EXIT

# Create two topic dirs with distinct content
mkdir -p "$TOPIC_A" "$TOPIC_B"
echo "topic-a prompt" > "$TOPIC_A/prompt.md"
echo "topic-a progress" > "$TOPIC_A/progress.md"
echo "topic-b prompt" > "$TOPIC_B/prompt.md"
echo "secret-b data" > "$TOPIC_B/secret.md"

# Mount topic A to /workspace
docker run -d --name "$CONTAINER" \
    -v "$TOPIC_A:/workspace" \
    "$IMAGE" \
    tail -f /dev/null >/dev/null

# Container sees topic A files
docker exec "$CONTAINER" cat /workspace/prompt.md | grep -q "topic-a prompt" \
    || { echo "FAIL: should see topic A prompt.md"; exit 1; }

docker exec "$CONTAINER" cat /workspace/progress.md | grep -q "topic-a progress" \
    || { echo "FAIL: should see topic A progress.md"; exit 1; }

# Container does NOT see topic B files
ls_output=$(docker exec "$CONTAINER" ls /workspace/ 2>&1)
echo "$ls_output" | grep -q "secret.md" && { echo "FAIL: topic B files should not be visible"; exit 1; }

# Container cannot access topic B path at all (not mounted)
docker exec "$CONTAINER" test -d "$TOPIC_B" 2>/dev/null \
    && { echo "FAIL: topic B host path should not exist in container"; exit 1; } || true

# Files written in container appear in host topic A dir
docker exec "$CONTAINER" bash -c "echo 'new-file' > /workspace/output.md"
grep -q "new-file" "$TOPIC_A/output.md" \
    || { echo "FAIL: writes should appear in host topic A dir"; exit 1; }

# Files do NOT leak to topic B
test -f "$TOPIC_B/output.md" && { echo "FAIL: writes should not appear in topic B"; exit 1; } || true

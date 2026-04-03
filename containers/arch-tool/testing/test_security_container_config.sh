#!/bin/bash
# Test: static analysis of launch.sh, Dockerfile, and entrypoint.sh for security properties
set -euo pipefail

CONTAINER_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# --- launch.sh checks ---

# :ro mount for .claude
grep -q '\.claude:ro' "$CONTAINER_DIR/launch.sh" || { echo "FAIL: launch.sh missing :ro mount for .claude"; exit 1; }

# Resource limits
grep -q '\-\-memory=' "$CONTAINER_DIR/launch.sh" || { echo "FAIL: launch.sh missing --memory= resource limit"; exit 1; }
grep -q '\-\-cpus=' "$CONTAINER_DIR/launch.sh" || { echo "FAIL: launch.sh missing --cpus= resource limit"; exit 1; }
grep -q '\-\-pids-limit=' "$CONTAINER_DIR/launch.sh" || { echo "FAIL: launch.sh missing --pids-limit= resource limit"; exit 1; }

# --- Dockerfile checks ---

# No Docker-in-Docker
! grep -q 'docker\.io' "$CONTAINER_DIR/Dockerfile" || { echo "FAIL: Dockerfile should not contain docker.io (no Docker-in-Docker)"; exit 1; }
! grep -q 'dockerd' "$CONTAINER_DIR/Dockerfile" || { echo "FAIL: Dockerfile should not contain dockerd (no Docker-in-Docker)"; exit 1; }

# poc user created
grep -q 'useradd.*poc' "$CONTAINER_DIR/Dockerfile" || { echo "FAIL: Dockerfile missing useradd poc"; exit 1; }

# --- entrypoint.sh checks ---

grep -q 'chmod 700\|\.private' "$CONTAINER_DIR/entrypoint.sh" || { echo "FAIL: entrypoint.sh missing chmod 700 or .private reference"; exit 1; }

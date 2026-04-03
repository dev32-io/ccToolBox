#!/bin/bash
# Test: launch.sh help works without CLAUDE_CODE_RESEARCH_TOOL set
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Unset the env var to make sure help doesn't require it
unset CLAUDE_CODE_RESEARCH_TOOL 2>/dev/null || true

output=$(bash "$SCRIPT_DIR/launch.sh" help 2>&1)

echo "$output" | grep -q "setup" || { echo "FAIL: help should mention setup"; exit 1; }
echo "$output" | grep -q "run" || { echo "FAIL: help should mention run"; exit 1; }
echo "$output" | grep -q "shell" || { echo "FAIL: help should mention shell"; exit 1; }

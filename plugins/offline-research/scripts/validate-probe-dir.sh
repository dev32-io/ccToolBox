#!/bin/bash
# validate-probe-dir.sh — sanity-check a workshop-loop probe directory
# Exit codes:
#   0 — valid (emits VALIDATED line on stdout for command body to parse)
#   1 — missing/corrupt required files or headers
#   2 — bad CLI args
#   3 — probe-dir already in terminal state (nothing to do)

set -uo pipefail

usage() { echo "Usage: validate-probe-dir.sh <probe-dir> [--max-iter N]" >&2; exit 2; }

[[ $# -ge 1 ]] || usage
PROBE_DIR="$1"; shift
MAX_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-iter)
            [[ -n "${2:-}" ]] || { echo "❌ --max-iter requires a number" >&2; exit 2; }
            [[ "$2" =~ ^[1-9][0-9]*$ ]] || { echo "❌ --max-iter must be a positive integer, got: $2" >&2; exit 2; }
            MAX_OVERRIDE="$2"; shift 2 ;;
        *)
            echo "❌ unknown arg: $1" >&2; usage ;;
    esac
done

# Resolve to absolute path
PROBE_DIR_ABS="$(cd "$PROBE_DIR" 2>/dev/null && pwd)" || {
    echo "❌ probe-dir not found: $PROBE_DIR" >&2; exit 1; }
PROBE_DIR="$PROBE_DIR_ABS"

# Required files
for f in mission.md progress.md scoring-rubric.md; do
    [[ -f "$PROBE_DIR/$f" ]] || {
        echo "❌ missing $f in $PROBE_DIR — did you run a probe skill first?" >&2
        exit 1
    }
done

# progress.md must have max_iter header
HEADER_MAX=$(grep -m1 '^max_iter:' "$PROBE_DIR/progress.md" | sed 's/max_iter: *//' | tr -d '[:space:]')
[[ "$HEADER_MAX" =~ ^[0-9]+$ ]] || {
    echo "❌ progress.md missing or invalid 'max_iter: N' header" >&2; exit 1; }

# Apply --max-iter override
if [[ -n "$MAX_OVERRIDE" ]]; then
    # Portable in-place edit (works on macOS + Linux)
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^max_iter:.*/max_iter: $MAX_OVERRIDE/" "$PROBE_DIR/progress.md"
    else
        sed -i "s/^max_iter:.*/max_iter: $MAX_OVERRIDE/" "$PROBE_DIR/progress.md"
    fi
    HEADER_MAX="$MAX_OVERRIDE"
fi

# Sanity: at least one unchecked task or active row
PENDING=$(grep -c '^- \[ \]' "$PROBE_DIR/progress.md" 2>/dev/null || true)
PENDING="${PENDING:-0}"
ACTIVE=$(grep -c '| ACTIVE |' "$PROBE_DIR/progress.md" 2>/dev/null || true)
ACTIVE="${ACTIVE:-0}"
if [[ $PENDING -eq 0 && $ACTIVE -eq 0 ]]; then
    echo "ℹ️  probe-dir is already in terminal state (no pending tasks, no active rows). Nothing to do." >&2
    exit 3
fi

echo "VALIDATED probe_dir=$PROBE_DIR max_iter=$HEADER_MAX pending=$PENDING active=$ACTIVE"
exit 0

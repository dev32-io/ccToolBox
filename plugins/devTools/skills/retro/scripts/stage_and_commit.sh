#!/usr/bin/env bash
# stage_and_commit.sh — stage exactly the given paths and commit with the
# provided message file. Refuses on staging drift. Never uses --no-verify.
#
# Usage: stage_and_commit.sh <message-file> <path> [<path>...]
# Exit codes:
#   0  success
#   2  no paths provided / message file missing / path does not exist
#   3  staged set drifted from expected set (unrelated pre-staged content)
#   *  passthrough from `git commit` (e.g. hook rejection)
set -euo pipefail

msg_file="${1:-}"
if [[ -z "$msg_file" || ! -f "$msg_file" ]]; then
  echo "stage_and_commit.sh: message file required" >&2
  exit 2
fi
shift

if [[ $# -eq 0 ]]; then
  echo "stage_and_commit.sh: no paths to stage" >&2
  exit 2
fi

paths=("$@")

# Sanity: all paths must exist on disk.
for p in "${paths[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "stage_and_commit.sh: path does not exist: $p" >&2
    exit 2
  fi
done

git add -- "${paths[@]}"

# Verify the staged set matches exactly what we were asked to stage.
staged="$(git diff --cached --name-only | sort -u)"
expected="$(printf '%s\n' "${paths[@]}" | sort -u)"
if [[ "$staged" != "$expected" ]]; then
  echo "stage_and_commit.sh: staged set drifted from expected." >&2
  echo "--- staged ---" >&2
  echo "$staged" >&2
  echo "--- expected ---" >&2
  echo "$expected" >&2
  exit 3
fi

git commit -F "$msg_file"

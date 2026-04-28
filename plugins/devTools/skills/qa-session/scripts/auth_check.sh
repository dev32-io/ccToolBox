#!/usr/bin/env bash
# auth_check.sh — report whether a saved Playwright auth profile is fresh.
#
# Prints one of: "fresh", "stale", "missing".
#
# Usage: auth_check.sh <platform> <role>
#   <role> — typically "default", or a per-user identifier matching the
#            charter's `role:` frontmatter.
#
# Freshness is read from qa/<platform>/config.yml as
#   auth.profile_max_age_hours: <int>   # default 24
#
# The seed lives at qa/<platform>/.playwright/profiles/<role>.json
# (gitignored). Missing seed → "missing". Older than max age → "stale".
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: auth_check.sh <platform> <role>" >&2
  exit 2
fi

PLATFORM="$1"
ROLE="$2"

case "$PLATFORM" in
  *[/\\]*|"") echo "auth_check.sh: invalid platform name" >&2; exit 2 ;;
esac
case "$ROLE" in
  *[/\\]*|"") echo "auth_check.sh: invalid role" >&2; exit 2 ;;
esac

command -v git >/dev/null || { echo "auth_check.sh: git is required" >&2; exit 2; }
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "auth_check.sh: not a git repo" >&2; exit 2; }
cd "$REPO_ROOT"

PROFILE_PATH="qa/$PLATFORM/.playwright/profiles/$ROLE.json"
CONFIG_PATH="qa/$PLATFORM/config.yml"

if [[ ! -f "$PROFILE_PATH" ]]; then
  echo "missing"
  exit 0
fi

# Default freshness window: 24 hours.
MAX_AGE_HOURS=24
if [[ -f "$CONFIG_PATH" ]]; then
  CFG_VAL="$(awk '/^[[:space:]]+profile_max_age_hours:/ {print $2; exit}' "$CONFIG_PATH" | tr -d '"')"
  [[ "$CFG_VAL" =~ ^[0-9]+$ ]] && MAX_AGE_HOURS="$CFG_VAL"
fi

# File mtime in epoch seconds (BSD/macOS stat first, fallback to GNU).
FILE_TS="$(stat -f %m "$PROFILE_PATH" 2>/dev/null || stat -c %Y "$PROFILE_PATH" 2>/dev/null)"
NOW_TS="$(date -u +%s)"
AGE_SECS=$((NOW_TS - FILE_TS))
MAX_AGE_SECS=$((MAX_AGE_HOURS * 3600))

if (( AGE_SECS > MAX_AGE_SECS )); then
  echo "stale"
else
  echo "fresh"
fi

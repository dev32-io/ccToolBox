#!/usr/bin/env bash
# detect_context.sh — read-only context probe for the qa-session skill.
# Emits a single JSON object to stdout describing:
#   - current branch, parent branch, merge-base sha
#   - branch diff (written to a temp file; path returned)
#   - target platform paths under qa/<platform>/
#   - whether the platform exists (so the skill can route to scaffold)
#   - a fresh session id and the per-run sessions/<id>/ directory
#
# Usage: detect_context.sh <platform>
# Exit:  0 on success; 2 on missing dependency / not-a-repo / bad args.
# Compatible with bash 3.2 (macOS default).
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: detect_context.sh <platform>" >&2
  exit 2
fi

PLATFORM="$1"
case "$PLATFORM" in
  *[/\\]*|"") echo "detect_context.sh: invalid platform name: $PLATFORM" >&2; exit 2 ;;
esac

command -v jq >/dev/null  || { echo "detect_context.sh: jq is required" >&2; exit 2; }
command -v git >/dev/null || { echo "detect_context.sh: git is required" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "detect_context.sh: not a git repo" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# ---------------------------------------------------------------------------
# Parent-branch detection (adapted from retro/scripts/detect_context.sh).
#
# Strategy, in order:
#   1. `qa-session.baseBranch` git config override.
#   2. Prefer `develop` (local) or `origin/develop` when present — default
#      integration branch for our workflow.
#   3. Scan all local + remote-tracking branches; pick the ref whose
#      merge-base with HEAD has the latest committer timestamp (handles
#      branches forked from a sibling feature branch or non-default base).
#   4. Fallback chain: origin/HEAD → main → master → develop.
# ---------------------------------------------------------------------------
resolve_merge_base() {
  local head_branch override ref mb ts head_sha
  local best_ref="" best_sha="" best_ts=0
  head_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo)"
  head_sha="$(git rev-parse HEAD 2>/dev/null || echo)"

  try_ref() {
    local r="$1" s
    [[ -z "$r" ]] && return 1
    [[ "$r" == "$head_branch" ]] && return 1
    git rev-parse --verify --quiet "$r" >/dev/null || return 1
    s="$(git merge-base HEAD "$r" 2>/dev/null)" || return 1
    [[ -z "$s" ]] && return 1
    [[ "$s" == "$head_sha" ]] && return 1
    echo "$r $s"
    return 0
  }

  override="$(git config --get qa-session.baseBranch 2>/dev/null || true)"
  if [[ -n "$override" ]]; then
    try_ref "$override" && return 0
  fi

  for ref in develop origin/develop; do
    try_ref "$ref" && return 0
  done

  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    [[ "$ref" == "$head_branch" ]] && continue
    [[ "$ref" == "HEAD" ]] && continue
    [[ "$ref" == */HEAD ]] && continue
    [[ "$ref" == */"$head_branch" ]] && continue

    mb="$(git merge-base HEAD "$ref" 2>/dev/null || true)"
    [[ -z "$mb" ]] && continue
    [[ "$mb" == "$head_sha" ]] && continue

    ts="$(git log -1 --format=%ct "$mb" 2>/dev/null || echo 0)"
    if [[ "$ts" -gt "$best_ts" ]]; then
      best_ts="$ts"
      best_ref="$ref"
      best_sha="$mb"
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)

  if [[ -n "$best_ref" ]]; then
    echo "$best_ref $best_sha"
    return 0
  fi

  local origin_head
  origin_head="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's|refs/remotes/||' || true)"
  for ref in "$origin_head" main master develop; do
    try_ref "$ref" && return 0
  done
  return 1
}

MB_OUT="$(resolve_merge_base || true)"
if [[ -z "$MB_OUT" ]]; then
  MB_REF=""
  MB_SHA=""
else
  MB_REF="$(echo "$MB_OUT" | awk '{print $1}')"
  MB_SHA="$(echo "$MB_OUT" | awk '{print $2}')"
fi

# Branch diff to a temp file the Planner subagent can read.
DIFF_DIR="$(mktemp -d -t qa-session-XXXXXX)"
DIFF_PATH="$DIFF_DIR/branch.diff"
if [[ -n "$MB_SHA" ]]; then
  git diff "$MB_SHA"..HEAD > "$DIFF_PATH"
else
  : > "$DIFF_PATH"
fi

# Per-run session id: UTC ISO + 4-char random hex. Use $RANDOM (bash
# builtin, 0–32767, exactly 4 hex chars) to avoid the
# `tr | head` + `set -o pipefail` SIGPIPE trap that makes the fallback
# fire alongside the real read.
TS_COMPACT="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
RAND_HEX="$(printf '%04x' "$RANDOM")"
SESSION_ID="${TS_COMPACT}-${RAND_HEX}"

PLATFORM_DIR="qa/$PLATFORM"
CONFIG_PATH="$PLATFORM_DIR/config.yml"
CHARTERS_DIR="$PLATFORM_DIR/charters"
FINDINGS_BUGS_DIR="$PLATFORM_DIR/findings/bugs"
FINDINGS_ISSUES_PATH="$PLATFORM_DIR/findings/issues.md"
INDEX_PATH="$PLATFORM_DIR/index.json"
ORACLES_PATH="$PLATFORM_DIR/oracles.md"
RECON_PATH="$PLATFORM_DIR/recon.sh"
SESSION_DIR="$PLATFORM_DIR/sessions/$SESSION_ID"

PLATFORM_EXISTS="false"
[[ -f "$CONFIG_PATH" ]] && PLATFORM_EXISTS="true"

# Create the per-run session dir even if the platform doesn't yet exist —
# scaffolding flows still want a place to log. The skill is responsible
# for not running Explorer/Reporter steps when platform_exists is false.
mkdir -p "$SESSION_DIR/logs" "$SESSION_DIR/screenshots"

# Collect existing charter file paths (bash 3.2 compatible — no mapfile).
CHARTERS=()
if [[ -d "$CHARTERS_DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && CHARTERS+=("$f")
  done < <(find "$CHARTERS_DIR" -maxdepth 1 -type f -name '*.md' \
            ! -name '*.tmpl' 2>/dev/null | sort)
fi

# Helper: bash array → JSON array of strings via jq.
json_array() {
  if [[ $# -eq 0 ]]; then
    echo "[]"
    return
  fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}

CHARTERS_JSON="$(json_array "${CHARTERS[@]+"${CHARTERS[@]}"}")"

jq -n \
  --arg repo_root           "$REPO_ROOT" \
  --arg branch              "$BRANCH" \
  --arg merge_base_ref      "$MB_REF" \
  --arg merge_base_sha      "$MB_SHA" \
  --arg diff_path           "$DIFF_PATH" \
  --arg platform            "$PLATFORM" \
  --arg platform_dir        "$PLATFORM_DIR" \
  --arg platform_exists     "$PLATFORM_EXISTS" \
  --arg config_path         "$CONFIG_PATH" \
  --arg charters_dir        "$CHARTERS_DIR" \
  --arg findings_bugs_dir   "$FINDINGS_BUGS_DIR" \
  --arg findings_issues     "$FINDINGS_ISSUES_PATH" \
  --arg index_path          "$INDEX_PATH" \
  --arg oracles_path        "$ORACLES_PATH" \
  --arg recon_path          "$RECON_PATH" \
  --arg session_id          "$SESSION_ID" \
  --arg session_dir         "$SESSION_DIR" \
  --argjson charters        "$CHARTERS_JSON" \
'{
  repo_root:          $repo_root,
  branch:             $branch,
  merge_base_ref:     $merge_base_ref,
  merge_base:         $merge_base_sha,
  diff_path:          $diff_path,
  platform:           $platform,
  platform_dir:       $platform_dir,
  platform_exists:    ($platform_exists == "true"),
  config_path:        $config_path,
  charters_dir:       $charters_dir,
  charters:           $charters,
  findings_bugs_dir:  $findings_bugs_dir,
  findings_issues_path: $findings_issues,
  index_path:         $index_path,
  oracles_path:       $oracles_path,
  recon_path:         $recon_path,
  session_id:         $session_id,
  session_dir:        $session_dir
}'

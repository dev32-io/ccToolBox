#!/usr/bin/env bash
# probe_context.sh — context probe for recall-test-knowledge skill.
# Outputs a single JSON object to stdout: repo_root, branch, merge_base,
# diff_path (branch vs. merge-base), testing_file, rule_files (array).
# Bash 3.2 compatible.
set -euo pipefail

command -v jq >/dev/null || { echo "probe_context.sh: jq is required" >&2; exit 2; }
command -v git >/dev/null || { echo "probe_context.sh: git is required" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "probe_context.sh: not a git repo" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

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

  override="$(git config --get retro.baseBranch 2>/dev/null || true)"
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
      best_ts="$ts"; best_ref="$ref"; best_sha="$mb"
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)

  if [[ -n "$best_ref" ]]; then
    echo "$best_ref $best_sha"
    return 0
  fi

  local origin_head
  origin_head="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||' || true)"
  for ref in "$origin_head" main master develop; do
    try_ref "$ref" && return 0
  done
  return 1
}

MB_OUT="$(resolve_merge_base || true)"
if [[ -z "$MB_OUT" ]]; then
  MB_REF=""; MB_SHA=""
else
  MB_REF="$(echo "$MB_OUT" | awk '{print $1}')"
  MB_SHA="$(echo "$MB_OUT" | awk '{print $2}')"
fi

DIFF_DIR="$(mktemp -d -t recall-tk-XXXXXX)"
DIFF_PATH="$DIFF_DIR/branch.diff"
if [[ -n "$MB_SHA" ]]; then
  git diff --name-only "$MB_SHA"..HEAD > "$DIFF_PATH"
else
  : > "$DIFF_PATH"
fi

TESTING_FILE="agents/docs/testing-knowledge.md"
[[ -f "$TESTING_FILE" ]] || TESTING_FILE=""

RULE_FILES=()
if [[ -d ".claude/rules" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && RULE_FILES+=("$f")
  done < <(find .claude/rules -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
fi

json_array() {
  if [[ $# -eq 0 ]]; then echo "[]"; return; fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}
RULE_FILES_JSON="$(json_array "${RULE_FILES[@]+"${RULE_FILES[@]}"}")"

jq -n \
  --arg repo_root "$REPO_ROOT" \
  --arg branch "$BRANCH" \
  --arg merge_base_ref "$MB_REF" \
  --arg merge_base_sha "$MB_SHA" \
  --arg diff_path "$DIFF_PATH" \
  --arg testing_file "$TESTING_FILE" \
  --argjson rule_files "$RULE_FILES_JSON" \
'{
  repo_root:       $repo_root,
  branch:          $branch,
  merge_base_ref:  $merge_base_ref,
  merge_base:      $merge_base_sha,
  diff_path:       $diff_path,
  testing_file:    $testing_file,
  rule_files:      $rule_files
}'

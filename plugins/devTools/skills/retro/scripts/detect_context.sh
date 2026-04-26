#!/usr/bin/env bash
# detect_context.sh — read-only context probe for the retro skill.
# Outputs a single JSON object to stdout describing:
#   - current branch, merge-base (with fallback chain)
#   - where the branch diff was written (temp file)
#   - target project's rule/details/learnings/testing paths
#   - which of those paths are missing
#   - dirty-tree classification (retro-related vs unrelated)
#
# Usage: detect_context.sh
# Exit: 0 on success; nonzero on git errors or jq missing.
# Compatible with bash 3.2 (macOS default).
set -euo pipefail

command -v jq >/dev/null || { echo "detect_context.sh: jq is required" >&2; exit 2; }
command -v git >/dev/null || { echo "detect_context.sh: git is required" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "detect_context.sh: not a git repo" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Parent-branch detection.
#
# Strategy, in order:
#   1. If `git config retro.baseBranch` is set to a resolvable ref, use it.
#   2. Prefer `develop` (local) or `origin/develop` when it exists — it is
#      the default integration branch in this workflow.
#   3. Scan all local and remote-tracking branch refs, exclude the current
#      branch and symbolic HEAD aliases, compute `git merge-base` against HEAD,
#      and pick the ref whose merge-base commit has the latest committer
#      timestamp. Covers sibling feature branches and projects without develop.
#   4. Fallback chain for edge cases: origin/HEAD → main → master → develop.
resolve_merge_base() {
  local head_branch override ref mb ts head_sha sha
  local best_ref="" best_sha="" best_ts=0
  head_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo)"
  head_sha="$(git rev-parse HEAD 2>/dev/null || echo)"

  # Try a single ref; echo "ref sha" and return 0 on success.
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

  # (1) Manual override via git config.
  override="$(git config --get retro.baseBranch 2>/dev/null || true)"
  if [[ -n "$override" ]]; then
    try_ref "$override" && return 0
  fi

  # (2) Prefer `develop` as the default parent when available.
  for ref in develop origin/develop; do
    try_ref "$ref" && return 0
  done

  # (3) Scan all branches for newest merge-base (sibling branches, etc.).
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

  # (4) Fallback chain for edge cases.
  local origin_head
  origin_head="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||' || true)"
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

# Write diff to temp file.
DIFF_DIR="$(mktemp -d -t retro-XXXXXX)"
DIFF_PATH="$DIFF_DIR/branch.diff"
if [[ -n "$MB_SHA" ]]; then
  git diff "$MB_SHA"..HEAD > "$DIFF_PATH"
else
  : > "$DIFF_PATH"
fi

# Infer Claude Code session transcript path.
# ~/.claude/projects/<slug>/<session>.jsonl, slug is cwd with / replaced by -.
SLUG="$(echo "$REPO_ROOT" | sed 's|/|-|g')"
TRANSCRIPT_DIR="$HOME/.claude/projects/$SLUG"
TRANSCRIPT_PATH=""
if [[ -d "$TRANSCRIPT_DIR" ]]; then
  # Most recently modified .jsonl wins (the current session).
  TRANSCRIPT_PATH="$(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1 || true)"
fi

RULES_DIR=".claude/rules"
DETAILS_DIR="agents/docs"
LEARNINGS_FILE="agents/docs/learnings.md"
TESTING_FILE="agents/docs/testing-knowledge.md"

# Collect existing files (bash 3.2 compatible — no mapfile).
RULES_FILES=()
if [[ -d "$RULES_DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && RULES_FILES+=("$f")
  done < <(find "$RULES_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
fi

DETAILS_FILES=()
if [[ -d "$DETAILS_DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && DETAILS_FILES+=("$f")
  done < <(find "$DETAILS_DIR" -maxdepth 1 -type f -name '*-details.md' 2>/dev/null | sort)
fi

# Compute missing list.
MISSING=()
[[ -d "$RULES_DIR" ]]     || MISSING+=("$RULES_DIR")
[[ -d "$DETAILS_DIR" ]]   || MISSING+=("$DETAILS_DIR")
[[ -f "$LEARNINGS_FILE" ]]|| MISSING+=("$LEARNINGS_FILE")
[[ -f "$TESTING_FILE" ]]  || MISSING+=("$TESTING_FILE")

# Dirty-tree classification.
#   Retro-related paths = anything under .claude/rules/ or agents/docs/.
is_retro_path() {
  case "$1" in
    .claude/rules/*|agents/docs/*) return 0 ;;
    *) return 1 ;;
  esac
}

UNREL_UNSTAGED=()
UNREL_STAGED=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  status="${line:0:2}"
  path="${line:3}"
  if is_retro_path "$path"; then continue; fi
  # Index position 0 is staged; worktree position 1 is unstaged.
  # Untracked files show as "??" in both positions.
  idx="${status:0:1}"
  wt="${status:1:1}"
  if [[ "$idx" != " " && "$idx" != "?" ]]; then
    UNREL_STAGED+=("$path")
  fi
  if [[ "$wt" != " " ]]; then
    UNREL_UNSTAGED+=("$path")
  fi
done < <(git status --porcelain=v1)

# Helper: convert a bash array to a JSON array of strings via jq.
# Usage: json_array "${arr[@]}"
json_array() {
  if [[ $# -eq 0 ]]; then
    echo "[]"
    return
  fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}

RULES_FILES_JSON="$(json_array "${RULES_FILES[@]+"${RULES_FILES[@]}"}")"
DETAILS_FILES_JSON="$(json_array "${DETAILS_FILES[@]+"${DETAILS_FILES[@]}"}")"
MISSING_JSON="$(json_array "${MISSING[@]+"${MISSING[@]}"}")"
UNREL_UNSTAGED_JSON="$(json_array "${UNREL_UNSTAGED[@]+"${UNREL_UNSTAGED[@]}"}")"
UNREL_STAGED_JSON="$(json_array "${UNREL_STAGED[@]+"${UNREL_STAGED[@]}"}")"

jq -n \
  --arg repo_root      "$REPO_ROOT" \
  --arg branch         "$BRANCH" \
  --arg merge_base_ref "$MB_REF" \
  --arg merge_base_sha "$MB_SHA" \
  --arg diff_path      "$DIFF_PATH" \
  --arg transcript     "$TRANSCRIPT_PATH" \
  --arg rules_dir      "$RULES_DIR" \
  --arg details_dir    "$DETAILS_DIR" \
  --arg learnings      "$LEARNINGS_FILE" \
  --arg testing        "$TESTING_FILE" \
  --argjson rules_files   "$RULES_FILES_JSON" \
  --argjson details_files "$DETAILS_FILES_JSON" \
  --argjson missing       "$MISSING_JSON" \
  --argjson unrel_unstaged "$UNREL_UNSTAGED_JSON" \
  --argjson unrel_staged   "$UNREL_STAGED_JSON" \
'{
  repo_root:       $repo_root,
  branch:          $branch,
  merge_base_ref:  $merge_base_ref,
  merge_base:      $merge_base_sha,
  diff_path:       $diff_path,
  transcript_path: $transcript,
  rules_dir:       $rules_dir,
  rules_files:     $rules_files,
  details_dir:     $details_dir,
  details_files:   $details_files,
  learnings_file:  $learnings,
  testing_file:    $testing,
  missing:         $missing,
  dirty_tree: {
    unrelated_unstaged: $unrel_unstaged,
    unrelated_staged:   $unrel_staged
  }
}'

#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../skills/retro/scripts/detect_context.sh"
source "$here/lib/assert.sh"

ORIG_PWD="$(pwd)"
TMPDIRS=()
cleanup() {
  cd "$ORIG_PWD" 2>/dev/null || true
  local d
  for d in "${TMPDIRS[@]+"${TMPDIRS[@]}"}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# Build a fresh temp git repo in a known state and cd into it.
setup_repo() {
  local dir
  dir="$(mktemp -d)"
  TMPDIRS+=("$dir")
  cd "$dir"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  echo "base" > base.txt
  git add base.txt
  git commit -qm "base"
  git checkout -q -b feat/xyz
  echo "feature" > feature.txt
  git add feature.txt
  git commit -qm "feature work"
}

echo "== detect_context.sh =="

# Test 1: clean repo, no rules/docs → missing paths reported, clean tree
setup_repo
out="$(bash "$SCRIPT")"
assert_contains "$out" '"branch": "feat/xyz"' "T1 branch reported"
assert_contains "$out" '"merge_base":' "T1 merge_base present"
assert_contains "$out" '"rules_dir": ".claude/rules"' "T1 rules_dir path"
assert_contains "$out" '"details_dir": "agent/docs"' "T1 details_dir path"
assert_contains "$out" '"learnings_file": "agent/docs/learnings.md"' "T1 learnings path"
assert_contains "$out" '"testing_file": "agent/docs/testing-knowledge.md"' "T1 testing path"
assert_contains "$out" '.claude/rules' "T1 missing contains rules dir"
assert_contains "$out" 'agent/docs/learnings.md' "T1 missing contains learnings"
assert_contains "$out" '"unrelated_unstaged": []' "T1 clean tree"

# Test 2: with scaffolded rule/details/learnings/testing paths → empty missing
setup_repo
mkdir -p .claude/rules agent/docs
echo "# rules" > .claude/rules/auth.md
echo "# details" > agent/docs/auth-details.md
echo "# Learnings" > agent/docs/learnings.md
echo "# Testing Knowledge" > agent/docs/testing-knowledge.md
git add -A; git commit -qm "scaffold"
out="$(bash "$SCRIPT")"
assert_contains "$out" '"missing": []' "T2 nothing missing"
assert_contains "$out" '.claude/rules/auth.md' "T2 rule file listed"
assert_contains "$out" 'agent/docs/auth-details.md' "T2 details file listed"

# Test 3: dirty tree with unrelated file → reported in unrelated_unstaged
setup_repo
echo "unrelated change" > src_unrelated.py
out="$(bash "$SCRIPT")"
assert_contains "$out" 'src_unrelated.py' "T3 unrelated file listed"
assert_contains "$out" '"unrelated_unstaged"' "T3 unrelated bucket present"

# Test 4: dirty tree with only a rule file unstaged → NOT flagged unrelated
setup_repo
mkdir -p .claude/rules
echo "# rules" > .claude/rules/auth.md
git add .claude/rules/auth.md; git commit -qm "add rules"
echo "# rules updated" > .claude/rules/auth.md   # unstaged edit, retro-related
out="$(bash "$SCRIPT")"
assert_not_contains "$out" '"unrelated_unstaged": [".claude/rules/auth.md"]' "T4 retro file not flagged unrelated"

# Test 5: diff file is written and non-empty
setup_repo
out="$(bash "$SCRIPT")"
diff_path="$(echo "$out" | sed -n 's/.*"diff_path": "\([^"]*\)".*/\1/p')"
TESTS=$((TESTS+1))
if [[ -s "$diff_path" ]]; then _pass "T5 diff file non-empty"; else _fail "T5 diff file empty or missing"; fi

# Test 6: fallback merge base — when no origin/HEAD, falls back to local main
setup_repo
out="$(bash "$SCRIPT")"
assert_contains "$out" '"merge_base":' "T6 merge_base resolved via fallback"

summary

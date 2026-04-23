#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../skills/recall-test-knowledge/scripts/probe_context.sh"
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

echo "== probe_context_trimmed =="

# Test 1: clean repo reports branch, merge_base, empty testing_file and rule_files.
setup_repo
out="$(bash "$SCRIPT")"
assert_contains "$out" '"branch": "feat/xyz"' "T1 branch reported"
assert_contains "$out" '"merge_base":' "T1 merge_base present"
assert_contains "$out" '"testing_file": ""' "T1 no testing file"
assert_contains "$out" '"rule_files": []' "T1 no rule files"

# Test 2: trimmed keys — must NOT contain retro-only fields.
assert_not_contains "$out" 'dirty_tree' "T2 no dirty_tree key"
assert_not_contains "$out" 'missing' "T2 no missing key"
assert_not_contains "$out" 'learnings_file' "T2 no learnings_file key"
assert_not_contains "$out" 'details_files' "T2 no details_files key"

# Test 3: with testing-knowledge.md present, path is reported.
setup_repo
mkdir -p agent/docs
echo "# Testing Knowledge" > agent/docs/testing-knowledge.md
git add -A; git commit -qm "testing"
out="$(bash "$SCRIPT")"
assert_contains "$out" '"testing_file": "agent/docs/testing-knowledge.md"' "T3 testing file reported"

# Test 4: with rule files present, they are listed.
setup_repo
mkdir -p .claude/rules
echo "# auth" > .claude/rules/auth.md
echo "# testing-web" > .claude/rules/testing-web.md
git add -A; git commit -qm "rules"
out="$(bash "$SCRIPT")"
assert_contains "$out" '.claude/rules/auth.md' "T4 rule auth listed"
assert_contains "$out" '.claude/rules/testing-web.md' "T4 rule testing-web listed"

# Test 5: diff path lists changed filenames (not unified diff).
setup_repo
out="$(bash "$SCRIPT")"
diff_path="$(echo "$out" | sed -n 's/.*"diff_path": "\([^"]*\)".*/\1/p')"
TESTS=$((TESTS+1))
if grep -q '^feature.txt$' "$diff_path" 2>/dev/null; then
  _pass "T5 diff lists feature.txt"
else
  _fail "T5 diff missing feature.txt (path=$diff_path)"
fi

summary

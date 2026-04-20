#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../skills/retro/scripts/stage_and_commit.sh"
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
}

echo "== stage_and_commit.sh =="

# Test 1: happy path — stage two files, commit succeeds, only those files staged
setup_repo
echo "a" > a.md
echo "b" > b.md
msg="$(mktemp)"
printf 'chore(retro): test\n' > "$msg"
set +e
bash "$SCRIPT" "$msg" a.md b.md >/dev/null 2>&1
rc=$?
set -e
assert_exit_code 0 "$rc" "T1 happy path exit 0"
last_subject="$(git log -1 --pretty=%s)"
assert_eq "chore(retro): test" "$last_subject" "T1 commit subject"
changed="$(git show --stat --pretty=format: HEAD | grep -oE '(a|b)\.md' | sort -u | tr '\n' ' ')"
assert_eq "a.md b.md " "$changed" "T1 both files in commit"

# Test 2: no paths → exit 2
setup_repo
msg="$(mktemp)"; echo "m" > "$msg"
set +e
bash "$SCRIPT" "$msg" >/dev/null 2>&1
rc=$?
set -e
assert_exit_code 2 "$rc" "T2 no paths exit 2"

# Test 3: staging drift — pre-staged extra file triggers exit 3
setup_repo
echo "a" > a.md
echo "extra" > extra.md
git add extra.md   # pre-staged, not in call args — must trip drift check
msg="$(mktemp)"; printf 'chore(retro): test\n' > "$msg"
set +e
bash "$SCRIPT" "$msg" a.md >/dev/null 2>&1
rc=$?
set -e
assert_exit_code 3 "$rc" "T3 drift detected"

# Test 4: hook rejection — no --no-verify, exit non-zero, files remain staged
setup_repo
mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
exit 1
HOOK
chmod +x .git/hooks/pre-commit
echo "a" > a.md
msg="$(mktemp)"; printf 'chore(retro): test\n' > "$msg"
set +e
bash "$SCRIPT" "$msg" a.md >/dev/null 2>&1
rc=$?
set -e
TESTS=$((TESTS+1))
if [[ "$rc" != 0 ]]; then _pass "T4 hook failure non-zero"; else _fail "T4 hook failure was 0"; fi
staged="$(git diff --cached --name-only)"
assert_eq "a.md" "$staged" "T4 file still staged after hook rejection"

summary

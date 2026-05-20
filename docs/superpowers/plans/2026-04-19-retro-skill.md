# Retro Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `retro` skill inside a new `devTools` plugin (v1.0.0). Running the skill on a feature branch analyzes the branch diff + current session transcript, proposes rule/details/learnings/test-knowledge changes through a per-candidate approval table, writes approved changes, and creates a single retro commit in the target project.

**Architecture:** New `plugins/devTools/` plugin with one skill. Skill runs in the *user's target project* (not ccToolBox). Two bash helper scripts do deterministic work (merge-base detection, path discovery, dirty-tree classification, explicit-path staging + commit). One `Explore` subagent does the token-heavy analysis and returns a strict JSON candidate list. Main agent runs the UX (preamble gate, candidate table, approval DSL, confirm echo, apply, final summary, commit invocation).

**Tech Stack:** Bash 3.2+ (macOS-compatible, `jq` for JSON). Markdown SKILL.md prompt. JSON plugin manifests. Bash-based black-box tests for the two scripts (no pytest — scripts are bash).

**Spec:** `docs/superpowers/specs/2026-04-19-retro-skill-design.md`

**Plan/spec commits:** Per user preference, do NOT commit this plan document or the spec in ccToolBox. All other commits below proceed normally.

---

## File Structure

### Created
- `plugins/devTools/.claude-plugin/plugin.json` — plugin manifest, v1.0.0
- `plugins/devTools/README.md` — plugin docs (what it contains, how to invoke)
- `plugins/devTools/CHANGELOG.md` — starting at v1.0.0
- `plugins/devTools/skills/retro/SKILL.md` — the skill prompt
- `plugins/devTools/skills/retro/scripts/detect_context.sh` — context probe, outputs JSON
- `plugins/devTools/skills/retro/scripts/stage_and_commit.sh` — explicit-path staging + commit
- `plugins/devTools/tests/test_detect_context.sh` — bash tests for detect_context.sh
- `plugins/devTools/tests/test_stage_and_commit.sh` — bash tests for stage_and_commit.sh
- `plugins/devTools/tests/lib/assert.sh` — minimal assertion helpers shared by both test files

### Modified
- `.claude-plugin/marketplace.json` — append devTools entry at v1.0.0 (final task)

### Not modified
- No top-level marketplace version field exists today; the plan does NOT introduce one.
- `plugins/daily-briefing/*`, `plugins/offline-research/*` — unchanged.

### Script responsibilities

Each file has one job:
- `detect_context.sh` — read-only probe. Emits one JSON blob to stdout. No writes. No user interaction.
- `stage_and_commit.sh` — write-only git operation. Takes explicit paths + message file. Refuses on drift. Never passes `--no-verify`.
- `SKILL.md` — orchestrates: preamble, calls `detect_context.sh`, dispatches subagent, renders table, collects approval, writes files, calls `stage_and_commit.sh`.

---

## Task 1: Plugin scaffold (manifest + README + CHANGELOG)

**Files:**
- Create: `plugins/devTools/.claude-plugin/plugin.json`
- Create: `plugins/devTools/README.md`
- Create: `plugins/devTools/CHANGELOG.md`

- [ ] **Step 1: Create the directory and plugin manifest**

Create `plugins/devTools/.claude-plugin/plugin.json`:

```json
{
  "name": "devTools",
  "description": "Developer productivity skills for software engineering workflows",
  "version": "1.0.0",
  "author": { "name": "dev32-io" }
}
```

- [ ] **Step 2: Create README.md**

Create `plugins/devTools/README.md`:

```markdown
# devTools

Developer productivity skills for software engineering workflows.

## Skills

### `retro` — run a retrospective on a completed feature branch

Invoke with `/retro` (or phrases like "run a retro on this branch") when a
feature/sprint/bug-bash is complete and before merging to `develop` / `main`.

The skill analyzes the branch diff + the current Claude Code session transcript,
then proposes rule/details/learnings/test-knowledge updates through a
per-candidate approval table. Only approved changes are written, and all
changes are committed in a single `chore(retro): …` commit in the target project.

**Output artifacts in the target project:**
- `.claude/rules/<topic>.md` — topical instruction-only rule files (≤100 lines)
- `agent/docs/<topic>-details.md` — paired details/examples/gotchas
- `agent/docs/learnings.md` — flat dated observations awaiting promotion
- `agent/docs/testing-knowledge.md` — manual/integration test procedures

**First-run bootstrap:** if the target project lacks `.claude/rules/` or
`agent/docs/`, the skill asks once whether to scaffold them before proceeding.

**Requires:** `git`, `jq`, `bash` 3.2+.
```

- [ ] **Step 3: Create CHANGELOG.md**

Create `plugins/devTools/CHANGELOG.md`:

```markdown
# Changelog

## 1.0.0 — 2026-04-19

Initial release.

- Added `retro` skill: branch-scoped retrospective that distills session +
  diff into rule/details/learnings/test-knowledge artifacts via subagent
  analysis and per-candidate user approval.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/devTools/.claude-plugin/plugin.json plugins/devTools/README.md plugins/devTools/CHANGELOG.md
git commit -m "devTools: add plugin scaffold at 1.0.0"
```

---

## Task 2: Shared test assertion helpers

**Files:**
- Create: `plugins/devTools/tests/lib/assert.sh`

Minimal, zero-dependency assertion helpers used by both test files. No framework.

- [ ] **Step 1: Create the helper**

Create `plugins/devTools/tests/lib/assert.sh`:

```bash
#!/usr/bin/env bash
# Minimal bash test assertions. Use with `set -euo pipefail`.

_pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=$((FAILED+1)); }

: "${FAILED:=0}"
: "${TESTS:=0}"

assert_eq() {
  TESTS=$((TESTS+1))
  local expected="$1" actual="$2" msg="${3:-assert_eq}"
  if [[ "$expected" == "$actual" ]]; then
    _pass "$msg"
  else
    _fail "$msg"
    printf '    expected: %q\n' "$expected"
    printf '    actual:   %q\n' "$actual"
  fi
}

assert_contains() {
  TESTS=$((TESTS+1))
  local haystack="$1" needle="$2" msg="${3:-assert_contains}"
  if [[ "$haystack" == *"$needle"* ]]; then
    _pass "$msg"
  else
    _fail "$msg"
    printf '    needle:   %q\n' "$needle"
    printf '    haystack: %q\n' "$haystack"
  fi
}

assert_not_contains() {
  TESTS=$((TESTS+1))
  local haystack="$1" needle="$2" msg="${3:-assert_not_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    _pass "$msg"
  else
    _fail "$msg"
    printf '    needle:   %q\n' "$needle"
    printf '    haystack: %q\n' "$haystack"
  fi
}

assert_exit_code() {
  TESTS=$((TESTS+1))
  local expected="$1" actual="$2" msg="${3:-assert_exit_code}"
  if [[ "$expected" == "$actual" ]]; then
    _pass "$msg"
  else
    _fail "$msg (expected $expected, got $actual)"
  fi
}

summary() {
  printf '\n%d tests, %d failed\n' "$TESTS" "$FAILED"
  [[ "$FAILED" == 0 ]]
}
```

- [ ] **Step 2: Make executable and smoke-test**

```bash
chmod +x plugins/devTools/tests/lib/assert.sh
bash -c 'source plugins/devTools/tests/lib/assert.sh; assert_eq "a" "a" "sanity"; summary'
```

Expected output:
```
  PASS sanity

1 tests, 0 failed
```

- [ ] **Step 3: Commit**

```bash
git add plugins/devTools/tests/lib/assert.sh
git commit -m "devTools: add shared bash test assertions"
```

---

## Task 3: Tests for `detect_context.sh` (TDD — write these first, they will fail)

**Files:**
- Create: `plugins/devTools/tests/test_detect_context.sh`

These tests exercise the script against temp git repos with known state. The script does not exist yet; every test will fail. Then Task 4 implements the script.

- [ ] **Step 1: Create the test file**

Create `plugins/devTools/tests/test_detect_context.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../skills/retro/scripts/detect_context.sh"
source "$here/lib/assert.sh"

# Build a temp git repo in a known state.
# Signature: setup_repo <tmpdir>
setup_repo() {
  local dir="$1"
  mkdir -p "$dir"
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

# --- Test 1: clean repo, no rules/docs → missing paths reported, clean tree ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  out="$(bash "$SCRIPT")"

  assert_contains "$out" '"branch": "feat/xyz"' "branch reported"
  assert_contains "$out" '"merge_base":' "merge_base present"
  assert_contains "$out" '"rules_dir": ".claude/rules"' "rules_dir path"
  assert_contains "$out" '"details_dir": "agent/docs"' "details_dir path"
  assert_contains "$out" '"learnings_file": "agent/docs/learnings.md"' "learnings path"
  assert_contains "$out" '"testing_file": "agent/docs/testing-knowledge.md"' "testing path"
  assert_contains "$out" '.claude/rules' "missing contains rules dir"
  assert_contains "$out" 'agent/docs/learnings.md' "missing contains learnings"
  assert_contains "$out" '"unrelated_unstaged": []' "clean tree"
)

# --- Test 2: with scaffolded rule/details/learnings/testing paths → empty missing ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  mkdir -p .claude/rules agent/docs
  echo "# rules" > .claude/rules/auth.md
  echo "# details" > agent/docs/auth-details.md
  echo "# Learnings" > agent/docs/learnings.md
  echo "# Testing Knowledge" > agent/docs/testing-knowledge.md
  git add -A; git commit -qm "scaffold"

  out="$(bash "$SCRIPT")"
  assert_contains "$out" '"missing": []' "nothing missing"
  assert_contains "$out" '.claude/rules/auth.md' "rule file listed"
  assert_contains "$out" 'agent/docs/auth-details.md' "details file listed"
)

# --- Test 3: dirty tree with unrelated file → reported in unrelated_unstaged ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  echo "unrelated change" > src_unrelated.py
  out="$(bash "$SCRIPT")"
  assert_contains "$out" 'src_unrelated.py' "unrelated file listed"
  assert_contains "$out" '"unrelated_unstaged"' "unrelated bucket present"
)

# --- Test 4: dirty tree with only a rule file unstaged → NOT flagged unrelated ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  mkdir -p .claude/rules
  echo "# rules" > .claude/rules/auth.md
  git add .claude/rules/auth.md; git commit -qm "add rules"
  echo "# rules updated" > .claude/rules/auth.md   # unstaged edit, retro-related
  out="$(bash "$SCRIPT")"
  assert_not_contains "$out" '"unrelated_unstaged": [".claude/rules/auth.md"]' "retro file not flagged unrelated"
)

# --- Test 5: diff file is written and non-empty ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  out="$(bash "$SCRIPT")"
  diff_path="$(echo "$out" | sed -n 's/.*"diff_path": "\([^"]*\)".*/\1/p')"
  [[ -s "$diff_path" ]] && _pass "diff file non-empty" || _fail "diff file empty or missing"
  TESTS=$((TESTS+1))
)

# --- Test 6: fallback merge base — when no origin/HEAD, falls back to local main ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  # no remote configured — should still find merge-base via local main
  out="$(bash "$SCRIPT")"
  assert_contains "$out" '"merge_base":' "merge_base resolved via fallback"
)

summary
```

- [ ] **Step 2: Make executable and run — expect failures**

```bash
chmod +x plugins/devTools/tests/test_detect_context.sh
bash plugins/devTools/tests/test_detect_context.sh || true
```

Expected: script does not exist yet. Output will show a `bash: ... No such file or directory` error on first test. That's the red in red-green-refactor. Do NOT commit yet — Task 4 implements and then we commit together.

---

## Task 4: Implement `detect_context.sh`

**Files:**
- Create: `plugins/devTools/skills/retro/scripts/detect_context.sh`

The script is read-only. It emits a single JSON object to stdout. On any internal failure, it exits non-zero with a diagnostic on stderr.

- [ ] **Step 1: Create the script**

Create `plugins/devTools/skills/retro/scripts/detect_context.sh`:

```bash
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
set -euo pipefail

command -v jq >/dev/null || { echo "detect_context.sh: jq is required" >&2; exit 2; }
command -v git >/dev/null || { echo "detect_context.sh: git is required" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "detect_context.sh: not a git repo" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Merge-base resolution: try origin/HEAD, then main, master, develop.
resolve_merge_base() {
  local candidates=()
  local origin_head
  origin_head="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||' || true)"
  [[ -n "$origin_head" ]] && candidates+=("$origin_head")
  candidates+=(main master develop)

  for ref in "${candidates[@]}"; do
    if git rev-parse --verify --quiet "$ref" >/dev/null; then
      if base="$(git merge-base HEAD "$ref" 2>/dev/null)"; then
        echo "$ref $base"
        return 0
      fi
    fi
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
TS="$(date +%Y%m%d-%H%M%S)"
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
DETAILS_DIR="agent/docs"
LEARNINGS_FILE="agent/docs/learnings.md"
TESTING_FILE="agent/docs/testing-knowledge.md"

# Collect existing files (globs).
mapfile -t RULES_FILES < <(find "$RULES_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
mapfile -t DETAILS_FILES < <(find "$DETAILS_DIR" -maxdepth 1 -type f -name '*-details.md' 2>/dev/null | sort)

# Compute missing list.
MISSING=()
[[ -d "$RULES_DIR" ]]     || MISSING+=("$RULES_DIR")
[[ -d "$DETAILS_DIR" ]]   || MISSING+=("$DETAILS_DIR")
[[ -f "$LEARNINGS_FILE" ]]|| MISSING+=("$LEARNINGS_FILE")
[[ -f "$TESTING_FILE" ]]  || MISSING+=("$TESTING_FILE")

# Dirty-tree classification.
#   Retro-related paths = anything under .claude/rules/ or agent/docs/, plus the two named files.
is_retro_path() {
  case "$1" in
    .claude/rules/*|agent/docs/*) return 0 ;;
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
  # index position 0 is staged; worktree position 1 is unstaged
  [[ "${status:0:1}" != " " && "${status:0:1}" != "?" ]] && UNREL_STAGED+=("$path")
  [[ "${status:1:1}" != " " ]] && UNREL_UNSTAGED+=("$path")
done < <(git status --porcelain=v1)

# Emit JSON via jq.
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
  --argjson rules_files   "$(printf '%s\n' "${RULES_FILES[@]}"   | jq -R . | jq -s .)" \
  --argjson details_files "$(printf '%s\n' "${DETAILS_FILES[@]}" | jq -R . | jq -s .)" \
  --argjson missing       "$(printf '%s\n' "${MISSING[@]}"       | jq -R . | jq -s 'map(select(length>0))')" \
  --argjson unrel_unstaged "$(printf '%s\n' "${UNREL_UNSTAGED[@]}" | jq -R . | jq -s 'map(select(length>0))')" \
  --argjson unrel_staged   "$(printf '%s\n' "${UNREL_STAGED[@]}"   | jq -R . | jq -s 'map(select(length>0))')" \
'{
  repo_root:       $repo_root,
  branch:          $branch,
  merge_base_ref:  $merge_base_ref,
  merge_base:      $merge_base_sha,
  diff_path:       $diff_path,
  transcript_path: $transcript,
  rules_dir:       $rules_dir,
  rules_files:     ($rules_files | map(select(length>0))),
  details_dir:     $details_dir,
  details_files:   ($details_files | map(select(length>0))),
  learnings_file:  $learnings,
  testing_file:    $testing,
  missing:         $missing,
  dirty_tree: {
    unrelated_unstaged: $unrel_unstaged,
    unrelated_staged:   $unrel_staged
  }
}'
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/devTools/skills/retro/scripts/detect_context.sh
```

- [ ] **Step 3: Run the tests — expect all green**

```bash
bash plugins/devTools/tests/test_detect_context.sh
```

Expected: `N tests, 0 failed` at the end.

If any test fails, fix the script (not the tests — the tests encode the contract).

- [ ] **Step 4: Commit**

```bash
git add plugins/devTools/skills/retro/scripts/detect_context.sh plugins/devTools/tests/test_detect_context.sh
git commit -m "devTools/retro: add detect_context.sh + tests"
```

---

## Task 5: Tests for `stage_and_commit.sh` (TDD — write first)

**Files:**
- Create: `plugins/devTools/tests/test_stage_and_commit.sh`

- [ ] **Step 1: Create the test file**

Create `plugins/devTools/tests/test_stage_and_commit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../skills/retro/scripts/stage_and_commit.sh"
source "$here/lib/assert.sh"

setup_repo() {
  local dir="$1"
  mkdir -p "$dir"
  cd "$dir"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  echo "base" > base.txt
  git add base.txt
  git commit -qm "base"
}

echo "== stage_and_commit.sh =="

# --- Test 1: happy path — stage two files, commit succeeds, only those files staged ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  echo "a" > a.md
  echo "b" > b.md
  msg="$(mktemp)"
  printf 'chore(retro): test\n' > "$msg"

  set +e
  bash "$SCRIPT" "$msg" a.md b.md
  rc=$?
  set -e
  assert_exit_code 0 "$rc" "happy path exit 0"

  last_subject="$(git log -1 --pretty=%s)"
  assert_eq "chore(retro): test" "$last_subject" "commit subject"

  changed="$(git show --stat --pretty=format: HEAD | grep -oE '(a|b)\.md' | sort -u | tr '\n' ' ')"
  assert_eq "a.md b.md " "$changed" "both files in commit"
)

# --- Test 2: no paths → exit 2 ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  msg="$(mktemp)"; echo "m" > "$msg"

  set +e
  bash "$SCRIPT" "$msg"
  rc=$?
  set -e
  assert_exit_code 2 "$rc" "no paths exit 2"
)

# --- Test 3: staging drift — pre-staged extra file triggers exit 3 ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  echo "a" > a.md
  echo "extra" > extra.md
  git add extra.md   # pre-staged, not in the call args — must trip drift check
  msg="$(mktemp)"; printf 'chore(retro): test\n' > "$msg"

  set +e
  bash "$SCRIPT" "$msg" a.md
  rc=$?
  set -e
  assert_exit_code 3 "$rc" "drift detected"
)

# --- Test 4: hook rejection — no --no-verify, exit non-zero, files remain staged ---
(
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  setup_repo "$tmp"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
exit 1
HOOK
  chmod +x .git/hooks/pre-commit

  echo "a" > a.md
  msg="$(mktemp)"; printf 'chore(retro): test\n' > "$msg"

  set +e
  bash "$SCRIPT" "$msg" a.md
  rc=$?
  set -e

  # Hook failure → commit returns non-zero. Exact code may vary; just require != 0.
  TESTS=$((TESTS+1))
  [[ "$rc" != 0 ]] && _pass "hook failure non-zero" || _fail "hook failure was 0"

  staged="$(git diff --cached --name-only)"
  assert_eq "a.md" "$staged" "file still staged after hook rejection"
)

summary
```

- [ ] **Step 2: Make executable and run — expect failures**

```bash
chmod +x plugins/devTools/tests/test_stage_and_commit.sh
bash plugins/devTools/tests/test_stage_and_commit.sh || true
```

Expected: script doesn't exist yet. Move to Task 6.

---

## Task 6: Implement `stage_and_commit.sh`

**Files:**
- Create: `plugins/devTools/skills/retro/scripts/stage_and_commit.sh`

- [ ] **Step 1: Create the script**

Create `plugins/devTools/skills/retro/scripts/stage_and_commit.sh`:

```bash
#!/usr/bin/env bash
# stage_and_commit.sh — stage exactly the given paths and commit with the
# provided message file. Refuses on staging drift. Never uses --no-verify.
#
# Usage: stage_and_commit.sh <message-file> <path> [<path>...]
# Exit codes:
#   0  success
#   2  no paths provided
#   3  staged set drifted from expected set (unrelated pre-staged content)
#   *  passthrough from `git commit` (e.g. hook rejection)
set -euo pipefail

msg_file="${1:-}"
[[ -n "$msg_file" && -f "$msg_file" ]] || { echo "stage_and_commit.sh: message file required" >&2; exit 2; }
shift

paths=("$@")
[[ ${#paths[@]} -gt 0 ]] || { echo "stage_and_commit.sh: no paths to stage" >&2; exit 2; }

# Sanity: all paths must exist on disk.
for p in "${paths[@]}"; do
  [[ -e "$p" ]] || { echo "stage_and_commit.sh: path does not exist: $p" >&2; exit 2; }
done

git add -- "${paths[@]}"

# Verify the staged set matches exactly what we were asked to stage.
staged="$(git diff --cached --name-only | sort -u)"
expected="$(printf '%s\n' "${paths[@]}" | sort -u)"
if [[ "$staged" != "$expected" ]]; then
  echo "stage_and_commit.sh: staged set drifted from expected." >&2
  echo "--- staged ---"   >&2; echo "$staged"   >&2
  echo "--- expected ---" >&2; echo "$expected" >&2
  exit 3
fi

git commit -F "$msg_file"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/devTools/skills/retro/scripts/stage_and_commit.sh
```

- [ ] **Step 3: Run tests — expect all green**

```bash
bash plugins/devTools/tests/test_stage_and_commit.sh
```

Expected: `N tests, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add plugins/devTools/skills/retro/scripts/stage_and_commit.sh plugins/devTools/tests/test_stage_and_commit.sh
git commit -m "devTools/retro: add stage_and_commit.sh + tests"
```

---

## Task 7: Write `SKILL.md` — frontmatter, preamble, context probe

**Files:**
- Create: `plugins/devTools/skills/retro/SKILL.md`

This is the largest prose task — the skill's behavior is almost entirely defined by this file. We write it in two commits (Task 7 = first half, Task 8 = second half) so review is manageable.

- [ ] **Step 1: Create SKILL.md with frontmatter and the preamble section**

Create `plugins/devTools/skills/retro/SKILL.md`:

````markdown
---
name: retro
description: >
  Run a retrospective on a completed feature/sprint/bug-bash branch before
  merging. Analyzes the branch diff plus this session's transcript, proposes
  rule/details/learnings/testing-knowledge updates through a per-candidate
  approval table, writes approved changes, and commits the retro artifacts
  in a single commit. Use when the user says "run a retro", "retrospective
  on this branch", "distill what we learned", or invokes /retro. Do NOT
  trigger on casual "recap" or "looking back" mentions.
tools: Agent, AskUserQuestion, Bash, Read, Write, Edit, Grep, Glob
---

# Retro — Branch Retrospective

Run at the end of a feature branch, before merging to `develop` or `main`.
The skill is **write-and-commit**; it only runs on explicit user intent.

This skill operates on the **user's target project**, not on ccToolBox. All
script paths below are relative to this skill directory; all output paths
are relative to the target project root.

## Flow at a glance

1. **Preamble + gate** — describe what will happen, get `go` / `go --auto`.
2. **Context probe** — run `scripts/detect_context.sh`, parse JSON.
3. **Bootstrap** — if missing paths, ask one y/n, create skeletons.
4. **Subagent analysis** — dispatch one `Explore` subagent, receive candidate JSON.
5. **Candidate table** — render, collect approval DSL, echo final list, wait for `confirm`.
6. **Apply** — write files in order: remove-stale → revise → new-file → new-section → append.
7. **Final summary** — show applied / skipped / failed, show proposed commit message.
8. **Commit** — on `commit`, run `scripts/stage_and_commit.sh`; on `hold`, exit.

## Step 1 — Preamble and gate

Run the context probe first (deterministic; cheap) so the preamble can cite the
branch and merge base.

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect_context.sh"
```

Parse the JSON output. Record these fields for the rest of the flow:

- `REPO_ROOT`, `BRANCH`, `MERGE_BASE_REF`, `MERGE_BASE` (sha)
- `DIFF_PATH`, `TRANSCRIPT_PATH`
- `RULES_DIR`, `RULES_FILES`, `DETAILS_DIR`, `DETAILS_FILES`, `LEARNINGS_FILE`, `TESTING_FILE`
- `MISSING` (array), `DIRTY_TREE.UNRELATED_UNSTAGED`, `DIRTY_TREE.UNRELATED_STAGED`

Print the preamble (markdown). Replace bracketed fields with the parsed values.
If `UNRELATED_UNSTAGED` or `UNRELATED_STAGED` is non-empty, include the warning
paragraph; otherwise omit it.

```
Retro on branch `[BRANCH]` (merge base: `[MERGE_BASE_REF] @ [MERGE_BASE short sha]`)

I will:
  1. Read the branch diff and this session's transcript.
  2. Review existing rules, details, learnings, and test procedures.
  3. Propose a candidate table — each row is one proposed change with
     evidence and a destination file. Nothing is written yet.
  4. Apply only the candidates you approve (approve / skip / modify / redirect).
  5. Stage retro-written files and create a single `chore(retro): …` commit.

[If unrelated dirty files:]
Before proceeding: unrelated changes detected — [paths]. These will NOT
be included in the retro commit.

Reply `go` to proceed, `go --auto` to skip per-candidate approval
(apply all proposed changes), or describe anything different you want.
```

Wait for the user. Accepted replies:

- `go` → proceed with per-candidate approval (normal flow).
- `go --auto` → set `AUTO_APPROVE=true`; skip Step 5's gate.
- anything else → treat as scope clarification; incorporate into subagent prompt or stop.

## Step 2 — Bootstrap (first-run only)

If `MISSING` is non-empty, ask one question (use `AskUserQuestion`):

> Missing in this project: `[list]`. Create these with skeleton content
> before proceeding? (y/n)

On `y`, create the missing artifacts using the **exact** templates below.
Do NOT scaffold any rule files — those emerge per-candidate from the analysis.

Skeleton for `agent/docs/learnings.md`:

```
# Learnings

Short, dated observations that haven't earned a topical rule yet.

```

Skeleton for `agent/docs/testing-knowledge.md`:

```
<!-- last-distilled: [TODAY_ISO] branch: [BRANCH] -->
# Testing Knowledge

Manual/integration test procedures not covered by the code test suite.

```

After scaffolding, if `CLAUDE.md` exists at repo root, ask one more y/n:

> Also append a four-line pointer to `CLAUDE.md` so future sessions know
> about the learning artifacts? (y/n)

On `y`, append this block (with a leading blank line):

```
## Learning artifacts
- Topical rules: `.claude/rules/*.md` (instructions only, ≤100 lines each)
- Topic details: `agent/docs/<topic>-details.md` (examples, gotchas)
- Active learnings: `agent/docs/learnings.md` — read this for recent discoveries
- Test procedures: `agent/docs/testing-knowledge.md`
```

If no `CLAUDE.md`, skip silently.

If the user declines the initial bootstrap, stop the retro — the skill cannot
route candidates without the destination structure.
````

- [ ] **Step 2: Commit (partial SKILL.md; Task 8 continues it)**

```bash
git add plugins/devTools/skills/retro/SKILL.md
git commit -m "devTools/retro: SKILL.md preamble and bootstrap sections"
```

---

## Task 8: Extend `SKILL.md` — subagent dispatch, candidate table, apply, commit

**Files:**
- Modify: `plugins/devTools/skills/retro/SKILL.md` (append sections)

- [ ] **Step 1: Append the remaining sections**

Append this content to `plugins/devTools/skills/retro/SKILL.md` (after Step 2):

````markdown

## Step 3 — Dispatch the analysis subagent

Use the `Agent` tool with `subagent_type: "Explore"`. The subagent is single
(not fan-out) so cross-batch duplicates don't need reconciling.

**Subagent prompt** (fill the bracketed fields from the context probe):

> You are the analysis pass of the `retro` skill. Read the inputs below, apply
> the filter, and return a **single JSON object** to stdout. No prose, no
> markdown fences, no explanation. Malformed JSON will cause a retry; a second
> malformed output aborts the skill.
>
> **Inputs:**
> - Branch diff: `[DIFF_PATH]`
> - Session transcript: `[TRANSCRIPT_PATH]` — extract corrections the user made,
>   mistakes the agent made, techniques discovered, and decisions with their
>   rationale. Skip small talk.
> - Existing rules: files listed in `[RULES_FILES]`
> - Existing details: files listed in `[DETAILS_FILES]`
> - Existing learnings: `[LEARNINGS_FILE]`
> - Existing tests: `[TESTING_FILE]`
>
> **Promotion filter.** A candidate is `type: rule` only if ALL three hold:
> 1. Recurs — 2+ occurrences in session/diff, OR matches an existing
>    `learnings.md` entry.
> 2. Actionable — expressible as `do X` or `don't do Y` (not "X is important").
> 3. Articulable violation cost — one-sentence answer to "what breaks if ignored?"
>
> If a candidate fails the filter, route it to:
> - `type: details` if it's a topic-tied gotcha/example/rationale
> - `type: learnings` if it's a small dated observation
> - drop it entirely if it's low signal
>
> **Routing:**
> - `type: rule` → `.claude/rules/<topic>.md`
> - `type: details` → `agent/docs/<topic>-details.md` (paired with rule filename)
> - `type: learnings` → `agent/docs/learnings.md`
> - `type: test` → `agent/docs/testing-knowledge.md`
>
> **Line budget:** rule files cap at 100 lines total. If adding a new rule
> would exceed the cap, also emit a paired `remove-stale` verdict for a rule
> the diff has made obsolete.
>
> **Contradictions:** if a candidate conflicts with an existing rule/details
> entry, emit `verdict: revise` with literal `before` / `after` bytes. Never
> silently replace.
>
> **Output schema (strict):**
> ```json
> {
>   "branch": "[BRANCH]",
>   "merge_base": "[MERGE_BASE]",
>   "summary": { "diff_files_changed": N, "rules_scanned": N,
>                "details_scanned": N, "learnings_entries": N,
>                "testing_entries": N },
>   "candidates": [
>     {
>       "id": "kebab-case-stable-id",
>       "type": "rule|details|learnings|test",
>       "verdict": "new-file|new-section|append|revise|remove-stale",
>       "destination": "repo-root-relative path",
>       "alt_destinations": ["..."],
>       "content": "literal bytes to insert (omit for revise/remove-stale)",
>       "before": "existing bytes (for revise/remove-stale)",
>       "after":  "replacement bytes (for revise)",
>       "section": "## Heading (for test type only)",
>       "evidence": "short provenance (e.g. 'session L142-160')",
>       "violation_cost": "one sentence (required for type=rule, null otherwise)",
>       "recurs": true
>     }
>   ],
>   "stale_candidates": [ /* same shape, verdict=remove-stale */ ]
> }
> ```
>
> Hard rules:
> - Rule candidates MUST have `recurs: true` and a non-null `violation_cost`.
>   Demote any rule-typed candidate that fails either check to `learnings`.
> - Every `destination` must be a real path that exists or will be created by
>   a `new-file` verdict.
> - `id` must be stable, kebab-case, and globally unique within this output.

Parse the returned JSON. On parse error, re-run the subagent once with the
error message appended ("your previous output was not valid JSON: [msg]; emit
JSON only"). On a second failure, stop the skill cleanly with a one-line
message to the user.

## Step 4 — Render candidate table and collect approval

Group the parsed candidates with `stale_candidates` appended at the bottom.
Render a markdown table — columns: `#`, `id`, `type`, `verdict`, `dest`,
`preview` (first 60 chars of `content` or `before→after`).

Below the table, for each row, render an expanded block:

```
[N] <id>
    Evidence:       <evidence>
    Violation cost: <violation_cost | —>
    Alt dests:      <alt_destinations | —>
    [for revise/remove-stale:]
    Before: <before>
    After:  <after>
```

Then prompt:

> Reply with a comma-separated directive list. Examples:
>   `all` — approve everything as proposed
>   `all except 3` — approve everything except skip candidate 3
>   `skip 3, 5; redirect 1 → .claude/rules/security.md; modify 2 → "<new content>"`
>   `only 1, 5, 6` — approve only these
>
> Or reply `cancel` to abort without writing.

If `AUTO_APPROVE=true` (from `go --auto`), skip the prompt and treat the reply
as `all`. Still render the table for transparency.

**Parse the directive:**
- `all` → approve every candidate as-is.
- `all except N[, M, …]` → approve everything, skip the listed #s.
- `only N[, M, …]` → approve only the listed #s.
- `skip N[, M, …]` → drop from the approve-all baseline.
- `redirect N → <path>` → change `destination` on #N.
- `modify N → "<content>"` → replace the `content` field (or `after` field for
  revise) on #N with the quoted bytes.
- Multiple directives separated by `;` apply left-to-right.
- `cancel` → abort without writes or commit.

After parsing, echo the final list numbered, showing final destination + final
content preview per candidate. End with:

> Reply `confirm` to write these changes, or `cancel` to abort.

Wait for `confirm`. This echo step is the second gate; do NOT skip it even in
`--auto` mode — the parse could have fired incorrectly. `--auto` only bypasses
the *first* approval, not the final write confirmation.

## Step 5 — Apply writes

Process approved candidates in this order (within a single pass):

1. **`remove-stale`** — delete the matching `before` block from the destination
   file. Use `Edit` (literal string match); on zero matches, pause and ask the
   user how to proceed; on multiple matches, ask which.
2. **`revise`** — replace `before` with `after` in the destination file. Same
   zero/multi handling.
3. **`new-file`** — create the rule file with this exact header:
   ```
   <!-- last-distilled: [TODAY_ISO] branch: [BRANCH] -->
   # <Topic title derived from filename>

   <content>
   ```
4. **`new-section`** — append `\n\n## <heading>\n\n<content>\n` to the
   destination file. For `type=test`, the heading comes from the `section`
   field.
5. **`append`** — append `<content>\n` to the destination file (or to the
   named section for `type=test`).

**100-line cap enforcement** (rule files only, before each write):

```
projected_lines = (current file line count) +
                  (net lines added by this candidate and any still-pending
                   candidates targeting the same file)
```

If `projected_lines > 100`:
- Abort THIS candidate's write (others proceed).
- Print the numbered current bullets in that file, plus the pending addition.
- Ask: "Which bullets should remain? Reply with a space-separated list of
  line numbers, plus `+new` if the new addition should stay."
- Apply the user's selection: rewrite the file with only the chosen bullets,
  update the `last-distilled` header, move on.

**`last-distilled` header** is rewritten on any successful write to a rule
file or to `testing-knowledge.md`. `learnings.md` and details files have no
header. Details files have no line cap.

**Per-candidate failures are isolated** — log, continue, report in the final
summary.

**Track the set of files actually written** — this is the explicit path list
passed to `stage_and_commit.sh` later.

## Step 6 — Final summary + commit prompt

Print a summary block:

```
Applied N candidates:
  ✓ <id>  →  <destination>  (<verdict>)
  ...
Skipped M: <id> (<reason>)
Failed K: <id> (<reason>)

Files modified (X):
  <path 1>
  <path 2>
  ...

About to stage these X files and commit with:

  chore(retro): distill <BRANCH>

  Rules:
    +<new count> new (<ids>)
    ~<revise count> revised (<ids>)
    -<stale count> removed stale (<ids>)
  Details: +<count> (<ids>)
  Learnings: +<count>
  Tests: +<count> (<ids>)

  🤖 Generated with Claude Code — retro skill

Reply `commit` to proceed, or `hold` to leave files written but unstaged.
```

Wait for the reply:
- `commit` → write the message to a temp file, call `stage_and_commit.sh`
  with the explicit path list, report the resulting commit sha.
- `hold` → print a one-liner noting files are on disk but unstaged, exit.

## Step 7 — Invoke the commit script

```bash
MSG_FILE="$(mktemp)"
cat > "$MSG_FILE" <<EOF
<commit subject + body assembled above>
EOF

bash "${CLAUDE_SKILL_DIR}/scripts/stage_and_commit.sh" "$MSG_FILE" \
  <path 1> <path 2> ... <path N>

rm -f "$MSG_FILE"
```

If the script exits non-zero:
- `2` — internal bug (no paths or bad args) — report and stop.
- `3` — staging drift. Print the stderr diff, suggest the user resolve manually,
  stop.
- any other non-zero — pre-commit hook likely rejected. Print hook output,
  note that files remain staged, suggest the user fix and `git commit` manually.
  Do NOT retry. Do NOT add `--no-verify`.

On success, print:

```
✓ Committed <sha>: chore(retro): distill <BRANCH>
```

Done.

## Notes and invariants

- The skill does NOT walk multiple session JSONL files (deferred to a later
  version). `detect_context.sh` picks the most-recently-modified JSONL in
  the project's Claude Code directory; that is the current session.
- Rule files are bullet-only. If a candidate's `content` contains prose, the
  subagent should have already split it into a paired rule + details
  candidate. If you see prose in a rule candidate at apply time, split it
  yourself: bullets → rule file, prose → paired details file. Record the
  split in the final summary.
- Details files do NOT have the `last-distilled` header; they are re-reviewed
  implicitly whenever their paired rule file is touched.
- `learnings.md` entries are dated with today's ISO date (`[YYYY-MM-DD]`
  prefix on each bullet) when the subagent emits `type: learnings`. If the
  subagent forgets, apply the date yourself before writing.
- Never use `git add -A`, `git add .`, or `git add -u` anywhere in this flow.
  The commit script receives explicit paths only.
- Never pass `--no-verify` to git. If a hook rejects, the user fixes it.
````

- [ ] **Step 2: Commit the full SKILL.md**

```bash
git add plugins/devTools/skills/retro/SKILL.md
git commit -m "devTools/retro: SKILL.md analysis, apply, and commit sections"
```

---

## Task 9: Smoke-test the skill manually

The skill's orchestration is not automatable; the spec's smoke checklist is
how we validate v1.0.0. Run these in a **throwaway** git repo — not ccToolBox.

**Files:** none modified.

- [ ] **Step 1: Set up a throwaway target repo**

```bash
TMPDIR="$(mktemp -d)"
cd "$TMPDIR"
git init -b main
git config user.email smoke@example.com
git config user.name smoke
echo "base" > base.txt
git add base.txt && git commit -m "base"
git checkout -b feat/smoke
echo "feature" > feature.py
git add feature.py && git commit -m "feature"
```

- [ ] **Step 2: Happy path — bootstrap + candidate table + commit**

In a Claude Code session rooted at the temp repo, invoke `/retro`. Walk
through: accept preamble, accept bootstrap (no `.claude/rules/` yet),
review the candidate table, approve a subset, confirm, then `commit`.

Expected:
- Skeleton `agent/docs/learnings.md` and `agent/docs/testing-knowledge.md` created.
- Candidate table renders with at least one candidate per type that matches
  the (tiny) feature work.
- Single `chore(retro): distill feat/smoke` commit in the temp repo.
- Only retro files in the commit — no untracked feature code.

- [ ] **Step 3: Overflow path**

Pre-seed `.claude/rules/api.md` with 98 lines of dummy bullets. Make changes
that should produce a rule candidate routed to `api.md`. Invoke `/retro`.

Expected:
- At apply time, the skill aborts the write to `api.md`, prints the numbered
  bullets, asks which to keep.
- Selection is honored; file is rewritten to ≤100 lines.
- `last-distilled` header is updated.

- [ ] **Step 4: Stale/contradiction path**

Pre-seed a rule that the feature diff contradicts (e.g.,
`- Compare webhook signatures with ==`). Invoke `/retro`.

Expected:
- Subagent emits a `revise` verdict with literal before/after.
- Candidate table shows before/after block.
- Apply replaces the rule bytes.

- [ ] **Step 5: Dirty-tree path**

Leave an unrelated unstaged file (e.g., touch a file outside `.claude/rules`
and `agent/docs`). Invoke `/retro`.

Expected:
- Preamble warns about the unrelated file.
- Retro commit does NOT include the unrelated file.

- [ ] **Step 6: `--auto` path**

Invoke `/retro` and reply `go --auto`. Expected: candidate table still
renders (transparency), the per-candidate approval is skipped, and the final
`confirm`/`hold` gate still runs (it is NOT bypassed by `--auto`).

- [ ] **Step 7: Document smoke results in CHANGELOG**

If any smoke run revealed a bug, fix it and re-run. Once all six pass,
amend `plugins/devTools/CHANGELOG.md` under the 1.0.0 entry with a single
line:

```markdown
- Smoke-tested: bootstrap, overflow, revise, dirty-tree, --auto paths.
```

- [ ] **Step 8: Commit the CHANGELOG amendment**

```bash
git add plugins/devTools/CHANGELOG.md
git commit -m "devTools: note smoke-test coverage in 1.0.0 changelog"
```

---

## Task 10: Register devTools in the marketplace (FINAL)

**Files:**
- Modify: `.claude-plugin/marketplace.json`

This is deliberately the last task. The plugin is only visible to users once
this lands.

- [ ] **Step 1: Read the current marketplace.json**

```bash
cat .claude-plugin/marketplace.json
```

Current file (for reference):

```json
{
  "name": "ccToolBox",
  "description": "Personal Claude Code plugin collection by dev32-io",
  "owner": {
    "name": "dev32-io"
  },
  "plugins": [
    {
      "name": "daily-briefing",
      "description": "Generate a personalized daily news/tech/weather briefing with TTS audio",
      "version": "2.3.1",
      "source": "./plugins/daily-briefing",
      "category": "productivity"
    },
    {
      "name": "offline-research",
      "description": "Tools for structured offline research, architecture exploration, and codebase refactoring",
      "version": "2.4.2",
      "source": "./plugins/offline-research",
      "category": "productivity"
    }
  ]
}
```

- [ ] **Step 2: Append the devTools entry**

Edit `.claude-plugin/marketplace.json` so the final file is exactly:

```json
{
  "name": "ccToolBox",
  "description": "Personal Claude Code plugin collection by dev32-io",
  "owner": {
    "name": "dev32-io"
  },
  "plugins": [
    {
      "name": "daily-briefing",
      "description": "Generate a personalized daily news/tech/weather briefing with TTS audio",
      "version": "2.3.1",
      "source": "./plugins/daily-briefing",
      "category": "productivity"
    },
    {
      "name": "offline-research",
      "description": "Tools for structured offline research, architecture exploration, and codebase refactoring",
      "version": "2.4.2",
      "source": "./plugins/offline-research",
      "category": "productivity"
    },
    {
      "name": "devTools",
      "description": "Developer productivity skills: retrospective learning, and more to come",
      "version": "1.0.0",
      "source": "./plugins/devTools",
      "category": "productivity"
    }
  ]
}
```

No top-level `version` field is introduced (per user preference; the
marketplace has never carried one).

- [ ] **Step 3: Verify JSON validity**

```bash
jq . .claude-plugin/marketplace.json
```

Expected: pretty-printed JSON, no parse errors.

- [ ] **Step 4: Verify the devTools entry version matches plugin.json**

```bash
mp_ver="$(jq -r '.plugins[] | select(.name=="devTools") | .version' .claude-plugin/marketplace.json)"
pl_ver="$(jq -r '.version' plugins/devTools/.claude-plugin/plugin.json)"
echo "marketplace=$mp_ver plugin=$pl_ver"
[[ "$mp_ver" == "$pl_ver" && "$mp_ver" == "1.0.0" ]]
```

Expected: both `1.0.0`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "marketplace: register devTools at 1.0.0"
```

---

## Self-review results

Ran a quick check against the spec (`2026-04-19-retro-skill-design.md`):

**Spec coverage:**
- Purpose & scope → Task 1 (README), Tasks 7-8 (SKILL.md behavior).
- Architecture (Approach 2 subagent) → Task 8 Step 3.
- Input scope (diff + transcript) → Task 4 (detect_context.sh) + Task 8 subagent prompt.
- Promotion filter (3-part) → Task 8 subagent prompt.
- Approval UX (two gates + `--auto`) → Task 7 preamble + Task 8 candidate table + echo.
- Candidate-table JSON contract → Task 8 subagent prompt schema.
- File formats (rule header, 100-line cap, learnings dates, testing heading) → Task 8 apply section.
- Routing (D + iii) → Task 8 subagent routing + Task 7 bootstrap.
- Write logic order (remove-stale → revise → new-file → new-section → append) → Task 8 apply.
- Commit flow (explicit paths, no `--no-verify`, `hold` escape) → Task 6 + Task 8.
- Staleness (per-entry dates on learnings, file-level header on rules/tests) → Task 8 apply.
- Plugin scaffold → Task 1.
- Marketplace registration → Task 10.
- Smoke checklist → Task 9.

All spec sections covered.

**Placeholder scan:** none of the forbidden patterns (`TBD`, `implement later`,
`handle edge cases`, etc.) appear.

**Type consistency:** JSON field names in the candidate contract match between
the spec and Task 8's prompt (`id`, `type`, `verdict`, `destination`,
`alt_destinations`, `content`, `before`, `after`, `section`, `evidence`,
`violation_cost`, `recurs`). Script exit codes consistent between Task 6's
implementation (0/2/3/passthrough) and Task 5's tests.

No issues to fix.

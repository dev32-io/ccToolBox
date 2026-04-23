#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
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

# Reference implementation of the documented migration.
migrate_legacy() {
  local file="$1" today="$2" branch="$3"
  python3 - "$file" "$today" "$branch" <<'PY'
import sys, re, pathlib
path, today, branch = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text()
# Already migrated?
if "## Methods" in text and "## Cases" in text:
    sys.exit(0)
# Split off any existing <!-- last-distilled ... --> comment.
head_m = re.match(r'^(<!--\s*last-distilled:[^\n]*-->\n)', text)
if head_m:
    body = text[head_m.end():]
else:
    body = text
# Split off existing `# Testing Knowledge` title + intro paragraph.
title_m = re.match(r'(#\s+Testing Knowledge\s*\n)', body)
if title_m:
    after_title = body[title_m.end():]
else:
    after_title = body
# Intro = everything up to the first blank line OR first `## ` heading.
intro_m = re.match(r'((?:(?!\n##\s)[^\n]*\n)*?)(\n|$)', after_title)
intro = intro_m.group(1) if intro_m else ""
legacy_body = after_title[len(intro):].lstrip('\n')
migrated = (
    f"<!-- last-distilled: {today} branch: {branch} -->\n"
    f"# Testing Knowledge\n\n"
    f"{intro.strip() or 'Manual/integration test procedures not covered by the code test suite.'}\n\n"
    f"## Methods\n\n"
    f"Tools and techniques this project uses to verify changes on each surface,\n"
    f"and why those tools were chosen. One `###` subsection per surface.\n\n"
    f"## Cases\n\n"
    f"Reusable test scenarios. Each case has explicit steps and expected outcome.\n"
    f"One `###` subsection per case.\n\n"
    f"## Legacy\n\n"
    f"{legacy_body.strip()}\n"
)
pathlib.Path(path).write_text(migrated)
PY
}

setup_tmp() {
  local dir
  dir="$(mktemp -d)"
  TMPDIRS+=("$dir")
  cd "$dir"
}

echo "== legacy_testing_migration =="

# Test 1: legacy file with unstructured prose → migrated with Legacy section.
setup_tmp
cat > tk.md <<'EOF'
# Testing Knowledge

Manual/integration test procedures not covered by the code test suite.

Some old prose about how we test.
Chrome devtools MCP works for smoke.
EOF
migrate_legacy tk.md 2026-04-22 feat/testing
out="$(cat tk.md)"
assert_contains "$out" "## Methods" "T1 Methods section added"
assert_contains "$out" "## Cases" "T1 Cases section added"
assert_contains "$out" "## Legacy" "T1 Legacy section added"
assert_contains "$out" "Some old prose about how we test." "T1 legacy content preserved"
assert_contains "$out" "<!-- last-distilled: 2026-04-22 branch: feat/testing -->" "T1 header written"

# Test 2: already-structured file is a no-op.
setup_tmp
cat > tk.md <<'EOF'
<!-- last-distilled: 2026-04-01 branch: main -->
# Testing Knowledge

Intro.

## Methods

### Existing

## Cases
EOF
before="$(cat tk.md)"
migrate_legacy tk.md 2026-04-22 feat/testing
after="$(cat tk.md)"
assert_eq "$before" "$after" "T2 already-structured file unchanged"

# Test 3: file with an existing last-distilled header preserves intro paragraph.
setup_tmp
cat > tk.md <<'EOF'
<!-- last-distilled: 2026-04-01 branch: main -->
# Testing Knowledge

Custom intro paragraph kept verbatim.

Legacy bullet 1.
Legacy bullet 2.
EOF
migrate_legacy tk.md 2026-04-22 feat/testing
out="$(cat tk.md)"
assert_contains "$out" "Custom intro paragraph kept verbatim." "T3 intro preserved"
assert_contains "$out" "Legacy bullet 1." "T3 body moved to Legacy"
# Intro should appear BEFORE ## Methods.
intro_line=$(grep -n 'Custom intro' tk.md | cut -d: -f1)
methods_line=$(grep -n '^## Methods$' tk.md | cut -d: -f1)
TESTS=$((TESTS+1))
if [[ "$intro_line" -lt "$methods_line" ]]; then
  _pass "T3 intro before Methods"
else
  _fail "T3 intro placement wrong"
fi

summary

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

# Reference implementation of the documented append-into-section behavior.
# Appends <content> inside the named section, immediately before the next
# `## ` heading (or EOF). Creates the section if absent.
append_into_section() {
  local file="$1" section="$2" content="$3"
  python3 - "$file" "$section" "$content" <<'PY'
import sys, re, pathlib
path, section, content = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text()
section_re = re.compile(r'(^|\n)' + re.escape(section) + r'[ \t]*\n', re.MULTILINE)
m = section_re.search(text)
if not m:
    if not text.endswith('\n'):
        text += '\n'
    text += f'\n{section}\n\n{content}\n'
else:
    start = m.end()
    next_m = re.search(r'\n## ', text[start:])
    insert_at = start + next_m.start() if next_m else len(text)
    # Ensure blank line before insertion and single trailing newline after.
    block = f'\n{content.rstrip()}\n'
    text = text[:insert_at].rstrip() + '\n' + block + text[insert_at:]
pathlib.Path(path).write_text(text)
PY
}

setup_tmp() {
  local dir
  dir="$(mktemp -d)"
  TMPDIRS+=("$dir")
  cd "$dir"
}

echo "== apply_testing_candidates =="

# Test 1: append a test-method into the existing ## Methods section.
setup_tmp
cat > tk.md <<'EOF'
<!-- last-distilled: 2026-04-01 branch: main -->
# Testing Knowledge

Intro.

## Methods

## Cases

EOF
append_into_section tk.md "## Methods" "### Web UI smoke tests
**Tool:** chrome-devtools-mcp
**When:** after app/ changes
**Why this tool:** headless, MCP wired
**How:** navigate_page then take_snapshot"
out="$(cat tk.md)"
assert_contains "$out" "### Web UI smoke tests" "T1 method heading present"
assert_contains "$out" "**Tool:** chrome-devtools-mcp" "T1 tool line present"
# The method must land inside ## Methods, i.e. BEFORE ## Cases.
methods_line=$(grep -n '^## Methods$' tk.md | cut -d: -f1)
heading_line=$(grep -n '^### Web UI smoke tests$' tk.md | cut -d: -f1)
cases_line=$(grep -n '^## Cases$' tk.md | cut -d: -f1)
TESTS=$((TESTS+1))
if [[ "$methods_line" -lt "$heading_line" && "$heading_line" -lt "$cases_line" ]]; then
  _pass "T1 method placed inside Methods section"
else
  _fail "T1 method placement wrong (methods=$methods_line heading=$heading_line cases=$cases_line)"
fi

# Test 2: append a test-case into ## Cases.
setup_tmp
cat > tk.md <<'EOF'
# Testing Knowledge

## Methods

## Cases

EOF
append_into_section tk.md "## Cases" "### Probe handles missing transcript dir
**Scenario:** context probe
**Why added:** 2026-04-15 bug
**Steps:**
1. rm dir
2. run script
**Expected:** exit 0"
out="$(cat tk.md)"
assert_contains "$out" "### Probe handles missing transcript dir" "T2 case heading present"
assert_contains "$out" "**Expected:** exit 0" "T2 expected line present"

# Test 3: append creates the section if absent.
setup_tmp
cat > tk.md <<'EOF'
# Testing Knowledge
EOF
append_into_section tk.md "## Methods" "### X
**Tool:** y
**When:** z
**Why this tool:** w
**How:** v"
out="$(cat tk.md)"
assert_contains "$out" "## Methods" "T3 section created"
assert_contains "$out" "### X" "T3 entry appended"

# Test 4: two sequential appends both land in the same section, in order.
setup_tmp
cat > tk.md <<'EOF'
# Testing Knowledge

## Methods

## Cases

EOF
append_into_section tk.md "## Methods" "### First
**Tool:** a
**When:** b
**Why this tool:** c
**How:** d"
append_into_section tk.md "## Methods" "### Second
**Tool:** a
**When:** b
**Why this tool:** c
**How:** d"
first=$(grep -n '^### First$' tk.md | cut -d: -f1)
second=$(grep -n '^### Second$' tk.md | cut -d: -f1)
cases_line=$(grep -n '^## Cases$' tk.md | cut -d: -f1)
TESTS=$((TESTS+1))
if [[ "$first" -lt "$second" && "$second" -lt "$cases_line" ]]; then
  _pass "T4 both entries in Methods, in order"
else
  _fail "T4 ordering wrong (first=$first second=$second cases=$cases_line)"
fi

summary

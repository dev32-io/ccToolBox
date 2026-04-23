#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$here/../skills/recall-test-knowledge/scripts/parse_testing_knowledge.sh"
FIXTURE="$here/fixtures/testing-knowledge.sample.md"
source "$here/lib/assert.sh"

echo "== parse_testing_knowledge =="

out="$(bash "$SCRIPT" "$FIXTURE")"

# Structural checks.
assert_contains "$out" '"methods_total": 3' "T1 method count"
assert_contains "$out" '"cases_total": 2' "T2 case count"
assert_contains "$out" '"malformed": 2' "T3 malformed count (1 method + 1 case)"

# Method fields.
assert_contains "$out" '"surface": "Web UI smoke tests"' "T4 method surface captured"
assert_contains "$out" '"tool": "chrome-devtools-mcp"' "T5 method tool captured"

# Case fields.
assert_contains "$out" '"name": "Context probe handles missing transcript dir"' "T6 case name captured"
assert_contains "$out" '"scenario":' "T7 case scenario captured"
assert_contains "$out" '"why_added":' "T8 case why_added captured"
# Steps must be a JSON array with at least the two items.
assert_contains "$out" 'rm -rf ~/.claude/projects/-Users-test-proj' "T9 case step 1 captured"
assert_contains "$out" 'bash scripts/detect_context.sh' "T10 case step 2 captured"

# Validity flags.
python3 - "$out" <<'PY'
import sys, json
data = json.loads(sys.argv[1])
valid_methods = [m for m in data["methods"] if m["valid"]]
assert len(valid_methods) == 2, f"expected 2 valid methods, got {len(valid_methods)}"
valid_cases = [c for c in data["cases"] if c["valid"]]
assert len(valid_cases) == 1, f"expected 1 valid case, got {len(valid_cases)}"
print("PYCHECK OK")
PY

# Error paths.
TESTS=$((TESTS+1))
if bash "$SCRIPT" /tmp/nonexistent-file.md 2>/dev/null; then
  _fail "T11 missing file should exit nonzero"
else
  _pass "T11 missing file exits nonzero"
fi

TESTS=$((TESTS+1))
if bash "$SCRIPT" 2>/dev/null; then
  _fail "T12 missing arg should exit nonzero"
else
  _pass "T12 missing arg exits nonzero"
fi

summary

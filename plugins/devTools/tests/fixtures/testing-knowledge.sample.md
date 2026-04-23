<!-- last-distilled: 2026-04-22 branch: feat/testing -->
# Testing Knowledge

Manual/integration test procedures not covered by the code test suite.

## Methods

### Web UI smoke tests
**Tool:** chrome-devtools-mcp
**When:** after `app/` route changes
**Why this tool:** headless, already wired, no Playwright install
**How:** `mcp__chrome-devtools__navigate_page` then `take_snapshot`

### Shell harness CI
**Tool:** bash harness in `plugins/*/tests/`
**When:** any script under `plugins/*/scripts/`
**Why this tool:** no runtime install, matches existing convention
**How:** `bash plugins/<plugin>/tests/test_*.sh`

### Broken method (missing How)
**Tool:** x
**When:** y
**Why this tool:** z

## Cases

### Context probe handles missing transcript dir
**Scenario:** retro's context probe, when `~/.claude/projects/<slug>` is absent
**Why added:** 2026-04-15 — skill crashed on fresh-clone projects
**Steps:**
1. `rm -rf ~/.claude/projects/-Users-test-proj`
2. `bash scripts/detect_context.sh`
**Expected:** exit 0, JSON contains `"transcript_path": ""`

### Broken case (no steps)
**Scenario:** x
**Why added:** y
**Expected:** z

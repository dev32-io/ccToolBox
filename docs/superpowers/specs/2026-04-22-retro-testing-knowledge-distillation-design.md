# Retro Skill — Testing Knowledge Distillation (v1.3)

**Status:** Design, awaiting approval
**Target plugin:** `plugins/devTools/skills/retro`
**Version bump:** 1.2.0 → 1.3.0
**Paired with:** `plugins/devTools/skills/recall-test-knowledge` (separate spec, same branch)

## Problem

The retro skill's testing extraction is weak. The subagent treats testing as
one of four candidate types under a generic "extract corrections, mistakes,
techniques" instruction — it has no dedicated pass for testing signal.
Consequences:

- **Test methods** (tool-per-surface with rationale, e.g. "chrome-devtools-mcp
  for web smoke tests, because headless + already-wired MCP") land as
  unstructured prose or not at all.
- **Test cases** (reusable scenarios worth re-running during future refactors)
  are captured inconsistently, often missing `steps` or `expected` — which
  makes them impossible to replay later.
- Nothing distinguishes method-style from case-style entries in the file;
  downstream consumers (human or the future `recall-test-knowledge` skill)
  can't tell what they're looking at.

## Goals

1. Dedicated testing extraction pass in the subagent with tight filters.
2. Two explicit sections inside `testing-knowledge.md`: **`## Methods`** and
   **`## Cases`** — so the `recall-test-knowledge` loader can parse
   mechanically.
3. Every case entry has `steps` and `expected` — no vague cases allowed.

## Non-goals

- **No file restructuring.** Keep single `agent/docs/testing-knowledge.md`.
  No per-feature files, no `testing/` tree, no `last-verified` stamps. All
  deferred — YAGNI.
- No changes to rule / details / learnings flow.
- No result baselines / golden files.

## Design

### File layout — unchanged

```
agent/docs/testing-knowledge.md
```

Skeleton (bootstrap unchanged except for the two top-level sections):

```markdown
<!-- last-distilled: YYYY-MM-DD branch: <branch> -->
# Testing Knowledge

Manual/integration test procedures not covered by the code test suite.

## Methods

Tools and techniques this project uses to verify changes on each surface,
and why those tools were chosen. One `###` subsection per surface.

## Cases

Reusable test scenarios. Each case has explicit steps and expected outcome.
One `###` subsection per case.
```

### Section formats

**`## Methods` → `### <Surface>`:**

```markdown
### Web UI smoke tests
**Tool:** chrome-devtools-mcp
**When:** after changes to `app/` routes or shared layout components
**Why this tool:** headless, scriptable, MCP already wired, no Playwright install
**How:** `mcp__chrome-devtools__navigate_page` then `take_snapshot`
```

**`## Cases` → `### <Case name>`:**

```markdown
### Context probe handles missing transcript dir
**Scenario:** retro skill's context probe, when `~/.claude/projects/<slug>` is absent
**Why added:** 2026-04-15 — skill crashed on fresh-clone projects with no session history
**Steps:**
1. `rm -rf ~/.claude/projects/<encoded-project-path>`
2. `bash plugins/devTools/skills/retro/scripts/detect_context.sh`
**Expected:** exit 0; JSON output contains `"transcript_path": ""`
```

Both formats use bold inline labels (`**Tool:**`, `**Scenario:**`, etc.) so
the `recall-test` skill can parse them without YAML/TOML fences.

### Subagent prompt — new testing extraction pass

Insert after the existing promotion filter, replacing the current
`type: test` routing line. Verbatim block:

> **Testing extraction (dedicated second pass).**
>
> Scan the diff and transcript a second time specifically for testing
> signal. Route to `type: test-method` or `type: test-case` only when the
> respective filter passes. Weak candidates → `learnings`, not
> `testing-knowledge.md`.
>
> **`test-method` filter (ALL must hold):**
> 1. A testing TOOL or TECHNIQUE was used or adopted during this branch.
> 2. It is NEW to the project for this surface — check `testing-knowledge.md`
>    `## Methods` first; if the surface is already covered with this tool,
>    skip.
> 3. You can state, in one line each: *when to use it* and *why this tool
>    over alternatives*.
>
> `content` for a `test-method` candidate MUST use this template:
> ```
> ### <Surface>
> **Tool:** <tool or technique>
> **When:** <one line>
> **Why this tool:** <one line rationale>
> **How:** <one-line invocation hint or example>
> ```
>
> **`test-case` filter (ALL must hold):**
> 1. A concrete scenario was added, run, or manually verified during this
>    branch.
> 2. The scenario is **reusable** — re-running it in a future session would
>    meaningfully verify behavior still holds.
> 3. You can state `scenario`, `why added`, `steps`, `expected` — if any is
>    vague, DROP the candidate. Do not invent missing fields.
>
> `content` for a `test-case` candidate MUST use this template:
> ```
> ### <Case name>
> **Scenario:** <one line>
> **Why added:** <one line — bug? new feature? regression?>
> **Steps:**
> 1. <step>
> 2. <step>
> **Expected:** <assertion>
> ```
>
> **Routing:**
> - `type: test-method` → destination `agent/docs/testing-knowledge.md`,
>   `section: "## Methods"`
> - `type: test-case`   → destination `agent/docs/testing-knowledge.md`,
>   `section: "## Cases"`
>
> Both use verdict `append` when the section exists, or `new-section`
> only if the section is somehow absent (shouldn't happen post-bootstrap).

### Output schema

`candidates[].type` enum becomes:
`rule | details | learnings | test-method | test-case`

No new fields. `section` (already present, was test-only) now used for
both new types.

### Apply logic changes (Step 5 of the skill flow)

- `test-method` and `test-case` with `append` → append `\n\n<content>\n` to
  the named `section` (`## Methods` or `## Cases`) inside
  `testing-knowledge.md`. Refresh `last-distilled` header.
- `test-method` / `test-case` with `revise` or `remove-stale` → same
  literal-bytes match as existing rule/details verdicts.
- If the section heading is missing (legacy file), insert the heading
  before appending.

No line cap on `testing-knowledge.md` (unchanged).

### Migration for legacy files

On first run of v1.3 against a project with an existing
`testing-knowledge.md` that lacks the `## Methods` / `## Cases` sections:

1. Bootstrap detects the absence and asks one y/n:
   > Existing `testing-knowledge.md` lacks `## Methods` and `## Cases`
   > sections. Retrofit the structure now? Existing content will be kept
   > verbatim under a `## Legacy` section. (y/n)
2. On `y`: prepend the two section headings at the top, demote existing
   content under `## Legacy`, refresh `last-distilled` header.
3. On `n`: proceed without migrating. New candidates will still append
   under `## Methods` / `## Cases`, creating those sections via
   `new-section` as needed.

### CLAUDE.md pointer block

Unchanged. `agent/docs/testing-knowledge.md` line stays as-is. The internal
section structure is an implementation detail — consumers (including
`recall-test-knowledge`) grep for `## Methods` / `## Cases` headings.

### Version bump

- `plugin.json`: 1.2.0 → 1.3.0
- `marketplace.json`: same
- `CHANGELOG.md`: entry describing dedicated testing extraction pass +
  Methods/Cases section enforcement + migration prompt
- No settings file — nothing to bump there.

## Test plan (for this change)

Extend `plugins/devTools/tests/`:

- `test_apply_testing_candidates.sh` — new. Simulates a subagent JSON with
  one `test-method` and one `test-case` candidate, runs apply logic, asserts
  file contents match templates and both appear under the correct section
  headings.
- `test_legacy_testing_migration.sh` — new. Starts with a legacy
  `testing-knowledge.md` (no section headings), runs bootstrap migration
  branch, asserts `## Methods` / `## Cases` / `## Legacy` all present and
  original content preserved.
- `test_detect_context.sh` — no changes needed (paths unchanged).
- Manual smoke: run `/retro` on this very branch after implementation;
  confirm testing candidates route to the right sections.

## Consumption contract (for `recall-test-knowledge`)

The format above is the parse target for the `recall-test-knowledge` skill.
Two invariants that must hold:
1. Every method entry has `**Tool:**`, `**When:**`, `**Why this tool:**`,
   `**How:**` in that order.
2. Every case entry has `**Scenario:**`, `**Why added:**`, `**Steps:**`,
   `**Expected:**` in that order; `**Steps:**` is followed by a numbered
   list; `**Expected:**` is a single assertion line.

Changing these labels is a breaking change for `recall-test-knowledge` and
must bump both skills' versions together.

## Open questions

None at spec write. User to confirm before implementation.

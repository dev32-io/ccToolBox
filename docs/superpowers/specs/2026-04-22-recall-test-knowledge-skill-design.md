# recall-test-knowledge Skill — Design

**Status:** Design, awaiting approval
**New plugin skill:** `plugins/devTools/skills/recall-test-knowledge`
**Initial version:** 1.0.0
**Paired with:** `plugins/devTools/skills/retro` v1.3.0 (producer of its input)

## Problem

Distilled testing knowledge in `agent/docs/testing-knowledge.md` is useless
to a working session unless it's *actively surfaced* at the right moment.
Today:

- The main agent doesn't remember to read the file. Even when a `CLAUDE.md`
  pointer exists, as the project grows the testing file competes with
  every other pointer and loses attention.
- Loading the whole file into the main context bloats token use — most
  entries aren't relevant to the specific thing the session is about to
  test.
- Relevant rule files (`.claude/rules/*.md`) that touch testing topics
  have the same problem.

Result: sessions write new tests from scratch, re-discover methods
already documented, miss reusable cases that would catch regressions.

## Goals

1. Auto-invoke when the session is about to write, modify, or reason
   about tests.
2. Use a subagent to scan `testing-knowledge.md` + relevant
   `.claude/rules/*.md` — scanning work stays OUT of the main context.
3. Use **both** the user's query AND the current working context (diff,
   recently referenced files) to find relevant entries.
4. Confirm the candidate set with the user before injecting anything —
   no silent context dumps.
5. On approval, inject the approved entries verbatim into the main
   session as assistant-visible text. No summarization (source of truth
   stays intact).

## Non-goals

- **Does not execute anything.** Not a test runner. If the user wants to
  run the loaded cases, they do so in the main conversation using the
  injected content.
- **Does not write to any file.** Read-only consumer.
- **No staleness stamping / nag** in v1.
- **No fuzzy semantic ranking beyond simple keyword match + LLM
  judgement in the subagent.** Good enough to start; iterate based on
  real use.

## Design

### Trigger (skill `description`)

The skill auto-invokes when the user asks to write, add, design, or
reason about tests. Keywords that should fire it:

> Use when the user asks to write a test, add a test case, design a test
> plan, smoke-test a feature, verify behavior, or otherwise work on
> testing — e.g. "how do we test X", "write a test for Y", "add a smoke
> test", "what's the test plan", "verify this works". Do NOT trigger on
> casual mentions ("I tested it earlier", "the tests pass").

### Inputs the skill reads

- `agent/docs/testing-knowledge.md` — the retro-distilled file. Format
  contract defined in the retro v1.3 spec.
- `.claude/rules/*.md` — all rule files; the subagent filters to ones
  whose content mentions testing.
- **User query** — the message that triggered the skill (the session's
  most recent user turn).
- **Current work context** — the output of a context probe:
  - Current branch + diff vs. merge-base (same logic as
    `retro/scripts/detect_context.sh`, trimmed)
  - Paths of files mentioned in the last few conversation turns
    (surfaced by the parent skill, not the subagent)

### Flow at a glance

1. **Trigger fires** — skill loads.
2. **Context probe** — reuse retro's context-detection logic (trimmed).
   Capture: repo root, branch, merge-base, diff paths, path to
   `testing-knowledge.md`, list of rule files.
3. **Extract session hints** — parent skill scans the recent
   conversation for file paths, component/function names mentioned.
   Passes these to the subagent as hints.
4. **Dispatch search subagent** — one `Explore` subagent receives: user
   query, diff path list, session hints, testing-knowledge.md path,
   rule file paths. Its job is to return a **candidate list** of
   relevant entries.
5. **Render candidates + confirm** — parent skill renders a table,
   asks user to approve / pick subset / cancel.
6. **Inject** — parent skill outputs the full content of the approved
   entries as assistant text, with a header line like
   `Loaded N entries from testing-knowledge.md:`. This text becomes
   part of the session context.

### Subagent contract

**Subagent prompt (fill bracketed fields):**

> You are the search pass of the `recall-test-knowledge` skill. Read
> the inputs, find entries relevant to the session's testing intent,
> and return a single JSON object to stdout. No prose, no markdown
> fences.
>
> **Inputs:**
> - User query: `[USER_QUERY]`
> - Diff paths: `[DIFF_PATHS]` (newline-separated)
> - Session hints: `[SESSION_HINTS]` (filenames / component names from
>   recent conversation)
> - Testing knowledge file: `[TESTING_FILE]`
> - Rule files: `[RULE_FILES]` (newline-separated paths)
>
> **Method:**
> 1. Parse `[TESTING_FILE]`. Extract `## Methods` entries (each
>    `### <Surface>` is one) and `## Cases` entries (each
>    `### <Case name>` is one). Use the label format defined by the
>    retro v1.3 spec.
> 2. For each rule file, read and decide if it's testing-related
>    (mentions tests, verification, assertion, smoke, etc.). Note the
>    title and a one-line summary of relevant content — do NOT emit
>    whole rule files as entries; emit a reference.
> 3. Rank relevance using union of:
>    - Keyword match between user query and the entry's surface /
>      case name / scenario / when / steps
>    - Path overlap between diff paths and the entry's scenario /
>      steps / when strings
>    - Hint overlap between session hints and entry names
> 4. Return up to 8 entries. Under-select rather than over-select —
>    the user can ask again.
>
> **Output schema (strict):**
> ```json
> {
>   "query": "[USER_QUERY]",
>   "stats": { "methods_scanned": N, "cases_scanned": N,
>              "rules_scanned": N },
>   "candidates": [
>     {
>       "id": "kebab-case-stable-id",
>       "kind": "method|case|rule-ref",
>       "source": "testing-knowledge.md|.claude/rules/<name>.md",
>       "heading": "### <as-is from file>",
>       "preview": "<first 120 chars of entry body>",
>       "content": "<full literal bytes of the entry, for injection>",
>       "relevance": "<one sentence on why this matched>"
>     }
>   ]
> }
> ```
>
> For `kind: rule-ref`, `content` is a short pointer string like
> `See .claude/rules/testing-web.md — section "Smoke test checklist"`
> rather than the full rule file. Rules are referenced, not injected
> wholesale, to avoid context bloat.
>
> Malformed JSON → the parent skill retries once with the error
> message appended; a second failure aborts the skill cleanly.

### Confirmation UX

After the subagent returns, the parent renders:

```
recall-test-knowledge — search results for: "<user query>"

Scanned: N methods, M cases, K rule files.

Candidates:
  [1] method | Web UI smoke tests           | chrome-devtools-mcp for web smoke...
  [2] case   | Context probe handles ...    | retro skill's context probe, when ~/.claude...
  [3] rule-ref | .claude/rules/testing-web.md | See section "Smoke test checklist"
  ...

Reply `all` / `only 1,3` / `except 2` / `cancel`.
Or `preview N` to expand candidate N before deciding.
```

If the user replies `preview N`, the parent prints the full `content`
of that candidate and re-prompts for a directive. No separate
confirmation step — the directive reply IS the approval.

If zero candidates returned: print `No relevant testing knowledge
found for this query.` and exit silently.

### Injection

On approved directive, the parent outputs:

```
Loaded N entries from testing-knowledge.md:

---
[candidate 1 heading]
[candidate 1 content]

---
[candidate 2 heading]
[candidate 2 content]

---
(Rule references:)
- [rule-ref 1 content]
- [rule-ref 2 content]
```

This text is part of the skill's assistant-visible output, which means
the main session sees it as ordinary context and can reference it on
subsequent turns.

### Plugin layout

```
plugins/devTools/skills/recall-test-knowledge/
├── SKILL.md
└── scripts/
    └── probe_context.sh    # trimmed copy of retro's detect_context.sh
```

`probe_context.sh` trims retro-specific outputs (dirty-tree
classification, missing-list, learnings-file). Keeps: repo root,
branch, merge-base, diff path, testing file path, rule file list.

Shared-library extraction deferred — one trimmed copy is cheaper to
maintain than a shared lib right now.

### Settings

No user settings in v1.

### Marketplace registration

- Add `recall-test-knowledge` skill under `plugins/devTools` in
  `marketplace.json`.
- `plugins/devTools/.claude-plugin/plugin.json` version bumps to 1.3.0
  (ships together with retro v1.3).
- `CHANGELOG.md` entry: "add recall-test-knowledge skill: auto-loader
  for distilled testing methods and cases."

## Test plan

Extend `plugins/devTools/tests/`:

- `test_parse_testing_knowledge.sh` — new. Fixture
  `testing-knowledge.md` with both Methods and Cases plus a malformed
  entry. Feeds to a test harness that invokes the subagent's parsing
  logic (or a dedicated parser script if extracted). Asserts counts
  and field values.
- `test_probe_context_trimmed.sh` — new. Asserts the trimmed context
  probe returns the expected fields and omits retro-only ones.
- Manual smoke: after retro v1.3 has distilled at least one method and
  one case, start a new session, type `how do we test the retro
  context probe?`, confirm the skill fires and surfaces the expected
  case.

## Failure modes and mitigations

| Failure | Mitigation |
|---|---|
| Main context bloat from full testing file | Subagent parses + filters; only approved entries injected |
| LLM over-selects, returns irrelevant entries | Subagent prompt: "under-select rather than over-select, max 8"; user approval gate |
| LLM misses relevant entries | User can re-invoke with a more specific phrase; no-result path is silent |
| Malformed entry in testing-knowledge.md | Subagent skips with a warning in `stats`; parent prints warning after results |
| Rule file content dumped wholesale | `rule-ref` kind is reference-only, full content excluded |
| Skill fires on false-positive phrases ("tests pass") | Description spells out negative triggers; iterate if it over-fires |

## Relationship with `/retro`

- `/retro` writes `testing-knowledge.md`. Never reads this skill's
  state.
- `recall-test-knowledge` reads `testing-knowledge.md` + rule files.
  Never writes anything.
- The label format contract in retro v1.3 is the coupling surface.
  Changing labels → bump both.

## Open questions

None.

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
- `go --auto` → set `AUTO_APPROVE=true`; skip Step 5's first gate.
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

## Methods

Tools and techniques this project uses to verify changes on each surface,
and why those tools were chosen. One `###` subsection per surface.

## Cases

Reusable test scenarios. Each case has explicit steps and expected outcome.
One `###` subsection per case.

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

**Legacy `testing-knowledge.md` migration.** After bootstrap (or if bootstrap
is skipped because paths already exist), check whether
`agent/docs/testing-knowledge.md` contains both `## Methods` and `## Cases`
section headings. If either is absent, ask one y/n via `AskUserQuestion`:

> Existing `testing-knowledge.md` lacks `## Methods` and `## Cases` sections.
> Retrofit the structure now? Existing content will be preserved verbatim
> under a `## Legacy` section. (y/n)

On `y`: rewrite the file with this layout. Refresh the `last-distilled`
header to today's date + current branch. Keep the `# Testing Knowledge`
title verbatim. Keep the existing intro paragraph if present; if absent,
use the default intro `Manual/integration test procedures not covered by
the code test suite.`. All file content that was below the intro paragraph
moves verbatim under `## Legacy`.

```
<!-- last-distilled: [TODAY_ISO] branch: [BRANCH] -->
# Testing Knowledge

[EXISTING_OR_DEFAULT_INTRO]

## Methods

Tools and techniques this project uses to verify changes on each surface,
and why those tools were chosen. One `###` subsection per surface.

## Cases

Reusable test scenarios. Each case has explicit steps and expected outcome.
One `###` subsection per case.

## Legacy

[EXISTING_BODY_BELOW_INTRO]
```

On `n`: proceed. New candidates will create the sections on first append.

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
> - `type: test-method` → `agent/docs/testing-knowledge.md` (section `## Methods`)
> - `type: test-case`   → `agent/docs/testing-knowledge.md` (section `## Cases`)
>
> **Testing extraction (dedicated second pass).**
>
> Scan the diff and transcript a second time specifically for testing
> signal. Route to `type: test-method` or `type: test-case` only when the
> respective filter passes. Weak candidates → `learnings`, not
> `testing-knowledge.md`.
>
> **`test-method` filter (ALL must hold):**
> 1. A testing TOOL or TECHNIQUE was used or adopted during this branch.
> 2. It is NEW to the project for this surface — check
>    `testing-knowledge.md` `## Methods` first; if the surface is already
>    covered with this tool, skip.
> 3. You can state, in one line each: *when to use it* and *why this tool
>    over alternatives*.
>
> `content` for a `test-method` candidate MUST use this template verbatim:
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
> 2. The scenario is reusable — re-running it in a future session would
>    meaningfully verify behavior still holds.
> 3. You can state `scenario`, `why added`, `steps`, `expected` — if any
>    is vague, DROP the candidate. Do not invent missing fields.
>
> `content` for a `test-case` candidate MUST use this template verbatim:
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
> Both testing types use verdict `append` with `section` set to either
> `"## Methods"` or `"## Cases"`. Never emit verdict `new-section` for
> testing types — the sections are created by bootstrap / migration.
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
>       "type": "rule|details|learnings|test-method|test-case",
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

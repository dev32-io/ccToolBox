# Retro Skill — Design Spec

**Date:** 2026-04-19
**Plugin:** `devTools` (new, v1.0.0)
**Skill:** `retro`
**Status:** design approved, pending implementation plan

## Purpose

Run a retrospective on a completed feature/sprint/bug-bash branch before merging to `develop` or `main`. Turn the session's conversation + branch diff into durable learning artifacts: topical rules, paired details, active learnings, and manual/integration test procedures. Write the approved changes and create a single retro commit.

The skill is destructive-ish (writes files, makes a commit), so it gates behind explicit user intent and a per-candidate approval table.

## Scope

**In scope (v1.0.0):**
- Analyze the branch diff (`git diff <merge-base>...HEAD`) and the current Claude Code session's transcript JSONL.
- Read existing `.claude/rules/*.md`, `agent/docs/*-details.md`, `agent/docs/learnings.md`, `agent/docs/testing-knowledge.md` in the target project.
- Produce a candidate table (rule / details / learnings / test), gated per-candidate.
- Write approved changes, enforce 100-line cap on rule files, update `last-distilled` headers.
- Stage and commit retro artifacts in a single `chore(retro): …` commit.
- First-run bootstrap for projects missing `.claude/rules/` or `agent/docs/`.

**Out of scope (v1.0.0, candidates for future versions):**
- Walking multiple JSONL sessions on the same branch (only the current session's transcript is read).
- Automated consolidation when `learnings.md` exceeds its soft cap — v1.0.0 surfaces the opportunity to the next retro's subagent prompt only.
- Non-`.claude/rules` + `agent/docs` layouts (the file-routing conventions are pinned for v1.0.0).

## Prior art and how this differs

Researched community patterns: `rules-distill` (affaan-m), `session retrospective` (accidentalrebel), `learnings-loop` (mindstudio), `self-improving-agent` (alirezarezvani).

| Community pattern | Adopted | Adapted | Rejected |
|---|---|---|---|
| 3-part promotion filter (recurs, actionable, violation cost) | ✅ | — | — |
| Verdicts: Append / Revise / New Section / New File | ✅ | + `remove-stale` | — |
| Per-candidate approval table, never silent modify | ✅ | + `--auto` escape hatch | — |
| Dated learnings entries | ✅ (learnings only) | — | per-rule dating |
| Tiered knowledge (raw notes → consolidated principles) | — | file-tier equivalent: learnings → rules/details | — |
| Two-command review/apply split (`/si:review` + `/si:promote`) | — | — | single `/retro` with in-flight gating |
| Console-only output, no file writes | — | — | writes + commit (the point of the skill) |

**Novel pieces:** `testing-knowledge.md` as a structured, actively-curated manual/integration test procedure file (no community analogue). File-level `last-distilled` header on rule files (vs. per-bullet dating) so rule files stay as pure instructions.

## Architecture (Approach 2 — subagent-driven analysis)

```
User invokes /retro
        │
        ▼
1. Preamble + single gate       main agent: "proceed with Retro? I will..."
        │
        ▼
2. Context probe                scripts/detect_context.sh:
        │                         merge-base, diff path, transcript path,
        │                         rule/details/learnings/testing paths,
        │                         dirty-tree classification
        ▼
3. First-run bootstrap          if missing dirs → one y/n to scaffold +
        │                         optional CLAUDE.md pointer append
        ▼
4. Analysis subagent (Explore)  reads all inputs, returns JSON candidate list
        │
        ▼
5. Candidate table              main agent prints table, collects approvals
        │                         via DSL (skip/redirect/modify/only)
        ▼
6. Confirm echo                 main agent shows final list, waits for `confirm`
        │
        ▼
7. Apply                        writes in order: remove-stale, revise,
        │                         new-file, new-section, append
        ▼
8. Final summary                applied/skipped/failed, files modified,
        │                         proposed commit message
        ▼
9. Retro commit                 scripts/stage_and_commit.sh stages the
                                  explicit paths only, commits with structured
                                  message. Refuses on staging drift or hook
                                  rejection (no `--no-verify`).
```

Properties:
- **Context isolation:** heavy reads (diff + transcript + all rule files) happen inside the subagent; only the candidate JSON crosses back.
- **Deterministic work is scripted.** Merge-base, path discovery, staging — all in bash. No LLM non-determinism for filesystem/git state.
- **No plugin-side cache.** Staleness signals live in the rule-file headers. Every run reads fresh state.
- **Single subagent, not fan-out.** Avoids cross-batch duplicate merging.

## Input scope (locked: Q1 option B)

- `git merge-base HEAD origin/HEAD` (with fallback chain `main` → `master` → `develop`) — chosen base surfaced in preamble.
- `git diff <merge-base>...HEAD` — full diff text.
- The current Claude Code session's transcript JSONL (inferred from `~/.claude/projects/<project-slug>/<session>.jsonl`).

Multiple-JSONL walking is deferred; v1.0.0 design allows layering it on by extending `detect_context.sh`.

## Promotion filter (locked: Q2 option B — `rules-distill` 3-part filter)

A candidate is routed to `type: rule` only if all three hold:
1. **Recurs** — 2+ occurrences in session OR matches an entry already in `learnings.md`.
2. **Actionable** — expressible as `do X` / `don't do Y`, not as an importance claim.
3. **Articulable violation cost** — one-line answer to "what breaks if this is ignored?"

Candidates failing the filter route to `details` (topic-tied gotcha/example), `learnings` (small dated observation), or drop entirely (low signal). `recurs: true` is a hard gate for `rule`; rule-typed candidates with `recurs: false` are auto-demoted to `learnings`.

Conflict with existing rule → `revise` verdict with literal before/after. Never a silent replacement.

## Approval UX (locked: Q3 option D — two gates + `--auto`)

**Gate 1 — preamble:**

```
Retro on branch <branch> (merge base: <base-branch> @ <sha>)

I will:
  1. Read the branch diff and this session's transcript.
  2. Review existing rules, details, learnings, and test procedures in the target project.
  3. Propose a candidate table — each row is one proposed change with evidence
     and a destination file. Nothing is written yet.
  4. Apply only the candidates you approve (approve / skip / modify / redirect).
  5. Stage retro-written files and create a single `chore(retro): …` commit.

[If unrelated unstaged changes detected:]
Before proceeding: unrelated unstaged changes detected — <file list>.
These will NOT be included in the retro commit.

Reply `go` to proceed, `go --auto` to skip per-candidate approval, or describe
anything you want me to do differently.
```

**Gate 2 — candidate table:**

Markdown table: `# | id | type | verdict | dest | preview`. Below the table, per-row expanded view with `Evidence:`, `Violation cost:`, `Alt destinations:`, and `Before:/After:` for revisions.

Approval DSL examples:
- `all`
- `all except 3`
- `skip 3, 5; redirect 1 → .claude/rules/security.md; modify 2 → "…"`
- `only 1, 5, 6`

Main agent parses, echoes final list numbered, waits for `confirm`.

**`--auto` flag:** skips Gate 2 entirely. Gate 1 preamble still required. Used only when the user has built trust with the skill on their codebase.

## Candidate-table contract (subagent → main agent)

JSON, no prose, no markdown fences. Subagent returns:

```json
{
  "branch": "<branch>",
  "merge_base": "<sha>",
  "summary": {
    "diff_files_changed": <int>,
    "rules_scanned": <int>,
    "details_scanned": <int>,
    "learnings_entries": <int>,
    "testing_entries": <int>
  },
  "candidates": [
    {
      "id": "<kebab-case-stable-id>",
      "type": "rule | details | learnings | test",
      "verdict": "new-file | new-section | append | revise | remove-stale",
      "destination": "<repo-root-relative path>",
      "alt_destinations": ["<path>", "..."],
      "content": "<literal bytes to insert>",
      "before": "<existing bytes, for revise/remove-stale>",
      "after":  "<replacement bytes, for revise>",
      "section": "<##-heading, for test>",
      "evidence": "<short provenance pointer, e.g. 'session L142-160'>",
      "violation_cost": "<one sentence, required for type=rule>",
      "recurs": true
    }
  ],
  "stale_candidates": [ /* same shape, verdict: remove-stale */ ]
}
```

Field semantics pinned in the skill's subagent prompt. Rule-typed candidates MUST have `recurs: true` and a non-null `violation_cost`; others are demoted or dropped at the contract boundary.

## File formats and routing

### `.claude/rules/<topic>.md` (rules)

```
<!-- last-distilled: 2026-04-19 branch: feat/payment-webhook -->
# <Topic>

- Short bullet rule.
- Short bullet rule.
```

- Header comment only metadata — no per-bullet dates.
- Bullets only. No prose, examples, or explanations.
- **100-line hard cap.** If a write would exceed 100, skill aborts THAT write, prints numbered current bullets + pending additions, asks user which to keep. Other writes in the pass proceed.
- Header rewritten on any write.

### `agent/docs/<topic>-details.md` (details)

Free-form markdown with `###` subheadings. Examples, rationale, gotchas. Paired with rule file by filename convention `<topic>.md` ↔ `<topic>-details.md`. No line cap. No `last-distilled` header.

### `agent/docs/learnings.md` (active learnings)

```
# Learnings

Short, dated observations that haven't earned a topical rule yet.

- [2026-04-19] <observation>
- [2026-04-19] <observation>
```

Flat dated bullets, no subsections. Soft cap 100 entries. Overflow surfaces a prompt on the NEXT retro: "do any of these now recur strongly enough to promote to a rule?"

### `agent/docs/testing-knowledge.md` (test procedures)

```
<!-- last-distilled: 2026-04-19 branch: feat/payment-webhook -->
# Testing Knowledge

Manual/integration test procedures not covered by the code test suite.

## <Code area>

**Purpose:** <one sentence>
**Area:** <file paths>
**Steps:**
1. <bash/script/MCP invocation>
2. ...
**Expected:** <one sentence>
```

Topical `##` headings by code area. Entry format pinned (Purpose/Area/Steps/Expected). Header with `last-distilled` stamp. No hard cap; structure + stale-detection keep it manageable. Explicit note in the skill preamble that unit tests belong in the code test suite, not here.

### Routing decision (locked: Q5 — option D + iii)

- Subagent proposes `destination` per candidate via heading-aware clustering across existing rule/details files.
- Candidate table shows proposed destination with `alt_destinations` for ambiguous cases; user can override via approval DSL.
- **First-run bootstrap:** if `.claude/rules/`, `agent/docs/`, `learnings.md`, or `testing-knowledge.md` missing, one y/n up front to scaffold empty skeletons before subagent runs.
- **CLAUDE.md pointer:** on bootstrap, if root `CLAUDE.md` exists, offer (one y/n) to append a four-line pointer to the learning artifacts. Skip silently if no `CLAUDE.md`.

## Write logic

Ordered within a single approval pass:
1. `remove-stale` — frees line budget.
2. `revise` — uses `before`/`after`; greps literal `before`; zero matches → pause, multiple matches → ask which.
3. `new-file` — creates rule file with header + topic heading + initial bullet.
4. `new-section` — appends new `## Subheading` to existing file.
5. `append` — appends bullet/block.

Per-candidate failures are isolated — they surface in the final summary; approved neighbors still apply.

## Commit flow (locked: user's clarification — one retro commit at the end)

`scripts/stage_and_commit.sh`:
- Stages only the explicit paths passed in (no `git add -A`).
- Sanity-checks that the staged set matches the expected set; aborts on drift.
- Commits with a structured message file (heredoc, not `-m`).
- Does NOT pass `--no-verify`. Hook rejection leaves files staged for manual resolution.

Message template:

```
chore(retro): distill <branch>

Rules:
  +<N> new (<id>, ...)
  ~<N> revised (<id>, ...)
  -<N> removed stale (<id>, ...)
Details: +<N> (<id>, ...)
Learnings: +<N>
Tests: +<N> (<id>, ...)

🤖 Generated with Claude Code — retro skill
```

`hold` escape hatch: after final summary, user can reply `hold` instead of `commit`. Files stay written, nothing staged. User finishes manually.

## Staleness and staleness signals

- Per-entry dates on `learnings.md` only (Q4-D).
- File-level `last-distilled: <date> branch: <branch>` header on rule files and `testing-knowledge.md`.
- Details files don't carry headers — they're re-reviewed when their paired rule changes.
- Subagent uses the header date to pick rule files for re-verification against current code on every run, catching silent staleness without per-bullet dating.
- Rules superseded by current code → `revise` verdict, not silent delete.

## Plugin scaffold

```
plugins/devTools/
├── .claude-plugin/plugin.json
├── README.md
└── skills/retro/
    ├── SKILL.md
    └── scripts/
        ├── detect_context.sh
        └── stage_and_commit.sh
```

Marketplace entry added to `.claude-plugin/marketplace.json` (no top-level marketplace version exists; not introducing one):

```json
{
  "name": "devTools",
  "description": "Developer productivity skills: retrospective learning, and more to come",
  "version": "1.0.0",
  "source": "./plugins/devTools",
  "category": "productivity"
}
```

`plugin.json`:
```json
{
  "name": "devTools",
  "description": "Developer productivity skills for software engineering workflows",
  "version": "1.0.0",
  "author": { "name": "dev32-io" }
}
```

No `settings.default.json` for v1.0.0. Add versioned settings if/when tunables emerge.

## Skill trigger

Frontmatter `description` narrow to explicit intent:

- Fires on: "run a retro", "retrospective on this branch", "distill what we learned", `/retro`.
- Does NOT fire on: "recap what we did", "looking back", "summarize this session".

The skill is write-and-commit; it must only run on clear intent.

## Tools used by the skill

`Agent, AskUserQuestion, Bash, Read, Write, Edit, Grep, Glob` — declared in SKILL.md frontmatter.

## Smoke checklist (before declaring v1.0.0 done)

- Dry-run on a toy branch in a throwaway repo — small diff, small transcript, confirm table renders and writes land.
- Bootstrap path — repo without `.claude/rules/` or `agent/docs/`, confirm scaffold y/n.
- Overflow path — pre-seed a rule file at 98 lines, propose a 4-line addition, confirm the skill refuses and offers the prune picker.
- Stale/contradiction path — seed a rule the diff contradicts, confirm subagent emits `revise`.
- Dirty-tree path — leave unrelated unstaged file, confirm preamble warns and commit excludes it.
- `--auto` path — confirm it skips Gate 2 but retains Gate 1 and the final commit confirmation.

## Decisions log (what was chosen and why)

- **Q1 input scope:** B — branch diff + current conversation. Multi-session JSONL walk deferred; 80% of value, designed for later layering.
- **Q2 promotion filter:** B — `rules-distill` 3-part filter. Strongest community safeguard against noise.
- **Q3 approval UX:** D — two gates + `--auto`. Per-candidate approval is the expensive-failure safeguard; `--auto` is the trust escape hatch.
- **Q4 dating:** D — per-entry dates on learnings only; file-level `last-distilled` header on rule and test files. Preserves "rules are pure instructions" while retaining staleness signal.
- **Q5 routing:** D + iii — subagent proposes, candidate table lets user redirect; one y/n bootstrap on first run; CLAUDE.md pointer append offered on bootstrap.
- **Q6 testing-knowledge format:** C — topical sections with merge, per-candidate approval. No per-entry dating (broken tests fail loudly; rules fail silently — different risk profiles).
- **Q7 commit flow:** user override — single retro commit at the end, explicit-path staging, no `--no-verify`, `hold` escape hatch.
- **Approach selection:** Approach 2 — subagent-driven analysis, main agent applies. Keeps main context clean; matches ccToolBox's daily-briefing pattern.
- **Filename case:** `testing-knowledge.md` kebab-case to match `<topic>-details.md` convention.

## Open items deferred to later versions

- Multi-JSONL session walking for long-lived branches.
- Automated `learnings.md` overflow consolidation (v1.0.0 only flags it to next retro's subagent).
- Configurable rule/details path conventions for projects that don't use `.claude/rules` + `agent/docs`.
- Per-project settings (`settings.default.json`) when/if tunables emerge.

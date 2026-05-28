# Synthesizer Redesign: Mission-Anchored, IMRAD-Structured Report

> Status: design approved 2026-05-27. Implementation plan to follow via `superpowers:writing-plans`.

## Context & motivation

The `offline-research` plugin's workshop-loop drives multi-topic research and produces per-topic findings under `<probe_dir>/findings/`. A `synthesizer` agent is invoked at `Synthesize` and `Final report` tasks to roll up findings into cross-topic narrative.

Three problems surfaced from the live `research/vancouver-townhouse-garden` run:

1. **Architectural mismatch.** The mental model of the loop is: expansion adds more topics → another round of scoring → **another synthesize**. Each `Synthesize` should produce a fully presentable report (the user might stop the run at any iteration and want a usable artifact). The current design splits `Synthesize` (mid-run, narrative) from `Final report` (end-of-run, user-facing README), causing the in-progress garden run to lack any user-facing artifact when the loop hadn't yet reached `Final report`.

2. **Seed template drift.** `templates/research-probe/progress.md` still includes a `- [ ] Expand scope: all topics (create topic files in topics/)` task — but the probe skill already creates `topics/NN-<slug>.md` files before emitting `progress.md`. It also still appends a `- [ ] Final report` task that conflicts with point 1. The arch-forge and refactor-probe templates already use the correct shape (no `Expand scope`, no `Final report`, double-`Synthesize`). Only `research-probe` is broken.

3. **Synthesis quality.** The current synthesizer output structure is ad-hoc (cross-topic narrative → key insights → contradictions → tensions). It lacks:
   - **Mission recap** — reader has no anchor to the original goal.
   - **Mission-deliverables audit** — `mission.md` enumerates explicit deliverables (e.g., "master shopping list", "per-plant care cards"); the report should explicitly check which findings satisfy each.
   - **Early navigation** — the table of contents and per-topic links to findings/ are missing or buried; reader cannot skim the artifact's structure.
   - **Actionable conclusion** — the report stops at "so what" (key insights). Academic convention (Harvard "what / so what / now what") requires a "now what" — concrete steps the reader takes to achieve their mission.
   - **Professional structure** — sections are loosely labeled. Real scientific reports follow IMRAD (Introduction / Methods / Results / Discussion) or thesis conventions (Title → Abstract → ToC → Introduction → body → Conclusion → References) that readers know how to navigate.

## Goals

- Each `Synthesize` invocation produces a presentable, mission-anchored report at the current state of the research. The user can stop the loop at any iteration and have a usable artifact.
- Collapse `Synthesize` and `Final report` into a single task type.
- Fix `templates/research-probe/progress.md` so the loop shape matches arch-forge and refactor-probe.
- Restructure synthesizer output to follow thesis-aligned IMRAD with the table of contents placed high (between Abstract and Introduction, per academic convention) and explicit Mission Deliverables Audit + Conclusion & Recommendations sections.
- Remove implicit word caps from synthesizer and reaffirm absence of caps in topic-researcher. Agent gauges depth from material; do not throttle research capability.

## Non-goals

- No changes to the Stop hook (`hooks/workshop-loop-stop.sh`); it already operates generically on `^- \[ \]` count and `| ACTIVE |` rows.
- No changes to `critique-scorer`, `poc-builder`, or `topic-researcher` procedures (topic-researcher confirmed already has no word cap; no edit needed).
- No changes to arch-forge or refactor-probe seed templates (already correct).
- No migration tooling for existing v3.0.x probe directories; the synthesizer change is forward-compatible (it just regenerates `synthesis.md`).

## Architectural decision

**Each `Synthesize` task produces the user-facing report.**

The `Synthesize` task is the loop's deliverable boundary. After every full sweep (initial research → scoring → expansion rounds → re-scoring), one `Synthesize` task fires and writes `<probe_dir>/synthesis.md` as a fully presentable report. `Final report` as a distinct task type is removed; the last `Synthesize` in the queue IS the final report.

This means:

- `synthesis.md` is the single user-facing artifact (no separate `README.md` produced by the synthesizer).
- Each `Synthesize` regenerates `synthesis.md` from scratch by re-reading mission, all findings, scoreboard, connections, contradictions. The file is overwritten in full (not incrementally edited).
- The loop self-perpetuates correctly: `expansion-planner` inserts `Investigate:` + `Score:` tasks before the next `Synthesize` anchor, so every round closes with a fresh synthesis.

## Loop shape (canonical)

After this redesign, all three probe variants share this shape (placeholder substitution differs but the surrounding structure is identical):

```
- [ ] Survey: all topics (skim sources, log in sources.md)
- [ ] Research: <topic-1>
- [ ] Research: <topic-2>
- [ ] ... (per-topic research tasks)
- [ ] Synthesize
- [ ] Critique & Score: <topic-1>
- [ ] Critique & Score: <topic-2>
- [ ] ... (per-topic critique tasks)
- [ ] Synthesize
```

Expansion-planner inserts new `Investigate:` / `Score:` / `PoC:` tasks before the second `Synthesize`, which can then be followed by another `Synthesize` (inserted by expansion-planner when it adds a new round) — preserving the invariant that every round ends with a presentable artifact.

## File-level changes

### 1. `plugins/offline-research/templates/research-probe/progress.md`

Drop two lines:

- `- [ ] Expand scope: all topics (create topic files in topics/)` — redundant; the probe skill creates `topics/NN-<slug>.md` files before emitting `progress.md`.
- `- [ ] Final report` — collapsed into the preceding `Synthesize`.

Final template:

```
max_iter: [MAX_ITER]
max_parallel: 4

# Research Progress

## Scoreboard
| Topic | Status | Src | Depth | Action | Cohere | Confid | Total | Δ | Streak |
|-------|--------|-----|-------|--------|--------|--------|-------|---|--------|
[TOPIC_SCOREBOARD]

## Task Queue

- [ ] Survey: all topics (skim sources, log in sources.md)
[TOPIC_RESEARCH]
- [ ] Synthesize
[TOPIC_CRITIQUE]
- [ ] Synthesize
```

### 2. `plugins/offline-research/agents/synthesizer.md` — full rewrite

**Frontmatter:**

```
---
name: synthesizer
description: Produces the user-facing report for a workshop-loop probe. Reads <probe_dir>/mission.md, all findings/*.md, progress.md scoreboard, connections.md, contradictions.md. Writes <probe_dir>/synthesis.md as a thesis-aligned IMRAD report. Each Synthesize call regenerates the report in full. Handles Synthesize and Synthesize: <variant> tasks.
allowed-tools: Read, Glob, Write
model: opus
---
```

(Removed `Edit` from allowed-tools; synthesizer only writes full-file outputs now.)

**Procedure body:**

```markdown
# synthesizer

You produce the user-facing report at each `Synthesize` task. The report is thesis-aligned and follows IMRAD conventions. A reader who reaches `synthesis.md` cold should be able to (a) understand the mission, (b) navigate to any topic's detailed findings, (c) act on the conclusion.

## Inputs (in the dispatch prompt)

- `probe_dir` — absolute path
- `task` — exact task line, one of:
  - `Synthesize`
  - `Synthesize: <variant>` (e.g., `Synthesize: update synthesis.md` from arch-forge/refactor-probe templates)

Both forms produce the same artifact at `<probe_dir>/synthesis.md`.

## Procedure

1. Read `<probe_dir>/mission.md`. Extract: intent, constraints, goal hierarchy, explicit user-stated deliverables (the artifacts/answers the user requested).
2. Glob and read all `<probe_dir>/findings/*.md`. Read every file fully.
3. Read `<probe_dir>/progress.md`. Extract scoreboard rows (topic, status, per-dim scores, total, streak).
4. Read `<probe_dir>/connections.md` if present.
5. Read `<probe_dir>/contradictions.md` if present.
6. Read `<probe_dir>/gaps.md` if present.
7. Read `<probe_dir>/scoring-rubric.md` (for the Methods section reference).
8. Compose and Write `<probe_dir>/synthesis.md` in full. Use the structure below. Do not append; overwrite the existing file.

## Output structure (mandatory section order)

```markdown
# <Mission Title from mission.md>

<ISO date> · <N topics, M completed iterations, K total sources from sources.md if available>

## Abstract

<Single dense paragraph. Condensed summary covering mission, methods, principal
findings, and implications. A reader who reads only this paragraph gets the
whole study. No bullets. No headings. One paragraph.>

## Table of Contents

- [Introduction](#introduction)
- [Methods](#methods)
- [Findings Index](#findings-index)
  - [<topic-1>](findings/<topic-1>.md) — <status>, <total>/<max>
  - [<topic-2>](findings/<topic-2>.md) — <status>, <total>/<max>
  - ...
- [Discussion](#discussion)
- [Mission Deliverables Audit](#mission-deliverables-audit)
- [Conclusion & Recommendations](#conclusion--recommendations)
- [Open Questions & Suggested Reruns](#open-questions--suggested-reruns)
- [References & Navigation](#references--navigation)

## Introduction

<Restate the mission's intent, constraints, and goal hierarchy. Be faithful to
mission.md — paraphrase only where it improves readability; do not introduce
new framing. Establish what was investigated, why, and against what constraints.>

## Methods

<How the investigation was conducted: workshop-loop with parallel topic
decomposition; per-topic research and critique-scoring against the rubric at
[scoring-rubric.md](scoring-rubric.md); expansion-planner inserting follow-up
tasks (Investigate/Score/PoC) per plateau math; iteration count. 1–2 paragraphs.>

## Findings Index

<Per-topic summary. Each entry:

### <topic name>

**Status:** <ACTIVE | CONCLUDED> · **Score:** <total>/<max> · **Full finding:** [findings/<topic-slug>.md](findings/<topic-slug>.md)

<2–3 sentence summary of what this topic established. Surface the single most
important takeaway. Do not repeat the abstract.>

Repeat for every topic in the scoreboard, in scoreboard order.>

## Discussion

<Thematic synthesis. Group findings into 3–5 cross-cutting themes that weave
multiple topics together. Each theme is 1–3 paragraphs. Reference connections.md
where cross-topic insights apply. Surface resolved contradictions (from
contradictions.md) with how the body of findings resolved each. Surface
remaining tensions (where findings disagree or evidence is split). Do not
restate per-topic content already in the Findings Index.>

## Mission Deliverables Audit

<Explicit checklist mapping each user-stated deliverable from mission.md to
the finding(s) that satisfy it. Use checkbox syntax with three states:

- [x] **<deliverable>** — fully delivered → [findings/<slug>.md](findings/<slug>.md) §<section if applicable>
- [⚠] **<deliverable>** — partial delivery; gap: <one-line> → [findings/<slug>.md](findings/<slug>.md)
- [ ] **<deliverable>** — not addressed in current findings; would require: <one-line>

If mission.md lists no explicit deliverables, infer the implicit deliverables
from the Intent section and audit those.>

## Conclusion & Recommendations

<The "now what" — prioritized actionable plan answering: how does the user
achieve their mission goal? Organize by time horizon:

### Immediate (Week 1)
- <action>. Justification: <finding link>.
- ...

### Near-term (Month 1)
- <action>. Justification: <finding link>.

### Ongoing
- <action>. Justification: <finding link>.

Every action must tie back to a finding for justification. Do not invent
recommendations beyond what the findings support.>

## Open Questions & Suggested Reruns

### Open Questions

<Limitations: unknown variables in mission.md not yet resolved; untested
assumptions surfaced in findings' Open Questions sections; topics still
marked ACTIVE in the scoreboard at end of run.>

### Suggested Reruns

<INCLUDE THIS SUBSECTION ONLY IF rubric retrospective surfaces anomalies.
SKIP THE SUBSECTION ENTIRELY (do not write the heading) if no anomalies.

Anomalies:
- Topic marked CONCLUDED with `total < 60% of max`:
  - **<topic>** plateaued at <total>/<max> after N rounds. Score floor came from
    `<weakest dim>` (<that dim's score>/10 across rounds). Current rubric anchor
    for this dim may undervalue the constraint that matters most for this topic
    — consider rerunning with <weakest dim> weighted higher or with a stricter
    anchor at 0/10.
- Topic that hit first plateau at Δ ≤ 1 from initial score (suspicious):
  - **<topic>**: first plateau Δ=<delta> from <prev> → <current>. Rubric's `<dim>`
    (currently <hint_action>) may need a different hint tag — improvements asked
    for <hint_action-implied work> when the gap appears to be <alternative-work>.>

## References & Navigation

- mission: [mission.md](mission.md)
- rubric: [scoring-rubric.md](scoring-rubric.md)
- all findings: [findings/](findings/)
- scoring history: [scores/](scores/)
- PoCs (if any): [poc/](poc/)
- source bibliography: [sources.md](sources.md)
- contradictions: [contradictions.md](contradictions.md)
- connections: [connections.md](connections.md)
- self-critique / gaps: [gaps.md](gaps.md)
```

## Length policy

No word cap. The Abstract is a single dense paragraph; other sections expand as the material warrants. Push raw detail to `findings/`; synthesis is interpretation, navigation, and conclusion — not duplication of findings content.

## Return contract

Return ONE line:

```
wrote synthesis.md — <N> topics indexed, <M> deliverables audited (<X> ✓, <Y> ⚠, <Z> unmet), <K> open questions
```

If Suggested Reruns subsection was included, append `, suggested-reruns: <count>`.

## Critical rules

- Do NOT modify `progress.md`, `mission.md`, `topics/*.md`, `findings/*.md`, `scores/*.md`, `scoring-rubric.md`, `connections.md`, `contradictions.md`, `gaps.md`, `sources.md`, or `poc/*`. Synthesizer only writes `synthesis.md`.
- Do NOT produce `README.md` (removed from synthesizer's output set).
- Suggested Reruns are SUGGESTIONS only. Do not modify `scoring-rubric.md`.
- Each `Synthesize` regenerates `synthesis.md` in full. Do not attempt incremental Edit; use Write.
- Do not skip sections. The structure is mandatory. If a section has no content (e.g., no contradictions surfaced), state that explicitly inside the section rather than omitting the heading. Exception: Suggested Reruns subsection IS omitted entirely when there are no anomalies.
```

### 3. `plugins/offline-research/agents/expansion-planner.md`

Two changes:

**Frontmatter description** (line 3): drop `/Final report` reference.

Before:
```
description: ...inserts new tasks into <probe_dir>/progress.md (after all current Critique & Score: tasks, before Synthesize/Final report). Invoked by workshop-loop orchestrator immediately after critique-scorer returns.
```

After:
```
description: ...inserts new tasks into <probe_dir>/progress.md (after all current Critique & Score: tasks, before the next Synthesize). Invoked by workshop-loop orchestrator immediately after critique-scorer returns.
```

**Procedure step 6, sub-step (a)** and the example: drop `Final report` mentions.

Before (step 6a):
```
a. **After the last `Critique & Score:` or `Score:` task** in the queue (checked or unchecked) AND before any `Synthesize` / `Final report` task.
```

After:
```
a. **After the last `Critique & Score:` or `Score:` task** in the queue (checked or unchecked) AND before the next `Synthesize` task.
```

Before (example after-edit):
```
- [x] Critique & Score: 01-alpha
- [ ] Critique & Score: 02-beta
- [ ] Critique & Score: 03-gamma
- [ ] Investigate: alpha-source-diversity — ...
- [ ] Score: 01-alpha
- [ ] Synthesize
- [ ] Final report
```

After (example after-edit):
```
- [x] Critique & Score: 01-alpha
- [ ] Critique & Score: 02-beta
- [ ] Critique & Score: 03-gamma
- [ ] Investigate: alpha-source-diversity — ...
- [ ] Score: 01-alpha
- [ ] Synthesize
```

Logic is unchanged; only the textual anchor reference simplifies.

### 4. `plugins/offline-research/commands/workshop-loop.md`

**Dispatch table:** drop the `Final report` row. Update the `Synthesize` row to cover both bare and variant forms.

Before:
```
| `Synthesize` | `synthesizer` | Runs alone. |
| `Final report` | `synthesizer` | Runs alone. Last task of the run. |
```

After:
```
| `Synthesize` (including `Synthesize: <variant>` like `Synthesize: update synthesis.md`) | `synthesizer` | Runs alone. Each call produces a presentable user-facing report at the current state. The final `Synthesize` in the queue IS the final report. |
```

**Agent dispatch prompts section:** simplify synthesizer dispatch.

Before:
```
- `synthesizer`: `probe_dir=<abs>`, `task=Synthesize|Final report`.
```

After:
```
- `synthesizer`: `probe_dir=<abs>`, `task=<exact-task-line>` (e.g., `Synthesize` or `Synthesize: update synthesis.md`).
```

### 5. `plugins/offline-research/CHANGELOG.md`

Add a `[3.1.0] — 2026-05-27` section documenting:

- **Changed:** `Synthesize` and `Final report` collapsed into a single `Synthesize` task type. Each `Synthesize` regenerates `<probe_dir>/synthesis.md` as a presentable mission-anchored report. README.md is no longer produced by the synthesizer. Backward compatible: probe directories from v3.0.x still run; the deprecated `Final report` task (if present in an existing queue) dispatches to the synthesizer and produces a normal synthesize output.
- **Changed:** `templates/research-probe/progress.md` drops the `Expand scope: all topics` task (redundant — probe skill creates topic files) and the `Final report` task (collapsed into `Synthesize`). Now matches arch-forge / refactor-probe template shape.
- **Changed:** synthesizer output restructured to a thesis-aligned IMRAD shape: Title → Abstract → Table of Contents → Introduction → Methods → Findings Index → Discussion → Mission Deliverables Audit → Conclusion & Recommendations → Open Questions & Suggested Reruns → References & Navigation. Mission deliverables explicitly audited against findings. Conclusion section delivers a prioritized actionable plan (the "now what").
- **Removed:** word/length caps on synthesizer output. Agent gauges depth from material.

### 6. `plugins/offline-research/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`

Bump version: `3.0.4` → `3.1.0`. Update both files in the same commit.

## Compatibility

- **Probe directories created by v3.0.x:** still runnable. If a `progress.md` contains a `Final report` task, it dispatches to the synthesizer (same agent) and produces a normal `Synthesize`-equivalent output. The user can manually delete the `Final report` line or leave it — it gets checked off after running and changes nothing.
- **Existing `synthesis.md` files:** overwritten by the new structure on the next `Synthesize`. If a user wants to preserve the prior synthesis, they should rename the file before running.
- **Existing `README.md` files:** untouched. The synthesizer no longer writes to `README.md`. Any prior synthesizer-generated `README.md` becomes stale but is not deleted.

## Validation plan

- **Manual smoke test** against the live `research/vancouver-townhouse-garden` run: invoke `Synthesize` after updating the plugin and inspect the resulting `synthesis.md` for all mandatory sections and a working Mission Deliverables Audit.
- **Template diff verification:** `templates/research-probe/progress.md` now matches arch-forge / refactor-probe shape (no `Expand scope`, no `Final report`, double-`Synthesize`).
- **Dispatch table verification:** orchestrator no longer references `Final report` as a task type.

## Open questions

None at design time. All ambiguity resolved during brainstorming (see conversation in this repo's git history for context).

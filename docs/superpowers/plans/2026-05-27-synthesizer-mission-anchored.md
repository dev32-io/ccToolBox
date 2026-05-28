# Synthesizer Mission-Anchored Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse `Synthesize` + `Final report` into one task, restructure synthesizer output to thesis-aligned IMRAD with Mission Deliverables Audit, fix research-probe seed template drift, bump to v3.1.0.

**Architecture:** Pure prompt + template edits in `plugins/offline-research/`. No code logic changes. Six files modified. No new tests; existing test harnesses (validate-probe-dir, workshop-loop-stop) untouched and need no rerun. Validation is manual smoke against `research/vancouver-townhouse-garden` after plugin update.

**Tech Stack:** Markdown (skill/agent/command/template files), JSON (plugin manifests), bash (no script changes), git.

**Spec:** `docs/superpowers/specs/2026-05-27-synthesizer-mission-anchored-design.md`.

---

## File map

| File | Change | Why |
|---|---|---|
| `plugins/offline-research/templates/research-probe/progress.md` | Drop `Expand scope: all topics` line + `Final report` line | Match arch-forge/refactor-probe template shape |
| `plugins/offline-research/agents/synthesizer.md` | Full rewrite | New IMRAD structure + single task type |
| `plugins/offline-research/agents/expansion-planner.md` | Two text edits | Drop `Final report` anchor references |
| `plugins/offline-research/commands/workshop-loop.md` | Two text edits | Drop `Final report` dispatch row; cover `Synthesize:` variant |
| `plugins/offline-research/CHANGELOG.md` | Prepend 3.1.0 entry | Document changes |
| `plugins/offline-research/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` | Version bump 3.0.4 → 3.1.0 | Plugin install cache refetch |

Task order matters: agent prompts first (1, 2, 3), then template (4), then orchestrator (5), then version+changelog last together (6) so the version bump commit captures all behavior changes.

---

### Task 1: Rewrite synthesizer agent

**Files:**
- Modify: `plugins/offline-research/agents/synthesizer.md` (full file overwrite)

- [ ] **Step 1: Overwrite synthesizer.md with new content**

Replace entire file with:

````markdown
---
name: synthesizer
description: Produces the user-facing report for a workshop-loop probe. Reads <probe_dir>/mission.md, all findings/*.md, progress.md scoreboard, connections.md, contradictions.md. Writes <probe_dir>/synthesis.md as a thesis-aligned IMRAD report. Each Synthesize call regenerates the report in full. Handles Synthesize and Synthesize: <variant> tasks.
allowed-tools: Read, Glob, Write
model: opus
---

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
````

- [ ] **Step 2: Verify allowed-tools dropped Edit**

Run: `grep '^allowed-tools:' plugins/offline-research/agents/synthesizer.md`
Expected: `allowed-tools: Read, Glob, Write` (no Edit).

- [ ] **Step 3: Verify no Final report mention remains**

Run: `grep -i 'final report' plugins/offline-research/agents/synthesizer.md`
Expected: no output (exit 1 from grep).

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/agents/synthesizer.md
git commit -m "feat(synthesizer): IMRAD mission-anchored report (3.1.0 prep)"
```

---

### Task 2: Drop Final report references in expansion-planner

**Files:**
- Modify: `plugins/offline-research/agents/expansion-planner.md`

- [ ] **Step 1: Edit frontmatter description**

Find:
```
description: Computes Δ from a critique-scorer result, applies plateau math + dimension-aware expansion rules, and inserts new tasks into <probe_dir>/progress.md (after all current Critique & Score: tasks, before Synthesize/Final report). Invoked by workshop-loop orchestrator immediately after critique-scorer returns.
```
Replace with:
```
description: Computes Δ from a critique-scorer result, applies plateau math + dimension-aware expansion rules, and inserts new tasks into <probe_dir>/progress.md (after all current Critique & Score: tasks, before the next Synthesize). Invoked by workshop-loop orchestrator immediately after critique-scorer returns.
```

- [ ] **Step 2: Edit step 6a**

Find:
```
   a. **After the last `Critique & Score:` or `Score:` task** in the queue (checked or unchecked) AND before any `Synthesize` / `Final report` task. Rationale: every topic must get scored at the current round before any single topic gets re-investigated. Otherwise the loop drifts into improving one topic while peers stay unscored.
```
Replace with:
```
   a. **After the last `Critique & Score:` or `Score:` task** in the queue (checked or unchecked) AND before the next `Synthesize` task. Rationale: every topic must get scored at the current round before any single topic gets re-investigated. Otherwise the loop drifts into improving one topic while peers stay unscored.
```

- [ ] **Step 3: Edit the after-edit example**

Find:
```
   After edit (you just finished `Critique & Score: 01-alpha`, expansion-planner appends `Investigate: ...` and `Score: 01-alpha`):
   ```
   - [x] Critique & Score: 01-alpha
   - [ ] Critique & Score: 02-beta
   - [ ] Critique & Score: 03-gamma
   - [ ] Investigate: alpha-source-diversity — ...
   - [ ] Score: 01-alpha
   - [ ] Synthesize
   - [ ] Final report
   ```
   The Edit `old_string` is `- [ ] Critique & Score: 03-gamma\n- [ ] Synthesize`. The `new_string` includes the new tasks between them.
```
Replace with:
```
   After edit (you just finished `Critique & Score: 01-alpha`, expansion-planner appends `Investigate: ...` and `Score: 01-alpha`):
   ```
   - [x] Critique & Score: 01-alpha
   - [ ] Critique & Score: 02-beta
   - [ ] Critique & Score: 03-gamma
   - [ ] Investigate: alpha-source-diversity — ...
   - [ ] Score: 01-alpha
   - [ ] Synthesize
   ```
   The Edit `old_string` is `- [ ] Critique & Score: 03-gamma\n- [ ] Synthesize`. The `new_string` includes the new tasks between them.
```

- [ ] **Step 4: Edit the before-edit example**

Find:
```
   Example. Before edit:
   ```
   - [x] Critique & Score: 01-alpha
   - [ ] Critique & Score: 02-beta
   - [ ] Critique & Score: 03-gamma
   - [ ] Synthesize
   - [ ] Final report
   ```
```
Replace with:
```
   Example. Before edit:
   ```
   - [x] Critique & Score: 01-alpha
   - [ ] Critique & Score: 02-beta
   - [ ] Critique & Score: 03-gamma
   - [ ] Synthesize
   ```
```

- [ ] **Step 5: Verify no Final report mention remains**

Run: `grep -i 'final report' plugins/offline-research/agents/expansion-planner.md`
Expected: no output (exit 1).

- [ ] **Step 6: Commit**

```bash
git add plugins/offline-research/agents/expansion-planner.md
git commit -m "fix(expansion-planner): drop Final report anchor references"
```

---

### Task 3: Drop Final report dispatch in workshop-loop command

**Files:**
- Modify: `plugins/offline-research/commands/workshop-loop.md`

- [ ] **Step 1: Edit dispatch table**

Find:
```
| `Synthesize` | `synthesizer` | Runs alone. |
| `Final report` | `synthesizer` | Runs alone. Last task of the run. |
```
Replace with:
```
| `Synthesize` (including `Synthesize: <variant>` like `Synthesize: update synthesis.md`) | `synthesizer` | Runs alone. Each call produces a presentable user-facing report at the current state. The final `Synthesize` in the queue IS the final report. |
```

- [ ] **Step 2: Edit synthesizer dispatch prompt example**

Find:
```
- `synthesizer`: `probe_dir=<abs>`, `task=Synthesize|Final report`.
```
Replace with:
```
- `synthesizer`: `probe_dir=<abs>`, `task=<exact-task-line>` (e.g., `Synthesize` or `Synthesize: update synthesis.md`).
```

- [ ] **Step 3: Verify no Final report mention remains**

Run: `grep -i 'final report' plugins/offline-research/commands/workshop-loop.md`
Expected: no output (exit 1).

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/commands/workshop-loop.md
git commit -m "fix(workshop-loop): drop Final report dispatch row, cover Synthesize variants"
```

---

### Task 4: Fix research-probe seed template

**Files:**
- Modify: `plugins/offline-research/templates/research-probe/progress.md`

- [ ] **Step 1: Overwrite template with corrected content**

Replace entire file with:

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

- [ ] **Step 2: Diff verify against arch-forge / refactor-probe shape**

Run:
```bash
diff <(grep -E '^- \[ \]' plugins/offline-research/templates/research-probe/progress.md | sed 's/Survey:.*$/Survey:/' | sed 's/Synthesize.*$/Synthesize/') <(grep -E '^- \[ \]' plugins/offline-research/templates/refactor-probe/progress.md | sed 's/Scan:.*$/Scan:/' | sed 's/Survey:.*$/Survey:/' | sed 's/Synthesize.*$/Synthesize/')
```
Expected: structural difference only on the first task line (`Survey:` vs `Scan:`). No `Expand scope:` or `Final report` lines present.

- [ ] **Step 3: Verify no Expand scope or Final report remains**

Run: `grep -E 'Expand scope|Final report' plugins/offline-research/templates/research-probe/progress.md`
Expected: no output (exit 1).

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/templates/research-probe/progress.md
git commit -m "fix(research-probe-template): drop Expand scope + Final report tasks"
```

---

### Task 5: Verify no orphaned Final report references plugin-wide

**Files:**
- (read-only audit of `plugins/offline-research/`)

- [ ] **Step 1: Scan entire plugin for remaining Final report mentions**

Run:
```bash
grep -ri 'final report' plugins/offline-research/ --include='*.md' --include='*.json' --include='*.sh'
```
Expected: no output (exit 1) — all references removed. CHANGELOG mentions of `Final report` are allowed (historical) but should not appear in any agent/command/template/script file.

- [ ] **Step 2: If CHANGELOG entries from prior versions (3.0.0, etc.) match, narrow grep**

Run:
```bash
grep -rli 'final report' plugins/offline-research/ --include='*.md' --include='*.json' --include='*.sh' | grep -v CHANGELOG
```
Expected: no output (exit 1).

- [ ] **Step 3: No commit needed**

Audit task — no file changes.

---

### Task 6: Version bump + CHANGELOG entry

**Files:**
- Modify: `plugins/offline-research/.claude-plugin/plugin.json:4`
- Modify: `.claude-plugin/marketplace.json:18`
- Modify: `plugins/offline-research/CHANGELOG.md` (prepend new entry under `## [Unreleased]`)

- [ ] **Step 1: Bump plugin.json version**

Find:
```json
  "version": "3.0.4",
```
Replace with:
```json
  "version": "3.1.0",
```

- [ ] **Step 2: Bump marketplace.json version**

Find (in the `offline-research` plugin block):
```json
      "version": "3.0.4",
```
Replace with:
```json
      "version": "3.1.0",
```

- [ ] **Step 3: Prepend CHANGELOG entry**

Insert after the `# Changelog` preamble lines (before the `## [3.0.4]` heading):

```markdown
## [3.1.0] — 2026-05-27

### Changed

- `Synthesize` and `Final report` collapsed into a single `Synthesize` task type. Each `Synthesize` regenerates `<probe_dir>/synthesis.md` as a presentable mission-anchored report. README.md is no longer produced by the synthesizer.
- `templates/research-probe/progress.md` drops the `Expand scope: all topics` task (redundant — probe skill creates topic files) and the `Final report` task (collapsed into `Synthesize`). Now matches arch-forge / refactor-probe template shape.
- Synthesizer output restructured to a thesis-aligned IMRAD shape: Title → Abstract → Table of Contents → Introduction → Methods → Findings Index → Discussion → Mission Deliverables Audit → Conclusion & Recommendations → Open Questions & Suggested Reruns → References & Navigation. Mission deliverables explicitly audited against findings. Conclusion section delivers a prioritized actionable plan (the "now what").
- Workshop-loop dispatch table updated: `Synthesize` row now covers `Synthesize: <variant>` forms (used by arch-forge / refactor-probe templates).

### Removed

- `Final report` task type. Use `Synthesize` instead — the last `Synthesize` in the queue IS the final report.
- Word/length caps on synthesizer output. Agent gauges depth from material.
- Synthesizer-generated `README.md` output.

```

- [ ] **Step 4: Verify versions match**

Run:
```bash
grep '"version"' plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json
```
Expected: both files show `"version": "3.1.0"` for offline-research.

- [ ] **Step 5: Commit**

```bash
git add plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/offline-research/CHANGELOG.md
git commit -m "chore(offline-research): bump to 3.1.0 + changelog"
```

- [ ] **Step 6: Push**

```bash
git push origin main
```

---

## Post-implementation manual smoke (user-driven, NOT a task step)

After the user updates the plugin (`/plugin update offline-research` or session restart):

1. Resume `research/vancouver-townhouse-garden` run with `/offline-research:workshop-loop /Users/kevinye/Development/research/vancouver-townhouse-garden`.
2. Let the loop reach the next `Synthesize` task.
3. Inspect `research/vancouver-townhouse-garden/synthesis.md`:
   - All 11 mandatory sections present in correct order (Title, Abstract, ToC, Introduction, Methods, Findings Index, Discussion, Mission Deliverables Audit, Conclusion & Recommendations, Open Questions & Suggested Reruns, References & Navigation)
   - ToC links resolve to existing finding files
   - Mission Deliverables Audit lists all four deliverables from `mission.md` (shopping list, care cards, seasonal calendar, aesthetic combos)
   - Conclusion section has Immediate / Near-term / Ongoing buckets
   - Suggested Reruns subsection present only if anomalies (otherwise skipped entirely)

If any section is missing or malformed, iterate on the synthesizer prompt.

---

## Spec-coverage check (self-review)

| Spec requirement | Task |
|---|---|
| Collapse Synthesize + Final report | Tasks 1, 3 |
| Each Synthesize produces presentable report | Task 1 (procedure + structure) |
| Drop Expand scope from research-probe template | Task 4 |
| Drop Final report from research-probe template | Task 4 |
| IMRAD section order in synthesizer output | Task 1 (mandatory structure) |
| Mission Deliverables Audit section | Task 1 |
| Conclusion & Recommendations with time-horizon buckets | Task 1 |
| No word caps | Task 1 (Length policy section) |
| Suggested Reruns conditional inclusion | Task 1 (rule in Critical rules + structure note) |
| Expansion-planner anchor update | Task 2 |
| Workshop-loop dispatch table update | Task 3 |
| Version bump 3.0.4 → 3.1.0 | Task 6 |
| CHANGELOG entry | Task 6 |
| Orphan reference audit | Task 5 |

All spec requirements mapped to tasks. No gaps.

# Self-Critical Research Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an iterative self-critical loop (Phase 6) to the offline-research prompt template so the agent scores its findings via Sonnet subagents, identifies gaps, expands topics, and keeps researching until all topics plateau.

**Architecture:** The existing 5-phase linear template gets a new Phase 6 that repeats. Two new template files (`critique-loop.md`, `scoring-rubric.md`) define the loop mechanics and scoring rubric. The research-probe skill writes all 4 templates and calculates `max-iterations = topics + 15`.

**Tech Stack:** Markdown templates, Claude Code Agent tool with `model: sonnet`, ralph-loop

---

### Task 1: Create `scoring-rubric.md` template

This file is read by both the main Opus agent (to understand scores) and each Sonnet subagent (to produce scores). It must be self-contained — the Sonnet subagent has NO other context.

**Files:**
- Create: `plugins/offline-research/templates/scoring-rubric.md`

- [ ] **Step 1: Write `scoring-rubric.md`**

```markdown
# Scoring Rubric

You MUST read this file completely before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption.

## Your Role

You are a quality probe. You will receive one research topic's findings (or PoC output — code, plans, diagrams, READMEs). Your job: read it as a curious, skeptical reader and score how well it holds up.

**Be curious.** Wonder "but what about...?", "how does this compare to...?", "what would happen if...?". Genuine curiosity produces sharper critique than a checklist.

## Scoring Dimensions (each 0-10, max 50)

| Dimension | 0 | 5 | 10 |
|-----------|---|---|-----|
| **Source diversity** | Single source or no sources cited | 3-4 sources, some overlap | 5+ independent sources, multiple perspectives |
| **Depth of insight** | Surface-level summary, no specifics | Some detail, a few examples | Specific examples, concrete data, expert-level detail |
| **Actionable clarity** | Reader would need to research further to act | Partially actionable, some gaps | Reader can act immediately, no ambiguity |
| **Internal coherence** | Contradicts itself, logic gaps | Mostly consistent, minor issues | Fully consistent, logical flow throughout |
| **Confidence** | Speculative claims, no evidence | Mix of supported and unsupported | Every claim backed by evidence or clearly marked as opinion |

## Friction-Based Deduction

Any friction you experience while reading is a quality signal. This includes:

- Wanting to search the web to verify a claim → deduct from **Confidence**
- Wanting to push back on a conclusion → deduct from **Internal coherence**
- Wanting to ask the author what they mean → deduct from **Actionable clarity**
- Wanting a second opinion → deduct from **Confidence**
- Wanting to see an example → deduct from **Depth of insight**
- Wanting to check other sources → deduct from **Source diversity**
- Any hesitation, uncertainty, or "wait, really?" → identify which dimension it affects and deduct

**The urge itself is the deduction.** You do not need to actually verify — the fact that you wanted to is the score signal.

## Output Format

Return your critique in exactly this format:

```
## Scores
- Source diversity: N/10
- Depth of insight: N/10
- Actionable clarity: N/10
- Internal coherence: N/10
- Confidence: N/10
- **Total: N/50**

## Friction Log
- [dimension affected]: "description of what caused friction"
- [dimension affected]: "description of what caused friction"
...

## What's Missing
- question or gap this topic hasn't addressed
- question or gap this topic hasn't addressed
...

## What's Strong
- what works well and should be preserved
...
```
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/scoring-rubric.md
git commit -m "feat(offline-research): add scoring rubric template for Sonnet subagents"
```

---

### Task 2: Create `critique-loop.md` template

This file defines the Phase 6 loop mechanics. The main Opus agent reads it after Phase 5 completes. It must contain everything the agent needs: the loop steps, how to spawn subagents, how to update the scoreboard, topic lifecycle rules, workspace evolution, and termination conditions.

**Files:**
- Create: `plugins/offline-research/templates/critique-loop.md`

- [ ] **Step 1: Write `critique-loop.md`**

```markdown
# Phase 6: Critique & Expand Loop

Do NOT proceed without reading this file in full. Every instruction here is load-bearing.

## Overview

You have completed the initial research (Phases 1-5). Now you enter an iterative loop: score your work, find what's weak, expand into new territory, and keep going until every topic has plateaued — or you run out of iterations.

## The Loop

Repeat the following cycle:

### 6a. Score — Spawn Sonnet Subagents

For each ACTIVE topic in progress.md, spawn a subagent:

- **Model:** sonnet
- **Isolation:** The subagent gets ONLY the scoring rubric and the topic's output. No other context. No web access. No research history. This isolation is the point — if the subagent can't understand your findings without extra context, your findings aren't good enough.
- **Prompt:** "You MUST read `<path>/scoring-rubric.md` before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption. After reading the rubric, read `<path>/findings/<topic>.md` and score it according to the rubric. Be curious — wonder what's missing, what doesn't add up, what you'd want to know more about."

Replace `<path>` with the actual workspace path. For PoC topics, point the subagent at whatever the topic produced (code, plans, diagrams, READMEs in `poc/<topic>/`).

Spawn subagents in parallel where possible — they are independent.

### 6b. Update Scoreboard

Collect scores from all subagents. For each topic:

1. Record the new scores in the progress.md scoreboard
2. Compute Δ (this cycle's total minus last cycle's total)
3. Update streak:
   - If Δ ≤ 1: increment streak by 1
   - If Δ > 1: reset streak to 0
4. If streak reaches 2: mark topic as **CONCLUDED**

### 6c. Plan Next Actions

Look at ACTIVE topics only. For each:

- Read the subagent's friction log and "What's Missing" section
- Decide what to do next: close gaps, research deeper, add new topics
- Before adding any new topic, deduplicate against ALL topics in progress.md (both ACTIVE and CONCLUDED). If it substantially overlaps with an existing topic, don't add it.
- New topics enter as ACTIVE with no prior scores.

Research isn't only reading. When a topic would benefit from *making something* — you should definitely do it. This includes:
- Building a prototype or proof-of-concept script
- Drafting an architecture or system design
- Sketching a visual mockup, diagram, or flowchart
- Writing a plan that stress-tests an idea by trying to build it

Create a folder in `poc/` and add it as a topic in progress.md. Scored the same way.

### 6d. Execute

Research, build, or explore ACTIVE topics based on your plan from 6c. Write output to `findings/` (or `poc/` for PoC topics). Update `sources.md` with any new sources.

### 6e. Re-synthesize

Update these files to reflect everything you now know:
- `connections.md` — cross-topic patterns and insights
- `contradictions.md` — where sources disagree
- `gaps.md` — what's still weak
- `README.md` — TLDR summary with navigation

Log the cycle in progress.md under the Cycle Log section.

### Termination

- **All topics CONCLUDED →** Output `<promise>ALL PHASES COMPLETE</promise>` and stop.
- **Max iterations reached →** Do a final re-synthesis, output the completion promise, and stop.
- **Otherwise →** Loop back to 6a.

## Topic Lifecycle

Two states only:

- **ACTIVE** — scored each cycle, researched if gaining
- **CONCLUDED** — Δ ≤ 1 for 2 consecutive cycles. Permanent. No further research.

There is no parent/child distinction. Sub-topics are just topics. All topics live as rows in the progress.md scoreboard.

## Workspace Evolution

You own this workspace. Organize it as the research demands:
- Add new topic files in `topics/` and findings in `findings/`
- Create `poc/` subfolders for prototyping work
- Split, merge, or reorganize files when it makes the research clearer
- Every new topic gets a row in the progress.md scoreboard
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/critique-loop.md
git commit -m "feat(offline-research): add critique loop template for Phase 6"
```

---

### Task 3: Update `prompt.md` template

Add the workspace entries for the new files, add Phase 6 as a hard gate to `critique-loop.md`, and add the PoC exploration hint.

**Files:**
- Modify: `plugins/offline-research/templates/prompt.md`

- [ ] **Step 1: Update the workspace structure diagram**

Replace the existing workspace structure block:

```
## Workspace Structure

```
/workspace/
├── progress.md              # thin checklist — current phase + per-topic status
├── topics/
│   ├── 01-topic-name.md     # sub-topics + questions (generated in Phase 1)
│   └── ...
├── findings/
│   ├── topic-name.md        # research output per topic
│   └── ...
├── sources.md               # running bibliography — URLs, titles, notes
├── contradictions.md        # where sources disagree
├── connections.md           # cross-topic patterns and insights
├── gaps.md                  # self-critique — what's weak, what needs more work
└── README.md                # final TLDR + navigation
```
```

With:

```
## Workspace Structure

```
/workspace/
├── progress.md              # live scoreboard — scores, deltas, cycle log
├── critique-loop.md         # Phase 6 loop protocol (read after Phase 5)
├── scoring-rubric.md        # scoring dimensions for subagents
├── topics/
│   ├── 01-topic-name.md     # sub-topics + questions (generated in Phase 1)
│   └── ...
├── findings/
│   ├── topic-name.md        # research output per topic
│   └── ...
├── poc/                     # prototypes, architectures, visual explorations
│   └── ...
├── sources.md               # running bibliography — URLs, titles, notes
├── contradictions.md        # where sources disagree
├── connections.md           # cross-topic patterns and insights
├── gaps.md                  # self-critique — what's weak, what needs more work
└── README.md                # final TLDR + navigation
```
```

- [ ] **Step 2: Replace Phase 5 and the completion promise**

Replace the current Phase 5 and the completion promise line:

```
### Phase 5: Final Report
1. Write README.md — TLDR summary with links to each findings file
2. Update progress.md to mark all phases complete

Output <promise>ALL PHASES COMPLETE</promise> when done.
```

With:

```
### Phase 5: Final Report
1. Write README.md — TLDR summary with links to each findings file
2. Update progress.md to mark Phase 5 complete

### Phase 6: Critique & Expand Loop

Do NOT proceed past Phase 5 without reading `critique-loop.md` in full. The loop protocol, scoring system, and subagent instructions are defined there. Skipping this file will produce incorrect results.

Read `critique-loop.md` now and follow it exactly.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/templates/prompt.md
git commit -m "feat(offline-research): add Phase 6 gate and PoC workspace to prompt template"
```

---

### Task 4: Update `progress.md` template

Replace the simple checklist with the scoreboard format.

**Files:**
- Modify: `plugins/offline-research/templates/progress.md`

- [ ] **Step 1: Replace entire file contents**

Replace the current contents with:

```markdown
# Research Progress

## Current Phase: Phase 1 — Scope Expansion

## Topic Scoreboard
| Topic | Status | Src | Depth | Action | Cohere | Confid | Total | Δ | Streak |
|-------|--------|-----|-------|--------|--------|--------|-------|---|--------|
[TOPIC_SCOREBOARD]

## Phase Checklist
- [ ] Phase 1: Scope Expansion
- [ ] Phase 2: Survey
- [ ] Phase 3: Deep Dive
- [ ] Phase 4: Synthesize
- [ ] Phase 5: Final Report
- [ ] Phase 6: Critique & Expand

## Cycle Log
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/progress.md
git commit -m "feat(offline-research): replace progress checklist with scoreboard format"
```

---

### Task 5: Update `research-probe/SKILL.md`

Update the Generate phase (Step 5) to write 4 template files instead of 2 and calculate `max-iterations = topics + 15`.

**Files:**
- Modify: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Update the template reading section**

Find the "Read templates" block in Step 5 and replace:

```
**Read templates:**
- Read `<plugin-root>/templates/prompt.md`
- Read `<plugin-root>/templates/progress.md`
```

With:

```
**Read templates:**
- Read `<plugin-root>/templates/prompt.md`
- Read `<plugin-root>/templates/progress.md`
- Read `<plugin-root>/templates/critique-loop.md`
- Read `<plugin-root>/templates/scoring-rubric.md`
```

- [ ] **Step 2: Add instructions to fill and write the new templates**

After the existing "Fill progress.md" block and before "Write both files", replace:

```
**Fill progress.md:**
- Replace `[TOPIC_CHECKLIST]` with one `- [ ] topic-name.md` per topic

**Write both files** to the user's chosen directory using the Write tool.
```

With:

```
**Fill progress.md:**
- Replace `[TOPIC_SCOREBOARD]` with one row per topic:
  ```
  | topic-name | ACTIVE | - | - | - | - | - | - | - | 0 |
  ```

**Write `critique-loop.md` and `scoring-rubric.md`** unchanged (no placeholders to fill).

**Write all four files** to the user's chosen directory using the Write tool.
```

- [ ] **Step 3: Update max-iterations in the ralph-loop commands**

Find both ralph-loop command blocks (container and local) and replace `--max-iterations 15` with `--max-iterations <N>` where `<N>` is the number of initial topics + 15.

Replace:

```
  /ralph-loop:ralph-loop "Read /workspace/<folder-name>/prompt.md and execute the research mission. Read /workspace/<folder-name>/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from /workspace/<folder-name>/topics/ and write output to /workspace/<folder-name>/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations 15 --completion-promise "ALL PHASES COMPLETE"
```

With:

```
  /ralph-loop:ralph-loop "Read /workspace/<folder-name>/prompt.md and execute the research mission. Read /workspace/<folder-name>/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from /workspace/<folder-name>/topics/ and write output to /workspace/<folder-name>/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations <TOPIC_COUNT + 15> --completion-promise "ALL PHASES COMPLETE"
```

Do the same for the local command block.

Add a note above the command blocks:

```
**Calculate max-iterations:** Count the number of initial topics and add 15. The initial phases consume iterations proportional to topic count; the +15 guarantees room for the critique-expand loop. Example: 8 topics → `--max-iterations 23`.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/skills/research-probe/SKILL.md
git commit -m "feat(offline-research): write 4 templates and calculate max-iterations in research-probe"
```

---

### Task 6: Remove redundant container reference templates

The templates at `containers/offline-research/research_template/` are a redundant copy. The skill reads from `plugins/offline-research/templates/` and writes filled versions to the workspace. A second copy is just drift waiting to happen. Delete it.

**Files:**
- Delete: `containers/offline-research/research_template/prompt.md`
- Delete: `containers/offline-research/research_template/progress.md`
- Delete: `containers/offline-research/research_template/ralph-command.md`

- [ ] **Step 1: Remove the directory**

```bash
git rm -r containers/offline-research/research_template/
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore(offline-research): remove redundant container reference templates"
```

---

### Task 7: Verify template placeholders and end-to-end readability

Read through all 4 plugin templates and the SKILL.md as a final pass. Confirm: no stale placeholder names, no references to removed sections, workspace paths consistent, completion promise wording matches ralph-loop `--completion-promise` argument.

**Files:**
- Read: `plugins/offline-research/templates/prompt.md`
- Read: `plugins/offline-research/templates/progress.md`
- Read: `plugins/offline-research/templates/critique-loop.md`
- Read: `plugins/offline-research/templates/scoring-rubric.md`
- Read: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Verify placeholder consistency**

Check that:
- `prompt.md` still has `[TOPIC]` and `[TOPICS]` placeholders (filled by skill)
- `progress.md` has `[TOPIC_SCOREBOARD]` placeholder (filled by skill)
- `critique-loop.md` and `scoring-rubric.md` have NO placeholders (written as-is)
- SKILL.md references `[TOPIC_SCOREBOARD]` (not the old `[TOPIC_CHECKLIST]`)

- [ ] **Step 2: Verify completion promise consistency**

Check that:
- `prompt.md` does NOT contain `Output <promise>ALL PHASES COMPLETE</promise> when done.` at the end of Phase 5 (it was moved to `critique-loop.md`)
- `critique-loop.md` contains the completion promise in its termination section
- SKILL.md ralph-loop commands still have `--completion-promise "ALL PHASES COMPLETE"`

- [ ] **Step 3: Verify path references**

Check that `critique-loop.md` tells the agent to read `scoring-rubric.md` using the same path pattern used elsewhere (relative to workspace root).

- [ ] **Step 4: Fix any issues found, commit if changes were made**

```bash
git add -A
git commit -m "fix(offline-research): fix template consistency issues"
```

# Self-Critical Research Loop Design

## Overview

Extend the offline-research prompt template to add an iterative self-critical loop after the initial 5-phase research pass. The agent critiques its own findings using Sonnet subagents as quality probes, identifies gaps, expands into new topics, and keeps researching until all topics plateau — or max-iterations is reached.

## Problem

The current template runs Phases 1-5 linearly and exits. Despite running inside ralph-loop, the research itself doesn't loop. It finishes quickly because each iteration just processes one phase. The agent never re-examines what it produced, never asks "what's missing?", and never goes deeper.

## Solution

Add Phase 6 (Critique & Expand) that repeats after Phase 5. Each cycle: score every active topic via isolated Sonnet subagents, compute information gain, conclude plateaued topics, expand into new topics, and research what's still gaining. The loop terminates when all topics are CONCLUDED or max-iterations is hit.

## Template File Structure

The research-probe skill writes 4 files to the workspace (up from 2):

```
workspace/
├── prompt.md            # research mission + phases 1-5 + phase 6 entry point
├── progress.md          # live scoreboard + cycle log
├── critique-loop.md     # loop mechanics, subagent protocol, workspace evolution
└── scoring-rubric.md    # scoring dimensions, friction-based deduction, plateau rules
```

`prompt.md` ends Phase 5 with a hard gate:

> "Do NOT proceed past Phase 5 without reading `critique-loop.md` in full. The loop protocol, scoring system, and subagent instructions are defined there. Skipping this file will produce incorrect results."

## Phase 6: Critique & Expand (Repeating)

```
6a. For each ACTIVE topic:
    → Spawn Sonnet subagent (model: sonnet)
    → Subagent reads scoring-rubric.md + that topic's findings
    → Subagent scores, critiques, flags friction
    → Returns scores + critique notes

6b. Per topic: compute gain delta (Δ)
    → Update progress.md scoreboard
    → If Δ ≤ 1 for 2 consecutive cycles → mark TOPIC CONCLUDED
    → Otherwise stays ACTIVE

6c. Plan next actions (ACTIVE topics only)
    → Close gaps flagged by subagents
    → Add new topics if needed (deduplicate first)
    → Optionally pursue PoC / visual exploration / architecture

6d. Execute (research, build, explore on ACTIVE topics)

6e. Re-synthesize
    → Update connections.md, contradictions.md, gaps.md, README.md

→ If ALL topics CONCLUDED: output completion promise, STOP
→ If max-iterations reached: STOP
→ Otherwise: loop back to 6a
```

## Topic Lifecycle

Two states only:

- **ACTIVE** — scored each cycle, researched if gaining
- **CONCLUDED** — gain Δ ≤ 1 for 2 consecutive cycles. Permanent. No further research.

Rules:
- New topics enter as ACTIVE.
- Before adding any topic, deduplicate against all existing topics (ACTIVE and CONCLUDED). If it substantially overlaps, don't add.
- Termination: all topics CONCLUDED, or max-iterations reached.
- There is no parent/child distinction. Sub-topics are just topics.

## Scoring System

### Sonnet Subagent Protocol

Each ACTIVE topic gets its own Sonnet subagent (model: sonnet). The subagent receives:
1. `scoring-rubric.md` — MUST be read before any output
2. The topic's findings file

The subagent has NO web access, NO accumulated context, NO research history. Just the rubric and the findings. This isolation is the point — if Sonnet can't understand the findings without extra context, the findings aren't good enough.

The subagent's core instruction: **Be curious. Wonder "but what about...?", "how does this compare to...?", "what would happen if...?". Genuine curiosity produces sharper critique than a checklist.**

### Scoring Dimensions (each 0-10, max 50)

| Dimension | What it measures |
|-----------|-----------------|
| Source diversity | Multiple independent sources, not one-source-heavy |
| Depth of insight | Goes beyond surface, has specific details and examples |
| Actionable clarity | Reader can act on this without further research |
| Internal coherence | Claims are consistent, logic follows, no contradictions |
| Confidence | Claims feel well-supported vs speculative |

### Friction-Based Deduction

The subagent's confusion and curiosity IS the scoring instrument. Any friction experienced while reading — hesitation, uncertainty, desire to verify, urge to push back, wanting clarification, needing a second thought, wishing for an example — is a quality signal.

Rule for the subagent:

> Any time you hesitate, feel uncertain, want to verify, want to push back, or wish you had more — that's friction. Log it, name which dimension it affects, and deduct accordingly.

This produces organic, reader-centric quality assessment. The report will ultimately be read by a human; the subagent is a proxy for that experience.

### Plateau Detection

- **Gain (Δ):** This cycle's total score minus last cycle's total score for that topic.
- **Streak:** Consecutive cycles with Δ ≤ 1.
- **CONCLUDED:** When streak reaches 2.

## Progress.md Scoreboard

Evolves from a simple checklist to a live scoreboard:

```markdown
# Research Progress

## Current Phase: Phase 6 — Critique & Expand (Cycle 3)

## Topic Scoreboard
| Topic | Status | Src | Depth | Action | Cohere | Confid | Total | Δ | Streak |
|-------|--------|-----|-------|--------|--------|--------|-------|---|--------|
| oauth-flows | ACTIVE | 7 | 6 | 5 | 8 | 6 | 32 | +4 | 0 |
| session-mgmt | CONCLUDED | 8 | 8 | 7 | 9 | 8 | 40 | 0 | 2 |
| token-storage | ACTIVE | 4 | 3 | 3 | 5 | 4 | 19 | +6 | 0 |

## Phase Checklist
- [x] Phase 1-5: Initial Research
- [ ] Phase 6: Critique & Expand (cycle 3 in progress)

## Cycle Log
### Cycle 1
- Topics scored: 5
- New topics added: 2 (oauth-flows, token-storage)
- Topics concluded: 1 (auth-overview)

### Cycle 2
...
```

## PoC / Exploration

Research isn't only reading. When a topic would benefit from *making something* — you should definitely do it. This includes:

- Building a prototype or proof-of-concept script
- Drafting an architecture or system design
- Sketching a visual mockup, diagram, or flowchart
- Writing a plan that stress-tests an idea by trying to build it

Create a folder in `workspace/poc/` and treat it as a topic in progress.md. Scored the same way — did it clarify understanding? Did it surface new questions? The medium doesn't matter. What matters is whether making the thing taught you something that reading couldn't.

## Max-Iterations Calculation

The research-probe skill calculates max-iterations when generating the ralph-loop command:

```
max-iterations = number_of_initial_topics + 15
```

The initial 5 phases consume iterations proportional to topic count. The `+ 15` guarantees at least 15 iterations for the critique-expand loop. Users can override this.

## Workspace Evolution

The agent self-organizes its workspace. The template gives initial structure and permission to restructure:

- Topics can spawn new topics → new files in `topics/`, new findings in `findings/`, new rows in progress.md scoreboard
- PoC work lives in `workspace/poc/` with agent-organized subfolders
- All new topics go through deduplication before being added
- The agent decides when to split, reorganize, or create new files

## Files Changed

1. **`plugins/offline-research/templates/prompt.md`** — Add Phase 6 entry point with hard gate to read `critique-loop.md`. Add PoC hint. Update workspace structure diagram.
2. **`plugins/offline-research/templates/progress.md`** — Replace simple checklist with scoreboard format.
3. **`plugins/offline-research/templates/critique-loop.md`** — NEW. Loop mechanics, subagent spawn protocol, topic lifecycle, workspace evolution rules.
4. **`plugins/offline-research/templates/scoring-rubric.md`** — NEW. Scoring dimensions, friction-based deduction rules, plateau detection. Read by both Opus agent and Sonnet subagents.
5. **`plugins/offline-research/skills/research-probe/SKILL.md`** — Update Phase 5 (Generate) to write 4 template files instead of 2. Update max-iterations formula to `topics + 15`.

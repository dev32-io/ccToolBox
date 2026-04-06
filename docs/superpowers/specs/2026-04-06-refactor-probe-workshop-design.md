# refactor-probe + Workshop Container Consolidation

**Status**: Draft  
**Date**: 2026-04-06  
**Plugin**: offline-research  

## Overview

Two changes in one spec:

1. **New skill**: `refactor-probe` — a tech debt and codebase refactoring probe adapted from the work-environment version. Faithfully preserves the rubric co-design flow (the gold feature) while swapping the local bash runner for container-based execution.

2. **Container consolidation**: Merge `containers/offline-research/` and `containers/arch-tool/` into a single `containers/workshop/` directory with per-tool Dockerfiles and runner scripts. All three probes (research, arch-forge, refactor) share this unified container infrastructure.

Additionally, backport the subagent rate-limit detection fix from the source `run-refactor-probe.sh` into all runner scripts.

## Problem

The source refactor-probe was built under enterprise constraints (no Docker, no permission bypass). It uses a local bash runner that disables `.claude/skills/` by renaming directories — a hack that works but is fragile. The ccToolBox container approach provides proper isolation without filesystem surgery.

Meanwhile, having two separate container directories (`offline-research/` and `arch-tool/`) with nearly identical `launch.sh` and runner scripts creates maintenance burden. A unified `workshop` container with per-profile Dockerfiles consolidates this.

## Skill Flow

```
User arrives with codebase concerns (tech debt, migration, refactoring)
         |
[Phase 1: Intake] — scan codebase, extract topics/intents
         |
[Phase 2: Quick Survey] — 2-5 web searches on topics
         |
[Phase 3: Critical Assessment + Refinement] — present findings,
    iterate with user (one question at a time)
         |
[Phase 4: Rubric Co-Design] — probe user concerns, propose 2-3
    custom rubric sets, user picks/mixes dimensions
         |
[Phase 5: Generate] — fill 4 templates, write seed files,
    present run command
         |
[Container Loop] — agent explores freely:
    scan → survey → explore → synthesize → score → expand
         |
[User Returns] — reviews synthesis.md, risks.md, connections.md
    with scored explorations and PoC references
```

### Phase 1: Intake

Extract topics and intents from freeform user input. Scan codebase with Glob, Grep, Read to understand:
- Directory structure and module boundaries
- Key patterns and conventions
- Specific code areas referenced by user
- Scale indicators (file counts, line counts, dependency counts)

### Phase 2: Quick Survey

2-5 fast web searches across user's topics. Understand landscape, migration paths, known patterns, pitfalls. Silent — no narration between tool calls.

### Phase 3: Critical Assessment + Refinement

Assessment message with:
- Topic breakdown with real code references
- What the survey revealed (existing patterns, risks, complexity)
- Suggested additions to strengthen experiment

Then iterative refinement — one question per message, always decompose (more specific = better), ground suggestions in actual codebase observations.

### Phase 4: Rubric Co-Design (Gold Feature)

This is what makes refactor-probe distinct from its siblings. Preserved exactly from source.

**4a. Probe Concerns** — 2-3 feeling/vibe questions:
- "What would make you confident this refactoring is worth pursuing?"
- "What's your biggest fear?"
- "When you say 'clean', what does that feel like?"
- "If this goes wrong, what does wrong look like?"

**4b. Propose 2-3 Rubric Sets** — each set has 3-7 dimensions with:
- 0/5/10 anchor descriptions per dimension
- Pros/cons of each set
- Per-dimension reasoning
- Dimension hint tags:
  - **BUILD**: needs proof, not more research. When < 6: spawn PoC tasks
  - **INVESTIGATE**: needs more information. When < 6: spawn research tasks
  - **RETHINK**: current approach may be wrong. When < 6: decompose/explore alternatives
  - **REFOCUS**: alignment brake. When < 6: re-read goals, prune drift. OVERRIDES ALL

**4c. Refine** — user picks set or mixes dimensions, back-and-forth

**4d. Confirm** — present final rubric for sign-off

### Phase 5: Generate Seed Files

Output location: default `.refactor-probe/YYYY-MM-DD-short-title/`

Read templates from `<plugin-root>/templates/refactor-probe/`, fill placeholders:
- `[TITLE]` → experiment title
- `[PROBE_DIR]` → output directory
- `[CODEBASE_CONTEXT]` → structure summary, key files, patterns
- `[GOALS]` → refined goals from Phase 3
- `[TOPICS]` → formatted topic list with sub-topics
- `[DIMENSION_HEADERS]` → abbreviated names (e.g., `MigSafe | BackCompat`)
- `[TOPIC_SCOREBOARD]` → one row per topic
- `[TOPIC_EXPLORATION]` → checklist of exploration tasks
- `[TOPIC_SCORING]` → checklist of scoring tasks
- `[DIMENSION_HINTS]` → per-dimension expansion rules
- `[DIMENSIONS]`, `[DIMENSION_COUNT]`, `[MAX_SCORE]`, `[SCORE_FORMAT]` → rubric template placeholders

Calculate max-iterations: `topics × 10 + 15`

Present run command:
```bash
./containers/workshop/launch.sh run --container=refactor <host-path> <max-iter>
```

## Scoring Model

User-designed custom rubric with 3-7 dimensions, each 0-10. Scored by isolated Sonnet subagent that receives ONLY the rubric + goals + topic exploration output + PoC results.

Isolation is the point — if the subagent can't evaluate without extra context, the exploration isn't thorough enough.

### Friction-Based Deduction

Same philosophy as siblings: the evaluator's urges to verify, ask "but what if?", or see more evidence are deduction signals themselves.

### Scorer Output Format

```
## Scores
- DimensionName: N/10
...
- **Total: N/MAX**

## Friction Log
- [dimension]: "description of friction"

## What's Missing
- gap or unknown

## What's Strong
- what works well
```

## Expansion Logic

Dimension-aware expansion driven by hint tags. After scoring:

1. Spawn Sonnet subagent with ONLY rubric + goals + exploration + PoC output
2. Record scores in progress.md, compute Δ (this score - last score)
3. Check weakest dimensions, apply hint tags:
   - **REFOCUS** < 6 → overrides all. Re-read goals, prune drift.
   - **BUILD** < 6 → spawn PoC task
   - **INVESTIGATE** < 6 → spawn research task
   - **RETHINK** < 6 → decompose/explore alternatives

### Delta Rules

- Δ > 3 (gaining): apply dimension expansion + if < 2 approaches explored, add alternative
- Δ ≤ 3, streak 0: add one more improvement task, streak → 1
- Δ ≤ 3, streak ≥ 1: if ≥ 2 approaches explored → CONCLUDED; else add alternative first

New tasks are appended before the final Synthesize step, never inserted in the middle.

## PoC Rules

- Build isolated sketch projects in `/workspace/poc/<name>/`
- MUST replicate the actual problem at small scale first
- DO NOT modify the real codebase (it's mounted read-only or not mounted at all)
- Scoring evaluates **transferability** (would this work in the real codebase?), not integration
- All PoC code runs via `sudo -u poc` (same sandbox as arch-forge)

## Workspace Structure

```
/workspace/<project>/
├── prompt.md                # seed prompt (read-only reference)
├── progress.md              # scoreboard + task queue (live state)
├── expansion-loop.md        # scoring + expansion protocol
├── scoring-rubric.md        # user-designed custom rubric
├── explorations/            # research + analysis per topic
│   ├── topic-name.md
│   └── ...
├── poc/                     # isolated sketch projects (poc user)
│   ├── poc-name/
│   └── ...
├── synthesis.md             # cross-cutting patterns and findings
├── risks.md                 # cross-cutting risks + mitigations
├── connections.md           # cross-topic dependencies
└── sources.md               # running bibliography
```

---

## Workshop Container Consolidation

### New Directory Structure

```
containers/workshop/
├── dockerfiles/
│   ├── research.Dockerfile      # lightweight — node, git, gh, basic tools
│   ├── arch.Dockerfile          # heavy — adds Bun, Rust, Go, Playwright, poc sandbox
│   └── refactor.Dockerfile      # same as arch (PoC runtimes needed)
├── entrypoint.sh                # poc sandbox setup (used by arch + refactor)
├── entrypoint-light.sh          # passthrough (used by research)
├── launch.sh                    # unified orchestrator with --container flag
├── run-research.sh              # research-probe runner
├── run-arch-forge.sh            # arch-forge runner (renamed from run-arch.sh)
├── run-refactor.sh              # refactor-probe runner (new)
├── .env.example
└── testing/
```

Old directories `containers/offline-research/` and `containers/arch-tool/` are removed.

### launch.sh Interface

```bash
# --container is required
./launch.sh setup   --container=research|arch|refactor
./launch.sh run     --container=research|arch|refactor <topic-path> [max-iter]
./launch.sh shell   --container=research|arch|refactor
./launch.sh help
```

Routing logic:
- `--container=research` → `dockerfiles/research.Dockerfile`, `entrypoint-light.sh`, `run-research.sh`
- `--container=arch` → `dockerfiles/arch.Dockerfile`, `entrypoint.sh`, `run-arch-forge.sh`
- `--container=refactor` → `dockerfiles/refactor.Dockerfile`, `entrypoint.sh`, `run-refactor.sh`

Each profile gets its own image name (`workshop-research`, `workshop-arch`, `workshop-refactor`) and container name (`workshop-research-sandbox`, `workshop-arch-sandbox`, `workshop-refactor-sandbox`).

### Dockerfile Notes

`refactor.Dockerfile` starts as a copy of `arch.Dockerfile` — same PoC runtimes and `poc` user sandbox. They may diverge over time (refactor might need different tools), hence separate files rather than a shared one.

`research.Dockerfile` is the lightweight variant — no PoC runtimes, no `poc` user, no resource limits.

### Entrypoint Split

- `entrypoint.sh` — runs as root, sets workspace permissions, restricts `.claude/` to 700, creates `/workspace/poc/` owned by `poc`, drops to `node` via `gosu`. Used by arch + refactor profiles.
- `entrypoint-light.sh` — simple passthrough, passes args to `claude --dangerously-skip-permissions` or falls through to `tail`/`bash`/`sh`. Used by research profile.

---

## Rate Limit Detection Fix

### Problem

When the lead agent spawns a subagent (e.g., the Sonnet scoring subagent) and the subagent hits a rate limit, the error may surface with a different string than the literal `rate_limit` the wrapper greps for. This breaks the resume flow — the runner doesn't detect the limit, doesn't pause, and the next iteration fails or produces garbage.

### Fix

Backport the broad pattern matching from the source `run-refactor-probe.sh` into all three runner scripts:

```bash
check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    # Catches subagent limit errors that surface with different messages
    grep -qiE 'rate.?limit|too many requests|429|quota exceeded|capacity|overloaded|resource_exhausted' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}
```

Applied to: `run-research.sh`, `run-arch-forge.sh`, `run-refactor.sh`.

---

## Sibling Skill Updates

### arch-forge SKILL.md

Update run command:
```
# Before
./containers/arch-tool/launch.sh run <host-path> <max-iter>

# After
./containers/workshop/launch.sh run --container=arch <host-path> <max-iter>
```

### research-probe SKILL.md

Update run command:
```
# Before
./containers/offline-research/launch.sh run <host-path> <max-iter>

# After
./containers/workshop/launch.sh run --container=research <host-path> <max-iter>
```

---

## Manifest Updates

### plugin.json

Bump version in `plugins/offline-research/.claude-plugin/plugin.json` (e.g., 2.3.2 → 2.4.0).

### marketplace.json

Bump version in `.claude-plugin/marketplace.json` to match.

---

## File Changes Summary

### New Files
- `plugins/offline-research/skills/refactor-probe/SKILL.md`
- `plugins/offline-research/templates/refactor-probe/prompt.md`
- `plugins/offline-research/templates/refactor-probe/progress.md`
- `plugins/offline-research/templates/refactor-probe/expansion-loop.md`
- `plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md`
- `containers/workshop/dockerfiles/research.Dockerfile`
- `containers/workshop/dockerfiles/arch.Dockerfile`
- `containers/workshop/dockerfiles/refactor.Dockerfile`
- `containers/workshop/launch.sh`
- `containers/workshop/run-research.sh`
- `containers/workshop/run-arch-forge.sh`
- `containers/workshop/run-refactor.sh`
- `containers/workshop/entrypoint.sh`
- `containers/workshop/entrypoint-light.sh`
- `containers/workshop/.env.example`

### Modified Files
- `plugins/offline-research/skills/arch-forge/SKILL.md` — update run command
- `plugins/offline-research/skills/research-probe/SKILL.md` — update run command
- `plugins/offline-research/.claude-plugin/plugin.json` — version bump
- `.claude-plugin/marketplace.json` — version bump

### Deleted Files
- `containers/offline-research/` (entire directory)
- `containers/arch-tool/` (entire directory)

## Max Iterations Formula

```
topics × 10 + 15
```

Same multiplier as arch-forge. Higher than research-probe (×8 + 10) because refactor exploration spawns PoCs, alternative approaches, and decomposition tasks.

## Verification

1. **Skill intake**: Run refactor-probe with a test concern (e.g., "migrate from Express to Hono"). Verify codebase scanning, topic extraction, and survey work.
2. **Rubric co-design**: Walk through Phase 4. Verify probing questions, 2-3 rubric sets proposed with hint tags, user can pick/mix dimensions.
3. **Template generation**: Verify 4 seed files generated with correct placeholders filled, including custom dimension headers and hint tags.
4. **Workshop container build**: `./launch.sh setup --container=refactor` builds successfully. Verify `poc` user exists, `.claude/` is restricted.
5. **Workshop container routing**: All three `--container` values build the correct Dockerfile and use the correct entrypoint/runner.
6. **PoC isolation**: Inside refactor container, verify `poc` user cannot read `/home/node/.claude/`.
7. **Rate limit detection**: Simulate a subagent rate limit (429 in output). Verify all three runners detect and pause.
8. **Scoring**: Run a single score task. Verify Sonnet subagent produces correct output format with custom dimensions.
9. **Dimension expansion**: After a low BUILD dimension score, verify PoC task is spawned. After low REFOCUS, verify brake is applied.
10. **Sibling skills**: Verify research-probe and arch-forge still work with updated run commands pointing to workshop.
11. **Old containers removed**: Verify `containers/offline-research/` and `containers/arch-tool/` are gone with no dangling references.

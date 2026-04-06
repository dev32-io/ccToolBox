# Offline Research

Structured offline research and architecture exploration using container-based Claude Code loops.

**Version:** 2.4.0

## Skills

### /research-probe

Guides freeform research intent into structured seed files for the offline research container loop.

**Trigger:** `/research-probe`, "start an offline research on...", "offline research on...", "launch a research probe on..."

**Flow:**

1. Dump your research idea (freeform text)
2. Skill surveys the landscape and presents an organized breakdown
3. Guided refinement -- 3-5 questions to sharpen scope and priorities
4. Generates 4 seed files (`prompt.md`, `progress.md`, `critique-loop.md`, `scoring-rubric.md`) to your chosen directory
5. Gives you the run command for the research container

**How the loop works:**

The agent follows a checklist in `progress.md`, processing one item per iteration:

1. **Research** each topic -- deep dive with sources
2. **Critique & Score** each topic via isolated Sonnet subagent (0-50 across 5 dimensions)
3. **Improve** based on scorer feedback, spawn sub-topics as needed
4. **Repeat** until plateau -- a topic is CONCLUDED when delta <= 3 for 2 consecutive scores

The loop ends when all topics plateau or max-iterations is reached.

**Max iterations:** `topics * 8 + 10`

```
Per topic (multiplier 8):
- Research → Score → Improve → Re-score = 4 (base)
- First plateau (streak 0) triggers one more improve cycle = +2
- Minimum 2 approaches rule may force an alternative = +2

Headroom (+10):
- Decompose, Survey, and Synthesize steps that run once regardless of topic count
- Buffer for the model to explore spawned sub-topics when needed

Exits early when all topics plateau.
```

---

### /arch-forge

Refines a sketch architecture through the offline container loop with PoC validation.

**Trigger:** `/arch-forge`, "forge this architecture", "expand this architecture", "refine this architecture"

**Flow:**

1. Intake -- extract decisions, constraints, and components from the sketch
2. Quick survey -- web searches to ground decisions in current ecosystem
3. Refinement -- 3-5 questions to clarify constraints and priorities
4. Generates 4 seed files (`prompt.md`, `progress.md`, `expansion-loop.md`, `scoring-rubric.md`) to your chosen directory
5. Gives you the run command for the arch-tool container

**How it differs from research-probe:**

- Spawns PoCs to validate architectural decisions
- Explores alternatives per decision area (minimum 2 approaches before concluding)
- Uses dimension-aware expansion based on weakest scoring dimension:
  - Feasibility < 6 -- build a PoC
  - Maintainability < 6 -- decompose into sub-decisions
  - Risk < 6 -- investigate failure modes
  - Effort < 6 -- find a simpler alternative
  - Alignment < 6 -- refocus on project intent

**Max iterations:** `decisions * 10 + 15`

```
Per decision (multiplier 10):
- Explore → Score → PoC → Re-score → Alternative → Score = 6 (base)
- Dimension-aware expansion may add Decompose/Investigate tasks = +2
- Plateau improvement cycles before concluding = +2

Headroom (+15):
- Decompose, Survey, and multiple Synthesize steps
- Larger buffer than research-probe — PoC builds and sub-decision spawning need room

Exits early when all decisions converge.
```

---

### /refactor-probe

Explores codebase tech debt and refactoring ideas through collaborative rubric co-design and autonomous loop exploration with PoC building.

**Trigger:** `/refactor-probe`, "refactor-probe this codebase", "launch a refactor probe"

**Flow:**

1. Dump your refactoring idea (freeform text)
2. Skill scans the codebase and surveys the landscape
3. Critical assessment with real code references, then guided refinement
4. Rubric co-design — you define 3-7 custom scoring dimensions with expansion hint tags
5. Generates 4 seed files (`prompt.md`, `progress.md`, `expansion-loop.md`, `scoring-rubric.md`) to your chosen directory
6. Gives you the run command for the workshop container

**How it differs from siblings:**

- User-designed custom rubric (3-7 dimensions with custom anchors)
- Dimension hint tags drive expansion: BUILD, INVESTIGATE, RETHINK, REFOCUS
- Codebase-aware — scans real code during intake and grounds suggestions in actual patterns
- PoCs replicate the real problem at small scale in isolated sketch projects

**Max iterations:** `topics * 10 + 15`

```Per topic (multiplier 10):
- Explore → Score → PoC → Re-score → Alternative → Score = 6 (base)
- Dimension-aware expansion may add PoC/Investigate/Rethink tasks = +2
- Plateau improvement cycles before concluding = +2

Headroom (+15):
- Scan, Survey, and multiple Synthesize steps
- Larger buffer — PoC builds and topic spawning need room

Exits early when all topics plateau.
```

## Containers

All skills share the unified workshop container:

| Skill | Profile | Purpose |
|-------|---------|---------|
| /research-probe | `--container=research` | Web research and analysis |
| /arch-forge | `--container=arch` | Architecture exploration with PoC sandbox |
| /refactor-probe | `--container=refactor` | Codebase refactoring with PoC sandbox |

See [containers/workshop/](../../containers/workshop/) for setup and configuration.

## Prerequisites

- Docker
- Claude Code with ccToolBox marketplace
- ralph-loop plugin (installed inside the container)

## Setup

```bash
claude plugins install offline-research@ccToolBox
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

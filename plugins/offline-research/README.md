# Offline Research

Structured offline research and architecture exploration using container-based Claude Code loops.

**Version:** 2.3.2

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

## Containers

Each skill has a dedicated container:

| Skill | Container | Purpose |
|-------|-----------|---------|
| /research-probe | `containers/offline-research/` | Web research and analysis |
| /arch-forge | `containers/arch-tool/` | Architecture exploration with PoC sandbox |

See [containers/README.md](../../containers/README.md) for setup and configuration.

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

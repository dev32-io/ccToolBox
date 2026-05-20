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

For container architecture, structured I/O contract, plateau math, and dimension-aware expansion, see [`docs/architecture.md`](docs/architecture.md).

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

---

See [CHANGELOG.md](CHANGELOG.md) for version history.

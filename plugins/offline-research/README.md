# Offline Research

Structured offline research with self-critical scoring loop.

## Skills

### /research-probe

Guides you from freeform research intent to a structured prompt ready for ralph-loop execution. Helps you think through topics, decompose them, and identify gaps before committing to a long research session.

**Invoke:** `/research-probe` or "start an offline research on..."

**Flow:**
1. Dump your research idea (freeform text)
2. Skill surveys the landscape and presents an organized breakdown
3. Guided refinement — questions, pushback, decomposition
4. Generates 4 files (`prompt.md`, `progress.md`, `critique-loop.md`, `scoring-rubric.md`) to your chosen directory
5. Gives you the ralph-loop command to run in the research container

### How the research loop works

The agent follows a checklist in `progress.md` — one item per iteration:

1. **Research** each topic (one at a time, deep dive with sources)
2. **Critique & Score** each topic via isolated Sonnet subagent (0-50 scale across 5 dimensions)
3. **Improve** topics based on scorer feedback, spawn new sub-topics
4. **Repeat** — score → improve → score cycle continues per topic until plateau

Topics that stop improving (Δ ≤ 3 for 2 consecutive scores) are marked CONCLUDED. The loop ends when all topics plateau or max-iterations is reached.

## Requirements

- ralph-loop plugin (installed in research container)
- Research container from `containers/offline-research/`

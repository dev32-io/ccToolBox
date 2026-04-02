# Offline Research

Tools for structured offline research using ralph-loop.

## Skills

### /research-probe

Guides you from freeform research intent to a structured prompt ready for ralph-loop execution. Helps you think through topics, decompose them, and identify gaps before committing to a long research session.

**Invoke:** `/research-probe` or "start an offline research on..."

**Flow:**
1. Dump your research idea (freeform text)
2. Skill surveys the landscape and presents an organized breakdown
3. Guided refinement — questions, pushback, decomposition
4. Generates `prompt.md` + `progress.md` to your chosen directory
5. Gives you the ralph-loop command to run in the research container

## Requirements

- ralph-loop plugin (installed in research container)
- Research container from `containers/offline-research/`

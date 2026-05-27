---
name: arch-forge
description: >
  Refine a sketch architecture through the offline container loop.
  Use when the user says "forge this architecture", "expand this architecture",
  "refine this architecture", "arch-forge", or invokes /arch-forge.
  The user arrives with a sketch plan/architecture/stack and wants the container
  loop to explore decisions, build PoCs, and score alternatives.
  Do NOT trigger on: general architecture questions, code reviews,
  "brainstorm", "plan this", "implement this".
allowed-tools: WebSearch, WebFetch, Bash, Write, Read, Glob
---

# Architecture Forge

Guide the user from a sketch architecture to structured seed files ready for container loop execution.

## Tone

You're a senior architect collaborating with the user. Be direct — short sentences, concrete observations. When you spot something interesting or risky in the sketch, say so: "the STT integration is the riskiest piece here — worth exploring first." Push back as options, not blocks.

## Flow

On skill start, create tasks for each phase using TaskCreate:
1. "Intake — extract decisions" (activeForm: "Extracting decisions")
2. "Quick survey — scan the landscape" (activeForm: "Surveying the landscape")
3. "Refinement — iterate with user" (activeForm: "Refining architecture")
4. "Generate — write seed files" (activeForm: "Generating seed files")

Mark each task `in_progress` when starting it, `completed` when done. Keep internal work (searches, reads, writes) quiet — no narration between tool calls within a phase.

### Step 1: Intake

The user has provided a sketch architecture. Read it carefully. Extract:

- **Project intent** — one paragraph describing what they're building and why
- **Constraints** — hard boundaries (home network, single person, budget, etc.)
- **Architecture components** — the building blocks mentioned
- **Implicit decisions** — open questions embedded in the sketch (runtime choice, protocol choice, storage choice, etc.)

Present back to the user:

1. **Project intent** — your one-paragraph summary (user confirms or corrects)
2. **Constraints** — extracted list
3. **Decision areas** — organized list of decisions to explore, each with a short description of what's unclear
4. **First question** — one multiple-choice question to start refining

### Step 2: Quick Survey

Do 2-5 fast web searches across the key decision areas. Just enough to:
- Flag known gotchas for proposed components
- Spot existing solutions that match the sketch
- Identify early infeasibility

Do not narrate each search — just do them silently.

Present findings briefly: what's interesting, what exists, what looks risky.

### Step 3: Refinement

Iterate with the user. Each message:
- Refine decision areas based on their response
- Suggest decisions the user didn't think of ("you haven't mentioned auth — in scope?")
- Probe constraints ("single machine or willing to use a second box?")
- Push back where warranted — as options with rationale
- Ask one follow-up question with multiple choice + open input

Continue for 3-5 questions until scope feels right.

### Step 4: Generate

Ask the user if they'd like you to write the seed files now, or make further adjustments.

Once confirmed, ask the user (and **wait for their response before proceeding**):

> Where should I write the seed files?
> 1. `<cwd>/<short-title>/`  (Recommended)
> 2. `~/offline-research/<short-title>/`
> 3. Type a custom path

Get the current date via `date +%Y-%m-%d`. Determine git root via `git rev-parse --show-toplevel 2>/dev/null`. CWD = `$(pwd)` from a Bash invocation. Derive `<short-title>` as a kebab-case slug from the mission.

Determine the plugin root (two directories up from this skill file) to find templates.

**Read templates:**
- Read `<plugin-root>/templates/arch-forge/mission.md`
- Read `<plugin-root>/templates/arch-forge/progress.md`
- Read `<plugin-root>/templates/arch-forge/scoring-rubric.md`

**Fill mission.md:**
- Replace `[PROJECT_NAME]` with the project name
- Replace `[PROJECT_INTENT]` with the confirmed project intent paragraph
- Replace `[CONSTRAINTS]` with the confirmed constraints list
- Replace `[ARCHITECTURE_SKETCH]` with the user's original sketch (cleaned up)

**Write topics/ files:** For each decision area, write `<probe-dir>/topics/NN-<decision>.md`. Content:

```
# <Decision Name>

## Alternatives to consider
- <option>
- <option>

## What's unclear
- <question>
- <question>

## Hard constraints
- <constraint from mission>
```

**Fill progress.md:**
- Replace `[MAX_ITER]` in the header with: `decisions × 10 + 15`
- Replace `[DECISION_SCOREBOARD]` (unchanged from v1)
- Replace `[DECISION_EXPLORATION]` (unchanged)
- Replace `[DECISION_SCORING]` (unchanged)

**Write `scoring-rubric.md`** unchanged (no placeholders to fill).

**Write all files** to the user's chosen directory using the Write tool.

**Present two run options:**

Derive `<folder-name>` from the last path segment of the user's chosen directory.

> **How do you want to run this architecture exploration?**
> 1. `/workshop-loop` in the current Claude Code session (Recommended)
> 2. `/workshop-loop` inside a sandboxed container (if PoC code execution will be material)

After the user picks, print only the selected command:

- **Option 1**:
  ```
  /workshop-loop <probe-dir>
  ```

- **Option 2**:
  ```
  ./containers/workshop/launch.sh build --container=arch
  ./containers/workshop/launch.sh shell --container=arch <probe-dir>
  # inside container shell:
  claude
  # in Claude Code:
  /workshop-loop /workspace
  ```

Replace `<probe-dir>` with the user's chosen directory (absolute path).

Then ask:

> Copy to clipboard? (y/n)

If yes, copy the selected command to clipboard via `printf '%s' '<command>' | pbcopy`.

Design rationale: [`../../docs/architecture.md`](../../docs/architecture.md)

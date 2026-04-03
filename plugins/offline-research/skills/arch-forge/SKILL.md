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
tools: WebSearch, WebFetch, Bash, Write, Read, Glob
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

Once confirmed, ask where to write them:

> Where should I write the seed files?
> 1. `~/offline-research/YYYY-MM-DD-short-title/`
> 2. `<git-root>/offline-research/YYYY-MM-DD-short-title/` (or `./YYYY-MM-DD-short-title/` if not in a git repo)
> 3. Type a custom path

Get the current date via `date +%Y-%m-%d`. Determine git root via `git rev-parse --show-toplevel 2>/dev/null`.

Determine the plugin root (two directories up from this skill file) to find templates.

**Read templates:**
- Read `<plugin-root>/templates/arch-forge/prompt.md`
- Read `<plugin-root>/templates/arch-forge/progress.md`
- Read `<plugin-root>/templates/arch-forge/expansion-loop.md`
- Read `<plugin-root>/templates/arch-forge/scoring-rubric.md`

**Fill prompt.md:**
- Replace `[PROJECT_NAME]` with the project name
- Replace `[PROJECT_INTENT]` with the confirmed project intent paragraph
- Replace `[CONSTRAINTS]` with the confirmed constraints list
- Replace `[ARCHITECTURE_SKETCH]` with the user's original sketch (cleaned up)
- Replace `[DECISIONS]` with the refined decision list, each formatted as:
  ```
  ### N. Decision Area Name (`decision-area-name.md`)
  - what's unclear or needs exploration
  - specific alternatives to consider
  - ...
  ```

**Fill progress.md:**
- Replace `[DECISION_SCOREBOARD]` with one row per decision:
  ```
  | decision-area-name | ACTIVE | - | - | - | - | - | - | - | 0 | 0 |
  ```
- Replace `[DECISION_EXPLORATION]` with one line per decision:
  ```
  - [ ] Explore: decision-area-name
  ```
- Replace `[DECISION_SCORING]` with one line per decision:
  ```
  - [ ] Score: decision-area-name
  ```

**Write `expansion-loop.md` and `scoring-rubric.md`** unchanged (no placeholders to fill).

**Write all four files** to the user's chosen directory using the Write tool.

**Calculate max-iterations:** `decisions × 10 + 15`. Higher multiplier than research-probe because architecture exploration spawns PoCs, alternative explorations, risk investigations, and decomposition tasks. Example: 6 decisions → `--max-iterations 75`.

**Present three run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory.

> **How do you want to run this architecture exploration?**
> 1. In the arch-tool container with auto-resume (Recommended)
> 2. In the arch-tool container (manual)
> 3. Locally

After the user picks, print only the selected command:

- **Auto-resume command** (option 1):
  ```
  ./containers/arch-tool/launch.sh run /workspace/<folder-name> <DECISION_COUNT * 10 + 15>
  ```

- **Manual container command** (option 2):
  ```
  /ralph-loop:ralph-loop "Read /workspace/<folder-name>/prompt.md for context. Read /workspace/<folder-name>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <DECISION_COUNT * 10 + 15> --completion-promise "TASK DONE"
  ```

- **Local command** (option 3):
  ```
  /ralph-loop:ralph-loop "Read <local-path>/prompt.md for context. Read <local-path>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <DECISION_COUNT * 10 + 15> --completion-promise "TASK DONE"
  ```

Replace `<folder-name>` and `<local-path>` with actual values.

Then ask:

> Copy to clipboard? (y/n)

If yes, copy the selected command to clipboard via `printf '%s' '<command>' | pbcopy`.

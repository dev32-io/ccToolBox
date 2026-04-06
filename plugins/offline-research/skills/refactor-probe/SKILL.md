---
name: refactor-probe
description: >
  Explore codebase tech debt and refactoring ideas through structured experimentation.
  Use when the user says "refactor-probe this codebase", "launch a refactor probe",
  or invokes /refactor-probe.
  Do NOT trigger on: "refactor this", "fix this tech debt", "clean up this code",
  "improve this", "optimize this" (those are direct action requests).
allowed-tools: WebSearch, WebFetch, Bash, Write, Read, Glob, Grep
---

# Refactor Probe

Guide freeform tech debt and refactoring ideas through collaborative refinement, custom scoring rubric co-design, and autonomous loop exploration with PoC building.

## Tone

You are a senior engineer pairing on tech debt. Be direct about what you see in the code — reference specific files, patterns, and line counts. When probing for rubric dimensions, use questions that draw out the user's real concerns, not abstract frameworks: "what would make you confident this is worth doing?" not "what quality dimensions matter?". Short sentences, concrete observations. Push back as options, not blocks.

## Flow

On skill start, create tasks for each phase using TaskCreate:
1. "Intake — scan codebase and extract topics" (activeForm: "Scanning codebase")
2. "Quick survey — landscape + codebase patterns" (activeForm: "Surveying landscape")
3. "Assessment + refinement — iterate with user" (activeForm: "Refining scope")
4. "Rubric co-design — build scoring dimensions" (activeForm: "Co-designing rubric")
5. "Generate — write seed files" (activeForm: "Generating seed files")

Mark each task `in_progress` when starting it, `completed` when done. Keep internal work quiet — no narration between tool calls within a phase. Only speak to the user when presenting results or asking questions.

### Step 1: Intake

The user has provided freeform text describing tech debt, refactoring ideas, or re-architecture goals. It may be messy — stream of consciousness, bullet points, half-formed ideas. Read it carefully. Extract all topics and intents.

Scan the codebase with Glob, Grep, and Read to understand:
- Directory structure and module boundaries
- Key patterns and conventions
- Areas of the codebase the user is referencing
- Scale indicators (file counts, line counts, dependency counts)

### Step 2: Quick Survey

Do 2-5 fast web searches across the user's topics to understand the landscape — migration paths, known patterns, prior art, common pitfalls. Explore the codebase more deeply grounded in what you find.

Silent — do not narrate each search or read. Just collect notes.

### Step 3: Critical Assessment + Refinement

Combined phase. Assessment flows naturally into refinement because codebase context makes the assessment richer.

**Assessment message:**

1. **Topic breakdown** — organized list of topics extracted from the user's input, with real code references (e.g., "your auth module at `src/auth/` uses the pattern you want to migrate — 14 files, 3 different session strategies")
2. **Your take** — what the survey revealed. What exists, what's risky, what's more complex than it looks. Reference specific files and patterns.
3. **Suggested additions** — topics the user didn't mention that would strengthen the experiment
4. **First question** — one multiple-choice question to start refining. Include options + "or tell me something else"

**Refinement loop:**

- One question per message
- Always decompose, never consolidate. More specific = better exploration.
- Push back as options with rationale, never blocks. User always has final say.
- Ground suggestions in actual codebase observations — "I see three different auth patterns in `src/` — worth treating each as a separate topic?"
- Continue until scope feels right

### Step 4: Rubric Co-Design

This is the centerpiece. The scoring rubric directly determines loop behavior through dimension-aware expansion. Take time here.

#### 4a. Probe Concerns

Ask 2-3 questions to understand what the user actually cares about. Not "what dimensions do you want?" but feeling/vibe questions that draw out real concerns:

- "What would make you confident this refactoring approach is worth pursuing?"
- "What's your biggest fear about this migration?"
- "When you say 'clean', what does that feel like in practice?"
- "If this goes wrong, what does wrong look like?"

Get the vibe. The answers shape the rubric.

#### 4b. Propose 2-3 Rubric Sets

Each set has 3-7 dimensions. For each set, present:

1. **Dimension list** — each dimension with 0/5/10 anchor descriptions:
   - **0**: what "not addressed" looks like
   - **5**: what "partially addressed" looks like
   - **10**: what "fully addressed" looks like

2. **Pros and cons** of this set

3. **Per-dimension reasoning** — why this dimension matters for *this* experiment

4. **Dimension hint tag** — which expansion behavior applies:
   - **BUILD**: needs proof, not more research. When < 6: spawn PoC tasks.
   - **INVESTIGATE**: needs more information. When < 6: spawn research tasks.
   - **RETHINK**: current approach may be wrong. When < 6: decompose or explore alternatives.
   - **REFOCUS**: alignment brake. When < 6: re-read goals, prune drift. Overrides all other tags.

5. **Recommended set** marked with reasoning

**Example rubric sets** (for a "migrate auth to OAuth2" experiment):

*Set A: Risk-focused (recommended — migration safety is paramount)*

| Dimension | Tag | 0 | 5 | 10 |
|-----------|-----|---|---|-----|
| Migration Safety | BUILD | No migration path identified | Path exists but untested, unclear ordering | Incremental migration demonstrated with rollout stages |
| Backwards Compatibility | INVESTIGATE | Existing clients/sessions will break | Some compatibility, gaps identified | Full compatibility plan with session migration strategy |
| Complexity Reduction | RETHINK | New approach adds complexity vs current | Neutral — different complexity, not less | Measurably simpler: fewer auth paths, less conditional logic |
| Test Coverage | BUILD | No tests for migration path | Unit tests for new auth, no integration | Full test harness: unit, integration, rollback verification |
| Rollback Viability | INVESTIGATE | No revert path | Manual rollback possible with data loss risk | Automated rollback tested, zero data loss |

- **Pros**: directly addresses migration risk (the thing most likely to go wrong)
- **Cons**: doesn't capture effort/timeline concerns
- **Why recommended**: the user's biggest fear is breaking existing auth — this set keeps that front and center

*Set B: Effort-focused*

| Dimension | Tag | 0 | 5 | 10 |
|-----------|-----|---|---|-----|
| Implementation Effort | INVESTIGATE | No estimate, unclear scope | Rough estimate with known unknowns | Detailed breakdown with time estimates per component |
| Incremental Delivery | BUILD | All-or-nothing migration | Some pieces can ship independently | Each component ships and provides value independently |
| Team Readability | RETHINK | New patterns unfamiliar to team | Some patterns familiar, docs needed | Follows existing team conventions, self-documenting |

- **Pros**: practical, answers "should we actually do this?"
- **Cons**: doesn't surface technical risk — you might estimate well and still break prod

#### 4c. Refine

User picks a set or mixes dimensions across sets. Back-and-forth until the rubric feels right:
- Adjust anchor descriptions
- Add or remove dimensions (stay within 3-7)
- Change hint tags if the user has different intuitions about what weak scores mean

#### 4d. Confirm

Present the final rubric with all dimensions, anchors, and hint tags. User signs off before proceeding to generation.

### Step 5: Generate

#### Output location

Get the current date via `date +%Y-%m-%d`. Derive a short kebab-case title from the experiment (e.g., `auth-migration`, `build-pipeline-cleanup`).

Ask:

> Where should I write the seed files?
> 1. `~/offline-research/YYYY-MM-DD-short-title/`
> 2. `<git-root>/offline-research/YYYY-MM-DD-short-title/` (or `./YYYY-MM-DD-short-title/` if not in a git repo)
> 3. Type a custom path

Get the current date via `date +%Y-%m-%d`. Determine git root via `git rev-parse --show-toplevel 2>/dev/null`.

#### Read templates

Determine the plugin root — two directories up from this skill file.

Read templates from `<plugin-root>/templates/refactor-probe/`:
- `prompt.md`
- `progress.md`
- `expansion-loop.md`
- `scoring-rubric-template.md`

#### Fill templates

**`prompt.md`** placeholders:
- `[TITLE]` -- experiment title
- `[PROBE_DIR]` -- the output directory path (e.g., `.refactor-probe/2026-04-06-auth-migration/`)
- `[CODEBASE_CONTEXT]` -- structure summary, key files, patterns observed during the survey
- `[GOALS]` -- refined goals from Phase 3
- `[TOPICS]` -- refined topic list with sub-topics, each formatted as:
  ```
  ### N. Topic Name (`topic-name.md`)
  - sub-topic or angle
  - sub-topic or angle
  - ...
  ```

**`progress.md`** placeholders:
- `[PROBE_DIR]` -- same output directory path as prompt.md
- `[DIMENSION_HEADERS]` -- abbreviated dimension names separated by ` | `, derived from the co-designed rubric (e.g., `MigSafe | BackCompat | Complex | TestCov | Rollback`)
- `[TOPIC_SCOREBOARD]` -- one row per topic:
  ```
  | topic-name | ACTIVE | - | - | ... | 0 | 0 | 0 |
  ```
  (one `-` per dimension, plus Total, Delta, Streak, Approaches columns)
- `[TOPIC_EXPLORATION]` -- one line per topic:
  ```
  - [ ] Explore: topic-name
  ```
- `[TOPIC_SCORING]` -- one line per topic:
  ```
  - [ ] Score: topic-name
  ```

**`expansion-loop.md`** placeholders:
- `[PROBE_DIR]` -- same output directory path as prompt.md
- `[DIMENSION_HINTS]` -- per-dimension expansion rules generated from the co-designed rubric. Format each dimension as:
  ```
  Dimension Name (TAG):
  +-- Add: <task-type>: <topic>-<specific> -- <description>
  \-- <fallback or alternative action>
  ```

  Example output:
  ```
  Migration Safety (BUILD):
  +-- Add: PoC: <topic>-incremental-migration -- build a sketch showing incremental cutover
  \-- If PoC exists, add: PoC: <topic>-alternative-migration -- try a different strategy

  Backwards Compatibility (INVESTIGATE):
  +-- Add: Investigate: <topic>-compat-risks -- find session/client breakage scenarios
  \-- Reference specific gaps from subagent's friction log

  Complexity Reduction (RETHINK):
  +-- Add: Rethink: <topic> -- is the new approach actually simpler? Consider alternatives
  \-- Add: Explore: <topic>-simpler -- look for a lighter approach

  Test Coverage (BUILD):
  +-- Add: PoC: <topic>-test-harness -- build a sketch test suite for the migration path
  \-- If PoC exists, add: PoC: <topic>-integration-test -- test at a different boundary

  Rollback Viability (INVESTIGATE):
  +-- Add: Investigate: <topic>-rollback-scenarios -- map failure modes and revert paths
  \-- Reference specific gaps from subagent's friction log
  ```

**`scoring-rubric-template.md`** -- generates `scoring-rubric.md`:
- `[DIMENSIONS]` -- full dimension table with 0/5/10 anchors from co-design
- `[DIMENSION_COUNT]` -- number of dimensions
- `[MAX_SCORE]` -- dimension count x 10
- `[SCORE_FORMAT]` -- one line per dimension:
  ```
  - <Dimension Name>: N/10
  ```

#### Write files

Write all files to the output directory:
- `prompt.md` (filled)
- `progress.md` (filled)
- `expansion-loop.md` (filled)
- `scoring-rubric.md` (generated from template)

#### Calculate max-iterations

`topics x 10 + 15`. PoC-heavy exploration needs room. Example: 5 topics -> `--max-iterations 65`.

**Present three run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory.

> **How do you want to run this refactor exploration?**
> 1. In the workshop container with auto-resume (Recommended)
> 2. In the workshop container (manual)
> 3. Locally

For container options (1 and 2), the container only sees `/workspace`. The user must copy their codebase into the output directory so the agent can read it. Include a `cp` command before the run command:

```
cp -r <codebase-path> <host-path>/codebase
```

Where `<codebase-path>` is the root of the target codebase. The prompt.md already tells the agent to read the codebase — this copy makes it available inside the container at `/workspace/codebase/`.

After the user picks, print only the selected command(s):

- **Auto-resume command** (option 1):
  ```
  cp -r <codebase-path> <host-path>/codebase
  ./containers/workshop/launch.sh run --container=refactor <host-path> <TOPIC_COUNT * 10 + 15>
  ```

- **Manual container command** (option 2):
  ```
  /ralph-loop:ralph-loop "Do NOT invoke any skills or use the Skill tool. Read /workspace/prompt.md for context. Read /workspace/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 10 + 15> --completion-promise "TASK DONE"
  ```

- **Local command** (option 3):
  ```
  /ralph-loop:ralph-loop "Do NOT invoke any skills or use the Skill tool. Read <local-path>/prompt.md for context. Read <local-path>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 10 + 15> --completion-promise "TASK DONE"
  ```

Replace `<host-path>` and `<local-path>` with the user's chosen directory path.

Then ask:

> Copy to clipboard? (y/n)

If yes, copy the selected command to clipboard via `printf '%s' '<command>' | pbcopy`.

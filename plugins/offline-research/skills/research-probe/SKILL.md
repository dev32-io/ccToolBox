---
name: research-probe
description: >
  Guide freeform research intent into a structured prompt for offline workshop-loop execution.
  Use when the user says "start an offline research on...", "offline research on...",
  "launch a research probe on...", or invokes /research-probe.
  Do NOT trigger on: "research this", "look into this", "find out about",
  "deep research", "do some research", "deep dive", "do a deep dive",
  "brainstorm", "investigate", "explore", "dig into",
  "what do you know about", "tell me about".
allowed-tools: WebSearch, WebFetch, Bash, Write, Read, Glob
---

# Research Probe

Guide the user from freeform research intent to a structured prompt ready for workshop-loop execution.

## Tone

Express genuine interest through specific observations from your survey. React naturally when something is surprising or interesting about the landscape. Use language that shows you are thinking alongside the user: "this could go a few directions...", "one angle I hadn't considered...". Write with warmth and directness — short sentences, conversational rhythm. When pushing back, frame as sharing what you found: "there's already a well-maintained tool for this part — worth knowing before spending research cycles on it."

## Flow

On skill start, create tasks for each phase using TaskCreate:
1. "Intake — extract topics" (activeForm: "Extracting topics")
2. "Quick survey — scan the landscape" (activeForm: "Surveying the landscape")
3. "Critical assessment — present findings" (activeForm: "Preparing assessment")
4. "Guided refinement — iterate with user" (activeForm: "Refining scope")
5. "Generate — write research files" (activeForm: "Generating research files")

Mark each task `in_progress` when starting it, `completed` when done. Keep internal work (searches, reads, writes) quiet — no narration between tool calls within a phase. Only speak to the user when presenting results or asking questions.

### Step 1: Intake

The user has provided freeform text describing what they want to research. Read it carefully — it may be messy, stream-of-consciousness, bullet points, or well-structured. Extract all topics and intents.

### Step 2: Quick Survey

Do fast web searches across the user's topics to understand the landscape. Use WebSearch. This is not deep research — just enough to form an informed opinion. Spend 2-5 searches total. Do not narrate each search — just do them and collect notes silently.

### Step 3: Critical Assessment

Present back to the user in a single message:

1. **Topic breakdown** — organized list of topics extracted from their input, with short descriptions
2. **Your take** — what the survey revealed. Share what's interesting. Flag where solutions already exist. Note what needs decomposition into smaller pieces.
3. **Suggested additions** — topics the user didn't mention that would strengthen the research
4. **First question** — one multiple-choice question to start refining. Include options + "or tell me something else"

### Step 4: Guided Refinement

Iterate with the user. Each message:
- Refine topics based on their response
- Break down further — always decompose, never consolidate. More specific = better research.
- For niche areas, probe the user's actual intent to find researchable angles
- Push back where warranted — as options with rationale, never blocks. User always has final say.
- Ask one follow-up question with multiple choice + open input

Continue until scope feels right.

### Step 5: Generate

Ask the user if they'd like you to write the research files now, or if they want to make further adjustments first.

Once confirmed, ask the user (and **wait for their response before proceeding**):

> Where should I write the research files?
> 1. `<cwd>/<short-title>/`  (Recommended — keeps probe co-located with the project that has the plugin installed)
> 2. `~/offline-research/<short-title>/`
> 3. Type a custom path

Get the current date via `date +%Y-%m-%d`. Determine git root via `git rev-parse --show-toplevel 2>/dev/null`. CWD = `$(pwd)` from a Bash invocation. Derive `<short-title>` as a kebab-case slug from the mission.

Determine the plugin root (two directories up from this skill file) to find templates.

**Read templates:**
- Read `<plugin-root>/templates/research-probe/mission.md`
- Read `<plugin-root>/templates/research-probe/progress.md`
- Read `<plugin-root>/templates/research-probe/scoring-rubric.md`

**Fill mission.md:**
- Replace `[TOPIC]` with the research mission title
- Replace `[INTENT]` with one paragraph describing what the user wants to learn and why
- Replace `[CONSTRAINTS]` with the user's hard boundaries (or "None specified" if none)

**Write topics/ files:** For each refined topic, write `<probe-dir>/topics/NN-<topic-slug>.md` (zero-padded ordinal for sort order + kebab `<topic-slug>` — example: `topics/01-vancouver-seasonal-calendar.md` has slug `vancouver-seasonal-calendar`). The `NN-` ordinal is ONLY for the topic file's filename — everywhere else (queue tasks, scoreboard, findings, scores) uses the bare slug. Content:

```
# <Topic Name>

## Sub-questions
- <question>
- <question>

## Why this matters
<one-line rationale>
```

**Fill progress.md:**

**CRITICAL — topic-slug convention.** The `topics/` directory uses `NN-<topic-slug>.md` filenames (e.g. `01-vancouver-seasonal-calendar.md`) for sort order. EVERYWHERE ELSE — scoreboard rows, queue tasks, findings files, scores files — use the **bare `<topic-slug>`** (no `NN-` prefix). Mixing the two forms produces duplicate files and queue/file mismatches in agent dispatches.

- Replace `[MAX_ITER]` in the header with the computed value: `topics × 8 + 10`
- Replace `[TOPIC_SCOREBOARD]` with one row per topic, using `<topic-slug>` ONLY (no `NN-` prefix):
  ```
  | <topic-slug> | ACTIVE | - | - | - | - | - | - | - | 0 |
  ```
  Example: `| vancouver-seasonal-calendar | ACTIVE | - | - | - | - | - | - | - | 0 |`
- Replace `[TOPIC_RESEARCH]` with one `- [ ] Research: <topic-slug>` line per topic (slug only — `Research: vancouver-seasonal-calendar`, NOT `Research: 01-vancouver-seasonal-calendar`).
- Replace `[TOPIC_CRITIQUE]` with one `- [ ] Critique & Score: <topic-slug>` line per topic (slug only).

**Write `scoring-rubric.md`** unchanged (no placeholders to fill).

**Write all files** to the user's chosen directory using the Write tool.

**Present two run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory.

> **How do you want to run this research?**
> 1. `/offline-research:workshop-loop` in the current Claude Code session (Recommended)
> 2. `/offline-research:workshop-loop` inside a sandboxed container (only needed for PoC code execution; research-probe rarely needs this)

After the user picks, print only the selected command:

- **Option 1 (recommended)**:
  ```
  /offline-research:workshop-loop <probe-dir>
  ```

- **Option 2 (sandbox)**:
  ```
  ./containers/workshop/launch.sh build --container=research
  ./containers/workshop/launch.sh shell --container=research <probe-dir>
  # inside the container shell:
  claude
  # in Claude Code:
  /offline-research:workshop-loop /workspace
  ```

Replace `<probe-dir>` with the user's chosen directory (absolute path).

Then ask:

> Copy to clipboard? (y/n)

If yes, copy the selected command to clipboard via `printf '%s' '<command>' | pbcopy`.

Design rationale: [`../../docs/architecture.md`](../../docs/architecture.md)

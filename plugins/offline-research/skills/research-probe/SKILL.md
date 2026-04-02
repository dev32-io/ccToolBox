---
name: research-probe
description: >
  Guide freeform research intent into a structured prompt for offline ralph-loop execution.
  Use when the user says "start an offline research on...", "offline research on...",
  "launch a research probe on...", or invokes /research-probe.
  Do NOT trigger on: "research this", "look into this", "find out about",
  "deep research", "do some research", "deep dive", "do a deep dive",
  "brainstorm", "investigate", "explore", "dig into",
  "what do you know about", "tell me about".
tools: WebSearch, WebFetch, Bash, Write, Read, Glob
---

# Research Probe

Guide the user from freeform research intent to a structured prompt ready for ralph-loop execution.

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

Once confirmed, ask where to write them:

> Where should I write the research files?
> 1. `~/offline-research/YYYY-MM-DD-short-title/`
> 2. `<git-root>/offline-research/YYYY-MM-DD-short-title/` (or `./YYYY-MM-DD-short-title/` if not in a git repo)
> 3. Type a custom path

Get the current date via `date +%Y-%m-%d`. Determine git root via `git rev-parse --show-toplevel 2>/dev/null`.

Determine the plugin root (two directories up from this skill file) to find templates.

**Read templates:**
- Read `<plugin-root>/templates/prompt.md`
- Read `<plugin-root>/templates/progress.md`

**Fill prompt.md:**
- Replace `[TOPIC]` with the research mission title
- Replace `[TOPICS]` with the refined topic list, each formatted as:
  ```
  ### N. Topic Name (`topic-name.md`)
  - sub-topic or question
  - sub-topic or question
  - ...
  ```

**Fill progress.md:**
- Replace `[TOPIC_CHECKLIST]` with one `- [ ] topic-name.md` per topic

**Write both files** to the user's chosen directory using the Write tool.

**Present two run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory (e.g. `2026-04-02-llm-safety`).

> **How do you want to run this research?**
> 1. In the offline research container (Recommended)
> 2. Locally

After the user picks, print only the selected command:

- **Container command** (uses `/workspace/<folder-name>/` as the path):
  ```
  /ralph-loop:ralph-loop "Read /workspace/<folder-name>/prompt.md and execute the research mission. Read /workspace/<folder-name>/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from /workspace/<folder-name>/topics/ and write output to /workspace/<folder-name>/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations 15 --completion-promise "ALL PHASES COMPLETE"
  ```

- **Local command** (uses `<local-path>/` as the path):
  ```
  /ralph-loop:ralph-loop "Read <local-path>/prompt.md and execute the research mission. Read <local-path>/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from <local-path>/topics/ and write output to <local-path>/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations 15 --completion-promise "ALL PHASES COMPLETE"
  ```

Replace `<folder-name>` and `<local-path>` with actual values.

Then ask:

> Copy to clipboard? (y/n)

If yes, copy the selected command to clipboard via `printf '%s' '<command>' | pbcopy`.

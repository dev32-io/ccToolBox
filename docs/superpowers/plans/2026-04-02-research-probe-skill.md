# Research Probe Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `research-probe` skill within a new `offline-research` plugin that guides users from freeform research intent to a structured prompt ready for ralph-loop execution.

**Architecture:** A single SKILL.md drives the entire interactive flow — no agents or scripts needed. Templates for prompt.md and progress.md live inside the plugin. The skill reads templates, fills them with user-refined topics, and writes output files.

**Tech Stack:** Claude Code plugin system (SKILL.md frontmatter + markdown instructions), WebSearch for quick survey.

---

## File Structure

```
plugins/offline-research/
├── .claude-plugin/
│   └── plugin.json          # plugin metadata (name, version, author)
├── skills/
│   └── research-probe/
│       └── SKILL.md          # skill definition — triggers, flow, tone rules
├── templates/
│   ├── prompt.md             # 5-phase research mission template
│   └── progress.md           # seed progress checklist template
└── README.md                 # user-facing documentation
```

Also modify:
- `.claude-plugin/marketplace.json` — register the new plugin

---

### Task 1: Create plugin scaffold

**Files:**
- Create: `plugins/offline-research/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "offline-research",
  "description": "Tools for structured offline research using ralph-loop",
  "version": "1.0.0",
  "author": {
    "name": "dev32-io"
  }
}
```

Write this to `plugins/offline-research/.claude-plugin/plugin.json`.

- [ ] **Step 2: Register in marketplace.json**

Add the new plugin entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "offline-research",
  "description": "Tools for structured offline research using ralph-loop",
  "version": "1.0.0",
  "source": "./plugins/offline-research",
  "category": "productivity"
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(offline-research): scaffold plugin with marketplace registration"
```

---

### Task 2: Create templates

**Files:**
- Create: `plugins/offline-research/templates/prompt.md`
- Create: `plugins/offline-research/templates/progress.md`

- [ ] **Step 1: Write prompt.md template**

Write to `plugins/offline-research/templates/prompt.md`:

```markdown
# Research Mission: [TOPIC]

You have full autonomy. Do not ask questions. Use your best judgement.

## Workspace Structure

\```
/workspace/
├── progress.md              # thin checklist — current phase + per-topic status
├── topics/
│   ├── 01-topic-name.md     # sub-topics + questions (generated in Phase 1)
│   └── ...
├── findings/
│   ├── topic-name.md        # research output per topic
│   └── ...
├── sources.md               # running bibliography — URLs, titles, notes
├── contradictions.md        # where sources disagree
├── connections.md           # cross-topic patterns and insights
├── gaps.md                  # self-critique — what's weak, what needs more work
└── README.md                # final TLDR + navigation
\```

## Phases

### Phase 1: Scope Expansion
Read the initial topics below. Think about what's missing.
For each topic, create a file in `topics/` with:
- The original bullet points
- Sub-topics you think are important but weren't listed
- Adjacent areas that would strengthen the research
- 3-5 specific questions to answer

Update progress.md to mark Phase 1 complete.

### Phase 2: Survey
Quick pass across all topics. For each:
- Skim available sources, log them in sources.md
- Note which areas are well-documented vs sparse
- Flag any early contradictions

Update progress.md with survey status per topic.

### Phase 3: Deep Dive
For each topic (read its spec from `topics/`, write output to `findings/`):
1. Research thoroughly — multiple sources, specific examples, actionable detail
2. Cite sources (reference entries in sources.md)
3. Mark topic complete in progress.md

### Phase 4: Synthesize
1. Write connections.md — patterns and insights across topics
2. Write contradictions.md — where sources disagree and why
3. Write gaps.md — what's weak, what would someone challenge, what needs more work

### Phase 5: Final Report
1. Write README.md — TLDR summary with links to each findings file
2. Update progress.md to mark all phases complete

Output <promise>ALL PHASES COMPLETE</promise> when done.

## Initial Topics

[TOPICS]
```

The `[TOPIC]` and `[TOPICS]` placeholders are filled by the skill at generation time.

- [ ] **Step 2: Write progress.md template**

Write to `plugins/offline-research/templates/progress.md`:

```markdown
# Research Progress

## Current Phase: Phase 1 — Scope Expansion

## Topic Status
[TOPIC_CHECKLIST]

## Phase Checklist
- [ ] Phase 1: Scope Expansion
- [ ] Phase 2: Survey
- [ ] Phase 3: Deep Dive
- [ ] Phase 4: Synthesize
- [ ] Phase 5: Final Report
```

The `[TOPIC_CHECKLIST]` placeholder is filled by the skill with `- [ ] topic-name.md` entries.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/templates/
git commit -m "feat(offline-research): add prompt and progress templates"
```

---

### Task 3: Write SKILL.md

This is the core of the plugin. The SKILL.md contains all the instructions for the interactive flow.

**Files:**
- Create: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Write to `plugins/offline-research/skills/research-probe/SKILL.md`:

```markdown
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

### Step 1: Intake

The user has provided freeform text describing what they want to research. Read it carefully — it may be messy, stream-of-consciousness, bullet points, or well-structured. Extract all topics and intents.

### Step 2: Quick Survey

Do fast web searches across the user's topics to understand the landscape. Use WebSearch. This is not deep research — just enough to form an informed opinion. Spend 2-5 searches total. Note what you find.

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

Ask where to write the research files:

> Where should I write the research files?
> 1. `~/research/YYYY-MM-DD-short-title/`
> 2. `<git-root>/research/YYYY-MM-DD-short-title/` (or `./YYYY-MM-DD-short-title/` if not in a git repo)
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

**Output the ralph-loop command:**
```
/ralph-loop:ralph-loop "Read <path>/prompt.md and execute the research mission. Read <path>/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from <path>/topics/ and write output to <path>/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations 15 --completion-promise "ALL PHASES COMPLETE"
```

Replace `<path>` with the actual workspace path. Tell the user to copy-paste this into the research container.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/skills/research-probe/SKILL.md
git commit -m "feat(offline-research): add research-probe skill"
```

---

### Task 4: Write README.md

**Files:**
- Create: `plugins/offline-research/README.md`

- [ ] **Step 1: Write README.md**

Write to `plugins/offline-research/README.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/README.md
git commit -m "docs(offline-research): add README"
```

---

### Task 5: Version bump and final commit

**Files:**
- Modify: `.claude-plugin/marketplace.json` (already done in Task 1)

- [ ] **Step 1: Verify plugin loads**

Run from the repo root:

```bash
cat plugins/offline-research/.claude-plugin/plugin.json | jq .
cat .claude-plugin/marketplace.json | jq .
ls plugins/offline-research/skills/research-probe/SKILL.md
ls plugins/offline-research/templates/prompt.md
ls plugins/offline-research/templates/progress.md
```

Verify all files exist and JSON is valid.

- [ ] **Step 2: Push to remotes**

```bash
git push origin main && git push lab main
```

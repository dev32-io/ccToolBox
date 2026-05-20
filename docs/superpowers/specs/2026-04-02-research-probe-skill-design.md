# Research Probe Skill Design

## Overview

A skill within the `offline-research` plugin that guides users from freeform research intent to a structured prompt ready for ralph-loop execution in the research container.

## Plugin Structure

```
plugins/offline-research/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── research-probe/
│       └── SKILL.md
├── templates/
│   ├── prompt.md
│   └── progress.md
└── README.md
```

Plugin: `offline-research`. Skill: `research-probe`. Templates self-contained within the plugin.

## Triggers

**Triggered by:**
- `/research-probe`
- "start an offline research on..."
- "offline research on..."
- "launch a research probe on..."

**Explicitly NOT triggered by:**
- "research this", "look into this", "find out about"
- "deep research", "do some research"
- "deep dive", "do a deep dive"
- "brainstorm", "let's brainstorm"
- "investigate", "explore", "dig into"
- "what do you know about", "tell me about"

## Skill Flow

### Step 1 — Intake
User provides freeform text describing what they want to research. Can be messy, stream-of-consciousness, bullet points, whatever.

### Step 2 — Quick Survey
Skill does fast web searches across the user's topics to understand the landscape. Not deep research — just enough to form an informed opinion.

### Step 3 — Critical Assessment
Skill presents:
- Organized topic breakdown extracted from user's input
- Its opinion after the survey — what looks straightforward, what's already solved, what needs decomposition
- Suggested additional topics the user didn't mention
- Questions with multiple choice options + room for user to add their own input

### Step 4 — Guided Refinement (loop)
User responds. Skill iterates:
- Refines topics based on user's answers
- Breaks down further — always decompose, never consolidate
- For niche areas, probes user's intent to find researchable pieces
- Pushes back where warranted (as options with rationale, never blocking)
- Asks follow-up questions with options
- Loops until scope feels right to both sides

### Step 5 — Generate
Skill asks where to write files:
1. `~/research/YYYY-MM-DD-topic-name/`
2. `<git-root>/research/YYYY-MM-DD-topic-name/` (or `./YYYY-MM-DD-topic-name/` if not in a git repo)
3. User types a custom path

Then writes:
- `prompt.md` — filled from template with 5-phase structure, all refined topics with detailed sub-topics and questions
- `progress.md` — seed checklist with all topics listed

Outputs the ralph-loop command with the workspace path baked in, ready to copy-paste.

## Tone & Interaction Rules

### Positive framing (what to do, not what to avoid)
- Express genuine interest through specific observations: "I looked into X and there's actually a whole ecosystem around Y that connects here"
- React to survey findings naturally — share what's surprising or interesting about the landscape
- Use language that shows thinking alongside the user: "this could go a few directions...", "one angle I hadn't considered..."
- Write with warmth and directness — short sentences, conversational rhythm
- When pushing back, frame as sharing what you found: "there's already a well-maintained tool for this part — worth knowing before spending research cycles on it"

### Interaction style
- One question at a time, multiple choice + room for user input
- Always decompose, never consolidate — more specific topics = better ralph loop results
- Niche topics: probe intent, break into researchable pieces
- Pushback as options with rationale, never blocks — user always has final say
- Form an opinion after the survey — share it with the user, be a thinking partner not a passive scribe

## Output Files

### prompt.md
Filled from template with:
- Research mission title
- Workspace structure reference (topics/, findings/, sources.md, etc.)
- 5 phases: scope expansion, survey, deep dive, synthesize, final report
- All refined topics with detailed sub-topics and questions

### progress.md
Seed checklist:
- Current phase marker
- All topics listed as unchecked
- Phase checklist (all 5 phases unchecked)

### Ralph-loop command
```
/ralph-loop:ralph-loop "Read /workspace/prompt.md and execute the research mission. Read /workspace/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from /workspace/topics/ and write output to /workspace/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done." --max-iterations 15 --completion-promise "ALL PHASES COMPLETE"
```

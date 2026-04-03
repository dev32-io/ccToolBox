# Research Loop v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the phase-based research template with a checklist-driven loop that enforces one-item-per-iteration and prevents stale scoring.

**Architecture:** prompt.md becomes minimal (just workspace + "follow the queue"). progress.md gets a pre-seeded task queue alongside the scoreboard. critique-loop.md is rewritten to focus on score handling + plateau rules + worked example. The skill pre-populates the full queue and uses `topics × 8 + 10` for max-iterations.

**Tech Stack:** Markdown templates, Claude Code Agent tool with `model: sonnet`, ralph-loop

---

### Task 1: Rewrite `prompt.md` — strip phases, add queue instruction

**Files:**
- Modify: `plugins/offline-research/templates/prompt.md`

- [ ] **Step 1: Replace entire file contents**

Replace the full contents of `plugins/offline-research/templates/prompt.md` with:

```markdown
# Research Mission: [TOPIC]

You have full autonomy. Do not ask questions. Use your best judgement.

## Workspace Structure

` ` `
/workspace/
├── progress.md              # scoreboard + task queue — your instruction sheet
├── critique-loop.md         # how to handle Critique & Score tasks
├── scoring-rubric.md        # scoring dimensions for subagents
├── topics/
│   ├── 01-topic-name.md     # sub-topics + questions
│   └── ...
├── findings/
│   ├── topic-name.md        # research output per topic
│   └── ...
├── poc/                     # prototypes, architectures, visual explorations
│   └── ...
├── sources.md               # running bibliography — URLs, titles, notes
├── contradictions.md        # where sources disagree
├── connections.md           # cross-topic patterns and insights
├── gaps.md                  # self-critique — what's weak, what needs more work
└── README.md                # final TLDR + navigation
` ` `

## How This Works

1. Read `progress.md` and find the next unchecked item in the Task Queue
2. Do that ONE item
3. Check it off in progress.md
4. Output `TASK DONE`
5. Stop — you will be re-invoked automatically

When the task queue is empty, output `<promise>TASK DONE</promise>` instead.

Research isn't only reading. When a topic would benefit from *making something* — you should definitely do it. Build prototypes, draft architectures, sketch mockups. Create a folder in `poc/` and treat it as a topic.

## Initial Topics

[TOPICS]
```

Note: The triple backticks in the workspace structure block must be actual triple backticks (the `\` ` \`` above is escaping for this plan doc). Write them as normal fenced code blocks.

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/prompt.md
git commit -m "feat(offline-research): rewrite prompt.md to checklist-driven model"
```

---

### Task 2: Rewrite `progress.md` — add task queue with placeholders

**Files:**
- Modify: `plugins/offline-research/templates/progress.md`

- [ ] **Step 1: Replace entire file contents**

Replace the full contents of `plugins/offline-research/templates/progress.md` with:

```markdown
# Research Progress

## Scoreboard
| Topic | Status | Src | Depth | Action | Cohere | Confid | Total | Δ | Streak |
|-------|--------|-----|-------|--------|--------|--------|-------|---|--------|
[TOPIC_SCOREBOARD]

## Task Queue

> For every `Critique & Score` task: you MUST read `critique-loop.md` and `scoring-rubric.md` before starting. Do not score from memory or assumption.

- [ ] Expand scope: all topics (create topic files in topics/)
- [ ] Survey: all topics (skim sources, log in sources.md)
[TOPIC_RESEARCH]
- [ ] Synthesize
- [ ] Final report
[TOPIC_CRITIQUE]
- [ ] Synthesize
- [ ] Final report
```

Three placeholders the skill fills:
- `[TOPIC_SCOREBOARD]` → one `| topic-name | ACTIVE | - | - | - | - | - | - | - | 0 |` per topic
- `[TOPIC_RESEARCH]` → one `- [ ] Research: topic-name` per topic
- `[TOPIC_CRITIQUE]` → one `- [ ] Critique & Score: topic-name` per topic

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/progress.md
git commit -m "feat(offline-research): add task queue with placeholders to progress.md"
```

---

### Task 3: Rewrite `critique-loop.md` — flowchart + plateau rules + worked example

**Files:**
- Modify: `plugins/offline-research/templates/critique-loop.md`

- [ ] **Step 1: Replace entire file contents**

Replace the full contents of `plugins/offline-research/templates/critique-loop.md` with:

```markdown
# Critique & Score — How It Works

You are handling a `Critique & Score: <topic>` task from the queue.

## Step 1: Spawn Sonnet Subagent

Spawn a subagent for this ONE topic:

- **Model:** sonnet
- **Isolation:** The subagent gets ONLY the scoring rubric and the topic's output. No other context. No web access. No research history. This isolation is the point — if the subagent can't understand your findings without extra context, your findings aren't good enough.
- **Prompt:** "You MUST read `<path>/scoring-rubric.md` before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption. After reading the rubric, read `<path>/findings/<topic>.md` and score it according to the rubric. Be curious — wonder what's missing, what doesn't add up, what you'd want to know more about."

Replace `<path>` with the actual workspace path. For PoC topics, point the subagent at whatever the topic produced in `poc/<topic>/`.

## Step 2: Update Scoreboard

Record the scores in progress.md. Compute Δ (this score's total minus the last score's total for this topic). Update streak.

## Step 3: Expand the Task Queue

Based on the score result, append items to the task queue in progress.md:

` ` `
Δ > 3 (topic is gaining):
├── Append: Improve: <topic> (gaps: ...) — from subagent's friction log
├── Append: Research: <new-topic> — if subagent surfaced new areas
├── Append: Research: poc-<name> — if building something would help
└── Streak → 0

Δ ≤ 3, streak 0 (first plateau):
├── Append: Improve: <topic> (last chance: ...) — one more try
└── Streak → 1

Δ ≤ 3, streak ≥ 1 (second plateau):
├── Append nothing
├── Mark CONCLUDED in scoreboard
└── Topic done — no more tasks will be added for it
` ` `

Before adding any new topic, deduplicate against ALL topics in the scoreboard (ACTIVE and CONCLUDED).

After the last `Critique & Score` item in the current round, also append `Synthesize` and `Final report` to keep the research output fresh.

## Worked Example

Starting state — first round of scoring underway:

` ` `
- [x] ... (expand, survey, research, synthesize, report done)
- [x] Critique & Score: stt-providers → 28/50 (gaps: no latency benchmarks, missing Groq Whisper)
- [ ] Critique & Score: openrouter-streaming
- [ ] Critique & Score: cloud-tts-providers
- [ ] Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)
- [ ] Research: groq-whisper-integration ← NEW
- [ ] Synthesize
- [ ] Final report
` ` `

**Agent picks: `Critique & Score: openrouter-streaming`**

Spawns Sonnet → 25/50 (gaps: no code examples, pricing stale). Δ = 25 (first score, gaining). Appends:

` ` `
- [x] Critique & Score: openrouter-streaming → 25/50
- [ ] Critique & Score: cloud-tts-providers
- [ ] Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)
- [ ] Research: groq-whisper-integration
- [ ] Improve: openrouter-streaming (gaps: code examples, pricing) ← APPENDED
- [ ] Synthesize
- [ ] Final report
` ` `

Outputs TASK DONE.

**Agent picks: `Improve: stt-providers (gaps: latency benchmarks, Groq Whisper)`**

Adds benchmarks table, writes Groq Whisper section. Appends:

` ` `
- [x] Improve: stt-providers ✓
- [ ] ...
- [ ] Critique & Score: stt-providers ← APPENDED (to verify improvement)
` ` `

Outputs TASK DONE.

**`Critique & Score: stt-providers` (second time) — Score: 40/50. Δ = +12. Gaining.**

` ` `
- [ ] Improve: stt-providers (gaps: VAD section thin) ← APPENDED
- [ ] Research: vad-pipeline-integration ← NEW
` ` `

**`Critique & Score: stt-providers` (third time) — Score: 42/50. Δ = +2. First plateau (streak → 1).**

` ` `
- [ ] Improve: stt-providers (last chance: tighten VAD section) ← APPENDED
` ` `

**`Critique & Score: stt-providers` (fourth time) — Score: 43/50. Δ = +1. Second plateau (streak → 2). CONCLUDED.**

Nothing appended. Topic done.
```

Note: Same escaping issue — the triple backticks inside the fenced code blocks must be actual triple backticks when written to the file.

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/critique-loop.md
git commit -m "feat(offline-research): rewrite critique-loop.md with flowchart + plateau rules + example"
```

---

### Task 4: Update `SKILL.md` — task queue generation + new formula + stop word

**Files:**
- Modify: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Update the "Fill progress.md" section**

Find the current fill instructions and replace:

```
**Fill progress.md:**
- Replace `[TOPIC_SCOREBOARD]` with one row per topic:
  ```
  | topic-name | ACTIVE | - | - | - | - | - | - | - | 0 |
  ```

**Write `critique-loop.md` and `scoring-rubric.md`** unchanged (no placeholders to fill).

**Write all four files** to the user's chosen directory using the Write tool.
```

With:

```
**Fill progress.md:**
- Replace `[TOPIC_SCOREBOARD]` with one row per topic:
  ```
  | topic-name | ACTIVE | - | - | - | - | - | - | - | 0 |
  ```
- Replace `[TOPIC_RESEARCH]` with one line per topic:
  ```
  - [ ] Research: topic-name
  ```
- Replace `[TOPIC_CRITIQUE]` with one line per topic:
  ```
  - [ ] Critique & Score: topic-name
  ```

**Write `critique-loop.md` and `scoring-rubric.md`** unchanged (no placeholders to fill).

**Write all four files** to the user's chosen directory using the Write tool.
```

- [ ] **Step 2: Update max-iterations formula**

Find:

```
**Calculate max-iterations:** Count the number of initial topics and add 15. The initial phases consume iterations proportional to topic count; the +15 guarantees room for the critique-expand loop. Example: 8 topics → `--max-iterations 23`.
```

Replace with:

```
**Calculate max-iterations:** `topics × 8 + 10`. Covers 3 rounds of research + critique & score + synthesis, plus buffer for new topics and PoC work. Example: 7 topics → `--max-iterations 66`.
```

- [ ] **Step 3: Update both ralph-loop commands — max-iterations and completion promise**

Find both command blocks (container and local). In each, replace:
- `--max-iterations <TOPIC_COUNT + 15>` → `--max-iterations <TOPIC_COUNT * 8 + 10>`
- `--completion-promise "ALL PHASES COMPLETE"` → `--completion-promise "TASK DONE"`

Also in each command, replace the prompt text:
- `"Read /workspace/<folder-name>/prompt.md and execute the research mission. Read /workspace/<folder-name>/progress.md to find your current phase and next incomplete task. For deep dive topics, read the spec from /workspace/<folder-name>/topics/ and write output to /workspace/<folder-name>/findings/. Update progress.md after each step. Output <promise>ALL PHASES COMPLETE</promise> when every phase is done."`

With:
- `"Read /workspace/<folder-name>/prompt.md for context. Read /workspace/<folder-name>/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop."`

Do the same replacement for the local command block, using `<local-path>` instead of `/workspace/<folder-name>`.

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/skills/research-probe/SKILL.md
git commit -m "feat(offline-research): update skill for checklist-driven queue + new formula"
```

---

### Task 5: Update `ralph-command.md` reference

**Files:**
- Modify: `plugins/offline-research/templates/ralph-command.md`

- [ ] **Step 1: Replace entire file contents**

Replace the full contents of `plugins/offline-research/templates/ralph-command.md` with:

```markdown
# Ralph Loop Command

Copy your `prompt.md`, `progress.md`, `critique-loop.md`, and `scoring-rubric.md` to `/workspace/`, then run:

` ` `
/ralph-loop:ralph-loop "Read /workspace/prompt.md for context. Read /workspace/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop." --max-iterations <TOPIC_COUNT * 8 + 10> --completion-promise "TASK DONE"
` ` `

**Max-iterations:** `topics × 8 + 10`. Example: 7 topics → `--max-iterations 66`.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/ralph-command.md
git commit -m "feat(offline-research): update ralph-command.md for v2 loop"
```

---

### Task 6: Verify template consistency

Read through all templates and SKILL.md as a final pass.

**Files:**
- Read: `plugins/offline-research/templates/prompt.md`
- Read: `plugins/offline-research/templates/progress.md`
- Read: `plugins/offline-research/templates/critique-loop.md`
- Read: `plugins/offline-research/templates/ralph-command.md`
- Read: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Verify placeholders**

Check that:
- `prompt.md` has `[TOPIC]` and `[TOPICS]` (filled by skill)
- `progress.md` has `[TOPIC_SCOREBOARD]`, `[TOPIC_RESEARCH]`, `[TOPIC_CRITIQUE]` (filled by skill)
- `critique-loop.md` and `scoring-rubric.md` have NO placeholders
- SKILL.md references all three progress.md placeholders

- [ ] **Step 2: Verify stop word consistency**

Check that:
- `prompt.md` says to output `TASK DONE` after each item
- `prompt.md` says to output `<promise>TASK DONE</promise>` when queue is empty
- SKILL.md ralph-loop commands use `--completion-promise "TASK DONE"`
- `ralph-command.md` uses `--completion-promise "TASK DONE"`
- `critique-loop.md` does NOT mention any stop words (that's prompt.md's job)

- [ ] **Step 3: Verify Δ threshold**

Check that `critique-loop.md` uses Δ > 3 / Δ ≤ 3 consistently (not the old Δ ≤ 1).

- [ ] **Step 4: Fix any issues found, commit if changes were made**

```bash
git add -A
git commit -m "fix(offline-research): fix template consistency issues"
```

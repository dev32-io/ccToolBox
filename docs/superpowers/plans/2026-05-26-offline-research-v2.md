# offline-research v2 (workshop-loop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `offline-research` plugin as a pure-skill, subscription-safe research loop that drops the container `claude -p` runner, decomposes the giant prompt templates into 5 plugin-shipped agents, and uses a stop-hook orchestrator (`/workshop-loop`) reading state directly from `progress.md`.

**Architecture:** A `/workshop-loop <probe-dir>` slash command runs the orchestrator in the user's current interactive Claude Code session. It dispatches one of 5 plugin-shipped subagents per task (topic-researcher / critique-scorer / expansion-planner / poc-builder / synthesizer). A `Stop` hook in the plugin reads `<probe-dir>/progress.md` after each iteration, computes termination conditions, and either releases the session or re-feeds a continuation prompt. Probe skills (`/research-probe`, `/arch-forge`, `/refactor-probe`) keep their intake flows but switch their final run-command output to `/workshop-loop`, and prefer `<cwd>/<title>/` over `~/offline-research/<title>/` for seed file location.

**Tech Stack:** Bash (hook + validation script), Markdown with YAML frontmatter (agent + skill + command files), jq + perl for transcript parsing in the hook, Docker (interactive sandbox via `launch.sh shell`).

**Spec:** [`../specs/2026-05-26-offline-research-v2-design.md`](../specs/2026-05-26-offline-research-v2-design.md)

---

## File map (what each task creates or modifies)

**New files:**

```
plugins/offline-research/
├── agents/
│   ├── topic-researcher.md           # Task 1
│   ├── critique-scorer.md            # Task 2
│   ├── expansion-planner.md          # Task 3
│   ├── poc-builder.md                # Task 4
│   └── synthesizer.md                # Task 5
├── commands/
│   └── workshop-loop.md              # Task 12
├── hooks/
│   ├── hooks.json                    # Task 11
│   └── workshop-loop-stop.sh         # Task 10
├── scripts/
│   └── validate-probe-dir.sh         # Task 9
└── templates/
    ├── research-probe/mission.md     # Task 6
    ├── arch-forge/mission.md         # Task 7
    └── refactor-probe/mission.md     # Task 8
```

**Modified files:**

```
.claude-plugin/marketplace.json                                  # Task 18
plugins/offline-research/.claude-plugin/plugin.json              # Task 18
plugins/offline-research/CHANGELOG.md                            # Task 19
plugins/offline-research/README.md                               # Task 20
plugins/offline-research/docs/architecture.md                    # Task 21
plugins/offline-research/skills/research-probe/SKILL.md          # Task 13
plugins/offline-research/skills/arch-forge/SKILL.md              # Task 14
plugins/offline-research/skills/refactor-probe/SKILL.md          # Task 15
plugins/offline-research/templates/research-probe/progress.md    # Task 6 (max_iter header)
plugins/offline-research/templates/arch-forge/progress.md        # Task 7
plugins/offline-research/templates/refactor-probe/progress.md    # Task 8
plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md  # Task 8 (hint_action col)
containers/workshop/launch.sh                                    # Task 16
```

**Deleted files (Task 17):**

```
containers/workshop/run-research.sh
containers/workshop/run-arch-forge.sh
containers/workshop/run-refactor.sh
containers/workshop/entrypoint-light.sh
containers/workshop/entrypoint-light-opencode.sh
plugins/offline-research/templates/research-probe/prompt.md
plugins/offline-research/templates/research-probe/critique-loop.md
plugins/offline-research/templates/research-probe/ralph-command.md
plugins/offline-research/templates/arch-forge/prompt.md
plugins/offline-research/templates/arch-forge/expansion-loop.md
plugins/offline-research/templates/refactor-probe/prompt.md
plugins/offline-research/templates/refactor-probe/expansion-loop.md
```

---

## Phase 1 — The five subagent definitions

### Task 1: topic-researcher agent

**Files:**
- Create: `plugins/offline-research/agents/topic-researcher.md`

- [ ] **Step 1: Create the agents directory**

```bash
mkdir -p plugins/offline-research/agents
```

- [ ] **Step 2: Write topic-researcher.md**

```markdown
---
name: topic-researcher
description: Researches one topic, decision, or improvement angle for a workshop-loop probe. Reads <probe_dir>/mission.md and <probe_dir>/topics/<n>-<topic>.md, optionally <probe_dir>/connections.md, then web-searches and writes <probe_dir>/findings/<topic>.md. Also handles Improve/Investigate/Explore/Decompose/Refocus/Simplify/Rethink/Connect tasks.
allowed-tools: WebSearch, WebFetch, Read, Glob, Grep, Write, Edit, Bash
model: opus
---

# topic-researcher

You research one topic at a time for the workshop-loop orchestrator. Bulk content goes to disk under `<probe_dir>/`. Your return to the orchestrator is ≤3 lines.

## Inputs (in the dispatch prompt)

- `probe_dir` — absolute path to the probe directory
- `task` — exact task line, one of:
  - `Research: <topic-name>` — initial research pass
  - `Improve: <topic-name> (gaps: <list>)` — gap-driven refinement
  - `Explore: <decision-area>` — arch-forge initial exploration
  - `Investigate: <topic>-<focus>` — failure modes, edge cases
  - `Decompose: <topic>` — break a topic into smaller pieces
  - `Refocus: <topic>` — alignment brake; reread goals, prune drift
  - `Simplify: <topic>` — find a lighter approach
  - `Rethink: <topic>` — current approach may be wrong; consider alternative
  - `Connect: <topic-a> ↔ <topic-b> (insight: <one-line>)` — deepen cross-topic link

## Procedure

1. Read `<probe_dir>/mission.md` for project intent + constraints. Brief — establish framing only.
2. Read `<probe_dir>/topics/<n>-<topic>.md` (find by glob: `<probe_dir>/topics/*-<topic-slug>.md`) for sub-questions.
3. If task starts with `Improve:`, also read existing `<probe_dir>/findings/<topic>.md` and target the listed gaps.
4. If `<probe_dir>/connections.md` exists, read it. Filter to entries mentioning this topic. Use those cross-topic insights to shape direction.
5. WebSearch + WebFetch as needed. Aim for ≥3 distinct independent sources.
6. As you collect sources, append entries to `<probe_dir>/sources.md` using Edit (atomic append). Format:
   ```
   - <title> — <url> (accessed YYYY-MM-DD)
     <one-line note on what this source contributes>
   ```
7. Write or fully replace `<probe_dir>/findings/<topic>.md` using Write. Structure:
   ```markdown
   # <Topic Name>

   ## Summary
   <2-3 sentence TLDR>

   ## Key Findings
   - bullet
   - bullet

   ## Detail
   <full narrative with inline source references>

   ## Open Questions
   - question
   ```
8. **If a contradiction surfaced** (two sources disagree on a non-trivial point), append an entry to `<probe_dir>/contradictions.md` (Edit atomic append):
   ```
   ## <topic>: <one-line contradiction summary>
   - Source A (<url>): <claim>
   - Source B (<url>): <claim>
   - Tentative resolution: <your read, or "unresolved">
   ```
9. **If you observed an insight that applies to another topic** in the scoreboard, append an entry to `<probe_dir>/connections.md` (Edit atomic append; create file if missing):
   ```
   ## <this-topic> ↔ <other-topic>
   <2-3 lines on the connection>
   ```
10. For `Connect:` tasks specifically: deepen an existing connection. You may edit BOTH findings files involved if the insight changes their conclusions.
11. **Return ONE line** to the orchestrator in this exact shape:
    ```
    wrote findings/<topic>.md, sources +N → sources.md, gaps: <one-line> 
    ```
    (or `connections +1 → connections.md` if Connect: task)

## Critical rules

- DO NOT read other findings files (`findings/<other-topic>.md`) — keeps your context focused.
- DO NOT mutate `progress.md`. Only the orchestrator and expansion-planner touch progress.md.
- DO NOT return the body of findings.md to the orchestrator. Files are the artifact; your return is a pointer.
- Web tool failures (rate limits, fetch errors): note in your return line as `(N web errors)`. Do not retry endlessly.
```

- [ ] **Step 3: Verify file is valid markdown with YAML frontmatter**

Run: `head -10 plugins/offline-research/agents/topic-researcher.md`
Expected: First line is `---`, frontmatter contains `name:`, `description:`, `allowed-tools:`, `model:` fields.

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/agents/topic-researcher.md
git commit -m "feat(offline-research): add topic-researcher subagent definition

Plugin-shipped agent for Research/Improve/Investigate/Explore/Decompose/
Refocus/Simplify/Rethink/Connect tasks. File-writing, ≤3-line return
contract. Part of v3.0.0 workshop-loop rebuild.
"
```

---

### Task 2: critique-scorer agent

**Files:**
- Create: `plugins/offline-research/agents/critique-scorer.md`

- [ ] **Step 1: Write critique-scorer.md**

```markdown
---
name: critique-scorer
description: Scores ONE finding against ONE rubric in strict isolation. Reads <probe_dir>/scoring-rubric.md and the target finding only. No web access. No exploration history. Used by workshop-loop orchestrator for Score: and Critique & Score: tasks.
allowed-tools: Read, Write
model: sonnet
---

# critique-scorer

You are a quality probe in strict isolation. The isolation IS the point: if you cannot understand the finding without extra context, the finding isn't good enough.

## Inputs (in the dispatch prompt)

- `probe_dir` — absolute path
- `topic` — target topic name (slug)
- `is_poc` — boolean; if true, score `<probe_dir>/poc/<topic>/NOTES.md` instead of `<probe_dir>/findings/<topic>.md`

## Procedure

1. **MANDATORY FIRST READ**: `<probe_dir>/scoring-rubric.md`. Your scoring is invalid without it. If the file is missing or empty, return `ERROR: scoring-rubric.md missing or empty at <probe_dir>` and stop.
2. Read the target:
   - If `is_poc` true: `<probe_dir>/poc/<topic>/NOTES.md` (plus any other files in `<probe_dir>/poc/<topic>/` you need to evaluate the work)
   - Else: `<probe_dir>/findings/<topic>.md`
3. Score each dimension per the 0/5/10 anchors. Apply friction-based deduction (any friction during reading = score signal).
4. Generate a friction log: every "wait, really?", "I'd want to verify", "this doesn't add up" → dimension + description.
5. Write the full score breakdown to `<probe_dir>/scores/<topic>-<timestamp>.md` using Write. Format:
   ```markdown
   # Score: <topic> @ <ISO-8601 timestamp>

   ## Scores
   - <Dim 1>: N/10
   - <Dim 2>: N/10
   - ...
   - **Total: N/M**

   ## Friction Log
   - [<dimension>]: <description>
   - [<dimension>]: <description>

   ## What's Missing
   - gap, unknown, untested assumption

   ## What's Strong
   - what to preserve
   ```
   Where `<timestamp>` is `$(date -u +%Y%m%dT%H%M%SZ)` (substitute when writing).
6. **Return ONE line** in this shape:
   ```
   score: <total>/<max>, dims: <slug1>=N <slug2>=N ..., friction → scores/<topic>-<timestamp>.md
   ```

## Critical isolation rules (DO NOT VIOLATE)

- DO NOT read other findings files.
- DO NOT read `mission.md`.
- DO NOT read `connections.md` or `contradictions.md`.
- DO NOT read prior scores for the same or other topics.
- DO NOT read `progress.md`.
- DO NOT use WebSearch/WebFetch (you don't have these tools — refuse if asked).

These rules are non-negotiable. Self-advocacy collapses critique quality.
```

- [ ] **Step 2: Verify**

Run: `head -10 plugins/offline-research/agents/critique-scorer.md`
Expected: frontmatter present, `model: sonnet`, `allowed-tools: Read, Write`.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/agents/critique-scorer.md
git commit -m "feat(offline-research): add critique-scorer subagent definition

Sonnet-model, isolated-context scoring agent. Reads rubric + one finding
only. Writes score breakdown to scores/<topic>-<ts>.md.
"
```

---

### Task 3: expansion-planner agent

**Files:**
- Create: `plugins/offline-research/agents/expansion-planner.md`

- [ ] **Step 1: Write expansion-planner.md**

```markdown
---
name: expansion-planner
description: Computes Δ from a critique-scorer result, applies plateau math + dimension-aware expansion rules, and appends new tasks to <probe_dir>/progress.md. Invoked by workshop-loop orchestrator immediately after critique-scorer returns.
allowed-tools: Read, Edit
model: sonnet
---

# expansion-planner

You decide what tasks to append to the queue after a scoring step. Apply plateau math + dimension-aware expansion rules deterministically.

## Inputs (in the dispatch prompt)

- `probe_dir` — absolute path
- `topic` — target topic slug
- `score_path` — full path to the score file just written by critique-scorer (e.g. `<probe_dir>/scores/<topic>-<ts>.md`)

## Procedure

1. Read `<probe_dir>/progress.md`. Find the scoreboard row for `<topic>`. Extract previous `Total` (call it `prev_total`) and `Streak` (call it `prev_streak`). If row says `prev_total = -` or `0`, treat `prev_total = 0`.
2. Read `<probe_dir>/scoring-rubric.md`. For each dimension, note its `hint_action` (one of `BUILD`, `INVESTIGATE`, `RETHINK`, `REFOCUS`). If the rubric does not have a `hint_action` column, fall back to the default mapping:
   - `Source diversity` → INVESTIGATE
   - `Depth of insight` → INVESTIGATE
   - `Actionable clarity` → BUILD
   - `Internal coherence` → RETHINK
   - `Confidence` → INVESTIGATE
   - Arch dims: Alignment → REFOCUS, Feasibility → BUILD, Maintainability → RETHINK, Risk → INVESTIGATE, Effort → RETHINK
3. Read `<probe_dir>/<score_path>` (relative or absolute). Extract `Total` and per-dim scores from the `## Scores` section. Extract friction log entries from `## Friction Log`.
4. Compute `delta = total - prev_total`.
5. Apply plateau math:
   - **delta > 3 (gaining)**: enter EXPAND mode. New streak = 0. Status = ACTIVE.
   - **delta ≤ 3 AND prev_streak == 0**: enter LAST-CHANCE mode. New streak = 1. Status = ACTIVE.
   - **delta ≤ 3 AND prev_streak ≥ 1**: enter CONCLUDED mode. New streak = prev_streak + 1. Status = CONCLUDED.
6. Generate appended tasks (write them at the end of the Task Queue section in progress.md using Edit):
   - **EXPAND mode**: For each dim with score < 6, apply hint_action:
     - `BUILD` → `- [ ] PoC: <topic>-<dim-slug>` (e.g., `PoC: stt-latency-bench`). If a PoC for this topic already exists in the queue or scoreboard, instead append `- [ ] PoC: <topic>-<dim-slug>-alt`.
     - `INVESTIGATE` → `- [ ] Investigate: <topic>-<dim-slug> — <specific gap from friction log>`
     - `RETHINK` → `- [ ] Decompose: <topic>` OR `- [ ] Rethink: <topic> (gap: <friction>)`. Pick Decompose if multiple dims are weak; Rethink if one specific dim dominates.
     - `REFOCUS` → `- [ ] Refocus: <topic>` (ONLY this task gets appended; overrides all other dim hints — exclusive).
   - After dim-driven appends, also append `- [ ] Score: <topic>` (re-score after improvements).
   - **LAST-CHANCE mode**: append exactly one task: `- [ ] Improve: <topic> (last chance: <top friction>)`, plus `- [ ] Score: <topic>` to re-verify.
   - **CONCLUDED mode**: append nothing. Topic done.
7. Deduplicate before appending: if `<topic>-<dim-slug>` already appears in the scoreboard or queue (ACTIVE or CONCLUDED), skip that append.
8. Update the scoreboard row for `<topic>` (using Edit) with new total, delta, streak, status.
9. **Return ONE line**:
   ```
   appended N tasks: <comma-list>, Δ=<delta>, streak=<new_streak>, status: ACTIVE|CONCLUDED
   ```

## Critical rules

- REFOCUS dim < 6 OVERRIDES all other hint actions. If REFOCUS triggers, append only `Refocus:` task.
- DO NOT dispatch any other subagent. You only edit progress.md.
- DO NOT modify findings or scores files. Read-only on those.
- A topic CANNOT be marked CONCLUDED in EXPAND mode regardless of streak. Streak only advances in LAST-CHANCE/CONCLUDED branches.
```

- [ ] **Step 2: Verify**

Run: `grep -E '^name:|^model:|^allowed-tools:' plugins/offline-research/agents/expansion-planner.md`
Expected: three lines matching, `model: sonnet`, tools `Read, Edit`.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/agents/expansion-planner.md
git commit -m "feat(offline-research): add expansion-planner subagent definition

Sonnet-model agent that applies plateau math + dimension-aware expansion
rules and appends new tasks to progress.md. Invoked after critique-scorer.
"
```

---

### Task 4: poc-builder agent

**Files:**
- Create: `plugins/offline-research/agents/poc-builder.md`

- [ ] **Step 1: Write poc-builder.md**

```markdown
---
name: poc-builder
description: Builds a Proof-of-Concept artifact for a workshop-loop probe. Writes code/configs/sketches to <probe_dir>/poc/<name>/ and a NOTES.md summarizing what was built, how to run it, and what it proves. Sandbox-aware via $WORKSHOP_CONTAINER env var.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch
model: opus
---

# poc-builder

You build executable artifacts. Sandbox awareness governs whether you may execute code or only write it.

## Inputs (in the dispatch prompt)

- `probe_dir` — absolute path
- `task` — exact task line, one of:
  - `PoC: <name>` — build a new PoC sketch under `<probe_dir>/poc/<name>/`
  - `Build: <name>` — alias for PoC

## Sandbox detection

Run this Bash command at the start of EVERY invocation:

```bash
test -n "$WORKSHOP_CONTAINER" && echo SANDBOXED || echo HOST
```

- If output is `SANDBOXED`: full Bash freedom. You may execute code, run package managers, spawn subprocesses. If the entrypoint set up a `poc` user, use `sudo -u poc` for writes inside `<probe_dir>/poc/`.
- If output is `HOST`: you MAY use read-only Bash (`ls`, `cat`, `find`, `grep`, `file`, `which`, version checks like `python --version`). You MUST NOT execute generated PoC code (no `python script.py`, no `node index.js`, no `cargo run`, no test runners). Annotate `NOTES.md` with `EXECUTION SKIPPED — re-run inside ./launch.sh shell to validate. Code written for future verification.`

## Procedure

1. Detect sandbox mode (see above).
2. Read `<probe_dir>/mission.md` for project context and constraints.
3. Read relevant `<probe_dir>/topics/*.md` and `<probe_dir>/findings/*.md` to understand what's already known. Pick the topic(s) most relevant to the PoC name.
4. Resolve the PoC directory: `<probe_dir>/poc/<name>/`. If it doesn't exist, create it.
5. Build the artifact. Multi-file is fine. Code, configs, test scaffolds, architectural sketches — whatever the task implies. Real, runnable code preferred over pseudocode.
6. Write `<probe_dir>/poc/<name>/NOTES.md`. Structure:
   ```markdown
   # PoC: <name>

   ## What it does
   <2-3 sentences>

   ## How to run
   <commands; if HOST mode, mark these as "to be verified inside ./launch.sh shell">

   ## What it proves (or disproves)
   <hypotheses confirmed or refuted>

   ## Known limitations
   <bullet list>

   ## File map
   - <path>: <purpose>
   - <path>: <purpose>
   ```
7. If SANDBOXED mode: run any quick smoke validation (`python -c "import x; print('ok')"`, syntax checks, dry-run flags). Capture outcomes in NOTES.md under a `## Smoke results` heading. Do NOT run long-running test suites or anything that touches network unless the task explicitly requires it.
8. **Return ONE line**:
   ```
   built poc/<name>/ (N files), entry: poc/<name>/<entrypoint>, notes → poc/<name>/NOTES.md
   ```
   Or if HOST mode: include `(HOST: execution skipped)` at the end.

## Critical rules

- DO NOT modify `progress.md`. Orchestrator handles checkoffs.
- DO NOT write outside `<probe_dir>/poc/<name>/` except for sources.md or contradictions.md (if relevant research happened en route).
- DO NOT make destructive system calls in HOST mode (no `rm`, no `mv` of user files, no installs).
- For HOST mode: if the user wants to actually run the PoC, they'll re-launch you via `./launch.sh shell`. Make that explicit in NOTES.md.
```

- [ ] **Step 2: Verify**

Run: `grep '^model:' plugins/offline-research/agents/poc-builder.md`
Expected: `model: opus`.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/agents/poc-builder.md
git commit -m "feat(offline-research): add poc-builder subagent definition

Opus-model PoC builder with sandbox detection via \$WORKSHOP_CONTAINER.
HOST mode = write-only; SANDBOXED mode = full Bash execution.
"
```

---

### Task 5: synthesizer agent

**Files:**
- Create: `plugins/offline-research/agents/synthesizer.md`

- [ ] **Step 1: Write synthesizer.md**

```markdown
---
name: synthesizer
description: End-of-run synthesis for a workshop-loop probe. Writes <probe_dir>/synthesis.md (cross-topic narrative) and <probe_dir>/README.md (TLDR + navigation + Suggested Reruns retrospective). Handles Synthesize and Final report tasks.
allowed-tools: Read, Glob, Write, Edit
model: opus
---

# synthesizer

You produce the end-of-run artifacts. Two task types: `Synthesize` (mid-run cross-topic narrative) and `Final report` (definitive README).

## Inputs (in the dispatch prompt)

- `probe_dir` — absolute path
- `task` — exact task line: `Synthesize` or `Final report`

## Procedure

1. Read `<probe_dir>/mission.md` (intent + constraints).
2. Glob and read all `<probe_dir>/findings/*.md`.
3. Read `<probe_dir>/progress.md` — extract scoreboard rows (topic, status, total, streak).
4. Read `<probe_dir>/connections.md` if present.
5. Read `<probe_dir>/contradictions.md` if present.
6. Read `<probe_dir>/gaps.md` if present.

### For `Synthesize` task

Write or overwrite `<probe_dir>/synthesis.md`. Structure:

```markdown
# Synthesis

## Cross-topic narrative
<2-4 paragraphs weaving the findings into a coherent story>

## Key insights
- bullet
- bullet

## Resolved contradictions
- <contradiction summary>: <how the body of findings resolves it, or "still open">

## Remaining tensions
- bullet
```

### For `Final report` task

1. First do everything in `Synthesize` (if synthesis.md is missing or older than the most recent finding, regenerate it).
2. Then write `<probe_dir>/README.md`. Structure:

```markdown
# <Mission Title>

> Run: <ISO date> — <N topics, M iterations>

## TLDR
<3-5 sentence executive summary>

## Topic findings

### <topic-1> — <status> (score: T/M)
<2-3 sentence summary> → see [findings/<topic-1>.md](findings/<topic-1>.md)

### <topic-2> ...

## Cross-topic insights
<reference connections.md>

## Open questions
- bullet
- bullet

## Suggested Reruns
<see retrospective procedure below>

## Navigation
- mission: [mission.md](mission.md)
- detailed findings: [findings/](findings/)
- scoring history: [scores/](scores/)
- PoCs: [poc/](poc/)
- sources: [sources.md](sources.md)
- contradictions: [contradictions.md](contradictions.md)
- connections: [connections.md](connections.md)
- gaps: [gaps.md](gaps.md)
- synthesis: [synthesis.md](synthesis.md)
```

3. **Rubric retrospective** for `Suggested Reruns` section: scan scoreboard for plateau anomalies.
   - Topic marked CONCLUDED with `total < 60% of max`:
     ```
     - **<topic>** plateaued at <total>/<max> after N rounds. Score floor came from
       `<weakest dim>` (<that dim's score>/10 across rounds). Current rubric anchor for
       this dim may undervalue the constraint that matters most for this topic — consider
       rerunning with <weakest dim> weighted higher or with a stricter anchor at 0/10.
     ```
   - Topic that hit first plateau at Δ ≤ 1 from initial score (suspicious):
     ```
     - **<topic>**: first plateau Δ=<delta> from <prev> → <current>. Rubric's `<dim>`
       (currently <hint_action>) may need a different hint tag — improvements asked for
       <hint_action-implied work> when the gap appears to be <alternative-work>.
     ```
   - No anomalies? Write `No rubric anomalies detected.`
4. **Return ONE line** for `Synthesize`:
   ```
   wrote synthesis.md, key insights: N, tensions: N
   ```
   For `Final report`:
   ```
   wrote synthesis.md, README.md updated, retro-suggestions: N
   ```

## Critical rules

- Do NOT modify progress.md.
- Do NOT touch findings/*.md — those are the authoritative per-topic outputs.
- For Final report: the README is the user-facing entry point. Make it skim-able. Heavy detail belongs in synthesis.md and findings/.
- Suggested Reruns are SUGGESTIONS only. Do not modify scoring-rubric.md.
```

- [ ] **Step 2: Verify**

Run: `grep -E '^name:|^description:' plugins/offline-research/agents/synthesizer.md`
Expected: name = synthesizer, description references README + Suggested Reruns.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/agents/synthesizer.md
git commit -m "feat(offline-research): add synthesizer subagent definition

Opus-model agent for Synthesize + Final report tasks. Writes synthesis.md
and README.md (with rubric-retrospective Suggested Reruns section).
Closes the 5-agent suite for v3.0.0.
"
```

---

## Phase 2 — Templates v2 (slimmed seed files)

### Task 6: research-probe templates (mission.md + progress.md update)

**Files:**
- Create: `plugins/offline-research/templates/research-probe/mission.md`
- Modify: `plugins/offline-research/templates/research-probe/progress.md` (add `max_iter:` header)
- Keep unchanged: `plugins/offline-research/templates/research-probe/scoring-rubric.md`

- [ ] **Step 1: Write mission.md**

```markdown
# Research Mission: [TOPIC]

## Intent

[INTENT]

## Constraints

[CONSTRAINTS]

## Workspace layout

```
<probe_dir>/
├── mission.md              # this file
├── progress.md             # scoreboard + task queue (max_iter header)
├── scoring-rubric.md       # dims with 0/5/10 anchors
├── topics/
│   ├── 01-<topic>.md       # sub-questions per topic
│   └── ...
├── findings/               # one file per topic, written by topic-researcher
├── scores/                 # one file per scoring pass, written by critique-scorer
├── poc/                    # PoC artifacts when built
├── sources.md              # running bibliography
├── contradictions.md       # where sources disagree
├── connections.md          # cross-topic insights (lazy)
├── gaps.md                 # self-critique
├── synthesis.md            # mid/end-of-run narrative (synthesizer)
└── README.md               # final TLDR + navigation (synthesizer)
```

Run with: `/workshop-loop <this-dir>`
```

- [ ] **Step 2: Modify progress.md — add max_iter header at the top**

Open `plugins/offline-research/templates/research-probe/progress.md` and replace the first line `# Research Progress` with:

```markdown
max_iter: [MAX_ITER]
max_parallel: 4

# Research Progress
```

Then remove the embedded loop instruction line `> For every Critique & Score task...` since the agent owns that procedure now.

The full updated `progress.md` should be:

```markdown
max_iter: [MAX_ITER]
max_parallel: 4

# Research Progress

## Scoreboard
| Topic | Status | Src | Depth | Action | Cohere | Confid | Total | Δ | Streak |
|-------|--------|-----|-------|--------|--------|--------|-------|---|--------|
[TOPIC_SCOREBOARD]

## Task Queue

- [ ] Expand scope: all topics (create topic files in topics/)
- [ ] Survey: all topics (skim sources, log in sources.md)
[TOPIC_RESEARCH]
- [ ] Synthesize
[TOPIC_CRITIQUE]
- [ ] Synthesize
- [ ] Final report
```

- [ ] **Step 3: Verify scoring-rubric.md is unchanged for research-probe**

Run: `head -3 plugins/offline-research/templates/research-probe/scoring-rubric.md`
Expected: starts with `# Scoring Rubric`, unchanged from v1.

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/templates/research-probe/mission.md plugins/offline-research/templates/research-probe/progress.md
git commit -m "feat(offline-research): add v2 research-probe templates

Add mission.md (replaces prompt.md). Update progress.md with max_iter and
max_parallel headers. Remove embedded loop instructions (now in
agents/topic-researcher.md and agents/critique-scorer.md).
"
```

---

### Task 7: arch-forge templates

**Files:**
- Create: `plugins/offline-research/templates/arch-forge/mission.md`
- Modify: `plugins/offline-research/templates/arch-forge/progress.md` (add `max_iter:` header)
- Keep unchanged: `plugins/offline-research/templates/arch-forge/scoring-rubric.md`

- [ ] **Step 1: Write mission.md**

```markdown
# Architecture: [PROJECT_NAME]

## Intent

[PROJECT_INTENT]

## Constraints

[CONSTRAINTS]

## Sketch architecture

[ARCHITECTURE_SKETCH]

## Workspace layout

```
<probe_dir>/
├── mission.md              # this file
├── progress.md             # scoreboard + task queue
├── scoring-rubric.md       # Alignment/Feasibility/Maintainability/Risk/Effort
├── topics/                 # one file per decision area (called "topics/" for tool-uniformity)
│   ├── 01-<decision>.md
│   └── ...
├── findings/               # one file per decision, written by topic-researcher (Explore tasks)
├── scores/                 # critique-scorer output
├── poc/                    # PoCs for Feasibility BUILD tags
├── sources.md
├── contradictions.md
├── connections.md
├── gaps.md
├── synthesis.md
└── README.md
```

Run with: `/workshop-loop <this-dir>`
```

- [ ] **Step 2: Modify progress.md** — add header lines at top:

Read the current arch-forge progress.md first to see its exact shape, then prepend:

```markdown
max_iter: [MAX_ITER]
max_parallel: 4

```

And remove any embedded "How This Works" instruction blocks if present (since the orchestrator owns that).

- [ ] **Step 3: Verify scoring-rubric.md is unchanged for arch-forge**

Run: `grep -E 'Alignment|Feasibility|Maintainability|Risk|Effort' plugins/offline-research/templates/arch-forge/scoring-rubric.md | head -5`
Expected: 5 dimension names present.

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/templates/arch-forge/mission.md plugins/offline-research/templates/arch-forge/progress.md
git commit -m "feat(offline-research): add v2 arch-forge templates

Add mission.md. Update progress.md with max_iter and max_parallel headers.
Drop embedded loop instructions (now in agents).
"
```

---

### Task 8: refactor-probe templates (scoring-rubric folds hint_action column)

**Files:**
- Create: `plugins/offline-research/templates/refactor-probe/mission.md`
- Modify: `plugins/offline-research/templates/refactor-probe/progress.md` (add `max_iter:` header)
- Modify: `plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md` (add `hint_action` column)

- [ ] **Step 1: Write mission.md**

```markdown
# Refactor Experiment: [TITLE]

## Intent

[GOALS]

## Codebase context

[CODEBASE_CONTEXT]

## Workspace layout

```
<probe_dir>/
├── mission.md              # this file
├── progress.md             # scoreboard + task queue (max_iter header)
├── scoring-rubric.md       # co-designed dims with hint_action column
├── codebase/               # copy of target codebase (read-only for non-sandbox)
├── topics/
│   ├── 01-<topic>.md
│   └── ...
├── findings/
├── scores/
├── poc/                    # PoCs for BUILD-tagged dims
├── sources.md
├── contradictions.md
├── connections.md
├── gaps.md
├── synthesis.md
└── README.md
```

Run with: `/workshop-loop <this-dir>` for write-only HOST mode, or sandbox via:

```bash
./containers/workshop/launch.sh build --container=refactor
./containers/workshop/launch.sh shell --container=refactor <this-dir>
# inside container shell:
claude
# in Claude Code:
/workshop-loop /workspace
```
```

- [ ] **Step 2: Modify progress.md** — prepend header lines:

```markdown
max_iter: [MAX_ITER]
max_parallel: 4

```

- [ ] **Step 3: Modify scoring-rubric-template.md — add `hint_action` column**

Replace the dimension table placeholder. The new template should have this structure:

```markdown
# Scoring Rubric

You MUST read this file completely before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption.

## Your Role

You are a quality probe for codebase refactoring experiments. You will receive one topic's exploration output — research, PoC code, analysis, trade-off documentation. Your job: read it as a skeptical senior engineer and score how well this exploration holds up.

**Always evaluate relative to the goals provided.**
**Be curious.**

## Scoring Dimensions (each 0-10, max [MAX_SCORE])

| Dimension | hint_action | 0 | 5 | 10 |
|-----------|-------------|---|---|-----|
[DIMENSIONS_WITH_HINT_ACTION]

> **Note for critique-scorer**: ignore the `hint_action` column when scoring. It is read by expansion-planner only.

## Friction-Based Deduction

[friction-based-deduction body unchanged from v1]

## Output Format

```
## Scores ([MAX_SCORE] max)
[SCORE_FORMAT]
- **Total: N/[MAX_SCORE]**

## Friction Log
- [dimension affected]: "description of what caused friction"
...

## What's Missing
- gap, unknown, or untested assumption
...

## What's Strong
- what works well and should be preserved
...
```
```

The `[DIMENSIONS_WITH_HINT_ACTION]` placeholder gets filled by `/refactor-probe` Step 4d (rubric co-design) with rows like:

```
| Migration Safety | BUILD | No migration path | Path exists but untested | Incremental migration demonstrated |
| Backwards Compat | INVESTIGATE | Will break clients | Some compat, gaps identified | Full compatibility plan |
| Complexity Reduction | RETHINK | Adds complexity | Neutral | Measurably simpler |
| Test Coverage | BUILD | None | Unit only | Full harness |
| Rollback Viability | INVESTIGATE | No revert path | Manual w/ data loss risk | Automated, zero loss |
```

- [ ] **Step 4: Verify hint_action column reads correctly**

Run: `head -25 plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md | grep -i hint_action`
Expected: at least one match showing the column header.

- [ ] **Step 5: Commit**

```bash
git add plugins/offline-research/templates/refactor-probe/mission.md plugins/offline-research/templates/refactor-probe/progress.md plugins/offline-research/templates/refactor-probe/scoring-rubric-template.md
git commit -m "feat(offline-research): add v2 refactor-probe templates

Add mission.md. Update progress.md with max_iter/max_parallel headers.
Fold hint_action column into scoring-rubric (was separate
expansion-loop.md in v1).
"
```

---

## Phase 3 — Validation script + tests

### Task 9: validate-probe-dir.sh

**Files:**
- Create: `plugins/offline-research/scripts/validate-probe-dir.sh`
- Create: `plugins/offline-research/scripts/test-validate-probe-dir.sh` (test harness)

- [ ] **Step 1: Create scripts directory and write the test harness FIRST (TDD)**

```bash
mkdir -p plugins/offline-research/scripts
```

Write `plugins/offline-research/scripts/test-validate-probe-dir.sh`:

```bash
#!/bin/bash
# Test harness for validate-probe-dir.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-probe-dir.sh"
PASS=0
FAIL=0

assert_exit() {
    local desc="$1" expected="$2" cmd="$3"
    local actual
    eval "$cmd" > /tmp/vpd-test-out.$$ 2>&1
    actual=$?
    if [[ "$actual" == "$expected" ]]; then
        echo "✓ $desc (exit $actual)"
        PASS=$((PASS+1))
    else
        echo "✗ $desc — expected exit $expected, got $actual"
        echo "    output:"
        sed 's/^/      /' /tmp/vpd-test-out.$$
        FAIL=$((FAIL+1))
    fi
    rm -f /tmp/vpd-test-out.$$
}

# Setup test probe dirs
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

# Case A: missing args
assert_exit "no args → exit 2" 2 "$SCRIPT"

# Case B: nonexistent probe dir
assert_exit "nonexistent dir → exit 1" 1 "$SCRIPT $TMP/does-not-exist"

# Case C: probe dir exists but missing required files
mkdir -p "$TMP/empty-probe"
assert_exit "empty probe dir → exit 1" 1 "$SCRIPT $TMP/empty-probe"

# Case D: probe dir with mission.md only
mkdir -p "$TMP/half-probe"
echo "# mission" > "$TMP/half-probe/mission.md"
assert_exit "missing progress.md → exit 1" 1 "$SCRIPT $TMP/half-probe"

# Case E: probe dir with mission + progress (no max_iter header)
echo "# Progress" > "$TMP/half-probe/progress.md"
echo "- [ ] task" >> "$TMP/half-probe/progress.md"
echo "# rubric" > "$TMP/half-probe/scoring-rubric.md"
assert_exit "missing max_iter header → exit 1" 1 "$SCRIPT $TMP/half-probe"

# Case F: valid probe dir with active work
cat > "$TMP/half-probe/progress.md" <<EOF
max_iter: 30
max_parallel: 4

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [ ] Research: topic1
EOF
assert_exit "valid probe → exit 0" 0 "$SCRIPT $TMP/half-probe"

# Case G: --max-iter override
assert_exit "valid + --max-iter 50 → exit 0" 0 "$SCRIPT $TMP/half-probe --max-iter 50"
grep -q 'max_iter: 50' "$TMP/half-probe/progress.md" && \
    { echo "✓ --max-iter override applied"; PASS=$((PASS+1)); } || \
    { echo "✗ --max-iter override NOT applied"; FAIL=$((FAIL+1)); }

# Case H: bad --max-iter (negative)
assert_exit "--max-iter -5 → exit 2" 2 "$SCRIPT $TMP/half-probe --max-iter -5"

# Case I: bad --max-iter (non-numeric)
assert_exit "--max-iter abc → exit 2" 2 "$SCRIPT $TMP/half-probe --max-iter abc"

# Case J: terminal state probe (no pending, no active)
cat > "$TMP/half-probe/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | CONCLUDED | 10 | 9 | 8 | 7 | 6 | 40 | 1 | 2 |
## Task Queue
- [x] Research: topic1
EOF
assert_exit "terminal-state probe → exit 3" 3 "$SCRIPT $TMP/half-probe"

echo
echo "Results: $PASS pass, $FAIL fail"
[[ $FAIL -eq 0 ]]
```

Mark executable:

```bash
chmod +x plugins/offline-research/scripts/test-validate-probe-dir.sh
```

- [ ] **Step 2: Run the test harness to verify it fails (script doesn't exist yet)**

Run: `bash plugins/offline-research/scripts/test-validate-probe-dir.sh`
Expected: FAIL on every assertion (script not found).

- [ ] **Step 3: Write validate-probe-dir.sh**

```bash
#!/bin/bash
# validate-probe-dir.sh — sanity-check a workshop-loop probe directory
# Exit codes:
#   0 — valid (emits VALIDATED line on stdout for command body to parse)
#   1 — missing/corrupt required files or headers
#   2 — bad CLI args
#   3 — probe-dir already in terminal state (nothing to do)

set -uo pipefail

usage() { echo "Usage: validate-probe-dir.sh <probe-dir> [--max-iter N]" >&2; exit 2; }

[[ $# -ge 1 ]] || usage
PROBE_DIR="$1"; shift
MAX_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-iter)
            [[ -n "${2:-}" ]] || { echo "❌ --max-iter requires a number" >&2; exit 2; }
            [[ "$2" =~ ^[1-9][0-9]*$ ]] || { echo "❌ --max-iter must be a positive integer, got: $2" >&2; exit 2; }
            MAX_OVERRIDE="$2"; shift 2 ;;
        *)
            echo "❌ unknown arg: $1" >&2; usage ;;
    esac
done

# Resolve to absolute path
PROBE_DIR_ABS="$(cd "$PROBE_DIR" 2>/dev/null && pwd)" || {
    echo "❌ probe-dir not found: $PROBE_DIR" >&2; exit 1; }
PROBE_DIR="$PROBE_DIR_ABS"

# Required files
for f in mission.md progress.md scoring-rubric.md; do
    [[ -f "$PROBE_DIR/$f" ]] || {
        echo "❌ missing $f in $PROBE_DIR — did you run a probe skill first?" >&2
        exit 1
    }
done

# progress.md must have max_iter header
HEADER_MAX=$(grep -m1 '^max_iter:' "$PROBE_DIR/progress.md" | sed 's/max_iter: *//' | tr -d '[:space:]')
[[ "$HEADER_MAX" =~ ^[0-9]+$ ]] || {
    echo "❌ progress.md missing or invalid 'max_iter: N' header" >&2; exit 1; }

# Apply --max-iter override
if [[ -n "$MAX_OVERRIDE" ]]; then
    # Portable in-place edit (works on macOS + Linux)
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^max_iter:.*/max_iter: $MAX_OVERRIDE/" "$PROBE_DIR/progress.md"
    else
        sed -i "s/^max_iter:.*/max_iter: $MAX_OVERRIDE/" "$PROBE_DIR/progress.md"
    fi
    HEADER_MAX="$MAX_OVERRIDE"
fi

# Sanity: at least one unchecked task or active row
PENDING=$(grep -c '^- \[ \]' "$PROBE_DIR/progress.md" || echo 0)
ACTIVE=$(grep -c '| ACTIVE |' "$PROBE_DIR/progress.md" || echo 0)
if [[ $PENDING -eq 0 && $ACTIVE -eq 0 ]]; then
    echo "ℹ️  probe-dir is already in terminal state (no pending tasks, no active rows). Nothing to do." >&2
    exit 3
fi

echo "VALIDATED probe_dir=$PROBE_DIR max_iter=$HEADER_MAX pending=$PENDING active=$ACTIVE"
exit 0
```

Mark executable:

```bash
chmod +x plugins/offline-research/scripts/validate-probe-dir.sh
```

- [ ] **Step 4: Run the test harness to verify it passes**

Run: `bash plugins/offline-research/scripts/test-validate-probe-dir.sh`
Expected: `Results: 11 pass, 0 fail`. Script exits 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/offline-research/scripts/validate-probe-dir.sh plugins/offline-research/scripts/test-validate-probe-dir.sh
git commit -m "feat(offline-research): add validate-probe-dir.sh + tests

Param validation for /workshop-loop. Exit codes:
 0 valid (emits VALIDATED line), 1 missing/corrupt files, 2 bad args,
 3 terminal-state probe. Test harness covers 11 cases.
"
```

---

## Phase 4 — Stop hook

### Task 10: workshop-loop-stop.sh (the hook script)

**Files:**
- Create: `plugins/offline-research/hooks/workshop-loop-stop.sh`
- Create: `plugins/offline-research/hooks/test-workshop-loop-stop.sh` (test harness)

- [ ] **Step 1: Create hooks dir and write the test harness FIRST**

```bash
mkdir -p plugins/offline-research/hooks
```

Write `plugins/offline-research/hooks/test-workshop-loop-stop.sh`:

```bash
#!/bin/bash
# Test harness for workshop-loop-stop.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")" && pwd)/workshop-loop-stop.sh"
PASS=0
FAIL=0

assert_decision() {
    local desc="$1" expected_decision="$2" hook_input="$3"
    local out
    out=$(echo "$hook_input" | bash "$HOOK" 2>/dev/null || true)
    local actual_decision
    actual_decision=$(echo "$out" | jq -r '.decision // "release"' 2>/dev/null || echo "release")
    if [[ "$actual_decision" == "$expected_decision" ]]; then
        echo "✓ $desc (decision: $actual_decision)"
        PASS=$((PASS+1))
    else
        echo "✗ $desc — expected $expected_decision, got $actual_decision"
        echo "    raw output: $out"
        FAIL=$((FAIL+1))
    fi
}

# Setup test fixtures
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT
PROBE="$TMP/probe"
mkdir -p "$PROBE"

# Build a transcript fixture
mk_transcript() {
    local file="$1"; shift
    : > "$file"
    while [[ $# -gt 0 ]]; do
        local role="$1" text="$2"
        echo "{\"role\":\"$role\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":$(jq -Rs . <<< "$text")}]}}" >> "$file"
        shift 2
    done
}

# Case A: no transcript path → release
assert_decision "no transcript_path → release" "release" '{}'

# Case B: empty transcript → release
TR="$TMP/empty.jsonl"
: > "$TR"
assert_decision "empty transcript → release" "release" "{\"transcript_path\":\"$TR\"}"

# Case C: transcript without any marker → release
mk_transcript "$TMP/no-marker.jsonl" "assistant" "hello world, no marker here"
assert_decision "no marker → release" "release" "{\"transcript_path\":\"$TMP/no-marker.jsonl\"}"

# Case D: done marker most recent → release
mk_transcript "$TMP/done.jsonl" \
    "assistant" "[workshop-loop-active] probe_dir=$PROBE" \
    "assistant" "[workshop-loop-done] probe_dir=$PROBE"
assert_decision "done marker → release" "release" "{\"transcript_path\":\"$TMP/done.jsonl\"}"

# Case E: active marker but no progress.md → release
mk_transcript "$TMP/active-no-prog.jsonl" \
    "assistant" "[workshop-loop-active] probe_dir=$PROBE"
assert_decision "active marker no progress.md → release" "release" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case F: active + progress with work pending → block
cat > "$PROBE/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [ ] Research: topic1
EOF
assert_decision "active + pending work → block" "block" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case G: active + queue empty + no active rows → release
cat > "$PROBE/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | CONCLUDED | 10 | 9 | 8 | 7 | 6 | 40 | 1 | 2 |
## Task Queue
- [x] Research: topic1
EOF
assert_decision "all CONCLUDED + queue empty → release" "release" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case H: active + iter >= max_iter → release
cat > "$PROBE/progress.md" <<EOF
max_iter: 2

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [x] task A
- [x] task B
- [ ] task C
EOF
assert_decision "iter >= max_iter → release" "release" "{\"transcript_path\":\"$TMP/active-no-prog.jsonl\"}"

# Case I: active + RUN COMPLETE promise in last assistant text → release
cat > "$PROBE/progress.md" <<EOF
max_iter: 30

# Progress
## Scoreboard
| topic1 | ACTIVE | - | - | - | - | - | - | - | 0 |
## Task Queue
- [ ] Research: topic1
EOF
mk_transcript "$TMP/promise.jsonl" \
    "assistant" "[workshop-loop-active] probe_dir=$PROBE" \
    "assistant" "All done. <promise>RUN COMPLETE</promise>"
assert_decision "RUN COMPLETE promise → release" "release" "{\"transcript_path\":\"$TMP/promise.jsonl\"}"

echo
echo "Results: $PASS pass, $FAIL fail"
[[ $FAIL -eq 0 ]]
```

Mark executable:

```bash
chmod +x plugins/offline-research/hooks/test-workshop-loop-stop.sh
```

- [ ] **Step 2: Run the test to verify it fails (hook doesn't exist)**

Run: `bash plugins/offline-research/hooks/test-workshop-loop-stop.sh`
Expected: all 9 cases FAIL (hook script not found).

- [ ] **Step 3: Write workshop-loop-stop.sh**

```bash
#!/bin/bash
# workshop-loop-stop.sh — Stop hook for the offline-research workshop-loop.
# Reads transcript for [workshop-loop-active|done] markers, derives loop state
# from <probe-dir>/progress.md, and either releases (exit 0) or blocks
# (emits {"decision":"block","reason":...} JSON to stdout).

set -uo pipefail

HOOK_INPUT=$(cat)
TRANSCRIPT=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
[[ -f "$TRANSCRIPT" ]] || exit 0

# Find most recent marker (active or done) in assistant text blocks
LAST_MARKER=$(grep '"role":"assistant"' "$TRANSCRIPT" 2>/dev/null | tail -n 200 | \
  jq -rs 'map(.message.content[]? | select(.type=="text") | .text) | join("\n")' 2>/dev/null | \
  grep -oE '\[workshop-loop-(active|done)\] probe_dir=\S+' | tail -n 1)

[[ -z "$LAST_MARKER" ]] && exit 0
# Done marker most recent → post-run chat → fast release
echo "$LAST_MARKER" | grep -q 'workshop-loop-done' && exit 0

# Active marker — extract probe_dir
PROBE_DIR=$(echo "$LAST_MARKER" | sed 's/.*probe_dir=//')
PROGRESS="$PROBE_DIR/progress.md"
[[ -f "$PROGRESS" ]] || exit 0   # probe-dir vanished or never set up

# Derive state from progress.md
MAX_ITER=$(grep -m1 '^max_iter:' "$PROGRESS" | sed 's/max_iter: *//' | tr -d '[:space:]')
[[ -z "$MAX_ITER" ]] && MAX_ITER=999
ITER=$(grep -c '^- \[x\]' "$PROGRESS" 2>/dev/null || echo 0)
PENDING=$(grep -c '^- \[ \]' "$PROGRESS" 2>/dev/null || echo 0)
ACTIVE_ROWS=$(grep -c '| ACTIVE |' "$PROGRESS" 2>/dev/null || echo 0)

# Last assistant text for promise check
LAST_TEXT=$(grep '"role":"assistant"' "$TRANSCRIPT" 2>/dev/null | tail -n 50 | \
  jq -rs 'map(.message.content[]? | select(.type=="text") | .text) | last // ""' 2>/dev/null || echo "")
PROMISE=$(echo "$LAST_TEXT" | perl -0777 -ne 'print $1 if /<promise>\s*(RUN COMPLETE)\s*<\/promise>/s' 2>/dev/null || echo "")

# Termination tests (any one releases)
if [[ "$PROMISE" == "RUN COMPLETE" ]]; then
    echo "✅ workshop-loop: RUN COMPLETE (iter $ITER)" >&2
    exit 0
fi
if [[ $PENDING -eq 0 && $ACTIVE_ROWS -eq 0 ]]; then
    echo "✅ workshop-loop: all CONCLUDED, queue empty (iter $ITER)" >&2
    exit 0
fi
if [[ $ITER -ge $MAX_ITER ]]; then
    echo "🛑 workshop-loop: max_iter $MAX_ITER reached" >&2
    exit 0
fi

# Continue — re-feed minimal pointer
REFEED="Read $PROBE_DIR/progress.md. Find the first unchecked task. Dispatch the matching agent per the dispatch table in the workshop-loop command body. After the agent returns, Edit the task line in progress.md from \`[ ]\` to \`[x]\`. If the task was Score: or Critique & Score:, also dispatch expansion-planner with the scorer's return. Then stop."

jq -n --arg p "$REFEED" --arg msg "workshop-loop iter $ITER/$MAX_ITER ($PENDING pending, $ACTIVE_ROWS active)" \
  '{decision:"block", reason:$p, systemMessage:$msg}'

exit 0
```

Mark executable:

```bash
chmod +x plugins/offline-research/hooks/workshop-loop-stop.sh
```

- [ ] **Step 4: Run the test harness to verify it passes**

Run: `bash plugins/offline-research/hooks/test-workshop-loop-stop.sh`
Expected: `Results: 9 pass, 0 fail`. Script exits 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/offline-research/hooks/workshop-loop-stop.sh plugins/offline-research/hooks/test-workshop-loop-stop.sh
git commit -m "feat(offline-research): add workshop-loop-stop.sh hook + tests

Stateless Stop hook. Derives state from progress.md via transcript-based
activation/done markers. Termination conditions: RUN COMPLETE promise,
all rows CONCLUDED + empty queue, or max_iter reached. Test harness
covers 9 cases.
"
```

---

### Task 11: hooks.json registration

**Files:**
- Create: `plugins/offline-research/hooks/hooks.json`

- [ ] **Step 1: Write hooks.json**

```json
{
  "description": "offline-research workshop-loop stop hook (derives state from progress.md)",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/workshop-loop-stop.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `jq . plugins/offline-research/hooks/hooks.json`
Expected: pretty-printed JSON, no errors.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/hooks/hooks.json
git commit -m "feat(offline-research): register workshop-loop-stop.sh as Stop hook

Hooks.json declares the plugin's Stop hook. Auto-loaded when plugin is
enabled. CLAUDE_PLUGIN_ROOT env var resolves to plugin directory.
"
```

---

## Phase 5 — /workshop-loop command

### Task 12: commands/workshop-loop.md

**Files:**
- Create: `plugins/offline-research/commands/workshop-loop.md`

- [ ] **Step 1: Create commands dir and write workshop-loop.md**

```bash
mkdir -p plugins/offline-research/commands
```

Write `plugins/offline-research/commands/workshop-loop.md`:

```markdown
---
description: "Run workshop-loop orchestrator on a probe directory"
argument-hint: "<probe-dir> [--max-iter N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/validate-probe-dir.sh:*)", "Read", "Edit", "Agent"]
---

# Workshop Loop

Validate the probe directory first:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-probe-dir.sh" $ARGUMENTS
```

**If exit code is non-zero, STOP IMMEDIATELY.** Report the error to the user. Do NOT proceed to emit the activation marker or dispatch any agent.

**On success**, the script outputs a line starting with `VALIDATED `. Parse this line to extract:
- `probe_dir=<absolute-path>`
- `max_iter=<n>`
- `pending=<n>`
- `active=<n>`

Then emit this as the **FIRST line of your response** (verbatim, on its own line, with the absolute path):

    [workshop-loop-active] probe_dir=<absolute-probe-dir>

Then begin iteration 1.

---

## Dispatch table

| Task prefix in progress.md | Subagent to dispatch | Notes |
|---|---|---|
| `Research:`, `Explore:`, `Improve:`, `Investigate:`, `Decompose:`, `Refocus:`, `Simplify:`, `Rethink:`, `Connect:` | `topic-researcher` | Parallelizable up to `max_parallel` (default 4) across distinct topics. |
| `Score:`, `Critique & Score:` | `critique-scorer` **then** `expansion-planner` (sequential, scorer first) | Runs alone (never in parallel). expansion-planner is dispatched AFTER scorer returns, with the scorer's return data passed in the prompt. |
| `PoC:`, `Build:` | `poc-builder` | Runs alone. |
| `Synthesize` | `synthesizer` | Runs alone. |
| `Final report` | `synthesizer` | Runs alone. Last task of the run. |

---

## Iteration procedure

1. **Read** `<probe_dir>/progress.md`.
2. **Find the first unchecked task** matching `^- \[ \]` in the Task Queue section.
3. **Classify** the task by prefix using the dispatch table.
4. **Parallelizable batch?** If the task is parallelizable AND there are additional parallelizable tasks for *different* topics in the queue (no two tasks for the same topic), collect up to `max_parallel` such tasks. Dispatch all of them in a single Agent tool call with multiple parallel content blocks.
5. **Otherwise**, dispatch the single matching subagent.
6. **On agent return(s):**
   - For each returned agent, Edit the corresponding task line in progress.md from `- [ ]` to `- [x]`. Use the Edit tool with a single-line replacement per task.
   - If the task was `Score:` or `Critique & Score:`: immediately dispatch `expansion-planner` (sequential, single dispatch), passing `probe_dir`, `topic`, and `score_path` (from scorer's return). Wait for expansion-planner to return before proceeding.
   - If a parallel agent failed (returned an error or didn't produce expected output), leave its task line as `- [ ]`. It will be retried next iteration.
7. **Re-read** `<probe_dir>/progress.md`.
8. **Check for natural completion**: if `grep -c '^- \[ \]' progress.md == 0` AND no row in the Scoreboard table contains `| ACTIVE |`:
   - Emit on separate lines:
     ```
     <promise>RUN COMPLETE</promise>
     [workshop-loop-done] probe_dir=<absolute-probe-dir>
     ```
   - Then stop.
9. **Otherwise, just stop.** The Stop hook will re-fire and either release (max_iter hit, etc.) or feed back a continuation prompt for iteration N+1.

---

## Agent dispatch prompts

When invoking an agent via the Agent tool, pass these fields in the dispatch prompt:

- `topic-researcher`: `probe_dir=<abs>`, `task=<exact-task-line>`.
- `critique-scorer`: `probe_dir=<abs>`, `topic=<slug>`, `is_poc=<true|false>` (true if the task targets a `poc/` topic).
- `expansion-planner`: `probe_dir=<abs>`, `topic=<slug>`, `score_path=<abs path returned by scorer>`.
- `poc-builder`: `probe_dir=<abs>`, `task=<exact-task-line>`.
- `synthesizer`: `probe_dir=<abs>`, `task=Synthesize|Final report`.

Each agent's full procedure lives in its own agent file. Do not duplicate procedures here.

---

## Critical rules

- DO NOT emit `<promise>RUN COMPLETE</promise>` speculatively. The promise is for genuine completion only. The Stop hook enforces continuation regardless.
- DO NOT modify scoring-rubric.md, mission.md, or topic files. Those are seed inputs.
- DO NOT read findings/*.md or scores/*.md content into your own context. Subagents handle that material; trust their return summaries.
- DO NOT dispatch agents not in the dispatch table.
- For parallel batches, ALL must be the same task-prefix family (Research/Improve/Investigate/Explore/Connect mix is fine; never mix with Score/PoC/Synthesize).
```

- [ ] **Step 2: Verify frontmatter**

Run: `head -8 plugins/offline-research/commands/workshop-loop.md`
Expected: YAML frontmatter with `description`, `argument-hint`, `allowed-tools`.

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/commands/workshop-loop.md
git commit -m "feat(offline-research): add /workshop-loop slash command

Master orchestrator. Invokes validate-probe-dir.sh, emits activation
marker, dispatches one of 5 subagents per task. Supports parallel
batches of up to max_parallel (default 4) for distinct-topic
Research/Improve/Investigate/Explore/Connect tasks. Stop hook drives
the loop.
"
```

---

## Phase 6 — Probe skill updates

### Task 13: research-probe SKILL.md updates

**Files:**
- Modify: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Read the current SKILL.md to confirm line numbers**

```bash
grep -n -E 'launch.sh|ralph-loop|--container=|prompt.md|critique-loop|~/offline-research|How do you want' plugins/offline-research/skills/research-probe/SKILL.md
```

Note the line ranges you'll need to edit.

- [ ] **Step 2: Replace the seed-file location prompt section**

Find the existing "Where should I write the research files?" block (around the `Step 5: Generate` section) and replace it with:

```markdown
Ask the user (and **wait for their response before proceeding**):

> Where should I write the research files?
> 1. `<cwd>/<short-title>/`  (Recommended — keeps probe co-located with the project that has the plugin installed)
> 2. `~/offline-research/<short-title>/`
> 3. Type a custom path

Get the current date via `date +%Y-%m-%d`. Determine git root via `git rev-parse --show-toplevel 2>/dev/null`. CWD = `$(pwd)` from a Bash invocation. Derive `<short-title>` as a kebab-case slug from the mission.
```

- [ ] **Step 3: Update the templates read step**

Find the "Read templates" block and replace with:

```markdown
**Read templates:**
- Read `<plugin-root>/templates/research-probe/mission.md`
- Read `<plugin-root>/templates/research-probe/progress.md`
- Read `<plugin-root>/templates/research-probe/scoring-rubric.md`
```

(Remove the `critique-loop.md` read — it no longer exists.)

- [ ] **Step 4: Update the Fill steps**

Find the `**Fill prompt.md:**` block and replace it with `**Fill mission.md:**`. Update the placeholders:

```markdown
**Fill mission.md:**
- Replace `[TOPIC]` with the research mission title
- Replace `[INTENT]` with one paragraph describing what the user wants to learn and why
- Replace `[CONSTRAINTS]` with the user's hard boundaries (or "None specified" if none)
```

And the topic list (originally in prompt.md) becomes individual files. Insert this new step:

```markdown
**Write topics/ files:** For each refined topic, write `<probe-dir>/topics/NN-<topic-slug>.md` (zero-padded ordinal, kebab slug). Content:

```
# <Topic Name>

## Sub-questions
- <question>
- <question>

## Why this matters
<one-line rationale>
```
```

Then keep the existing `**Fill progress.md:**` step but add a new placeholder fill:

```markdown
**Fill progress.md:**
- Replace `[MAX_ITER]` in the header with the computed value: `topics × 8 + 10`
- Replace `[TOPIC_SCOREBOARD]` with one row per topic (unchanged from v1)
- Replace `[TOPIC_RESEARCH]` with one line per topic (unchanged)
- Replace `[TOPIC_CRITIQUE]` with one line per topic (unchanged)
```

Remove the `**Write `critique-loop.md`**` line entirely.

- [ ] **Step 5: Replace the run-options section**

Find the "Present three run options" block and replace with:

```markdown
**Present two run options (without showing commands yet):**

Derive `<folder-name>` from the last path segment of the user's chosen directory.

> **How do you want to run this research?**
> 1. `/workshop-loop` in the current Claude Code session (Recommended)
> 2. `/workshop-loop` inside a sandboxed container (only needed for PoC code execution; research-probe rarely needs this)

After the user picks, print only the selected command:

- **Option 1 (recommended)**:
  ```
  /workshop-loop <probe-dir>
  ```

- **Option 2 (sandbox)**:
  ```
  ./containers/workshop/launch.sh build --container=research
  ./containers/workshop/launch.sh shell --container=research <probe-dir>
  # inside the container shell:
  claude
  # in Claude Code:
  /workshop-loop /workspace
  ```

Replace `<probe-dir>` with the user's chosen directory (absolute path).
```

Remove all `--max-iterations` flag emission and the old `./launch.sh run` command lines.

- [ ] **Step 6: Verify all references to v1 artifacts are gone**

Run: `grep -nE 'critique-loop\.md|launch\.sh run|/ralph-loop:|prompt\.md' plugins/offline-research/skills/research-probe/SKILL.md`
Expected: no matches (or only matches inside a CHANGELOG-style historical comment, which we don't have). If any remain, fix them.

- [ ] **Step 7: Commit**

```bash
git add plugins/offline-research/skills/research-probe/SKILL.md
git commit -m "feat(research-probe): switch to /workshop-loop, cwd-first locations

- Final run command: /workshop-loop (drops container auto-resume + ralph commands)
- Seed location order: cwd/ > ~/offline-research/ > custom
- Templates: mission.md replaces prompt.md; critique-loop.md removed
- progress.md fills max_iter header
- Sandbox option points to ./launch.sh shell + interactive claude
"
```

---

### Task 14: arch-forge SKILL.md updates

**Files:**
- Modify: `plugins/offline-research/skills/arch-forge/SKILL.md`

- [ ] **Step 1: Read current SKILL.md**

```bash
grep -n -E 'launch.sh|ralph-loop|--container=|prompt.md|expansion-loop|~/offline-research' plugins/offline-research/skills/arch-forge/SKILL.md
```

- [ ] **Step 2: Replace seed-file location prompt**

Find the existing block and replace with the same cwd-first ordering as Task 13 Step 2 (substituting "research files" with "seed files" and "research" with "architecture exploration"):

```markdown
> Where should I write the seed files?
> 1. `<cwd>/<short-title>/`  (Recommended)
> 2. `~/offline-research/<short-title>/`
> 3. Type a custom path
```

- [ ] **Step 3: Update Read templates block**

```markdown
**Read templates:**
- Read `<plugin-root>/templates/arch-forge/mission.md`
- Read `<plugin-root>/templates/arch-forge/progress.md`
- Read `<plugin-root>/templates/arch-forge/scoring-rubric.md`
```

(Remove `expansion-loop.md` read.)

- [ ] **Step 4: Update Fill prompts**

Rename `**Fill prompt.md:**` → `**Fill mission.md:**`. Placeholders unchanged: `[PROJECT_NAME]`, `[PROJECT_INTENT]`, `[CONSTRAINTS]`, `[ARCHITECTURE_SKETCH]`.

Add explicit `topics/` file generation step (same pattern as Task 13 Step 4, but topic-files-per-decision instead of per-topic). Content for each `topics/NN-<decision>.md`:

```markdown
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

Update `**Fill progress.md:**`:
```markdown
- Replace `[MAX_ITER]` in the header with: `decisions × 10 + 15`
- Replace `[DECISION_SCOREBOARD]` (unchanged from v1)
- Replace `[DECISION_EXPLORATION]` (unchanged)
- Replace `[DECISION_SCORING]` (unchanged)
```

Remove the `**Write `expansion-loop.md`**` line.

- [ ] **Step 5: Replace the run-options section**

```markdown
**Present two run options:**

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
```

- [ ] **Step 6: Verify no v1 artifacts remain**

Run: `grep -nE 'expansion-loop\.md|launch\.sh run|/ralph-loop:|prompt\.md' plugins/offline-research/skills/arch-forge/SKILL.md`
Expected: no matches.

- [ ] **Step 7: Commit**

```bash
git add plugins/offline-research/skills/arch-forge/SKILL.md
git commit -m "feat(arch-forge): switch to /workshop-loop, cwd-first locations

Same shape as research-probe v2 update: mission.md replaces prompt.md,
expansion-loop.md removed (logic in agents), cwd-first ordering, final
command is /workshop-loop with optional sandbox via ./launch.sh shell.
"
```

---

### Task 15: refactor-probe SKILL.md updates

**Files:**
- Modify: `plugins/offline-research/skills/refactor-probe/SKILL.md`

- [ ] **Step 1: Read current SKILL.md**

```bash
grep -n -E 'launch.sh|ralph-loop|--container=|prompt.md|expansion-loop|~/offline-research|How do you want' plugins/offline-research/skills/refactor-probe/SKILL.md
```

- [ ] **Step 2: Replace seed-file location prompt**

```markdown
> Where should I write the seed files?
> 1. `<cwd>/<short-title>/`  (Recommended)
> 2. `~/offline-research/<short-title>/`
> 3. Type a custom path
```

- [ ] **Step 3: Update Read templates block**

```markdown
Read templates from `<plugin-root>/templates/refactor-probe/`:
- `mission.md`
- `progress.md`
- `scoring-rubric-template.md`
```

(Remove `expansion-loop.md` read; remove `prompt.md` read.)

- [ ] **Step 4: Update Fill prompts**

Rename `**`prompt.md`** placeholders:` → `**`mission.md`** placeholders:`. The placeholders for v2 mission.md:

```markdown
- `[TITLE]` — experiment title
- `[GOALS]` — refined goals from Phase 3
- `[CODEBASE_CONTEXT]` — structure summary, key files, patterns observed during the survey
```

Add `topics/` files step. For each refined topic, write `<probe-dir>/topics/NN-<topic-slug>.md`:

```markdown
# <Topic Name>

## Sub-questions / angles
- <question>
- <question>

## Codebase touchpoints
- <file or pattern>
- <file or pattern>

## Migration concerns
- <concern>
```

Update `**`progress.md`** placeholders:`:
```markdown
- `[MAX_ITER]` — `topics × 10 + 15`
- `[DIMENSION_HEADERS]` — abbreviated dim names (unchanged from v1)
- `[TOPIC_SCOREBOARD]` — one row per topic (unchanged)
- `[TOPIC_EXPLORATION]` — one line per topic (unchanged)
- `[TOPIC_SCORING]` — one line per topic (unchanged)
```

Remove `**`expansion-loop.md`** placeholders:` entirely.

Update `**`scoring-rubric-template.md`** -- generates `scoring-rubric.md`:`:
```markdown
- `[DIMENSIONS_WITH_HINT_ACTION]` — full dimension table with `hint_action` column AND 0/5/10 anchors from co-design. Format:
  ```
  | <Dimension Name> | <BUILD|INVESTIGATE|RETHINK|REFOCUS> | <0 anchor> | <5 anchor> | <10 anchor> |
  ```
- `[DIMENSION_COUNT]` — number of dimensions
- `[MAX_SCORE]` — dimension count x 10
- `[SCORE_FORMAT]` — one line per dimension: `- <Dimension Name>: N/10`
```

- [ ] **Step 5: Replace the run-options section**

```markdown
**Ask and wait for user's choice:**

> **How do you want to run this refactor exploration?**
> 1. `/workshop-loop` in the current Claude Code session (Recommended for write-only exploration)
> 2. `/workshop-loop` inside a sandboxed container (Recommended if PoCs must execute against the codebase)

**STOP HERE.** Wait for the user to pick 1 or 2.

For both options, the user must first copy their codebase into the probe dir:

```
cp -r <codebase-path> <probe-dir>/codebase
```

**After the user responds**, print ONLY the command for their choice:

**If user picks 1**, print:
```
/workshop-loop <probe-dir>
```

**If user picks 2**, print:
```
./containers/workshop/launch.sh build --container=refactor
./containers/workshop/launch.sh shell --container=refactor <probe-dir>
# inside container shell:
claude
# in Claude Code:
/workshop-loop /workspace
```

Replace `<probe-dir>` with the absolute path.
```

Remove all `/ralph-loop` lines, `--max-iterations` flag, "Do NOT invoke any skills" workaround.

- [ ] **Step 6: Verify**

Run: `grep -nE 'expansion-loop\.md|launch\.sh run|/ralph-loop:|prompt\.md' plugins/offline-research/skills/refactor-probe/SKILL.md`
Expected: no matches.

- [ ] **Step 7: Commit**

```bash
git add plugins/offline-research/skills/refactor-probe/SKILL.md
git commit -m "feat(refactor-probe): switch to /workshop-loop, cwd-first locations

- Final command: /workshop-loop (HOST or via ./launch.sh shell sandbox)
- Seed location order: cwd/ > ~/offline-research/ > custom
- Templates: mission.md replaces prompt.md
- expansion-loop.md template removed (logic in agents/expansion-planner.md)
- scoring-rubric-template.md placeholder updated for hint_action column
"
```

---

## Phase 7 — Container changes

### Task 16: launch.sh — remove `run`, enhance `shell` with probe-dir arg + WORKSHOP_CONTAINER env

**Files:**
- Modify: `containers/workshop/launch.sh`

- [ ] **Step 1: Read launch.sh entirely**

```bash
wc -l containers/workshop/launch.sh
cat containers/workshop/launch.sh
```

Confirm current structure (current `cmd_shell` exists; current `cmd_run` references `RUNNER_SCRIPT`).

- [ ] **Step 2: Remove RUNNER_SCRIPT assignments from the profile case block**

Edit the `case "$PROFILE" in` block (around lines 38-60) to remove the `RUNNER_SCRIPT="..."` line from each branch. The block should become:

```bash
case "$PROFILE" in
    research)
        IMAGE_NAME="workshop-research"
        CONTAINER_NAME="${CONTAINER_NAME:-workshop-research-sandbox}"
        RESOURCE_LIMITS=()
        ;;
    arch)
        IMAGE_NAME="workshop-arch"
        CONTAINER_NAME="${CONTAINER_NAME:-workshop-arch-sandbox}"
        RESOURCE_LIMITS=(--memory=4g --cpus=4 --pids-limit=200)
        ;;
    refactor)
        IMAGE_NAME="workshop-refactor"
        CONTAINER_NAME="${CONTAINER_NAME:-workshop-refactor-sandbox}"
        RESOURCE_LIMITS=(--memory=4g --cpus=4 --pids-limit=200)
        ;;
    *)
        ...unchanged...
        ;;
esac
```

- [ ] **Step 3: Add `WORKSHOP_CONTAINER=1` env to ensure_container**

In `ensure_container()`, find the `RUN_CMD+=(-e "TZ=${TZ}")` line and immediately AFTER it add:

```bash
RUN_CMD+=(-e "WORKSHOP_CONTAINER=1")
```

This is the env var that `poc-builder.md`'s sandbox detection reads.

- [ ] **Step 4: Update `cmd_shell` to accept an optional probe-dir argument**

Replace the current `cmd_shell` function with:

```bash
cmd_shell() {
    local probe_path="${1:-}"

    printf "\n${BOLD}${CYAN}  workshop shell (${PROFILE})${RESET}\n\n"

    # If probe path supplied, override WORKSPACE to mount it as /workspace
    if [[ -n "$probe_path" ]]; then
        if [[ ! -d "$probe_path" ]]; then
            log_err "probe directory does not exist: $probe_path"
            exit 1
        fi
        probe_path="$(cd "$probe_path" && pwd)"
        WORKSPACE="$probe_path"
        log_dim "Mounting $probe_path as /workspace"
    fi

    ensure_container
    echo
    log_dim "📦 You're inside ${BOLD}workshop-${PROFILE}${RESET}${DIM} sandbox at /workspace."
    log_dim "   Run: ${BOLD}claude${RESET}${DIM}"
    log_dim "   Then in Claude Code: ${BOLD}/workshop-loop /workspace${RESET}"
    echo
    docker exec -it --user node "$CONTAINER_NAME" bash
}
```

- [ ] **Step 5: Delete the `cmd_run` function entirely**

Find the `cmd_run() { ... }` function block (between `cmd_setup` and `cmd_shell`) and delete it.

- [ ] **Step 6: Update `cmd_help` to remove the `run` subcommand and document the new `shell <probe-dir>` form**

Find the help block listing commands and update it. Replace the `run` entry with documentation that `run` is removed; update `shell` to show the probe-dir argument:

```bash
    printf "    setup                          Build image + drop into shell for first-time setup\n"
    printf "    shell [<probe-dir>]            Drop into interactive container shell. If <probe-dir> is given,\n"
    printf "                                   it is mounted as /workspace (use /workshop-loop /workspace inside)\n"
    printf "    build                          Build the image without entering shell\n"
```

If a `build` subcommand doesn't currently exist as a standalone, add one:

```bash
cmd_build() {
    printf "\n${BOLD}${CYAN}  workshop build (${PROFILE})${RESET}\n\n"
    build_image
}
```

And in the main argument-dispatch switch at the bottom, ensure:

```bash
case "${FILTERED_ARGS[0]:-help}" in
    setup) shift; cmd_setup "$@" ;;
    shell) shift; cmd_shell "$@" ;;
    build) shift; cmd_build "$@" ;;
    run)
        log_err "\`run\` subcommand was removed in v3.0.0."
        log_dim "Use:  ./launch.sh shell --container=$PROFILE <probe-dir>"
        log_dim "Then: claude → /workshop-loop /workspace"
        exit 1
        ;;
    help|*) cmd_help ;;
esac
```

Locate the actual current main switch and preserve its style — the example above shows the substance, not the exact pre-existing form.

- [ ] **Step 7: Verify no references to RUNNER_SCRIPT remain**

Run: `grep -n RUNNER_SCRIPT containers/workshop/launch.sh`
Expected: no matches.

Run: `grep -n 'cmd_run' containers/workshop/launch.sh`
Expected: only the helpful-error stub in the dispatch case (if you added one).

- [ ] **Step 8: Smoke-test the help output**

Run: `bash containers/workshop/launch.sh --container=research help`
Expected: prints usage, lists `setup`, `shell [<probe-dir>]`, `build`. No mention of `run` as a command.

Run: `bash containers/workshop/launch.sh --container=research run /tmp 75`
Expected: exits with the helpful error message pointing at `./launch.sh shell ...`.

- [ ] **Step 9: Commit**

```bash
git add containers/workshop/launch.sh
git commit -m "feat(containers): retire \`run\` subcommand, enhance \`shell\` for v3.0.0

- Remove cmd_run (host-side \`claude -p\` loop, billing pain June 15).
- shell [<probe-dir>] mounts probe-dir as /workspace.
- Add WORKSHOP_CONTAINER=1 env (read by poc-builder for sandbox detection).
- \`run\` invocation now exits with a helpful migration message.
"
```

---

### Task 17: Delete obsolete container + template files

**Files (delete):**
- `containers/workshop/run-research.sh`
- `containers/workshop/run-arch-forge.sh`
- `containers/workshop/run-refactor.sh`
- `containers/workshop/entrypoint-light.sh`
- `containers/workshop/entrypoint-light-opencode.sh`
- `plugins/offline-research/templates/research-probe/prompt.md`
- `plugins/offline-research/templates/research-probe/critique-loop.md`
- `plugins/offline-research/templates/research-probe/ralph-command.md`
- `plugins/offline-research/templates/arch-forge/prompt.md`
- `plugins/offline-research/templates/arch-forge/expansion-loop.md`
- `plugins/offline-research/templates/refactor-probe/prompt.md`
- `plugins/offline-research/templates/refactor-probe/expansion-loop.md`

- [ ] **Step 1: Verify launch.sh and Dockerfiles do NOT reference the light entrypoints anymore**

Run: `grep -rn 'entrypoint-light' containers/workshop/ plugins/offline-research/`
Expected: no matches. If the research Dockerfiles still reference `entrypoint-light.sh`, update them in this step to point at `entrypoint.sh` instead:

```bash
grep -ln 'entrypoint-light' containers/workshop/dockerfiles/*.Dockerfile
```

For each match, edit the Dockerfile's `COPY entrypoint-light.sh /entrypoint.sh` (or similar) line to `COPY entrypoint.sh /entrypoint.sh`.

- [ ] **Step 2: Delete the container runner scripts**

```bash
git rm containers/workshop/run-research.sh \
       containers/workshop/run-arch-forge.sh \
       containers/workshop/run-refactor.sh \
       containers/workshop/entrypoint-light.sh \
       containers/workshop/entrypoint-light-opencode.sh
```

- [ ] **Step 3: Delete obsolete template files**

```bash
git rm plugins/offline-research/templates/research-probe/prompt.md \
       plugins/offline-research/templates/research-probe/critique-loop.md \
       plugins/offline-research/templates/research-probe/ralph-command.md \
       plugins/offline-research/templates/arch-forge/prompt.md \
       plugins/offline-research/templates/arch-forge/expansion-loop.md \
       plugins/offline-research/templates/refactor-probe/prompt.md \
       plugins/offline-research/templates/refactor-probe/expansion-loop.md
```

- [ ] **Step 4: Verify deletions are staged**

Run: `git status -s`
Expected: all 12 files appear as `D` (deleted) entries.

- [ ] **Step 5: Confirm nothing in the active code references them**

Run: `grep -rn -E 'run-research\.sh|run-arch-forge\.sh|run-refactor\.sh|entrypoint-light|critique-loop\.md|expansion-loop\.md|ralph-command\.md|templates/.*/prompt\.md' containers/ plugins/ 2>/dev/null`
Expected: no matches (or only matches in CHANGELOG/README historical text, which is fine).

- [ ] **Step 6: Commit**

```bash
git commit -m "chore(offline-research): delete v1 runner scripts + obsolete templates

BREAKING (v3.0.0):
- containers/workshop/run-{research,arch-forge,refactor}.sh — driven by claude -p
- containers/workshop/entrypoint-light{,-opencode}.sh — research-profile headless boot
- templates/*/prompt.md — replaced by mission.md
- templates/*/critique-loop.md, templates/*/expansion-loop.md — logic now in
  agents/critique-scorer.md + agents/expansion-planner.md
- templates/research-probe/ralph-command.md — obsolete

Migration: use /workshop-loop slash command instead of launch.sh run.
"
```

---

## Phase 8 — Plugin metadata + docs

### Task 18: Bump plugin version (plugin.json + marketplace.json)

**Files:**
- Modify: `plugins/offline-research/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Read current versions**

```bash
grep version plugins/offline-research/.claude-plugin/plugin.json
grep -A1 offline-research .claude-plugin/marketplace.json | grep version
```

- [ ] **Step 2: Update plugin.json**

Edit `plugins/offline-research/.claude-plugin/plugin.json` — change `"version": "2.4.2"` to `"version": "3.0.0"`. The file becomes:

```json
{
  "name": "offline-research",
  "description": "Pure-skill structured offline research, architecture exploration, and codebase refactoring with /workshop-loop orchestrator",
  "version": "3.0.0",
  "author": {
    "name": "dev32-io"
  }
}
```

- [ ] **Step 3: Update marketplace.json**

Edit `.claude-plugin/marketplace.json` — find the `offline-research` entry and update its `version` field to `"3.0.0"`. Also update its `description` to match the plugin.json change.

- [ ] **Step 4: Verify both bumped**

Run: `grep -A4 offline-research .claude-plugin/marketplace.json`
Expected: `"version": "3.0.0"`.

Run: `cat plugins/offline-research/.claude-plugin/plugin.json | jq .version`
Expected: `"3.0.0"`.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/offline-research/.claude-plugin/plugin.json
git commit -m "chore(offline-research): bump version 2.4.2 → 3.0.0 (breaking)

BREAKING v3.0.0 — see CHANGELOG entry for migration details.
Plugin shape changed: 5 plugin-shipped agents, /workshop-loop slash command,
plugin-shipped Stop hook, container \`run\` subcommand retired.
"
```

---

### Task 19: CHANGELOG v3.0.0 entry

**Files:**
- Modify: `plugins/offline-research/CHANGELOG.md`

- [ ] **Step 1: Read current CHANGELOG**

```bash
head -40 plugins/offline-research/CHANGELOG.md
```

- [ ] **Step 2: Prepend v3.0.0 entry above the most recent entry**

Insert at the top (after the file's `# Changelog` heading, before the previous v2.x entry):

```markdown
## [3.0.0] — 2026-05-26

### Breaking

- **Removed `./launch.sh run` subcommand.** Driving iteration via host-side
  `docker exec ... claude -p` would move to Anthropic's separate Agent SDK
  credit pool on 2026-06-15. Use `/workshop-loop <probe-dir>` from an
  interactive Claude Code session instead. The session can be local
  (subscription billing) or inside `./launch.sh shell` for PoC sandboxing
  (still subscription billing — interactive `claude`, not `claude -p`).
- **Removed light entrypoints** (`entrypoint-light.sh`, `entrypoint-light-opencode.sh`).
  All container profiles now use the same interactive `entrypoint.sh`.
- **Probe seed file shape changed.** `prompt.md` → `mission.md` (slimmed —
  no embedded loop instructions). `critique-loop.md` and `expansion-loop.md`
  files removed; their procedural logic now lives in the plugin-shipped
  subagent definitions. `ralph-command.md` removed.
- **For `refactor-probe` rubrics**, the `hint_action` column folds into
  `scoring-rubric.md`. `expansion-planner` reads it; `critique-scorer`
  ignores it.

### Added

- **`/workshop-loop <probe-dir> [--max-iter N]`** slash command. Runs the
  master orchestrator in the user's interactive Claude Code session.
  Validates the probe directory via `scripts/validate-probe-dir.sh`,
  emits an activation marker, dispatches subagents per task.
- **5 plugin-shipped subagents** under `agents/`:
  - `topic-researcher` (opus) — Research/Improve/Investigate/Explore/etc.
  - `critique-scorer` (sonnet, isolated) — Score/Critique & Score
  - `expansion-planner` (sonnet) — applies plateau math + hint_action expansion
  - `poc-builder` (opus) — PoC/Build, sandbox-aware via `$WORKSHOP_CONTAINER`
  - `synthesizer` (opus) — Synthesize + Final report (with Suggested Reruns
    retrospective)
- **`hooks/workshop-loop-stop.sh`** Stop hook. Derives state from
  `progress.md` (no external state file). Termination on RUN COMPLETE
  promise, all-CONCLUDED-empty-queue, or `max_iter` reached.
- **`./launch.sh shell <probe-dir>`** mounts the probe dir as `/workspace`
  and sets `WORKSHOP_CONTAINER=1` so `poc-builder` can run code freely.
- **`scripts/validate-probe-dir.sh`** — pre-orchestration param validation
  with test harness.
- **Parallel topic execution** — orchestrator dispatches up to
  `max_parallel` (default 4) topic-researcher agents per iteration for
  distinct-topic Research/Improve/Investigate/Explore/Connect tasks.
- **`connections.md`** — cross-topic insights, created lazily; integrated
  into `topic-researcher` (read on Improve/Explore, write on cross-topic
  observations) and `expansion-planner` (can append `Connect:` tasks).
- **End-of-run rubric retrospective** — `synthesizer` surfaces
  `Suggested Reruns` for topics that plateaued early or at low totals.
  Suggestions only; no mid-run rubric change.

### Changed

- Probe skills (`/research-probe`, `/arch-forge`, `/refactor-probe`) now
  recommend `<cwd>/<short-title>/` for seed file location (was
  `~/offline-research/<short-title>/`). Rationale: repo-level plugin
  install scopes hooks to the project.
- All three probe skills' final run-command emission now points at
  `/workshop-loop` (single recommended path) with sandboxed
  `./launch.sh shell` as the second option.
- Container Dockerfiles preserved; only the host-side runner scripts +
  light entrypoints removed.

### Migration

- v1 probe directories still readable in v3.0.0, but you cannot run them
  via the orchestrator until you regenerate seed files with the new
  templates (or manually add a `max_iter: N` header to existing
  `progress.md`, rename `prompt.md` → `mission.md`, and split topics into
  `topics/NN-<slug>.md` files). For new work, just re-invoke the probe
  skill into a new dated directory.
```

- [ ] **Step 3: Verify changelog renders**

Run: `head -80 plugins/offline-research/CHANGELOG.md`
Expected: v3.0.0 entry at top, properly formatted markdown.

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/CHANGELOG.md
git commit -m "docs(offline-research): add CHANGELOG entry for v3.0.0

Document breaking changes (container run subcommand, seed file shape),
new artifacts (5 agents, /workshop-loop, Stop hook, validation script,
parallel execution, connections.md, rubric retrospective), and migration
notes.
"
```

---

### Task 20: README rewrite

**Files:**
- Modify: `plugins/offline-research/README.md`

- [ ] **Step 1: Read current README**

```bash
cat plugins/offline-research/README.md
```

- [ ] **Step 2: Replace the README contents**

Write `plugins/offline-research/README.md` (full overwrite):

```markdown
# Offline Research

Structured offline research and architecture exploration, driven by an in-session orchestrator (`/workshop-loop`) with 5 plugin-shipped subagents.

**Version:** 3.0.0 — see [CHANGELOG.md](CHANGELOG.md) for the v3.0.0 breaking changes.

## What it does

Three intake skills generate seed files (`mission.md`, `progress.md`, `scoring-rubric.md`, `topics/*.md`) into a probe directory. Then one slash command — `/workshop-loop <probe-dir>` — runs the master orchestrator inside your current Claude Code session. It dispatches one of 5 specialized subagents per task, reads scores back, applies plateau math, and iterates until all topics are CONCLUDED or `max_iter` is reached.

The orchestrator is **subscription-safe**: it runs in your interactive Claude Code session, so it stays on the standard subscription quota (not the new Agent SDK credit pool).

## Skills (intake)

### /research-probe

Guides a freeform research idea into seed files for a research-style probe.

**Trigger:** `/research-probe`, "start an offline research on…", "launch a research probe on…"

### /arch-forge

Refines a sketch architecture into seed files for a decision-area-style probe (Alignment / Feasibility / Maintainability / Risk / Effort).

**Trigger:** `/arch-forge`, "forge this architecture", "refine this architecture"

### /refactor-probe

Co-designs a custom scoring rubric (BUILD / INVESTIGATE / RETHINK / REFOCUS hint tags per dimension) for a codebase refactoring exploration.

**Trigger:** `/refactor-probe`, "refactor-probe this codebase", "launch a refactor probe"

## Command (orchestrator)

### /workshop-loop &lt;probe-dir&gt; [--max-iter N]

Master loop. Reads `progress.md`, dispatches one of 5 subagents per task, checks off, and iterates until termination.

- `<probe-dir>`: path to the directory generated by an intake skill.
- `--max-iter N`: optional override of the value baked into `progress.md` by the intake skill.

## Subagents (plugin-shipped, auto-registered)

| Agent | Model | Role |
|---|---|---|
| `topic-researcher` | opus | Research / Improve / Investigate / Explore / Connect / etc. |
| `critique-scorer` | sonnet | Score one finding against the rubric in strict isolation |
| `expansion-planner` | sonnet | Apply plateau math + dim hints, append new tasks |
| `poc-builder` | opus | Build PoC artifacts; sandbox-aware |
| `synthesizer` | opus | Synthesize + Final report with rubric retrospective |

## Stop hook (`hooks/workshop-loop-stop.sh`)

A bash-side gate that re-feeds the orchestrator prompt after every iteration until termination. State is derived from `progress.md` and the session transcript — no external state file.

Termination conditions:
1. `<promise>RUN COMPLETE</promise>` in the last assistant text
2. All scoreboard rows CONCLUDED AND task queue empty
3. Iteration count (`grep -c '^- \[x\]' progress.md`) ≥ `max_iter`

## Installation

```bash
claude plugins install offline-research@ccToolBox
```

**Recommended**: install the plugin at **repo level** (your project's `.claude-plugin/marketplace.json` pointing at ccToolBox), not user-global. This scopes the Stop hook to the project and puts seed files alongside the work they research.

## PoC sandbox (optional)

For PoCs that need code execution against an isolated codebase:

```bash
./containers/workshop/launch.sh build --container=refactor
./containers/workshop/launch.sh shell --container=refactor /path/to/probe-dir
# inside the container shell:
claude
# in Claude Code:
/workshop-loop /workspace
```

This drops you into an interactive `claude` session inside a Docker sandbox with `WORKSHOP_CONTAINER=1` set. `poc-builder` detects this env var and unlocks full Bash execution. Still subscription billing (interactive `claude`, not `claude -p`).

## Architecture

See [docs/architecture.md](docs/architecture.md) for the full design rationale, including stop-hook mechanics, parallel topic execution, and the 5-agent dispatch model.

Design spec: [`../../docs/superpowers/specs/2026-05-26-offline-research-v2-design.md`](../../docs/superpowers/specs/2026-05-26-offline-research-v2-design.md)

---

See [CHANGELOG.md](CHANGELOG.md) for version history.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/README.md
git commit -m "docs(offline-research): rewrite README for v3.0.0

Replace container-loop description with /workshop-loop + 5-agent
overview. Add Stop hook explainer and repo-level install recommendation.
"
```

---

### Task 21: docs/architecture.md rewrite

**Files:**
- Modify: `plugins/offline-research/docs/architecture.md`

- [ ] **Step 1: Read current architecture.md**

```bash
wc -l plugins/offline-research/docs/architecture.md
head -20 plugins/offline-research/docs/architecture.md
```

- [ ] **Step 2: Replace the architecture doc**

Write `plugins/offline-research/docs/architecture.md` (full overwrite):

```markdown
# offline-research v3 — Architecture

> Design spec: [`../../../docs/superpowers/specs/2026-05-26-offline-research-v2-design.md`](../../../docs/superpowers/specs/2026-05-26-offline-research-v2-design.md)

The plugin's job is to run multi-hour exploratory research without burning out a Claude Code session's context window. v3 achieves this with a stop-hook-driven orchestrator (`/workshop-loop`) that runs inside the user's interactive session, dispatching specialized subagents per task and reading state from a single source of truth: `<probe-dir>/progress.md`.

This is a rebuild of v1's container-based loop. v1 drove iteration with host-side `docker exec ... claude -p`, which moves to a separate billing bucket on 2026-06-15. v3 stays on the subscription side by running the orchestrator in interactive Claude Code.

---

## How it works

### Lifecycle

```
User: /workshop-loop ~/offline-research/2026-05-26-foo [--max-iter 50]
  ↓
commands/workshop-loop.md
  - invokes scripts/validate-probe-dir.sh
    (checks mission.md, progress.md, scoring-rubric.md exist;
     verifies max_iter: header; applies --max-iter override)
  - emits [workshop-loop-active] probe_dir=/abs/path marker
  - runs iteration 1: reads progress.md, dispatches subagent for first
    unchecked task, on return Edits task [ ] → [x]
  - stops
  ↓
hooks/workshop-loop-stop.sh fires
  - reads transcript_path, scans for [workshop-loop-active|done] marker
  - extracts probe_dir from most recent marker
  - reads progress.md, derives:
      ITER         = grep -c '^- \[x\]'  progress.md
      PENDING      = grep -c '^- \[ \]'  progress.md
      ACTIVE_ROWS  = grep -c '| ACTIVE |' progress.md
      MAX_ITER     = first 'max_iter: N' line
  - termination tests (any one releases):
      RUN COMPLETE promise in last assistant text
      PENDING == 0 AND ACTIVE_ROWS == 0
      ITER >= MAX_ITER
  - otherwise: emits {decision:"block", reason:<refeed-prompt>} JSON
  ↓
Orchestrator continues iteration N+1
```

### Stop hook (`hooks/workshop-loop-stop.sh`)

- ~75 lines of bash. No external state file. Stateless across invocations.
- Reads the transcript JSONL for the most recent `[workshop-loop-active]` or `[workshop-loop-done]` marker emitted in chat.
- If the most recent marker is `-done`, the loop completed in this session — exits 0 fast (post-run chat).
- If `-active`, reads `<probe-dir>/progress.md` on every fire. progress.md is the single source of truth for iteration count, queue state, and `max_iter`.
- Hook does **not** write state. Only the orchestrator and `expansion-planner` ever touch `progress.md`.

### Why no state file

v1 of the design (and ralph-loop, the closest prior art) keep an iteration counter in `.claude/<plugin>.local.md`. v3 doesn't, because:

1. `progress.md` already encodes iteration count exactly (`grep -c '^- \[x\]'`).
2. `progress.md` is human-readable, git-trackable, and survives power loss mid-iteration.
3. Cancel = Ctrl-C. Resume = re-invoke `/workshop-loop <same-dir>`. The marker re-emits, the hook re-engages, picking up from the first `[ ]` in progress.md.

### The 5 subagents

| Agent | Model | Tools | Handles |
|---|---|---|---|
| `topic-researcher` | opus | WebSearch, WebFetch, Read, Glob, Grep, Write, Edit, Bash | Research / Improve / Investigate / Explore / Decompose / Refocus / Simplify / Rethink / Connect |
| `critique-scorer` | sonnet | Read, Write | Score / Critique & Score (strict isolation: rubric + one finding only) |
| `expansion-planner` | sonnet | Read, Edit | Invoked immediately after `critique-scorer`; applies plateau math + dim hints; appends new tasks |
| `poc-builder` | opus | Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch | PoC / Build; sandbox-aware via `$WORKSHOP_CONTAINER` env |
| `synthesizer` | opus | Read, Glob, Write, Edit | Synthesize / Final report; writes Suggested Reruns retrospective |

**Cross-cutting contract:**

- **Files-not-tokens.** Subagents write findings, scores, PoCs, etc. to disk under `<probe-dir>/`. Their return to the orchestrator is **≤3 lines** — file paths + outcome metadata only. Bulk content never crosses into the lead's context.
- **Atomic edits.** progress.md updates use Edit (single old→new diff). Hook reads progress.md as read-only — no write race.
- **Isolation rule** (critique-scorer specifically): MUST NOT read other findings, mission.md, connections.md, prior scores, or progress.md. The isolation IS the critique signal.

### Parallel topic execution

The orchestrator can dispatch up to `max_parallel` (default 4, configurable via `max_parallel: N` header in progress.md) subagents in a single iteration, but only for parallelizable task types:

**Parallelizable:** `Research:`, `Improve:`, `Investigate:`, `Explore:`, `Connect:` — independent topics, no shared write target.

**Not parallel (must run alone):**
- `Score:`/`Critique & Score:` — `critique-scorer` needs isolation; `expansion-planner` mutates progress.md (race risk)
- `PoC:`/`Build:` — Bash writes, expensive
- `Synthesize`/`Final report` — reads all findings, end-of-run

Iteration counter advances by N for an N-task batch. Each Edit on progress.md targets the specific task line that completed; failed subagents in a batch leave their task `[ ]`, retried next iteration.

### Critique loop with plateau math

`critique-scorer` reads `scoring-rubric.md` and one finding (or one PoC's `NOTES.md`). It scores each dimension per the 0/5/10 anchors and produces a friction log. Writes everything to `<probe-dir>/scores/<topic>-<ts>.md`. Returns only `score: T/M, dims: ..., friction → scores/...`.

`expansion-planner` then reads the score file, the previous scoreboard row in progress.md, and the rubric. It computes Δ and applies:

```
Δ > 3 (gaining):
  → for each dim < 6, append task per hint_action (BUILD/INVESTIGATE/RETHINK/REFOCUS)
  → also append: Score: <topic>
  → streak → 0, status ACTIVE

Δ ≤ 3, prev_streak == 0 (first plateau):
  → append: Improve: <topic> (last chance: <friction>)
  → append: Score: <topic>
  → streak → 1, status ACTIVE

Δ ≤ 3, prev_streak ≥ 1 (second plateau):
  → append nothing
  → status CONCLUDED
```

**REFOCUS hint** is exclusive: if any REFOCUS-tagged dim scores < 6, ONLY the `Refocus:` task is appended (overrides all other hints).

`arch-forge` uses a fixed dim taxonomy with built-in hint mappings (Alignment→REFOCUS, Feasibility→BUILD, Maintainability→RETHINK, Risk→INVESTIGATE, Effort→RETHINK). `refactor-probe` carries the `hint_action` per dim explicitly in `scoring-rubric.md`, co-designed with the user at intake time.

### Cross-topic transfer (`connections.md`)

Created lazily on first cross-topic insight. `topic-researcher`:

- **Reads** `connections.md` on Improve/Explore tasks. Filters to entries mentioning the target topic. Shapes the improvement direction.
- **Writes** new connections during research. When an insight applies to another topic in the scoreboard, appends an entry.

`expansion-planner` can append `Connect: <topic-a> ↔ <topic-b> (insight: <one-line>)` tasks based on friction logs. `topic-researcher` handles those tasks by deepening the link.

### End-of-run rubric retrospective

`synthesizer`'s Final report scans the scoreboard for plateau anomalies (CONCLUDED at total < 60% of max, or first-plateau Δ ≤ 1). For each anomaly, writes a `Suggested Reruns` section in README.md:

```
- **<topic>** plateaued at <total>/<max> after N rounds. Score floor came from
  `<weakest dim>`. Current rubric anchor may undervalue the constraint that
  matters most — consider rerunning with <weakest dim> weighted higher or
  with a stricter anchor at 0/10.
```

Suggestions only. No mid-run rubric change. Preserves the offline invariant.

---

## Tradeoffs and hard parts

**Why a stop hook, not a long-running Claude session loop.** A skill body that says "do this 70 times" relies on Claude's tool-loop convergence — which can converge prematurely on long runs ("looks done to me"). The stop hook is a deterministic bash gate that re-feeds the prompt until the termination conditions in `progress.md` are actually met. Small-model drift becomes irrelevant.

**Why no external state file.** `progress.md` already encodes everything (iteration count = checked tasks, max_iter = header line, queue state = `[ ]`/`[x]` lines). Adding a state file would duplicate truth and create staleness bugs. Activation/done markers in the session transcript identify which probe-dir is active for this session — derivable, no file needed.

**Why subagent delegation, not lead-only.** The lead orchestrator's per-iteration context footprint stays at ~1-2K tokens because bulk content lives in subagent contexts that return only file-path summaries. For 70-iteration runs, lead context ≈ 100K tokens before any compaction — comfortably under Opus 4.7's 1M cap.

**Why Sonnet for critique-scorer + expansion-planner, not Opus.** Both agents do structured work governed by a written rubric. Given a well-written rubric, Sonnet produces the same caliber as Opus at lower latency. Opus stays where exploration matters: research, PoC building, synthesis.

**Why parallel batches cap at 4.** Subscription model = no marginal token cost, but Claude Code rate-limits + memory pressure from 5+ parallel Opus dispatches becomes real. 4 is the conservative cap; configurable per probe via `max_parallel:` header.

**Why no migration helper for v1 probe-dirs.** v1 directories remain readable; v3 can't run them automatically. The split-prompt-into-mission+topics step is mechanical but error-prone. Users re-invoke the probe skill into a new dated directory.

---

## Sandbox mode (`./launch.sh shell`)

For PoCs that must execute against an isolated environment, the container still exists but only in interactive mode:

```bash
./launch.sh build --container=refactor
./launch.sh shell --container=refactor /path/to/probe-dir
# drops user into bash inside container at /workspace
$ claude
> /workshop-loop /workspace
```

The `shell` subcommand sets `WORKSHOP_CONTAINER=1` in the container env. `poc-builder` reads this at the start of every invocation:

- **SANDBOXED mode**: full Bash. May execute generated PoC code. Writes to `<probe-dir>/poc/<name>/` (potentially via `sudo -u poc` if entrypoint set up the isolated user).
- **HOST mode** (no env var): may use read-only Bash for inspection (`ls`, `cat`, `find`, version checks) but MUST NOT execute generated code. Annotates NOTES.md: `EXECUTION SKIPPED — re-run inside ./launch.sh shell to validate.`

Both modes use **interactive** `claude` (subscription billing). Only the `run` subcommand (deleted in v3.0.0) used `claude -p`.

---

## File map

```
plugins/offline-research/
├── .claude-plugin/plugin.json
├── README.md
├── CHANGELOG.md
├── skills/
│   ├── research-probe/SKILL.md         # intake — research topics
│   ├── arch-forge/SKILL.md             # intake — architecture decisions
│   └── refactor-probe/SKILL.md         # intake — codebase refactor + rubric co-design
├── agents/
│   ├── topic-researcher.md             # Research/Improve/Investigate/...
│   ├── critique-scorer.md              # Score/Critique & Score (isolated)
│   ├── expansion-planner.md            # plateau math + hint_action appends
│   ├── poc-builder.md                  # PoC/Build (sandbox-aware)
│   └── synthesizer.md                  # Synthesize/Final report + retro
├── commands/
│   └── workshop-loop.md                # /workshop-loop slash command
├── hooks/
│   ├── hooks.json                      # Stop hook registration
│   └── workshop-loop-stop.sh           # the hook itself
├── scripts/
│   ├── validate-probe-dir.sh           # pre-orchestration validation
│   └── test-validate-probe-dir.sh      # test harness
├── templates/
│   ├── research-probe/
│   │   ├── mission.md
│   │   ├── progress.md
│   │   └── scoring-rubric.md
│   ├── arch-forge/
│   │   ├── mission.md
│   │   ├── progress.md
│   │   └── scoring-rubric.md
│   └── refactor-probe/
│       ├── mission.md
│       ├── progress.md
│       └── scoring-rubric-template.md  # hint_action col folded in
└── docs/
    └── architecture.md                 # this file

containers/workshop/
├── launch.sh                           # build + shell subcommands only (run retired)
├── entrypoint.sh                       # sandbox setup
├── .env.example
└── dockerfiles/                        # interactive claude/opencode images
```
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/docs/architecture.md
git commit -m "docs(offline-research): rewrite architecture.md for v3.0.0

Replace v1 container-loop description. Document stop hook mechanics,
stateless transcript markers, 5-agent dispatch, parallel batches,
connections.md, retrospective. Keep tradeoffs section honest about
why subagent delegation + stop hook over alternatives.
"
```

---

## Phase 9 — End-to-end smoke

### Task 22: Smoke test against a real small probe

**Files:** none created; verifies the v3 end-to-end flow on a real probe.

- [ ] **Step 1: Verify plugin reloads cleanly**

Restart your Claude Code session (the plugin's hooks need to re-register). Then verify:

```bash
grep workshop-loop ~/.claude/plugins/cache/ccToolBox/offline-research/*/commands/workshop-loop.md | head -3
```

Expected: the command file is in the plugin cache, fronmatter visible.

Inside Claude Code, run `/workshop-loop --help` (or just `/workshop-loop` with no args) — expect a usage error from `validate-probe-dir.sh` saying `Usage: validate-probe-dir.sh <probe-dir>`.

- [ ] **Step 2: Generate a minimal probe via /research-probe**

In Claude Code, invoke `/research-probe`. Use a small, narrow topic — e.g., "compare 2 lightweight JSON schema libraries for Python". When the skill asks for seed location, pick option 1 (cwd). Confirm at most 2 topics — this keeps the smoke test under 10 iterations.

Verify the generated directory:

```bash
ls <chosen-cwd>/<short-title>/
```

Expected: `mission.md`, `progress.md`, `scoring-rubric.md`, `topics/01-<topic>.md`, `topics/02-<topic>.md`. progress.md first line should match `max_iter: 26` (2 topics × 8 + 10).

- [ ] **Step 3: Run the orchestrator**

In Claude Code: `/workshop-loop <abs-path-to-probe-dir>`.

Watch for:
- First-line activation marker: `[workshop-loop-active] probe_dir=...`
- First task picked from queue, agent dispatched (visible in tool-use blocks)
- progress.md updated with `[x]` on the first task
- Session attempts to stop → hook fires → re-feeds (look for the `🔄 workshop-loop iter N/M` systemMessage)
- Iteration continues automatically

If the orchestrator stops without re-feeding, run `bash plugins/offline-research/hooks/workshop-loop-stop.sh < /dev/null 2>&1` against a known transcript to debug.

- [ ] **Step 4: Verify a full Research → Score → Improve → Score cycle**

After the first Score: task completes, check that:
- `<probe-dir>/scores/<topic>-<ts>.md` exists with full score breakdown
- progress.md has new tasks appended by expansion-planner (either Improve+Score, or status changed to CONCLUDED)
- expansion-planner's return shows in the conversation as `appended N tasks: ..., Δ=N, streak=N, status: ...`

- [ ] **Step 5: Verify natural completion**

Let the loop run to completion (or kill it with Ctrl-C if it runs > 10 minutes — a 2-topic smoke should finish in 3-6 minutes).

On completion:
- Last assistant text contains `<promise>RUN COMPLETE</promise>` and `[workshop-loop-done] probe_dir=...`
- `<probe-dir>/README.md` exists and contains a Suggested Reruns section (possibly "No rubric anomalies detected.")
- `<probe-dir>/synthesis.md` exists

Now type a follow-up question to Claude in the same session (e.g., "summarize what we found"). Confirm the hook releases fast — no systemMessage about iter N/M appears. The done marker is in the transcript, hook short-circuits.

- [ ] **Step 6: Verify Ctrl-C + resume works**

(Optional but recommended.) Start a fresh run via `/workshop-loop <same-dir>` — but wait, the dir is in terminal state. Start a NEW small probe instead, dispatch `/workshop-loop`, let it run 2-3 iterations, then Ctrl-C. progress.md should reflect the work done so far (`[x]` on completed tasks). Re-invoke `/workshop-loop <same-dir>` — it should pick up from the first `[ ]`.

- [ ] **Step 7: Commit smoke-test artifacts (only if useful as a fixture; otherwise just discard)**

If the smoke probe-dir is illustrative, you may add it under `plugins/offline-research/docs/example-probe/` as a fixture. Otherwise, clean up:

```bash
rm -rf <smoke-probe-dir>
```

No commit needed for the smoke test itself.

---

## Done conditions

When all 22 tasks have green checkboxes:

1. `git log --oneline -25` shows 22 v3.0.0 commits (some may be combined if you batched).
2. `git status` is clean.
3. `plugins/offline-research/.claude-plugin/plugin.json` reports version `3.0.0`.
4. `/research-probe` → `/workshop-loop` end-to-end smoke test passed.
5. `bash plugins/offline-research/scripts/test-validate-probe-dir.sh` passes (11 cases).
6. `bash plugins/offline-research/hooks/test-workshop-loop-stop.sh` passes (9 cases).
7. No file in `containers/workshop/` or `plugins/offline-research/` references the deleted v1 artifacts (`run-*.sh`, `entrypoint-light*.sh`, `prompt.md`, `critique-loop.md`, `expansion-loop.md`, `ralph-command.md`).

Optionally: open a `v3.0.0` git tag once tested in real-use.

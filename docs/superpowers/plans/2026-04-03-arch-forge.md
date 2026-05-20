# arch-forge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the arch-forge skill inside the offline-research plugin, with templates, container, and template reorganization.

**Architecture:** New skill + 4 templates + standalone container replicated from offline-research. Templates reorganized into per-skill subdirectories.

**Tech Stack:** Markdown (skill + templates), Bash (container scripts), Docker (container image)

**Spec:** `docs/superpowers/specs/2026-04-03-arch-forge-design.md`

---

### Task 1: Reorganize research-probe templates into subdirectory

**Files:**
- Create: `plugins/offline-research/templates/research-probe/` (directory)
- Move: `plugins/offline-research/templates/*.md` → `plugins/offline-research/templates/research-probe/*.md`
- Modify: `plugins/offline-research/skills/research-probe/SKILL.md`

- [ ] **Step 1: Move template files into research-probe subdirectory**

```bash
cd ~/Development/ccToolBox/plugins/offline-research
mkdir -p templates/research-probe
mv templates/prompt.md templates/research-probe/
mv templates/progress.md templates/research-probe/
mv templates/critique-loop.md templates/research-probe/
mv templates/scoring-rubric.md templates/research-probe/
mv templates/ralph-command.md templates/research-probe/
```

- [ ] **Step 2: Update template paths in research-probe SKILL.md**

In `plugins/offline-research/skills/research-probe/SKILL.md`, replace all four template read instructions. Change:

```
- Read `<plugin-root>/templates/prompt.md`
- Read `<plugin-root>/templates/progress.md`
- Read `<plugin-root>/templates/critique-loop.md`
- Read `<plugin-root>/templates/scoring-rubric.md`
```

To:

```
- Read `<plugin-root>/templates/research-probe/prompt.md`
- Read `<plugin-root>/templates/research-probe/progress.md`
- Read `<plugin-root>/templates/research-probe/critique-loop.md`
- Read `<plugin-root>/templates/research-probe/scoring-rubric.md`
```

- [ ] **Step 3: Verify templates are accessible**

```bash
ls plugins/offline-research/templates/research-probe/
```

Expected: `critique-loop.md  progress.md  prompt.md  ralph-command.md  scoring-rubric.md`

- [ ] **Step 4: Commit**

```bash
git add plugins/offline-research/templates/ plugins/offline-research/skills/research-probe/SKILL.md
git commit -m "refactor(offline-research): reorganize templates into per-skill subdirectories"
```

---

### Task 2: Create arch-forge scoring rubric

**Files:**
- Create: `plugins/offline-research/templates/arch-forge/scoring-rubric.md`

- [ ] **Step 1: Create arch-forge template directory**

```bash
mkdir -p plugins/offline-research/templates/arch-forge
```

- [ ] **Step 2: Write scoring-rubric.md**

Write to `plugins/offline-research/templates/arch-forge/scoring-rubric.md`:

```markdown
# Architecture Scoring Rubric

You MUST read this file completely before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption.

## Your Role

You are an architecture quality probe. You will receive one decision area's exploration output — research, PoC code, analysis, trade-off documentation. Your job: read it as a skeptical senior engineer and score how well this architectural exploration holds up.

**Always evaluate relative to the project intent and constraints provided.** A brilliant design that doesn't serve the stated goals scores low on Alignment. An over-engineered solution for a home project scores low on Effort.

**Be curious.** Wonder "but what about failure modes?", "how does this integrate with the rest?", "is there a simpler way?". Genuine curiosity produces sharper critique than a checklist.

## Scoring Dimensions (each 0-10, max 50)

| Dimension | 0 | 5 | 10 |
|-----------|---|---|-----|
| **Feasibility & Validation** | Pure speculation, no evidence | Research-backed but unvalidated | Working PoC with measured results |
| **Maintainability & Testability** | Monolithic, untestable, requires team | Modular but testing strategy unclear | Clear module boundaries, test strategy documented, one-person viable |
| **Risk & Trade-offs** | No risks mentioned, trade-offs ignored | Some risks listed but no mitigation | Risks ranked by severity, mitigations proposed, unknowns called out |
| **Effort & Complexity** | Massively over-engineered for the use case | Reasonable but could be simpler | Minimal viable complexity, clear build path |
| **Alignment** | Completely disconnected from project goals | Related but solving a different problem | Directly advances the stated project intent |

## Friction-Based Deduction

Any friction you experience while reading is a quality signal:

- Wanting to ask "but would this actually work?" → deduct from **Feasibility & Validation**
- Wanting to ask "who maintains this?" or "how do you test this?" → deduct from **Maintainability & Testability**
- Feeling uneasy but unsure why, or spotting unaddressed failure modes → deduct from **Risk & Trade-offs**
- Thinking "this seems overkill" or "there must be a simpler way" → deduct from **Effort & Complexity**
- Thinking "why are we building this?" or "how does this serve the goal?" → deduct from **Alignment**

**The urge itself is the deduction.** You do not need to actually verify — the fact that you wanted to is the score signal.

## Output Format

Return your critique in exactly this format:

```
## Scores
- Feasibility & Validation: N/10
- Maintainability & Testability: N/10
- Risk & Trade-offs: N/10
- Effort & Complexity: N/10
- Alignment: N/10
- **Total: N/50**

## Friction Log
- [dimension affected]: "description of what caused friction"
- [dimension affected]: "description of what caused friction"
...

## What's Missing
- gap, unknown, or untested assumption
- gap, unknown, or untested assumption
...

## What's Strong
- what works well and should be preserved
...
```
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/templates/arch-forge/
git commit -m "feat(arch-forge): add architecture scoring rubric with 5 dimensions"
```

---

### Task 3: Create arch-forge expansion loop

**Files:**
- Create: `plugins/offline-research/templates/arch-forge/expansion-loop.md`

- [ ] **Step 1: Write expansion-loop.md**

Write to `plugins/offline-research/templates/arch-forge/expansion-loop.md`:

```markdown
# Score & Expand — How It Works

You are handling a `Score: <decision-area>` task from the queue.

## Step 1: Spawn Sonnet Subagent

Spawn a subagent for this ONE decision area:

- **Model:** sonnet
- **Isolation:** The subagent gets ONLY the scoring rubric, the project intent section from prompt.md, and this decision area's exploration output. No other context. No web access. No exploration history. This isolation is the point — if the subagent can't evaluate your exploration without extra context, your exploration isn't thorough enough.
- **Prompt:** "You MUST read `<path>/scoring-rubric.md` before producing ANY output. Your scoring is invalid without it. Do not score from memory or assumption. Then read the Project Intent section from `<path>/prompt.md` — this is the anchor for Alignment scoring. After reading both, read `<path>/explorations/<decision-area>.md` and any associated PoC output in `<path>/poc/<decision-area>/`. Score according to the rubric. Be curious — wonder what's missing, what failure modes exist, what a simpler alternative might be."

Replace `<path>` with the actual workspace path.

## Step 2: Update Scoreboard

Record the scores in progress.md. Compute Δ (this score's total minus the last score's total for this decision area). Update streak. Update the Approaches column count.

## Step 3: Expand the Task Queue

Based on the score result, apply **dimension-aware expansion**. Check which dimensions scored below 6, then expand based on the weakest:

### Expansion Rules

**Priority order when multiple dimensions are weak:** Alignment first, then Feasibility, then the rest.

```
Alignment < 6 (BRAKE):
├── Do NOT add expansion tasks
├── Add: Refocus: <decision-area> — re-read project intent, prune irrelevant content
└── This overrides all other expansion rules

Feasibility < 6 (BUILD):
├── Add: PoC: <decision-area>-<approach> — build something, don't research more
└── If PoC already exists, add: PoC: <decision-area>-<alternative> — try a different approach

Maintainability < 6 (DECOMPOSE):
├── Add: Decompose: <decision-area> — break into smaller pieces, redraw boundaries
└── Add: Explore: <sub-decision> — for each new sub-piece discovered

Risk < 6 (INVESTIGATE):
├── Add: Investigate: <decision-area>-risks — find failure modes, edge cases, prior art
└── Reference specific gaps from subagent's friction log

Effort < 6 (SIMPLIFY):
├── Add: Simplify: <decision-area> — find a simpler alternative or cut scope
└── Add: Explore: <decision-area>-alternative — research a lighter approach
```

### Delta Rules (applied AFTER dimension-specific expansion)

```
Δ > 3 (decision area is gaining):
├── Apply dimension-specific expansion above
└── Streak → 0

Δ ≤ 3, streak 0 (first plateau):
├── Add one more improvement task based on weakest dimension
└── Streak → 1

Δ ≤ 3, streak ≥ 1 (second plateau):
├── Check: does this decision area have at least 2 scored approaches?
│   ├── YES: Mark CONCLUDED in scoreboard. No more tasks.
│   └── NO: Add: Explore: <decision-area>-alternative — must have options before concluding
└── If concluding, append nothing further
```

### Synthesize Step

After expanding, ensure the task queue always ends with:
```
- [ ] Synthesize: update architecture.md
```

If this step already exists at the tail, do not duplicate it. If new tasks were inserted before it, it's already in the right place. If it was consumed, re-append it.

After the LAST `Score` item in the current round, also re-append `Synthesize: update architecture.md` to capture the full round's results.

## Minimum Approaches Rule

A decision area CANNOT be marked CONCLUDED with fewer than 2 scored approaches. If only one approach has been explored and scored, the agent MUST spawn an alternative exploration before concluding. The user must always have options to choose from.

## Worked Example

Starting state — first round of scoring underway:

```
- [x] ... (decompose, survey, explore tasks done)
- [x] Score: gateway-runtime → 32/50 (Feasibility: 4, Maint: 7, Risk: 5, Effort: 8, Align: 8)
- [ ] Score: client-protocol
- [ ] Score: persona-storage
- [ ] PoC: bun-websocket-server ← INSERTED (Feasibility < 6)
- [ ] Investigate: gateway-runtime-risks ← INSERTED (Risk < 6)
- [ ] Synthesize: update architecture.md
```

**Agent picks: `Score: client-protocol`**

Spawns Sonnet → 38/50 (Feasibility: 7, Maint: 8, Risk: 6, Effort: 9, Align: 8). Δ = 38 (first score). All dimensions ≥ 6, gaining. No dimension-specific expansion needed, but only 1 approach:

```
- [x] Score: client-protocol → 38/50
- [ ] Score: persona-storage
- [ ] PoC: bun-websocket-server
- [ ] Investigate: gateway-runtime-risks
- [ ] Explore: client-protocol-alternative ← need 2nd approach before can conclude
- [ ] Synthesize: update architecture.md
```

**Agent picks: `PoC: bun-websocket-server`**

Builds minimal Bun WebSocket server (50 lines), runs basic test. Appends re-score:

```
- [x] PoC: bun-websocket-server ✓
- [ ] Score: gateway-runtime ← re-score after PoC
- [ ] ...
```

**`Score: gateway-runtime` (second time) — 41/50. Δ = +9. Gaining. Streak → 0.**

Feasibility now 8/10 (PoC proved it). Only 1 approach explored. Agent adds alternative:

```
- [ ] Explore: gateway-runtime-nodejs ← alternative approach
- [ ] Synthesize: update architecture.md
```

**Later: `Score: gateway-runtime` (third time, after Node.js exploration) — 42/50. Δ = +1. First plateau. Streak → 1.**

Two approaches now scored (Bun: 41, Node.js: 36). One more improvement attempt:

```
- [ ] Improve: gateway-runtime (last chance: compare memory usage)
```

**`Score: gateway-runtime` (fourth time) — 43/50. Δ = +1. Second plateau. Streak → 2. 2 approaches exist. CONCLUDED.**

Nothing appended. Decision area done.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/arch-forge/expansion-loop.md
git commit -m "feat(arch-forge): add dimension-aware expansion loop protocol"
```

---

### Task 4: Create arch-forge prompt template

**Files:**
- Create: `plugins/offline-research/templates/arch-forge/prompt.md`

- [ ] **Step 1: Write prompt.md template**

Write to `plugins/offline-research/templates/arch-forge/prompt.md`:

```markdown
# Architecture Expansion: [PROJECT_NAME]

You have full autonomy. Do not ask questions. Use your best judgement.

## Project Intent

[PROJECT_INTENT]

This is your anchor. Re-read this before every expansion decision. Every exploration must serve this intent.

## Constraints

[CONSTRAINTS]

These are hard boundaries. Do not explore approaches that violate them.

## Architecture Sketch

[ARCHITECTURE_SKETCH]

This is the starting skeleton. Your job is to expand, validate, and refine — not replace. Explore alternatives for each decision area, but the overall shape should remain recognizable.

## Workspace Structure

```
/workspace/
├── prompt.md                # this file (read-only reference)
├── progress.md              # scoreboard + task queue — your instruction sheet
├── expansion-loop.md        # how to handle Score tasks
├── scoring-rubric.md        # scoring dimensions for subagents
├── architecture.md          # LIVING DOCUMENT — update at every Synthesize step
├── explorations/            # research + analysis per decision area
│   ├── decision-area.md
│   └── ...
├── poc/                     # working prototypes (execute as: su -c "..." poc)
│   ├── component-name/
│   └── ...
├── risks.md                 # cross-cutting risks + mitigations
├── sources.md               # running bibliography — URLs, titles, notes
└── connections.md           # cross-component dependencies + interactions
```

## How This Works

1. Read `progress.md` and find the next unchecked item in the Task Queue
2. Do that ONE item
3. Check it off in progress.md
4. Output `TASK DONE`
5. Stop — you will be re-invoked automatically

When the task queue is empty, output `<promise>TASK DONE</promise>` instead.

## PoC Execution

When building prototypes, execute code as the `poc` user for security isolation:

```bash
su -c "cd /workspace/poc/<name> && node index.js" poc
su -c "cd /workspace/poc/<name> && bun run index.ts" poc
su -c "cd /workspace/poc/<name> && python3 main.py" poc
```

PoCs should be minimal — just enough to validate feasibility. Limited scope: prove the concept works, measure key metrics, then move on. Do not build production code.

## Synthesize Step

When you reach a `Synthesize: update architecture.md` task:

1. Read all explorations, scores, and PoC results so far
2. Re-read the Project Intent section above to stay anchored
3. Update `architecture.md` with the current state of each decision area:
   - Use mermaid diagrams for component interactions, data flows, and sequence diagrams
   - Present 2-3 approaches per area with detailed pros/cons
   - Include score breakdowns per approach
   - Reference supporting PoCs with relative paths (e.g., `poc/bun-gateway/`)
   - Mark each area's status: exploring / scored / concluded
4. Update `risks.md` with any cross-cutting risks discovered
5. Update `connections.md` with cross-component dependencies

## Initial Decision Areas

[DECISIONS]
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/arch-forge/prompt.md
git commit -m "feat(arch-forge): add prompt template with workspace structure and PoC instructions"
```

---

### Task 5: Create arch-forge progress template

**Files:**
- Create: `plugins/offline-research/templates/arch-forge/progress.md`

- [ ] **Step 1: Write progress.md template**

Write to `plugins/offline-research/templates/arch-forge/progress.md`:

```markdown
# Architecture Expansion Progress

## Scoreboard
| Decision Area | Status | Feas | Maint | Risk | Effort | Align | Total | Δ | Streak | Approaches |
|---------------|--------|------|-------|------|--------|-------|-------|---|--------|------------|
[DECISION_SCOREBOARD]

## Task Queue

> For every `Score` task: you MUST read `expansion-loop.md` and `scoring-rubric.md` before starting. Do not score from memory or assumption.

- [ ] Decompose: read seed architecture, create exploration files in explorations/
- [ ] Survey: all decision areas (skim landscape, log in sources.md)
[DECISION_EXPLORATION]
- [ ] Synthesize: update architecture.md
[DECISION_SCORING]
- [ ] Synthesize: update architecture.md
```

- [ ] **Step 2: Commit**

```bash
git add plugins/offline-research/templates/arch-forge/progress.md
git commit -m "feat(arch-forge): add progress template with architecture scoreboard"
```

---

### Task 6: Create arch-forge SKILL.md

**Files:**
- Create: `plugins/offline-research/skills/arch-forge/SKILL.md`

- [ ] **Step 1: Create skill directory**

```bash
mkdir -p plugins/offline-research/skills/arch-forge
```

- [ ] **Step 2: Write SKILL.md**

Write to `plugins/offline-research/skills/arch-forge/SKILL.md`:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/skills/arch-forge/
git commit -m "feat(arch-forge): add skill definition with interactive refinement flow"
```

---

### Task 7: Create arch-tool container — Dockerfile + entrypoint

**Files:**
- Create: `containers/arch-tool/Dockerfile`
- Create: `containers/arch-tool/entrypoint.sh`

- [ ] **Step 1: Create container directory**

```bash
mkdir -p containers/arch-tool
```

- [ ] **Step 2: Write Dockerfile**

Write to `containers/arch-tool/Dockerfile`:

```dockerfile
FROM node:20-slim

ARG CLAUDE_CODE_VERSION=latest

# --- Base tools (same as offline-research) ---

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  curl \
  jq \
  less \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep \
  build-essential \
  tree \
  unzip \
  wget \
  sqlite3 \
  nano \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- PoC build dependencies ---

# Bun runtime
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash

# Rust toolchain
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=$PATH:/usr/local/cargo/bin
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# Go
RUN apt-get update && apt-get install -y --no-install-recommends golang-go \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Node.js ecosystem
USER root
RUN npm install -g typescript ts-node tsx pnpm yarn

# Databases & storage
RUN apt-get update && apt-get install -y --no-install-recommends \
  libsqlite3-dev \
  redis-tools \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Headless browser
RUN apt-get update && apt-get install -y --no-install-recommends \
  chromium \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN npm install -g playwright && npx playwright install --with-deps chromium

# Build tools & common libs
RUN apt-get update && apt-get install -y --no-install-recommends \
  cmake \
  pkg-config \
  libssl-dev \
  protobuf-compiler \
  net-tools \
  dnsutils \
  iputils-ping \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Security: poc user for sandboxed code execution ---

RUN useradd -m -s /bin/bash poc

# --- Non-root user setup ---

RUN mkdir -p /home/node/.claude /workspace && \
  chown -R node:node /home/node/.claude /workspace

USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
USER root
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share/npm-global
USER node
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

WORKDIR /workspace
ENV SHELL=/bin/bash
ENV TZ=America/Vancouver

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

- [ ] **Step 3: Write entrypoint.sh**

Write to `containers/arch-tool/entrypoint.sh`:

```bash
#!/bin/bash
# Lock down .claude/ so only the node user (Claude Code) can read it.
# The poc user used for PoC code execution cannot access auth tokens.
chmod 700 /home/node/.claude 2>/dev/null || true
exec claude --dangerously-skip-permissions "$@"
```

- [ ] **Step 4: Commit**

```bash
git add containers/arch-tool/Dockerfile containers/arch-tool/entrypoint.sh
git commit -m "feat(arch-tool): add Dockerfile with PoC deps and sandboxed poc user"
```

---

### Task 8: Create arch-tool container — launch.sh

**Files:**
- Create: `containers/arch-tool/launch.sh`

- [ ] **Step 1: Write launch.sh**

Write to `containers/arch-tool/launch.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env if present
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# Defaults
IMAGE_NAME="arch-tool"
WORKSPACE="${HOME}/offline-research"
CONTAINER_NAME="${CONTAINER_NAME:-arch-sandbox}"
TZ="${TZ:-America/Vancouver}"

# Colors
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'
FRAMES=('   ' '.  ' '.. ' '...')

spin() {
    local msg="$1" pid="$2" i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${DIM}${FRAMES[$((i % 4))]}${RESET} %s" "$msg"
        i=$((i + 1))
        sleep 0.3
    done
    wait "$pid"
    local exit_code=$?
    printf "\r  ${GREEN}ok${RESET}  %s\n" "$msg"
    return $exit_code
}

log_ok()   { printf "  ${GREEN}ok${RESET}  %b\n" "$1"; }
log_warn() { printf "  ${YELLOW}--${RESET}  %b\n" "$1"; }
log_dim()  { printf "  ${DIM}%b${RESET}\n" "$1"; }

build_image() {
    docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR" >/dev/null 2>&1 &
    spin "Building image" $!
}

ensure_container() {
    local CONTAINER_HOME="${CLAUDE_CODE_RESEARCH_TOOL:?CLAUDE_CODE_RESEARCH_TOOL is not set}"
    local CLAUDE_PATH="${CONTAINER_HOME}/.claude"

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            docker start "$CONTAINER_NAME" >/dev/null
            log_ok "Started existing container"
        else
            log_ok "Container already running"
        fi
    else
        mkdir -p "$WORKSPACE" "$CLAUDE_PATH"
        local claude_json="${CONTAINER_HOME}/.claude.json"
        [ -f "$claude_json" ] || echo '{"hasCompletedOnboarding":true,"installMethod":"native"}' > "$claude_json"

        docker run -d \
            --name "$CONTAINER_NAME" \
            --memory=4g --cpus=4 --pids-limit=200 \
            -v "$WORKSPACE:/workspace" \
            -v "${CLAUDE_PATH}:/home/node/.claude:ro" \
            -v "${CONTAINER_HOME}/.claude.json:/home/node/.claude.json:ro" \
            -e "TZ=${TZ}" \
            ${GH_TOKEN:+-e GH_TOKEN="$GH_TOKEN"} \
            "$IMAGE_NAME" \
            tail -f /dev/null >/dev/null

        log_ok "Created container ${DIM}${CONTAINER_NAME}${RESET}"
    fi
}

cmd_setup() {
    printf "\n${BOLD}${CYAN}  arch-tool setup${RESET}\n\n"
    build_image
    ensure_container
    echo
    log_dim "Dropping into container shell. Run 'claude login' to authenticate."
    echo
    docker exec -it "$CONTAINER_NAME" bash
}

cmd_run() {
    local workspace="${1:?Usage: launch.sh run <workspace-path> [max-iterations]}"
    local max_iter="${2:-75}"

    printf "\n${BOLD}${CYAN}  arch-tool run${RESET}\n\n"
    build_image
    ensure_container
    echo
    exec "$SCRIPT_DIR/run-arch.sh" "$workspace" "$max_iter"
}

cmd_shell() {
    printf "\n${BOLD}${CYAN}  arch-tool shell${RESET}\n\n"
    ensure_container
    echo
    docker exec -it "$CONTAINER_NAME" bash
}

cmd_help() {
    printf "\n${BOLD}${CYAN}  arch-tool${RESET}\n\n"
    printf "  ${BOLD}Usage:${RESET} launch.sh <command> [args]\n\n"
    printf "  ${BOLD}Commands:${RESET}\n"
    printf "    setup                          Create container and login\n"
    printf "    run <workspace> [max-iter]     Start architecture exploration with auto-resume\n"
    printf "    shell                          Open container shell\n"
    echo
}

case "${1:-help}" in
    setup) cmd_setup ;;
    run)   shift; cmd_run "$@" ;;
    shell) cmd_shell ;;
    *)     cmd_help ;;
esac
```

- [ ] **Step 2: Make executable**

```bash
chmod +x containers/arch-tool/launch.sh
```

- [ ] **Step 3: Commit**

```bash
git add containers/arch-tool/launch.sh
git commit -m "feat(arch-tool): add launch script with :ro mounts and resource limits"
```

---

### Task 9: Create arch-tool container — run-arch.sh + .env.example

**Files:**
- Create: `containers/arch-tool/run-arch.sh`
- Create: `containers/arch-tool/.env.example`

- [ ] **Step 1: Write run-arch.sh**

Write to `containers/arch-tool/run-arch.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults (overridden by .env)
RESEARCH_HOURS="${RESEARCH_HOURS:-23:00-07:00}"
TZ="${TZ:-America/Vancouver}"
CONTAINER_NAME="${CONTAINER_NAME:-arch-sandbox}"

# Load .env if present
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# Colors
DIM='\033[2m'
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'

# --- Functions ---

print_status() {
    local iter="$1" max="$2" workspace="$3" msg="${4:-}"
    printf "\n${BOLD}${CYAN}  arch-runner${RESET}  ${DIM}iter %d/%d${RESET}  ${DIM}%s${RESET}" "$iter" "$max" "$workspace"
    [[ -n "$msg" ]] && printf "  ${YELLOW}%s${RESET}" "$msg"
    printf "\n\n"
}

run_iteration() {
    local workspace="$1"
    local prompt="Read ${workspace}/prompt.md for context. Read ${workspace}/progress.md and do the next unchecked item in the Task Queue. Check it off when done. Output TASK DONE and stop."
    LAST_OUTPUT="/tmp/arch-runner-output.$$"

    # Run interactively (full TUI visible), tee output for completion/rate-limit detection
    docker exec -it "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "$prompt" \
        2>&1 | tee "$LAST_OUTPUT"

    LAST_EXIT=${PIPESTATUS[0]}
}

check_completed() {
    grep -q '<promise>TASK DONE</promise>' "$LAST_OUTPUT" 2>/dev/null
}

check_rate_limit() {
    [[ $LAST_EXIT -ne 0 ]] && return 0
    grep -q 'rate_limit' "$LAST_OUTPUT" 2>/dev/null && return 0
    return 1
}

probe_limit() {
    printf "  ${DIM}Probing if limit has reset...${RESET}\n"
    local probe_output="/tmp/arch-probe-output.$$"
    docker exec "$CONTAINER_NAME" \
        claude --dangerously-skip-permissions -p "say hi" \
        --output-format json --max-turns 1 \
        < /dev/null > "$probe_output" 2>&1
    local code=$?
    if [[ $code -eq 0 ]] && ! grep -q 'rate_limit' "$probe_output" 2>/dev/null; then
        rm -f "$probe_output"
        return 0  # limit reset
    fi
    rm -f "$probe_output"
    return 1  # still limited
}

in_schedule() {
    local now start end
    now=$(TZ="$TZ" date +%H%M)
    start="${RESEARCH_HOURS%%-*}"
    end="${RESEARCH_HOURS##*-}"
    start="${start/:/}"
    end="${end/:/}"

    if [[ "10#$start" -gt "10#$end" ]]; then
        # Overnight window (e.g., 23:00-07:00)
        [[ "10#$now" -ge "10#$start" || "10#$now" -lt "10#$end" ]]
    else
        # Same-day window (e.g., 09:00-17:00)
        [[ "10#$now" -ge "10#$start" && "10#$now" -lt "10#$end" ]]
    fi
}

wait_for_reset() {
    if in_schedule; then
        printf "  ${YELLOW}Rate limited.${RESET} Inside research window — probing every hour.\n"
        while true; do
            sleep 3600
            if probe_limit; then
                printf "  ${GREEN}Limit reset!${RESET} Resuming.\n"
                return 0
            fi
            printf "  ${DIM}Still limited. Next probe in 1 hour.${RESET}\n"
        done
    else
        printf "  ${YELLOW}Rate limited.${RESET} Outside research window (${RESEARCH_HOURS}).\n"
        printf "  ${BOLD}Type 'continue' to resume:${RESET} "
        local input
        while true; do
            read -r input
            [[ "$input" == "continue" ]] && return 0
            printf "  ${DIM}Type 'continue' to resume:${RESET} "
        done
    fi
}

main() {
    local workspace="${1:?Usage: run-arch.sh <workspace-path> [max-iterations]}"
    local max_iter="${2:-75}"
    local iter=0

    printf "\n${BOLD}${CYAN}  arch-runner${RESET}\n"
    printf "  ${DIM}workspace:  %s${RESET}\n" "$workspace"
    printf "  ${DIM}max-iter:   %d${RESET}\n" "$max_iter"
    printf "  ${DIM}schedule:   %s (%s)${RESET}\n\n" "$RESEARCH_HOURS" "$TZ"

    while [[ $iter -lt $max_iter ]]; do
        iter=$((iter + 1))
        print_status "$iter" "$max_iter" "$workspace"

        run_iteration "$workspace"

        # Check for completion
        if check_completed; then
            printf "\n  ${GREEN}${BOLD}Architecture exploration complete${RESET} after %d iterations.\n\n" "$iter"
            rm -f "$LAST_OUTPUT"
            break
        fi

        # Check for rate limit
        if check_rate_limit; then
            wait_for_reset
        fi

        rm -f "$LAST_OUTPUT"
        sleep 2
    done

    if [[ $iter -ge $max_iter ]]; then
        printf "\n  ${YELLOW}Max iterations reached${RESET} (%d).\n\n" "$max_iter"
    fi
}

main "$@"
```

- [ ] **Step 2: Write .env.example**

Write to `containers/arch-tool/.env.example`:

```
# Arch-tool runner config — copy to .env and customize
RESEARCH_HOURS="23:00-07:00"
TZ="America/Vancouver"
CONTAINER_NAME="arch-sandbox"
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x containers/arch-tool/run-arch.sh containers/arch-tool/entrypoint.sh
```

- [ ] **Step 4: Commit**

```bash
git add containers/arch-tool/run-arch.sh containers/arch-tool/.env.example
git commit -m "feat(arch-tool): add run script and env config"
```

---

### Task 10: Update plugin.json and marketplace.json

**Files:**
- Modify: `plugins/offline-research/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update plugin.json**

Replace the contents of `plugins/offline-research/.claude-plugin/plugin.json` with:

```json
{
  "name": "offline-research",
  "description": "Tools for structured offline research and architecture exploration using ralph-loop",
  "version": "2.3.0",
  "author": {
    "name": "dev32-io"
  }
}
```

- [ ] **Step 2: Update marketplace.json version to match**

In `.claude-plugin/marketplace.json`, update the offline-research entry:

Change:
```json
    {
      "name": "offline-research",
      "description": "Tools for structured offline research using ralph-loop",
      "version": "2.2.0",
      "source": "./plugins/offline-research",
      "category": "productivity"
    }
```

To:
```json
    {
      "name": "offline-research",
      "description": "Tools for structured offline research and architecture exploration using ralph-loop",
      "version": "2.3.0",
      "source": "./plugins/offline-research",
      "category": "productivity"
    }
```

- [ ] **Step 3: Commit**

```bash
git add plugins/offline-research/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(offline-research): bump to 2.3.0 — add arch-forge skill"
```

---

### Task 11: Verification

- [ ] **Step 1: Verify template reorganization**

```bash
ls plugins/offline-research/templates/research-probe/
ls plugins/offline-research/templates/arch-forge/
```

Expected research-probe: `critique-loop.md  progress.md  prompt.md  ralph-command.md  scoring-rubric.md`

Expected arch-forge: `expansion-loop.md  progress.md  prompt.md  scoring-rubric.md`

- [ ] **Step 2: Verify skill files exist**

```bash
ls plugins/offline-research/skills/research-probe/SKILL.md
ls plugins/offline-research/skills/arch-forge/SKILL.md
```

Expected: both files exist.

- [ ] **Step 3: Verify container files exist**

```bash
ls containers/arch-tool/
```

Expected: `Dockerfile  entrypoint.sh  launch.sh  run-arch.sh  .env.example`

- [ ] **Step 4: Build the arch-tool container**

```bash
cd containers/arch-tool && docker build -t arch-tool . && cd -
```

Expected: image builds successfully.

- [ ] **Step 5: Verify poc user exists in container**

```bash
docker run --rm arch-tool bash -c "id poc"
```

Expected: `uid=1001(poc) gid=1001(poc) groups=1001(poc)` (or similar)

- [ ] **Step 6: Verify poc user cannot read .claude/**

```bash
docker run --rm -v "$HOME/.claude:/home/node/.claude:ro" arch-tool bash -c "chmod 700 /home/node/.claude && su -c 'ls /home/node/.claude' poc"
```

Expected: `ls: cannot open directory '/home/node/.claude': Permission denied`

- [ ] **Step 7: Verify PoC toolchain availability**

```bash
docker run --rm arch-tool bash -c "bun --version && rustc --version && go version && tsc --version && python3 --version && chromium --version"
```

Expected: version numbers for all tools.

- [ ] **Step 8: Verify research-probe template paths still work**

Check that the SKILL.md references `templates/research-probe/`:

```bash
grep 'templates/research-probe' plugins/offline-research/skills/research-probe/SKILL.md
```

Expected: 4 matches (one per template file).

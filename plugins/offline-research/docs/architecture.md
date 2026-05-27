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

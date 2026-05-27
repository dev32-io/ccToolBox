# offline-research v2 — pure-skill workshop-loop

**Status:** Design accepted, ready for implementation plan
**Date:** 2026-05-26
**Author:** brainstorm session with Claude Code
**Successor to:** [2026-04-02-research-loop-design.md](2026-04-02-research-loop-design.md), [2026-04-03-arch-forge-design.md](2026-04-03-arch-forge-design.md), [2026-04-06-refactor-probe-workshop-design.md](2026-04-06-refactor-probe-workshop-design.md)
**Plugin version target:** offline-research `2.4.2` → `3.0.0` (breaking)

---

## 1. Why

Three triggers converge:

1. **Subscription billing change** — Anthropic splits Claude Code billing on 2026-06-15. Interactive Claude Code (terminal + IDE) keeps drawing from the subscription quota. Non-interactive `claude -p`, the Agent SDK, and the GitHub Action all move to a separate Agent SDK credit bucket. The current `containers/workshop/run-*.sh` scripts drive iteration via `docker exec ... claude -p "<prompt>"`, so they will start burning the new credit pool on every iteration. A multi-hour research run = expensive.

2. **Single-template fragility** — v1's per-skill workflow (research / arch / refactor) crams loop instructions, dispatch rules, plateau math, and dim-aware expansion into one `prompt.md` + `critique-loop.md` + `expansion-loop.md` triple per skill. Three near-duplicate copies of nearly identical procedural logic. Editing the scoring procedure means editing three files. Editing the expansion rules likewise.

3. **Claude Code now has first-class subagents** — `.claude/agents/<name>.md` (auto-registered when shipped by a plugin) lets us extract the procedural blobs into dedicated agent personas with their own model, tools, and prompts. The generator-verifier pattern that powers v1's critique is a textbook case.

v2 is a pure-skill rebuild that:
- Replaces the host-side `claude -p` runner with an in-session orchestrator (subscription-safe).
- Decomposes the giant templates into 5 plugin-shipped agents.
- Keeps the container as an optional sandbox-by-shell for PoC validation.

## 2. Non-goals

- **No mid-run rubric mutation.** Co-evolving critic (ECHO, Jan 2026) is interesting but breaks the offline invariant — runs are unattended. End-of-run "suggest a rerun with revised rubric" lives in the synthesizer's report instead.
- **No fresh session per iteration.** True session restart would require `claude -p`, the thing we're avoiding. Subagent delegation + auto-compaction get us most of the same context-hygiene benefit.
- **No live cancel command.** State is file-based; Ctrl-C is the cancel. Findings, scores, PoCs all on disk.

## 3. Architecture

### 3.1 Plugin directory layout (target)

```
plugins/offline-research/
├── .claude-plugin/plugin.json          # version → 3.0.0
├── README.md                           # rewrite for v2
├── CHANGELOG.md                        # v3.0.0 entry (breaking)
├── skills/
│   ├── research-probe/SKILL.md         # slim — drops container run options
│   ├── arch-forge/SKILL.md             # slim — drops container run options
│   └── refactor-probe/SKILL.md         # slim — drops container run options
├── agents/                             # NEW — plugin-shipped, auto-registered
│   ├── topic-researcher.md
│   ├── critique-scorer.md
│   ├── expansion-planner.md
│   ├── poc-builder.md
│   └── synthesizer.md
├── commands/                           # NEW
│   └── workshop-loop.md
├── hooks/                              # NEW
│   ├── hooks.json
│   └── workshop-loop-stop.sh
├── scripts/                            # NEW
│   └── validate-probe-dir.sh
├── templates/
│   ├── research-probe/
│   │   ├── mission.md                  # was prompt.md, slimmed
│   │   ├── progress.md                 # adds `max_iter:` header
│   │   └── scoring-rubric.md
│   ├── arch-forge/
│   │   ├── mission.md
│   │   ├── progress.md
│   │   └── scoring-rubric.md
│   └── refactor-probe/
│       ├── mission.md
│       ├── progress.md
│       └── scoring-rubric-template.md  # `hint_action` column folded in
└── docs/
    └── architecture.md                 # rewrite

containers/workshop/
├── launch.sh                           # delete `run` subcommand, add `shell`
├── entrypoint.sh                       # keep (sandbox setup still useful)
├── .env.example                        # trimmed (no RESEARCH_HOURS)
└── dockerfiles/
    ├── arch-claude.Dockerfile
    ├── arch-opencode.Dockerfile
    ├── refactor-claude.Dockerfile
    ├── refactor-opencode.Dockerfile
    ├── research-claude.Dockerfile
    └── research-opencode.Dockerfile
```

**Files deleted in v3.0.0:**

- `containers/workshop/run-research.sh`
- `containers/workshop/run-arch-forge.sh`
- `containers/workshop/run-refactor.sh`
- `containers/workshop/entrypoint-light.sh`
- `containers/workshop/entrypoint-light-opencode.sh`
- `plugins/offline-research/templates/*/prompt.md` (replaced by mission.md)
- `plugins/offline-research/templates/*/critique-loop.md`
- `plugins/offline-research/templates/*/expansion-loop.md`
- `plugins/offline-research/templates/research-probe/ralph-command.md`

### 3.2 Public surface

| Skill / command | Trigger | Role |
|---|---|---|
| `/research-probe` | unchanged | Intake → seed files (research topics) |
| `/arch-forge` | unchanged | Intake → seed files (architecture decisions) |
| `/refactor-probe` | unchanged | Intake → seed files (codebase refactor + rubric co-design) |
| `/workshop-loop <probe-dir> [--max-iter N]` | **NEW** | Master orchestrator. Runs the dispatch loop. |

No cancel command. Ctrl-C is cancel. Re-invoking `/workshop-loop` on the same probe-dir resumes from progress.md state.

### 3.3 The five agents

All at `plugins/offline-research/agents/<name>.md` with YAML frontmatter. Auto-registered when the plugin is enabled. Invoked via the Agent tool with `subagent_type: "<name>"`.

| Agent | Model | Handles | Tools |
|---|---|---|---|
| `topic-researcher` | opus | `Research:`, `Explore:`, `Improve:`, `Investigate:`, `Decompose:`, `Refocus:`, `Simplify:`, `Rethink:`, `Connect:` | WebSearch, WebFetch, Read, Glob, Grep, Write, Edit, Bash |
| `critique-scorer` | sonnet | `Score:`, `Critique & Score:` — strict isolation: reads rubric + one finding ONLY | Read, Write |
| `expansion-planner` | sonnet | Invoked by lead immediately after critique-scorer returns — computes Δ, applies plateau math + dim hints, emits append-task list | Read, Edit |
| `poc-builder` | opus | `PoC:`, `Build:` — sandbox-aware (checks `$WORKSHOP_CONTAINER`) | Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch |
| `synthesizer` | opus | `Synthesize`, `Final report` — also writes rubric-retrospective suggestions | Read, Glob, Write, Edit |

**Cross-cutting contract:**

- **Files-not-tokens.** Bulk content goes to disk under `<probe-dir>/`. Subagents return ≤3-line summaries (file paths + outcome metadata only).
- **Atomic edits.** Any write to progress.md uses the Edit tool with a single old→new diff. Never Write (full overwrite). Hook reads progress.md as read-only — no race risk.
- **Isolation rule** (critique-scorer specifically): MUST NOT read other findings, mission.md, connections.md, prior scores, or progress.md. Rubric + target finding only.

#### Return-shape contract (≤3 lines, file paths only)

| Agent | Return |
|---|---|
| `topic-researcher` | `wrote findings/<topic>.md, sources +N → sources.md, gaps → gaps.md` |
| `critique-scorer` | `score: T/M, dims: a=N b=N..., friction → scores/<topic>-<ts>.md` |
| `expansion-planner` | `appended N tasks: <comma-list>, Δ=N, streak=N, status: ACTIVE\|CONCLUDED` |
| `poc-builder` | `built poc/<name>/, entry: poc/<name>/<file>, notes → poc/<name>/NOTES.md` |
| `synthesizer` | `wrote synthesis.md, README.md updated, retro-suggestions: N` |

#### Lead per-iteration footprint

- Read progress.md: ~1-2K tokens
- Dispatch subagent + receive ≤300 token summary
- Edit progress.md (check off + append): ~200 tokens

≈1-2K tokens per iteration. 70 iters ≈ 100K tokens before any compaction. Comfortable under Opus 4.7's 1M context.

### 3.4 Loop driver — stop hook + stateless markers

The stop hook is the bash-side gate that keeps the loop running. It is **stateless across runs**: no `.claude/workshop-loop.local.md`, no setup script. State is derived on every fire from two sources:

1. **`<probe-dir>/progress.md`** — task queue, scoreboard, `max_iter: N` header. Source of truth for iteration count.
2. **Session transcript** — scanned for activation/done markers emitted in chat.

#### Markers (in transcript only)

```
[workshop-loop-active] probe_dir=/abs/path     ← emitted by /workshop-loop command body
[workshop-loop-done]   probe_dir=/abs/path     ← emitted on natural completion
```

The hook scans for the **most recent** marker of either type:
- No marker found → not a workshop-loop session → exit 0 (release)
- Most recent is `-done` → loop completed in this session, user is in post-run chat → fast exit 0
- Most recent is `-active` → extract probe_dir, read progress.md, run termination tests, otherwise block + re-feed

#### Termination conditions (any one releases)

1. `<promise>RUN COMPLETE</promise>` present in last assistant text block
2. `grep -c '^- \[ \]' progress.md == 0` AND `grep -c '| ACTIVE |' progress.md == 0`
3. `grep -c '^- \[x\]' progress.md >= max_iter`

Test 2 is the small-model drift gate — even if a Haiku-as-orchestrator hallucinates "all done", the hook objectively re-checks progress.md and refuses release unless reality matches.

#### Hook script (sketch — ~50 lines)

```bash
#!/bin/bash
set -euo pipefail

HOOK_INPUT=$(cat)
TRANSCRIPT=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""')
[[ -f "$TRANSCRIPT" ]] || exit 0

# Find most recent marker (active or done)
LAST_MARKER=$(grep '"role":"assistant"' "$TRANSCRIPT" | tail -n 200 | \
  jq -rs 'map(.message.content[]? | select(.type=="text") | .text) | join("\n")' | \
  grep -oE '\[workshop-loop-(active|done)\] probe_dir=\S+' | tail -n 1)

[[ -z "$LAST_MARKER" ]] && exit 0
echo "$LAST_MARKER" | grep -q 'done' && exit 0   # post-run fast path

PROBE_DIR=$(echo "$LAST_MARKER" | sed 's/.*probe_dir=//')
PROGRESS="$PROBE_DIR/progress.md"
[[ -f "$PROGRESS" ]] || exit 0

MAX_ITER=$(grep -m1 '^max_iter:' "$PROGRESS" | sed 's/max_iter: *//' | tr -d '[:space:]')
[[ -z "$MAX_ITER" ]] && MAX_ITER=999
ITER=$(grep -c '^- \[x\]' "$PROGRESS" || echo 0)
PENDING=$(grep -c '^- \[ \]' "$PROGRESS" || echo 0)
ACTIVE_ROWS=$(grep -c '| ACTIVE |' "$PROGRESS" || echo 0)

LAST_TEXT=$(grep '"role":"assistant"' "$TRANSCRIPT" | tail -n 50 | \
  jq -rs 'map(.message.content[]? | select(.type=="text") | .text) | last // ""')
PROMISE=$(echo "$LAST_TEXT" | perl -0777 -ne 'print $1 if /<promise>\s*(RUN COMPLETE)\s*<\/promise>/s')

[[ "$PROMISE" == "RUN COMPLETE" ]] && { echo "✅ workshop-loop: RUN COMPLETE (iter $ITER)"; exit 0; }
[[ $PENDING -eq 0 && $ACTIVE_ROWS -eq 0 ]] && { echo "✅ workshop-loop: all CONCLUDED (iter $ITER)"; exit 0; }
[[ $ITER -ge $MAX_ITER ]] && { echo "🛑 workshop-loop: max_iter $MAX_ITER reached"; exit 0; }

jq -n --arg p "Read $PROBE_DIR/progress.md. Find first unchecked task. Dispatch agent per dispatch table in workshop-loop command. After agent returns, edit task line to [x]. If Score: task, also dispatch expansion-planner. Then stop." \
  --arg msg "workshop-loop iter $ITER/$MAX_ITER ($PENDING pending)" \
  '{decision:"block", reason:$p, systemMessage:$msg}'

exit 0
```

#### Comparison vs ralph-loop hook

| | ralph | workshop-loop |
|---|---|---|
| Iteration counter | YAML frontmatter, written by hook | Derived from `grep -c '^- \[x\]' progress.md` |
| State file | `.claude/ralph-loop.local.md` | none |
| Termination | promise OR max_iter | promise OR max_iter OR `(pending==0 && active==0)` |
| State writes by hook | yes (increments iteration) | none (read-only) |
| Cancel mechanism | rm state file | Ctrl-C |
| Resume after kill | rerun /ralph-loop (state recreated) | rerun /workshop-loop (state from progress.md) |

### 3.5 Seed file contract

What probe skills generate at intake time, drastically reduced from v1:

| File | v2 role | Reader |
|---|---|---|
| `mission.md` | One-paragraph project intent + constraints. ~30 lines max. Replaces `prompt.md`. | All agents at dispatch time |
| `progress.md` | Scoreboard + task queue + `max_iter: N` header. Source of iteration state. | Hook (read), orchestrator (write), expansion-planner (write appends) |
| `scoring-rubric.md` | Dims + 0/5/10 anchors. For refactor-probe: `hint_action` column with BUILD/INVESTIGATE/RETHINK/REFOCUS actions per dim. | critique-scorer (reads), expansion-planner (reads hint_action) |
| `topics/<n>-<name>.md` | Sub-questions/angles per topic. One file per topic. | topic-researcher (reads its target) |

**Reduction:**

| Metric | v1 | v2 |
|---|---|---|
| Templates per skill | 4 (prompt/progress/critique-loop or expansion-loop/rubric) | 3 (mission/progress/rubric) |
| Lines of templated procedure | ~250/skill | ~50/skill |
| Cross-skill procedural duplication | high (critique-loop near-identical across 3 skills) | zero (lives in agent files) |

### 3.6 Parallel topic execution

Single iteration can dispatch up to **MAX_PARALLEL=4** agents in parallel when tasks are independent. Lead orchestrator scans the queue for eligible batches.

**Eligible:**
- Task type ∈ {Research, Improve, Investigate, Explore, Connect}
- Across distinct topics (no two parallel tasks for same topic)
- Up to MAX_PARALLEL (configurable via `max_parallel: N` header in progress.md, default 4)

**Not eligible (run alone):**
- `Score:`, `Critique & Score:` — critique-scorer needs isolation; expansion-planner mutates progress.md (race risk)
- `PoC:`, `Build:` — Bash writes, expensive
- `Synthesize`, `Final report` — reads all findings, end-of-run

**Iteration procedure (revised for parallel):**

```
1. Read progress.md
2. Find first unchecked task
3. If task is parallelizable:
     - scan forward, collect up to MAX_PARALLEL eligible tasks across distinct topics
     - dispatch all in single Agent tool call (parallel content blocks)
     - on returns: Edit each [ ] → [x] individually
     - partial failures: failed agent's task stays [ ], retried next iteration
4. Else:
     - dispatch single agent (sequential)
     - if Score, follow with expansion-planner
     - Edit task → [x]
5. Re-read progress.md; emit done marker if terminal state
6. Stop (hook handles next iter or release)
```

Iteration counter still = `grep -c '^- \[x\]'`. A 4-task batch advances counter by 4 in one lead invocation.

### 3.7 Cross-topic transfer (`connections.md`)

Created lazily on first cross-topic insight. Format:

```markdown
# Cross-Topic Connections

## stt-providers ↔ openrouter-streaming
Both face rate-limit cascades when burst load > 50 req/s. Solution from
stt-providers (token-bucket pre-throttle) likely applies to openrouter.

→ feed into: Improve: openrouter-streaming
```

**Integration points:**

1. **topic-researcher reads connections.md on Improve/Explore tasks.** Filters entries mentioning target topic; uses insights to shape direction.
2. **topic-researcher writes new connections during research.** When an insight applies to another topic in the scoreboard, append entry to `connections.md` (atomic append).
3. **expansion-planner can append `Connect:` tasks.** When friction log mentions cross-topic relevance, planner appends `- [ ] Connect: <topic-a> ↔ <topic-b> (insight: <one-line>)`. topic-researcher handles `Connect:` task by deepening the link, possibly editing both findings.

Zero new agents, zero new files at seed time. <50 lines added across topic-researcher + expansion-planner bodies.

### 3.8 End-of-run rubric retrospective

Synthesizer's `Final report` task scans the scoreboard for plateau anomalies:
- Topic CONCLUDED at `total < 60% of max`
- First plateau Δ ≤ 1 (rubric may be measuring the wrong dimension)

Writes a `## Suggested Reruns` section in `README.md`:

```markdown
## Suggested Reruns

- **stt-providers** plateaued at 28/50 after 2 rounds. Score floor came from
  `Latency Sensitivity` (3/10 across both rounds). Current rubric treats
  sub-100ms requirements as a 5/10 anchor — consider rerunning with
  Latency Sensitivity weighted higher or with a stricter anchor.

- **auth-migration**: first plateau Δ=1 from 22 → 23. Rubric's `Rollback Viability`
  (currently INVESTIGATE) may be a BUILD tag instead — improvements asked for
  research when the gap is actually proof-by-prototype.
```

Suggestions only. No mid-run rubric change. Preserves the offline invariant.

## 4. Container fate — sandbox by shell

### 4.1 What goes away

- `containers/workshop/run-research.sh`, `run-arch-forge.sh`, `run-refactor.sh` — host-side `claude -p` drivers.
- `launch.sh run` subcommand body.
- `entrypoint-light.sh`, `entrypoint-light-opencode.sh` — were for headless research-profile boots.

### 4.2 What stays

- `entrypoint.sh` — sandbox setup (poc user, /workspace permissions, /home/node/.claude lockdown). Still useful in interactive mode.
- All six Dockerfiles (arch/refactor/research × claude/opencode).
- `launch.sh build` subcommand, unchanged.

### 4.3 New `launch.sh shell` subcommand

```bash
./launch.sh shell --container=refactor /path/to/probe-dir
```

Behavior:
1. Resolve profile + agent, pick image.
2. `docker run --rm -it` with:
   - Volume: `<probe-dir> → /workspace`
   - Volume: `~/.claude → /home/node/.claude` (interactive auth forward)
   - For refactor: `<probe-dir>/codebase → /workspace/codebase:ro`
   - Resource limits as v1
   - Env: `WORKSHOP_CONTAINER=1` (poc-builder reads this)
   - Entrypoint: `bash` → user lands at `/workspace`
3. Print:
   ```
   📦 You're inside workshop-refactor sandbox at /workspace.
      Run: claude
      Then in Claude: /workshop-loop /workspace
   ```

Subscription billing applies (interactive `claude`, not `claude -p`). Sandbox isolation comes for free.

### 4.4 poc-builder sandbox awareness

Agent body checks `$WORKSHOP_CONTAINER` via Bash. If unset (host mode): writes PoC files but **refuses execution** (no python/node/cargo runs). Annotates `NOTES.md`: `EXECUTION SKIPPED — re-run inside ./launch.sh shell to validate`.

If set (container mode): full Bash. Uses `sudo -u poc` for writes to `/workspace/poc/` per entrypoint's permission setup.

## 5. Probe skill updates

The three intake skills get parallel changes (no new logic, just trimmed and re-pointed):

### 5.1 Drop container run options

Current "How do you want to run this?" menu offers three options (auto-resume container, manual container, local). v2 reduces to one local option, with sandbox-by-shell as a separate flow:

```
> **How do you want to run this?**
> 1. /workshop-loop in current session (Recommended)
> 2. /workshop-loop inside a sandbox container (for PoC code that must execute)
```

After user picks 1:

```
/workshop-loop <probe-dir>
```

After user picks 2:

```
./containers/workshop/launch.sh build --container=<profile>
./containers/workshop/launch.sh shell --container=<profile> <probe-dir>
# inside the container:
claude
# in Claude Code:
/workshop-loop /workspace
```

### 5.2 Seed file location ordering (changed)

Old order favored `~/offline-research/` (user-global). New order:

```
> Where should I write the seed files?
> 1. <cwd>/<short-title>/                            (Recommended)
> 2. ~/offline-research/<short-title>/
> 3. Type a custom path
```

**Why cwd-first:** the workshop-loop hook + agents only activate inside a project that has the offline-research plugin enabled at repo level. Putting seed files under cwd keeps the probe co-located with the project that's installing the plugin — which is the canonical setup.

### 5.3 New README guidance

Plugin README recommends repo-level install (`.claude-plugin/marketplace.json` in the user's project pointing at ccToolBox) rather than user-global. Rationale:
- Hooks are scoped to the repo (the stop hook only fires in sessions where the repo's `.claude-plugin` enables the plugin).
- Probe seed files live next to the project they research.
- Multiple repos can have different versions / configurations.

### 5.4 Other skill body trims

- Remove "max-iterations formula" output. `workshop-loop` derives it from progress.md header, which the probe skill writes. Formula stays (`topics × 8 + 10` for research, `decisions × 10 + 15` for arch, `topics × 10 + 15` for refactor) but is internal to the probe skill — surfaced to user only as the populated `max_iter:` value.
- Remove references to `critique-loop.md`, `expansion-loop.md`, `ralph-command.md` from skill body.
- Update `Read templates` step to fetch `mission.md` instead of `prompt.md`.

## 6. Param validation script

`plugins/offline-research/scripts/validate-probe-dir.sh` — invoked from `commands/workshop-loop.md` body via `!` block before the orchestrator emits its activation marker. Exits non-zero on any failure with a clear message:

- `2` — bad CLI args (missing probe-dir, malformed --max-iter)
- `1` — probe-dir missing required files (`mission.md`, `progress.md`, `scoring-rubric.md`)
- `1` — `progress.md` missing or invalid `max_iter: N` header
- `3` — probe-dir already in terminal state (nothing to do)
- `0` — emits `VALIDATED probe_dir=<abs> max_iter=<n> pending=<n> active=<n>` line for the command body to parse

On non-zero, the command body STOPS — does not emit the activation marker.

If `--max-iter N` is supplied and validates, the script overwrites the `max_iter:` line in `progress.md` (atomic sed + mv).

## 7. Improvements explicitly deferred

These came up in the web survey + brainstorm but are **not in v2.0** scope:

- **Co-evolving critic (ECHO).** Mid-run rubric mutation breaks offline invariant. Replaced by end-of-run synthesizer "Suggested Reruns" section.
- **Rubric versioning.** Same reasoning. User re-runs with a new probe directory if the rubric needs to change.
- **Done-marker `.claude/.wsl-done` cache (v2.1 candidate).** When max_iter hits without natural completion, hook releases but lacks a done marker. Post-run hook fires re-read progress.md (~50ms each). Acceptable for v2.0. v2.1 optimization: hook writes a one-line marker file on max-iter release; subsequent fires fast-exit.

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Small-model orchestrator hallucinates completion | Hook re-derives state from progress.md objectively. `pending==0 && active==0` is the only natural-completion gate. Promise tag is not an escape hatch. |
| Lead stops early (Claude decides "done" after few iters) | Hook re-feeds prompt via `decision: block`. Lead is forced to continue. |
| Subagent failures in parallel batch | Lead checks each return individually. Failed agent's task stays `[ ]`, picked up next iteration. |
| Hook misfires on transcript false positive (user pastes log containing marker) | Marker format is specific enough (`[workshop-loop-active] probe_dir=`) to be effectively unique. If user genuinely pastes that AND the path resolves AND has a valid progress.md, they're starting a loop. Edge case acceptable. |
| Multi-session conflict (two terminals, two `/workshop-loop`s on different probes) | Each session has its own transcript file; hook reads only its own session's transcript and finds its own marker. Independent. |
| PoC code execution in host mode (no sandbox) | poc-builder agent body explicitly refuses execution if `$WORKSHOP_CONTAINER` unset. Writes files only. User can rerun in sandbox to validate. |
| Token spend on Opus agents (4 parallel) | Subscription model = no marginal cost. Rate-limit risk capped by `max_parallel: 4` (configurable). |

## 9. Migration

CHANGELOG v3.0.0 entry surfaces:

- **BREAKING:** `./launch.sh run` retired. Use `/workshop-loop <probe-dir>` instead.
- **BREAKING:** Containers no longer run autonomously. Use `./launch.sh shell` then `/workshop-loop /workspace` from inside interactive `claude`.
- **BREAKING:** Probe seed files trimmed — `prompt.md` → `mission.md`; `critique-loop.md` and `expansion-loop.md` removed (logic moved into plugin-shipped agents); for refactor-probe, `hint_action` column folds into `scoring-rubric.md`.
- **NEW:** `/workshop-loop` command, stop hook, 5 plugin-shipped agents.
- **NEW:** Parallel topic execution (up to 4 distinct-topic Research/Improve/Investigate/Explore/Connect tasks per iteration).
- **NEW:** `connections.md` for cross-topic insights.
- **NEW:** End-of-run "Suggested Reruns" retrospective in `README.md`.

No migration helper for existing v1 probe dirs — they remain runnable on v1 until the user discards them. Going forward, all new probes use v2 templates from the probe skills.

## 10. Implementation order (high-level — detailed plan to follow in writing-plans phase)

1. **Agent definitions** — write 5 agent files. Pure prompt work, no integration. Verifiable by unit-style spawn from any session.
2. **Templates v2** — write new `mission.md`, modified `progress.md`, modified `scoring-rubric.md` for each of the three probe variants.
3. **Probe skill updates** — three SKILL.md files: drop container options, change location ordering, change final command emission.
4. **`/workshop-loop` command** — `commands/workshop-loop.md` body with dispatch table.
5. **Validation script** — `scripts/validate-probe-dir.sh`.
6. **Stop hook** — `hooks/workshop-loop-stop.sh` + `hooks/hooks.json`.
7. **Container shell mode** — `launch.sh shell` subcommand; remove `run`; delete runner scripts and light entrypoints.
8. **Plugin metadata** — bump plugin.json + marketplace.json to 3.0.0. CHANGELOG entry. README rewrite.
9. **Docs** — rewrite `plugins/offline-research/docs/architecture.md` for v2 mechanics.

End-to-end smoke test: run /research-probe with a small topic (1-2 topics), invoke /workshop-loop, observe at least one full Research → Score → Improve → Score round, then a synthesize + final report. Verify done marker emission, post-run chat has fast hook fires, resume after Ctrl-C works.

---

**Next step:** writing-plans skill produces the detailed implementation plan from this spec.

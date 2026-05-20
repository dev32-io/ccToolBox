# offline-research: Container Architecture

> Originally documented in [CHANGELOG.md](../CHANGELOG.md).
> Related design specs: [`2026-04-03-arch-forge-design.md`](../../../docs/superpowers/specs/2026-04-03-arch-forge-design.md), [`2026-04-06-refactor-probe-workshop-design.md`](../../../docs/superpowers/specs/2026-04-06-refactor-probe-workshop-design.md).

I built `offline-research` because long-running exploration with Claude inside a chat is broken. Token budget runs out, attention drifts, and there is no persistence across restarts. The container is the UX boundary. A specialized skill writes a structured prompt, progress tracker, and scoring rubric; the container reads them, runs hours of work in isolation, and produces scored alternatives plus PoC code as artifacts. When a rate limit hits at 2 AM, the runner pauses and resumes automatically at the next window. When the container crashes, nothing is lost. State lives in files, not in a conversation context.

The three skills (research-probe, arch-forge, refactor-probe) share the same container loop pattern. What differs is what the agent explores (research topics vs. architecture decisions vs. refactoring approaches), how the scoring rubric is defined (fixed dimensions vs. user co-designed), and which expansion logic fires when scores come in weak.

---

## How it works

> All file:line references below are relative to the repository root unless otherwise noted.

### Container lifecycle

`containers/workshop/launch.sh` is the single entrypoint for all three profiles. It parses `--container=research|arch|refactor` from any argument position (lines 15–27) and routes to an image name, container name, runner script, and resource limit set. Research gets no resource limits. Arch and refactor each get `--memory=4g --cpus=4 --pids-limit=200` (launch.sh lines 37–60).

**Dockerfile selection.** `launch.sh` derives the Dockerfile path from the profile and agent name: `DOCKERFILE="$SCRIPT_DIR/dockerfiles/${PROFILE}-${AGENT}.Dockerfile"` (launch.sh line 68). There are six Dockerfiles total — three profiles (`arch`, `refactor`, `research`) × two agents (`claude`, `opencode`) — covering every supported combination. Each Dockerfile in `containers/workshop/dockerfiles/` installs the agent toolchain and user permissions appropriate for that profile and agent pair.

**"Always recreate" container philosophy.** The `run` subcommand checks whether a container with the target name already exists; if so, it `docker rm -f`s it before recreating (launch.sh lines 128–130). State lives on mounted volumes (`/workspace`, `/home/node/.claude`), so tearing down the container loses nothing. The benefit is that every `launch.sh run` picks up the latest image build automatically — no "container is stale" class of bugs. The container is the execution surface; the volumes are the state.

**Entrypoint behavior splits by profile.** Research uses `containers/workshop/entrypoint-light.sh`, which is a conditional exec passthrough: if the first argument is `tail` or `bash` or `sh` (keep-alive or debug invocations), it does `exec "$@"` directly; otherwise it runs `exec claude --dangerously-skip-permissions "$@"`. There is no user-switching in the light entrypoint — the container already runs as the appropriate user. Arch and refactor use `containers/workshop/entrypoint.sh`, which runs as root first and sets up security boundaries before dropping to `node`. It `chown`s `/workspace` to `node:node`, then iterates over workspace subdirectories (excluding `poc/`) to restrict write access. It creates `/workspace/poc/` owned by `poc:poc` with mode 755, restricts `/home/node/.claude` to mode 700, then drops to `node` via `gosu` using the same conditional passthrough as the light variant (`entrypoint.sh` lines 26–30). The `poc` user exists so PoC code runs in an isolated sandbox. `node` cannot write to `/workspace/poc/` directly, `poc` cannot read auth credentials, and all PoC writes require `sudo -u poc`. Because the volume is mounted at container start, not at image build time, the permission setup must happen at entrypoint time — it cannot be baked into the Dockerfile.

**Runner script handoff.** Once the container is running, `launch.sh`'s `cmd_run` function (line 183) does `exec "$SCRIPT_DIR/$RUNNER_SCRIPT" "$max_iter"` — handing control to one of three profile-specific runner scripts: `run-research.sh`, `run-arch-forge.sh`, or `run-refactor.sh`. The runner script is what drives the iteration loop on the host side: it invokes `docker exec` for each task, watches for `TASK DONE` output, handles 429 rate-limit pauses, and enforces the schedule window (`RESEARCH_HOURS`, default `23:00-07:00`). The separation between `launch.sh` (image build + container lifecycle) and the runner script (iteration loop) means container concerns and loop concerns don't mix.

### Structured I/O contract

Each skill writes four seed files before handing off to the container. The container reads files, not CLI flags, which makes every run resumable without restart.

| File | Purpose |
|------|---------|
| `prompt.md` | Mission + workspace layout + workflow instructions. For research: `[TOPIC]` and `[TOPICS]`. For arch: project intent, constraints, architecture sketch, and `[DECISIONS]`. For refactor: title, codebase context, goals, and `[TOPICS]`. |
| `progress.md` | Scoreboard table + linear task queue. The agent reads the first unchecked item, does it, checks it off, and outputs `TASK DONE`. The runner sees `TASK DONE` and invokes the next iteration. |
| `critique-loop.md` / `expansion-loop.md` | Instructions for the scoring step. Research uses `templates/research-probe/critique-loop.md`. Arch and refactor use `templates/arch-forge/expansion-loop.md` and `templates/refactor-probe/expansion-loop.md` respectively. These tell the agent how to spawn the Sonnet subagent, compute Δ, and append to the task queue. |
| `scoring-rubric.md` | Scoring dimensions with 0/5/10 anchors. The subagent gets this file and nothing else besides the one topic's output. For refactor-probe, this file is generated from `templates/refactor-probe/scoring-rubric-template.md` using the user's co-designed dimensions. |

The contract is intentional. The container does not receive goals via environment variables. It reads `prompt.md` once for mission context and `progress.md` on every iteration for the current task. A run interrupted mid-session picks up exactly where it left off.

### Critique loop with plateau math

Every research-probe scoring step and every arch-forge/refactor-probe `Score` task follows the same plateau logic, documented in `templates/research-probe/critique-loop.md` lines 22–37 and `templates/arch-forge/expansion-loop.md` lines 55–66.

The agent spawns a Sonnet subagent with only the scoring rubric and the one topic's output file. No exploration history, no web access. The subagent scores the output and returns a friction log. The agent records the score in `progress.md`, computes Δ (this total minus the last total for this topic), and updates the streak counter.

```
Δ > 3 (gaining):
  → apply dimension-specific expansion, append improve tasks
  → streak → 0

Δ ≤ 3, streak 0 (first plateau):
  → append one more improvement task
  → streak → 1

Δ ≤ 3, streak ≥ 1 (second plateau):
  → mark CONCLUDED in scoreboard
  → no more tasks appended for this topic
```

A topic that jumps from 28 to 40 has Δ = 12. Gaining, keep expanding. One that moves from 42 to 43 has Δ = 1. Plateau, one more try. Then 43 to 44: Δ = 1 again, streak ≥ 1, CONCLUDED. The math terminates fast on easy topics and gives hard ones room to breathe.

### Dimension-aware expansion (arch-forge)

Arch-forge expansion logic lives in `templates/arch-forge/expansion-loop.md` lines 29–66. After scoring, the agent checks which dimensions fell below 6 and applies the corresponding action, with Alignment as the highest-priority override.

```
Alignment < 6 (BRAKE):
  → do NOT expand. Add: Refocus task only.
  → overrides all other rules.

Feasibility < 6 (BUILD):
  → add: PoC task. Build, don't research more.
  → if PoC already exists, add an alternative PoC.

Maintainability < 6 (DECOMPOSE):
  → add: Decompose task. Break into smaller pieces.
  → add: Explore sub-tasks for each new piece.

Risk < 6 (INVESTIGATE):
  → add: Investigate failure modes and edge cases.
  → reference specific gaps from subagent's friction log.

Effort < 6 (SIMPLIFY):
  → add: Simplify task. Find a lighter approach.
  → add: Explore alternative task.
```

A decision area cannot be marked CONCLUDED with fewer than 2 scored approaches (`templates/arch-forge/expansion-loop.md` line 83). If only one approach has been explored and the plateau is hit, the agent spawns an alternative exploration first. The user always gets options.

### Rubric co-design (refactor-probe)

Arch-forge uses a fixed dimension taxonomy (Alignment / Feasibility / Maintainability / Risk / Effort) with built-in expansion rules (BRAKE / BUILD / DECOMPOSE / INVESTIGATE / SIMPLIFY). Refactor-probe uses a user-designed scoring rubric where each dimension carries one of four hint tags (BUILD / INVESTIGATE / RETHINK / REFOCUS) that the loop reads at expansion time.

Refactor-probe's centerpiece is Phase 4 of the skill intake flow (`plugins/offline-research/skills/refactor-probe/SKILL.md` lines 67–138). Before the container ever starts, the user and skill co-design the scoring dimensions.

The skill asks 2–3 vibe questions: "What would make you confident this refactoring is worth pursuing?" and "What's your biggest fear about this migration?" The answers shape a custom rubric. The skill proposes 2–3 rubric sets, each with 3–7 dimensions and 0/5/10 anchors. Each dimension carries one of four hint tags that drive expansion behavior when the score falls below 6:

| Tag | Behavior |
|-----|---------|
| **BUILD** | Spawn a PoC task. Proof needed, not more research. |
| **INVESTIGATE** | Spawn a research task. More information needed. |
| **RETHINK** | Decompose or explore an alternative approach. |
| **REFOCUS** | Alignment brake. Re-read goals, prune drift. Overrides all others. |

The hint tags are baked into `expansion-loop.md` at seed generation time via the `[DIMENSION_HINTS]` placeholder (`templates/refactor-probe/expansion-loop.md` line 27). The loop does not know about rubric dimensions generically. It reads the filled-in expansion rules for this specific experiment. A user who cares most about rollback safety will have a BUILD-tagged "Rollback Viability" dimension that spawns PoC tasks when weak. A user focused on complexity reduction will have a RETHINK tag that triggers decomposition.

---

## Tradeoffs and hard parts

**Why a container, not a long-running Claude session.** A chat session has a fixed token budget. At 100+ iterations, the context window fills with prior work and the model starts losing early research. There is no mechanism to restart a session mid-flight and resume from a checkpoint. The container sidesteps all of this: each iteration is a fresh invocation with the full token budget, the agent reads its state from files, and a crash or timeout loses at most one task. The cost is setup overhead (Docker build, volume mounts, auth forwarding) and the inability to interactively redirect mid-run. That tradeoff is acceptable for multi-hour explorations where the alternative is manually managing context.

**Why Sonnet for critique, not Opus.** The critique subagent reads the scoring rubric and one topic's output, applies friction-based scoring, and writes a structured response. The rubric does all the intellectual heavy lifting. It defines what "good" looks like and how deductions should work. Given a well-written rubric, Sonnet produces the same caliber of critique as Opus at a fraction of the cost. Running 20–40 scoring iterations on a long research run would be meaningfully expensive with Opus. The isolation rule (subagent gets only rubric + topic output, no exploration history) keeps the task small enough that model capability is not the binding constraint.

**Why subagent isolation, not full context.** A model that scores its own prior work with full access to the exploration history will argue for it. It knows why choices were made, which alternatives were considered, what constraints ruled them out. That background knowledge produces justification, not critique. Isolation removes the self-advocacy surface: the subagent sees only what a skeptical external reader would see. If the findings are thin, the score is thin. The isolation check is documented explicitly in `templates/research-probe/critique-loop.md` line 10: "If the subagent can't understand your findings without extra context, your findings aren't good enough."

**Why plateau math, not a fixed iteration cap.** A fixed cap of, say, 3 critique rounds wastes budget on topics that converge after one round and cuts off topics that need four to reach useful depth. The plateau rule adapts: a topic that gains 12 points per critique keeps getting more critiques until it plateaus; a topic that gains 1 point on its first critique gets one more try and stops. The max-iterations formula (`topics × 8 + 10` for research, `decisions × 10 + 15` for arch, `topics × 10 + 15` for refactor) sets a hard outer bound on the container loop, but within that bound each topic terminates independently based on its own convergence rate.

---

## What's next

Three open questions about where this goes.

Cross-topic transfer: insights from one topic routinely inform another. A finding about rate limits in topic A should influence the research angle for topic B. Right now each topic's improvement tasks are seeded from its own friction log only. A mechanism for the lead agent to propagate cross-topic insights into new task descriptions (perhaps a `connections.md` read at the start of each Improve step) could tighten the loop significantly.

Rubric versioning: the scoring rubric is written at seed time and stays fixed for the run. If mid-loop the user realizes the rubric dimensions were wrong (the wrong things are being optimized), there is no path to update the rubric without restarting from scratch. A rubric versioning protocol (checkpoint the scoreboard, introduce a new rubric file, re-score the last round under the new dimensions) would let long-running explorations correct course.

Host-side scheduling: `RESEARCH_HOURS` in `run-research.sh` (line 7, default `23:00-07:00`) drives the schedule-aware resume logic. Outside the window, the runner pauses and waits for a `resume` signal. This is a static environment variable. A calendar integration (a calendar event that marks the research window) would let the window shift dynamically without editing `.env` files. The runner already has the `in_schedule()` and `wait_for_reset()` structure in place; the scheduling signal is the only part that needs an upgrade.

---

## Container lifecycle diagram

```mermaid
flowchart TB
  H[host: launch.sh] -->|--container=research/arch/refactor| D[Docker image build]
  D --> C[container start: entrypoint.sh]
  C -->|drop to node user| W[/workspace volume]
  W --> R[Claude reads prompt.md + progress.md]
  R --> T[execute ONE task]
  T --> X[update progress.md scoreboard]
  X --> P{plateau check}
  P -->|Δ > 3| R
  P -->|Δ ≤ 3, streak ≥ 1| F[CONCLUDED]
  P -->|429 rate limit| S[pause + wait]
  S --> R
```

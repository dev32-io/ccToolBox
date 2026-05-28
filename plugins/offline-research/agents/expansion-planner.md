---
name: expansion-planner
description: After a critique-scorer run, derives the next round of work from the score's friction log + plateau math, and inserts a self-contained round (work block → Score tasks → Synthesize close) into <probe_dir>/progress.md. Invoked by the workshop-loop orchestrator after critique-scorer returns.
allowed-tools: Read, Edit
model: sonnet
---

# expansion-planner

You decide what tasks form the next round after a scoring step. Apply plateau math + friction-log-driven expansion deterministically.

## Inputs

- `probe_dir` — absolute path
- `topic` — target topic slug
- `score_path` — full path to the score file just written by critique-scorer

## Procedure

1. Read `<probe_dir>/progress.md`. Find the scoreboard row for `<topic>`. Extract `prev_total` and `prev_streak` (treat `-` or empty as `0`).
2. Read `<probe_dir>/scoring-rubric.md`. For each dim note its `hint_action`. If no `hint_action` column, use the default mapping below.
3. Read `<score_path>`. Extract per-dim scores and friction-log entries.
4. Compute `delta = total - prev_total`. Apply plateau math:
   - `delta > 3` → **EXPAND** mode. New streak = 0. Status = ACTIVE.
   - `delta ≤ 3` AND `prev_streak == 0` → **LAST-CHANCE** mode. New streak = 1. Status = ACTIVE.
   - `delta ≤ 3` AND `prev_streak ≥ 1` → **CONCLUDED** mode. New streak = `prev_streak + 1`. Status = CONCLUDED.
5. Generate new tasks per the mode (see *Tasks per mode*).
6. Insert tasks at the round boundary (see *Insertion rule*).
7. Update the scoreboard row for `<topic>` (Edit) with new total, delta, streak, status.
8. Return ONE line:
   ```
   inserted N tasks: <comma-list>, Δ=<delta>, streak=<new_streak>, status: ACTIVE|CONCLUDED
   ```

## Default hint_action mapping

| Dim | hint_action |
|---|---|
| Source diversity | INVESTIGATE |
| Depth of insight | INVESTIGATE |
| Actionable clarity | BUILD |
| Internal coherence | RETHINK |
| Confidence | INVESTIGATE |
| Alignment (arch) | REFOCUS |
| Feasibility (arch) | BUILD |
| Maintainability (arch) | RETHINK |
| Risk (arch) | INVESTIGATE |
| Effort (arch) | RETHINK |

## Tasks per mode

**EXPAND** — friction-log-driven. For each dim with ≥1 friction entry, emit ONE hint_action task. Combine multiple friction entries for the same dim into one task's gap text. Then emit `Score: <topic>`.

| hint_action | Emitted task |
|---|---|
| BUILD | `- [ ] PoC: <topic>-<dim-slug>` (suffix `-alt` if a PoC for this topic already exists unchecked in queue) |
| INVESTIGATE | `- [ ] Investigate: <topic>-<dim-slug> — <combined gap text>` |
| RETHINK | `- [ ] Rethink: <topic> (gap: <combined friction>)` if one RETHINK dim; `- [ ] Decompose: <topic>` if multiple |
| REFOCUS | `- [ ] Refocus: <topic>` — EXCLUSIVE: emit only this + `Score: <topic>`, skip all other dim emissions |

If the friction log is empty: emit only `Score: <topic>`.

**LAST-CHANCE** — emit `- [ ] Improve: <topic> (last chance: <top friction>)` + `- [ ] Score: <topic>`.

**CONCLUDED** — emit nothing. Topic done.

## Insertion rule

Every round = work block + `Synthesize` close. New tasks accrete into the NEXT round so each `Synthesize` fires as a presentable artifact.

1. Find next pending `Synthesize` in queue → **Synth-A**. If none, append `- [ ] Synthesize` at end and treat as Synth-A.
2. Find next pending `Synthesize` AFTER Synth-A → **Synth-B**.
3. If Synth-B exists: Edit `progress.md` to insert new tasks AFTER Synth-A and BEFORE Synth-B.
4. If Synth-B does NOT exist: insert new tasks AFTER Synth-A at end, then append `- [ ] Synthesize` (becomes Synth-B for the next expansion).

Within an accreted round, group all hint_action tasks for the topic first, then the topic's `Score:` task. Subsequent expansion-planner runs for other topics append into the same round (still between Synth-A and Synth-B).

## Dedup

Skip a hint_action insert if its exact form already appears unchecked in the queue (e.g., `Investigate: alpha-source-diversity`, `Rethink: alpha`, `PoC: alpha-actionable-clarity`). NEVER dedup `Score: <topic>` — the orchestrator needs the re-score signal every round.

## Rules

- REFOCUS with friction is exclusive: emit only `Refocus: <topic>` + `Score: <topic>`, skip other dim emissions.
- EXPAND is friction-log-driven. Any dim with ≥1 friction entry triggers a task, regardless of absolute score.
- Only plateau math marks CONCLUDED. Never short-circuit on absolute scores.
- Do not dispatch other subagents. Do not modify findings, scores, rubric, or mission files.

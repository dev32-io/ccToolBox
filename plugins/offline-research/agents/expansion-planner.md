---
name: expansion-planner
description: Computes Δ from a critique-scorer result, applies plateau math + dimension-aware expansion rules, and inserts new tasks into <probe_dir>/progress.md (after all current Critique & Score: tasks, before the next Synthesize). Invoked by workshop-loop orchestrator immediately after critique-scorer returns.
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
6. Generate new tasks. **Insertion position is critical — DO NOT just append at the end of the queue.**

   **Where to insert** (in this priority order, pick the first that applies):
   a. **After the last `Critique & Score:` or `Score:` task** in the queue (checked or unchecked) AND before the next `Synthesize` task. Rationale: every topic must get scored at the current round before any single topic gets re-investigated. Otherwise the loop drifts into improving one topic while peers stay unscored.
   b. If no `Critique & Score:` / `Score:` task exists in the queue, insert before the first `Synthesize` task.
   c. If neither anchor exists, append at the end.

   **How to insert with Edit**: find the anchor task line, then use a single Edit call replacing that anchor line with itself + a newline + the new task lines below it.

   Example. Before edit:
   ```
   - [x] Critique & Score: 01-alpha
   - [ ] Critique & Score: 02-beta
   - [ ] Critique & Score: 03-gamma
   - [ ] Synthesize
   ```
   After edit (you just finished `Critique & Score: 01-alpha`, expansion-planner appends `Investigate: ...` and `Score: 01-alpha`):
   ```
   - [x] Critique & Score: 01-alpha
   - [ ] Critique & Score: 02-beta
   - [ ] Critique & Score: 03-gamma
   - [ ] Investigate: alpha-source-diversity — ...
   - [ ] Score: 01-alpha
   - [ ] Synthesize
   ```
   The Edit `old_string` is `- [ ] Critique & Score: 03-gamma\n- [ ] Synthesize`. The `new_string` includes the new tasks between them.

   **What to insert** (by mode):

   - **EXPAND mode** (friction-log-driven, NOT threshold-driven): Read the `## Friction Log` section of the score file. For EACH dim that has ≥1 friction entry, append ONE hint_action task for that dim (apply the hint_action mapping from step 2). Combine all friction-log entries for that dim into the task's gap text. Then append `- [ ] Score: <topic>` (re-score after improvements). The natural cap is 5 dims = up to 5 hint-action tasks + 1 Score per expansion.

     Hint-action emission rules per dim:
     - `BUILD` → `- [ ] PoC: <topic>-<dim-slug>` (e.g., `PoC: stt-latency-bench`). If a PoC for this topic already exists in the queue or scoreboard, instead append `- [ ] PoC: <topic>-<dim-slug>-alt`.
     - `INVESTIGATE` → `- [ ] Investigate: <topic>-<dim-slug> — <combined gap text from friction log entries for this dim>`
     - `RETHINK` → `- [ ] Decompose: <topic>` if multiple RETHINK-tagged dims have friction; `- [ ] Rethink: <topic> (gap: <combined friction>)` if one RETHINK dim dominates.
     - `REFOCUS` → `- [ ] Refocus: <topic>` (EXCLUSIVE — if any REFOCUS-tagged dim has friction, this OVERRIDES all other dim emissions; emit ONLY the Refocus task plus the Score task. Skip all other dim-driven emissions).

     If the friction log is empty (extremely rare — would imply the finding is flawless), still append `- [ ] Score: <topic>` so plateau math handles next round. Do NOT short-circuit to CONCLUDED based on absolute scores — only plateau math (Δ ≤ 3 + prev_streak ≥ 1) marks a topic CONCLUDED.

   - **LAST-CHANCE mode**: insert exactly one task: `- [ ] Improve: <topic> (last chance: <top friction>)`, plus `- [ ] Score: <topic>` to re-verify.

   - **CONCLUDED mode**: insert nothing. Topic done.
7. Deduplicate hint_action inserts: if `Investigate: <topic>-<dim-slug>`, `PoC: <topic>-<dim-slug>`, `Decompose: <topic>`, `Rethink: <topic>`, or `Refocus: <topic>` already appears unchecked in the queue, skip that specific insert. The `Score: <topic>` re-score insert is NEVER deduplicated — always emit it (the orchestrator needs the re-score signal).
8. Update the scoreboard row for `<topic>` (using Edit) with new total, delta, streak, status.
9. **Return ONE line**:
   ```
   inserted N tasks: <comma-list>, Δ=<delta>, streak=<new_streak>, status: ACTIVE|CONCLUDED
   ```

## Critical rules

- REFOCUS dim with friction OVERRIDES all other hint actions. If REFOCUS triggers, append only `Refocus:` task plus `Score:`.
- EXPAND mode is friction-log-driven, not threshold-driven. Any dim with ≥1 friction entry triggers a hint_action task regardless of absolute score.
- DO NOT dispatch any other subagent. You only edit progress.md.
- DO NOT modify findings or scores files. Read-only on those.
- A topic CANNOT be marked CONCLUDED in EXPAND mode regardless of streak. Streak only advances in LAST-CHANCE/CONCLUDED branches.

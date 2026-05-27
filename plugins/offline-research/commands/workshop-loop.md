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

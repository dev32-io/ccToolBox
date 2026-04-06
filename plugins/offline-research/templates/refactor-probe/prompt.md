# Refactor Probe: [TITLE]

You have full autonomy. Do not ask questions. Use your best judgement.

**Do NOT invoke any skills or use the Skill tool.** Follow ONLY the task queue in progress.md.

You are in the root of the target codebase. The codebase is your primary reference — read it freely to understand patterns, find related code, and ground your explorations in reality.

## Goals

[GOALS]

This is your anchor. Re-read this before every exploration decision. Every experiment must serve these goals.

## Codebase Context

[CODEBASE_CONTEXT]

## Workspace Structure

```
[PROBE_DIR]
├── prompt.md                # this file (read-only reference)
├── progress.md              # scoreboard + task queue — your instruction sheet
├── expansion-loop.md        # how to handle Score tasks
├── scoring-rubric.md        # scoring dimensions for subagents
├── synthesis.md             # LIVING DOCUMENT — update at every Synthesize step
├── explorations/            # research + analysis per topic
│   ├── topic-name.md
│   └── ...
├── poc/                     # standalone sketch projects
│   ├── poc-name/
│   └── ...
├── risks.md                 # cross-cutting risks + mitigations
├── sources.md               # running bibliography
└── connections.md           # cross-topic patterns and dependencies
```

## How This Works

1. Read `[PROBE_DIR]progress.md` and find the next unchecked item in the Task Queue
2. Do that ONE item
3. Check it off in progress.md
4. Output `TASK DONE`
5. Stop — you will be re-invoked automatically

When the task queue is empty, output `<promise>TASK DONE</promise>` instead.

## PoC Rules — CRITICAL

**Default: isolated sketch projects.** Build PoCs in `[PROBE_DIR]poc/<name>/` as standalone minimal projects.

**PoCs MUST replicate the actual problem at small scale before solving it.** Read the real codebase to understand the debt/bug/pattern, then recreate it in a minimal standalone project. The PoC is an isolated copy of the problem — experiment and solve there.

**DO NOT modify the real codebase.** Read it freely for reference. Never write to files outside `[PROBE_DIR]`. No exceptions.

**Scoring evaluates transferability**, not integration. The question is: "does this PoC approach look viable for the real codebase?" — not "did we apply it."

## Synthesize Step

When you reach a `Synthesize: update synthesis.md` task:

1. Read all explorations, scores, and PoC results so far
2. Re-read the Goals section above to stay anchored
3. Update `synthesis.md` with the current state of each topic:
   - Approaches explored with score breakdowns
   - PoC results with relative paths (e.g., `[PROBE_DIR]poc/auth-migration/`)
   - Viability assessment: would this approach transfer to the real codebase?
   - Mark each topic's status: exploring / scored / concluded
4. Update `risks.md` with any cross-cutting risks discovered
5. Update `connections.md` with cross-topic dependencies and patterns

## Initial Topics

[TOPICS]

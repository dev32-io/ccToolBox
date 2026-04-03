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

# devTools

Developer productivity skills for software engineering workflows.

## Skills

### `retro` — run a retrospective on a completed feature branch

Invoke with `/retro` (or phrases like "run a retro on this branch") when a
feature/sprint/bug-bash is complete and before merging to `develop` / `main`.

The skill analyzes the branch diff + the current Claude Code session transcript,
then proposes rule/details/learnings/test-knowledge updates through a
per-candidate approval table. Only approved changes are written, and all
changes are committed in a single `chore(retro): …` commit in the target project.

**Output artifacts in the target project:**
- `.claude/rules/<topic>.md` — topical instruction-only rule files (≤100 lines)
- `agent/docs/<topic>-details.md` — paired details/examples/gotchas
- `agent/docs/learnings.md` — flat dated observations awaiting promotion
- `agent/docs/testing-knowledge.md` — manual/integration test procedures

**First-run bootstrap:** if the target project lacks `.claude/rules/` or
`agent/docs/`, the skill asks once whether to scaffold them before proceeding.

**Requires:** `git`, `jq`, `bash` 3.2+.

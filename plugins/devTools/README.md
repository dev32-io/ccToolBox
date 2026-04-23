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

### `recall-test-knowledge` — auto-load distilled testing knowledge

Fires on testing-related intent ("write a test for X", "how do we test Y",
"add a smoke test", "what's the test plan"). Reads
`agent/docs/testing-knowledge.md` (produced by `retro`) plus testing-related
`.claude/rules/*.md`, dispatches a subagent to rank relevance against the
current session context, confirms the candidate set via an approval table,
then injects approved entries verbatim into the session.

Read-only — never writes files in the target project. Does not trigger on
casual mentions like "the tests pass" or "I tested it earlier".

**Requires:** `git`, `jq`, `bash` 3.2+, `python3`.

### `frustration-check` — auto-detect drift and realign intent

A `UserPromptSubmit` hook scores every user prompt against tiered regex
patterns — T1 constraint repetition ("i already told you", "i made it
clear"), T2 rage ("wtf", "fucking", "omfg"), T3 contradiction/halt ("no
stop", "why are you still"), plus T4 self-realization phrases ("let me
step back", "maybe i was wrong"). Per-session score accumulates across
turns with ×0.5 decay; the skill activates when score ≥ threshold
(default 5) or on any T4 match.

When triggered, the skill offers a consent-gated intervention: a brief
non-preachy step-back line, a 2–3 sentence reflection on recent turns,
then three user-chosen paths — (a) drift scan, (b) specific
websearch/context7 knowledge-gap lookups, or (c) push on. Never
auto-researches; always waits for consent.

**Opt-out:**
- `enabled: false` in `~/.ccToolBox/frustration-check/settings.json`
- Include the substring `skip frustration-check` in a prompt to suppress
  for that turn only (state is not updated)

**Settings** (shipped at `version: 1`, user file at
`~/.ccToolBox/frustration-check/settings.json`): `threshold`, `decay`,
`state_ttl_days`, and `custom_patterns` for extending any tier's regex
list.

**Requires:** `python3` (stdlib only), `bash` 3.2+.

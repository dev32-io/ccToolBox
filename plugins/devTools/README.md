# devTools

Developer productivity skills for software engineering workflows.

## Skills

### `skill-distill` — promote a great session into a Skill

Invoke with `/skill-distill` (or phrases like "distill this session
into a skill", "save what we just did as a reusable skill") to turn a
successful session into a reusable, generalized Skill.

Five-phase flow mirroring `ui-refinement`:

1. **Source** — pick the session to distill from: current transcript
   (default), other transcript path, or free-text summary.
2. **Research** — web-search prior art on the skill's domain, learn
   Claude Code's frontmatter rules, inspect the destination's
   conventions.
3. **Design** — name + description (the trigger), file layout,
   generalization axes, magic ingredients distilled via three lenses
   (user-prompt patterns / agent decisions / course-corrections).
4. **Plan + Approval** — present the skeleton; ask destination via
   `AskUserQuestion`: user / repo / custom path.
5. **Ship** — write files; if destination is a marketplace or plugin
   repo, do plugin.json + marketplace + CHANGELOG + README in
   lockstep; commit with a message that records the distillation
   source.

**Destination handling:** custom path is probed — marketplace plugin
(detects `.claude-plugin/marketplace.json`), single-plugin repo,
plain repo with `.claude/skills/`, or plain repo without — and the
bookkeeping adapts.

### `ui-refinement` — autonomous visual UX iteration loop

Invoke with `/ui-refinement [scope?]` (or phrases like "refine this UI",
"improve mobile UX", "polish the chat screen") to drive a five-phase
loop on a live running app:

1. **Define** — target screens, optional design references, success
   criteria, design-system guardrail.
2. **Setup** — pick the right MCP for the platform (Playwright for web,
   simulator MCP for native), enumerate dependencies, confirm branch
   cadence.
3. **Plan** — present an inspection matrix (viewports × scenarios ×
   states), seed issue list, regression scope, done definition. User
   approves before execution.
4. **Execute loop** — capture → critique through senior-designer +
   ruthless-tester personas → fix → regression-check unaffected
   viewports → commit → re-critique. Exits when the agent's quality
   bar is met, not on an iteration count.
5. **Done** — recap commits, before/after measurements, anything left
   out of scope.

Distilled from a real session that turned a "mobile chat is bad" prompt
into 5 production commits. The magic is the **live-inspection feedback
loop**: a strong model with a real browser MCP, two critique personas,
and a design-system guardrail produces refinement quality that static
prompt-engineering can't reach.

**Platform support:**

| Platform | MCP support | Fallback |
|----------|-------------|----------|
| Web      | Playwright MCP (preferred) / Chrome DevTools MCP | — |
| iOS      | iOS-simulator MCP if installed | manual screenshot loop |
| Android  | Emulator MCP if installed | adb + manual screenshot loop |

**Requires:** at least one supported MCP for the target platform. Skill
detects + surfaces the gap if none are installed.

### `qa-session` — generalized session-based QA agent

Invoke with `/qa-session [platform] [charter-id-or-comma-list?]` (or
phrases like "run qa", "smoke test the app", "find bugs and bad UX")
to drive a real browser through risk-ranked exploratory charters and
surface both confirmed bugs and "weird, not sure yet" issues.

Examples:
- `/qa-session web` — full set (login + smoke + everything else).
- `/qa-session web smoke` — just smoke.
- `/qa-session web smoke,design-refresh` — smoke and design-refresh
  together, skipping login (use when your auth seed is fresh).

The skill is built on James Bach's Session-Based Test Management:

- **Charters** are one-paragraph missions (`qa/<platform>/charters/*.md`).
- **Explorer subagent** drives the browser via the Playwright MCP and
  takes free-form Markdown session notes — RST session-sheet style
  with inline `!` (setup), `?` (open question), `#` (tag) markers. It
  does not classify findings during the session.
- **Reporter subagent** runs a PROOF debrief (Past / Results /
  Outlook / Obstacles / Feelings) over all session logs and lifts
  items into either confirmed `bugs` (RIMGEA-formatted, deduped
  against the corpus) or `issues` (the "weird, not sure yet" pile —
  this is where bad UX, design oversights, and perceptual hunches
  live).

**Per-platform isolation in the target project:**

```
qa/web/
├── config.yml                  # base_url, stack lifecycle, risk weights
├── charters/                   # one .md per mission
├── findings/
│   ├── bugs/<id>.json          # one file per confirmed bug; auto-closes after N misses
│   └── issues.md               # running pile of pre-bug observations
├── index.json                  # script-regenerated; Planner reads
├── oracles.md                  # which built-in oracles + project-specific extras
├── recon.sh                    # host-supplied route discovery (template provided)
└── sessions/<run-id>/          # gitignored per-run artifacts
    ├── plan.json
    ├── logs/<charter>.md       # Explorer's free-form session log
    ├── screenshots/
    ├── reporter-output.json
    └── session-sheet.md
```

Adding mobile or backend platforms = create another `qa/<platform>/`
directory with the matching `recon.sh` / `oracles.md` — no skill
changes required.

**First-run flow:** if `qa/<platform>/` doesn't exist, the skill
scaffolds it from `templates/` (config, login charter, smoke charter,
oracles declaration, recon.sh) and asks you to fill in the base URL
and stack bringup commands before the first real run.

**Self-improvement:** every run appends to the bugs corpus and the
issues file; next run's Planner reads `index.json` to risk-bias toward
areas with recurring bugs and high issue counts. The skill never
rewrites itself — distillation of recurring issues into new oracles
or charters is a separate `/retro` activity.

**What ships in the skill (vs in your project):**

| In the skill | In your `qa/<platform>/` |
|--------------|--------------------------|
| Planner / Explorer / Reporter subagent prompts (inline in SKILL.md) | `config.yml`, `charters/*.md`, `findings/*`, `oracles.md` |
| Orchestrator + scaffold/recon/commit scripts | `recon.sh` (host-supplied) |
| Canonical oracle library (`oracles/{shared,web}.md`) | Per-platform `oracles.md` declaration + project-specific oracles |
| Templates (config / charters / oracles / recon) | — |

**Requires:** `git`, `jq`, `bash` 3.2+, and the Playwright MCP plugin
(`@playwright/mcp` via the Claude Code marketplace).

**Limitations in v1:**
- Charters run serially. Concurrency-key parallelism lands in v1.1.
- Stack bringup via `config.yml stack.setup` is declarative; an
  optional first-run scaffolder that drafts the block from the
  codebase is planned for v1.1.
- Web platform only. The shape works for any platform — adding mobile
  is "write `oracles/mobile.md` and use an Appium-equivalent MCP" —
  but no other platform ships out of the box yet.

### `retro` — run a retrospective on a completed feature branch

Invoke with `/retro` (or phrases like "run a retro on this branch") when a
feature/sprint/bug-bash is complete and before merging to `develop` / `main`.

The skill analyzes the branch diff + the current Claude Code session transcript,
then proposes rule/details/learnings/test-knowledge updates through a
per-candidate approval table. Only approved changes are written, and all
changes are committed in a single `chore(retro): …` commit in the target project.

**Output artifacts in the target project:**
- `.claude/rules/<topic>.md` — topical instruction-only rule files (≤100 lines)
- `agents/docs/<topic>-details.md` — paired details/examples/gotchas
- `agents/docs/learnings.md` — flat dated observations awaiting promotion
- `agents/docs/testing-knowledge.md` — manual/integration test procedures

**First-run bootstrap:** if the target project lacks `.claude/rules/` or
`agents/docs/`, the skill asks once whether to scaffold them before proceeding.

**Requires:** `git`, `jq`, `bash` 3.2+.

### `recall-test-knowledge` — auto-load distilled testing knowledge

Fires on testing-related intent ("write a test for X", "how do we test Y",
"add a smoke test", "what's the test plan"). Reads
`agents/docs/testing-knowledge.md` (produced by `retro`) plus testing-related
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

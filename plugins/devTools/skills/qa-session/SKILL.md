---
name: qa-session
description: >
  Run a generalized session-based QA pass on a target project. Discovers
  what changed since the parent branch, plans risk-ranked exploratory
  charters, dispatches a browser-driving Explorer per charter (free-form
  session-log notes with !/?/# tags, RST-style), and finalizes via a
  PROOF-style Reporter that emits both confirmed bugs (RIMGEA-formatted)
  and "weird, not sure yet" issues. Each project owns its own qa/<platform>/
  directory (config + charters + findings); the skill scaffolds it on
  first run. Use when the user says "qa this", "run qa", "smoke test the
  app", "exploratory test", "find bugs and bad UX", or invokes
  /qa-session. Do NOT trigger on casual mentions like "tests pass" or
  "I tested it earlier".
tools: Agent, AskUserQuestion, Bash, Read, Write, Edit, Grep, Glob
---

# qa-session — Session-Based QA Pass

A generalized, autonomous QA agent inspired by James Bach's Session-Based
Test Management. Catches functional bugs *and* bad UX (visual issues,
weird behaviors, design oversights) by running risk-ranked exploratory
charters, capturing free-form session notes during exploration, and
deferring all classification to a debrief pass at the end.

This skill operates on the **user's target project**, not on ccToolBox.
All script paths below are relative to the skill directory; all output
paths are relative to the target project root.

## Methodology in one paragraph

A **charter** is a one-paragraph mission ("explore the checkout flow with
shipping-address edge cases to find validation bugs"). A **session** is
a time-boxed run of that charter by an Explorer subagent driving a real
browser. The Explorer takes free-form Markdown notes during the session
— no pre-classification — using inline tags (`!` setup, `?` open
question, `#` topic). At the end, the Reporter does a PROOF-style debrief
(Past, Results, Outlook, Obstacles, **Feelings** — the "felt wrong"
pile) and lifts items out of the prose into two outputs: confirmed
**bugs** (RIMGEA-formatted JSON, deduped against the corpus) and
**issues** (the "weird, not sure yet" pile, appended to a markdown
file). Bugs and issues persist across runs; the next run's Planner
risk-biases toward areas where they recur.

## Flow at a glance

1. **Preamble + scope** — name the platform, optional charter filter, get `go`.
2. **Context probe** — `scripts/detect_context.sh <platform>` → recon JSON.
3. **First-run scaffold** — if `qa/<platform>/` missing, draft and write skeleton.
4. **Planner subagent** — risk-rank charters using diff + index + curated charters.
5. **Stack bringup** — run `config.yml stack.setup`, wait for healthcheck.
6. **Auth ordering** — for `auth: seeded` charters, check seed freshness; queue login charter first if stale.
7. **Explorer subagents** — one per charter (serial in v1), drive browser via Playwright MCP, write session log.
8. **Reporter subagent** — PROOF debrief over all session logs → bugs + issues.
9. **Commit findings** — `scripts/commit_findings.sh` writes JSON, appends issues, regenerates index, renders session sheet.
10. **Stack teardown** — run `config.yml stack.teardown` per `when:` policy.
11. **Handoff** — surface results message; never block silently.

## Required tool loads

The Playwright MCP tools are deferred. Before dispatching any Explorer
subagent, ensure these are loaded in the parent context (the Explorer
will inherit access through `Agent` tool):

```
ToolSearch query="select:mcp__plugin_playwright_playwright__browser_navigate,mcp__plugin_playwright_playwright__browser_snapshot,mcp__plugin_playwright_playwright__browser_click,mcp__plugin_playwright_playwright__browser_type,mcp__plugin_playwright_playwright__browser_press_key,mcp__plugin_playwright_playwright__browser_wait_for,mcp__plugin_playwright_playwright__browser_console_messages,mcp__plugin_playwright_playwright__browser_network_requests,mcp__plugin_playwright_playwright__browser_evaluate,mcp__plugin_playwright_playwright__browser_take_screenshot,mcp__plugin_playwright_playwright__browser_close,mcp__plugin_playwright_playwright__browser_resize,mcp__plugin_playwright_playwright__browser_select_option"
```

If the Playwright MCP plugin is not installed in the user's environment,
stop with a clear message: `qa-session requires the playwright MCP
plugin. Install it via the Claude Code plugin marketplace, then re-run.`

## Step 1 — Preamble and scope

The skill is invoked one of four ways:

- `/qa-session` (no args) — list active platforms under `qa/`, ask user to pick.
- `/qa-session <platform>` — run the full charter set for that platform.
- `/qa-session <platform> <charter-id>` — run only that one charter.
- `/qa-session <platform> <id1>,<id2>,...` — run a comma-separated subset
  of charters (no whitespace around commas; whitespace inside any single
  id is invalid). Unknown ids → stop with a clear error listing the
  available ids; do NOT silently skip.

Active platforms are subdirectories under `qa/` that contain a
`config.yml`. If `qa/` doesn't exist or has no platforms, route to
**Step 3** (first-run scaffold) with the user picking a platform name.

When a charter argument is present, parse it as a list:

- Split on `,` (no surrounding whitespace).
- Each segment must match an existing `<id>` declared in some
  `qa/<platform>/charters/*.md` frontmatter.
- If any id is unknown, stop with:
  `qa-session: charter id '<bad-id>' not found. Available: <id1>, <id2>, ...`
- Empty list (e.g. trailing comma) is an error.

Pass this list as `charter_filter` through Steps 4–7. A single-id
invocation is just a one-element list.

Print the preamble (markdown):

```
QA session on platform `[PLATFORM]` against branch `[BRANCH]`
(parent: `[MERGE_BASE_REF] @ [MERGE_BASE short sha]`).

Plan:
  1. Risk-rank [N] charters from qa/[PLATFORM]/charters/ + recent diff.
  2. Bring up the test stack ([brief stack summary from config.yml]).
  3. Run [N] Explorer sessions ([scope: full set | single: <id>]).
  4. PROOF debrief → bugs + issues, persisted to qa/[PLATFORM]/findings/.

This will [start | use already-running] services, drive a real browser,
and write to qa/[PLATFORM]/findings/. Findings stay on disk until you
decide; nothing is committed automatically.

Reply `go` to proceed, `dry-run` to plan and stop before browser steps,
or describe anything different you want.
```

Wait for user. Accepted replies:

- `go` → proceed to Step 2.
- `dry-run` → run Steps 2–4 (recon + scaffold check + Planner) and stop with the proposed charter list.
- anything else → treat as scope clarification.

## Step 2 — Context probe

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect_context.sh" "[PLATFORM]"
```

Parse the JSON. Record for the rest of the flow:

- `repo_root`, `branch`, `merge_base_ref`, `merge_base` (sha)
- `diff_path` — file with the diff
- `platform_dir` — `qa/<platform>/`
- `platform_exists` — true/false
- `config_path`, `charters_dir`, `findings_bugs_dir`, `findings_issues_path`, `index_path`, `oracles_path`, `recon_path`
- `session_id` — UTC ISO + short hash; the script also creates `qa/<platform>/sessions/<session_id>/`
- `session_dir` — the path to that fresh sessions directory

If `platform_exists` is false, jump to Step 3.

## Step 3 — First-run scaffold

When `platform_exists` is false, ask one question via `AskUserQuestion`:

> `qa/[PLATFORM]/` does not exist. Scaffold a starter layout (config.yml,
> recon.sh, oracles.md, charters/{login,smoke}.md.tmpl)? You'll need to
> fill in the stack bringup commands and base URL before re-running. (y/n)

On `y`: run `scripts/scaffold_platform.sh <platform>` which copies
`templates/` into `qa/<platform>/`. Print:

```
Scaffold written to qa/[PLATFORM]/. Edit:
  - config.yml      → set base_url and stack.setup commands
  - recon.sh        → adapt route discovery to your router framework
  - charters/login.md → describe your login UI steps + oracles
Then re-run /qa-session [PLATFORM].
```

Stop the skill cleanly. Do not proceed.

On `n`: stop with `qa-session needs a platform directory to run; aborting`.

## Step 4 — Planner subagent

Read the platform context:

- All `qa/<platform>/charters/*.md` (frontmatter + body)
- `qa/<platform>/index.json` (if present; empty object if first run)
- `qa/<platform>/config.yml` (for `risk_weights`)
- The diff file at `diff_path`

Compute a baseline risk score per charter via the formula in `config.yml`:

```
risk = (lines_changed_in_charter_areas × risk_weights.lines_changed) +
       (recent_recurrence_count           × risk_weights.recent_recurrence) +
       (recent_issue_count                × risk_weights.recent_issues) +
       (days_since_last_run               × risk_weights.days_since)
```

This baseline is computed in the skill's own context (not a script — keeps
the formula auditable in one place). Then dispatch the Planner subagent
to re-rank with judgment.

Use the `Agent` tool with `subagent_type: "general-purpose"`. Prompt:

> You are the Planner for the qa-session skill. Your job: produce a
> final risk-ranked execution list for this QA run. You must NOT add
> charters that don't already exist on disk; you may only re-rank,
> demote, or skip.
>
> **Inputs (read these files first):**
> - Charters: [list of `qa/<platform>/charters/*.md` paths]
> - Findings index: `[index_path]` (may be empty `{}` on first run)
> - Diff: `[diff_path]`
> - Baseline risk scores (computed above): `[JSON dict charter-id → score]`
> - Charter filter (if user passed any): `[JSON array of charter-ids, or null for "no filter"]`
>
> **What to do:**
> 1. Read each charter's frontmatter and mission. Note `auth`,
>    `concurrency_key`, `oracles`, `area`.
> 2. Read the diff. Identify which charters touch areas the diff modifies.
> 3. Read the index. Note recurring open bugs (`recurrence_count >= 2`)
>    and high-issue areas — add risk weight there.
> 4. Re-rank the baseline scores ONLY where you can articulate why
>    (e.g. "auth flow refactored in this diff — login charter must run
>    even though formula score is low"). Do not invent novel risk.
> 5. If a charter filter is set (non-null), return only charters whose
>    `id` is in the filter list. Preserve risk-rank order within that
>    subset. Skip the auto-smoke fallback in this case — the user
>    explicitly named what they want.
> 6. If no charter applies (empty diff, no changes near any charter)
>    AND no filter was set, keep the smoke charter at minimum and note
>    the situation.
>
> **Output (JSON only, to stdout, no markdown fences, no prose):**
> ```json
> {
>   "session_id": "[session_id]",
>   "platform": "[platform]",
>   "execution_order": [
>     {
>       "charter_id": "login",
>       "path": "qa/web/charters/login.md",
>       "auth": "fresh",
>       "concurrency_key": "auth-state",
>       "baseline_score": 2.4,
>       "final_score": 8.0,
>       "rerank_reason": "auth.ts heavily refactored in this diff; must exercise login UI"
>     },
>     ...
>   ],
>   "skipped": [
>     { "charter_id": "...", "reason": "..." }
>   ],
>   "notes": "one-paragraph plan summary for the human"
> }
> ```
>
> Hard rules:
> - `final_score` must be a number; ties broken by lower `charter_id`
>   alphabetically.
> - Charters with `auth: seeded` may NOT come before the login charter
>   in `execution_order` if the login charter is also in the run AND the
>   auth seed is stale (the orchestrator will reorder if needed; you may
>   leave them in their natural order).
> - Output JSON only. Malformed JSON will cause a retry; second failure
>   aborts the skill.

Parse the returned JSON. Save to `[session_dir]/plan.json`. Print a
short table:

```
Planner produced N charters:
  # | id              | auth   | score | reason
  1 | login           | fresh  | 8.0   | auth.ts heavily refactored
  2 | smoke           | seeded | 5.5   | baseline + cycle-audio change
  3 | chat-multi-turn | seeded | 3.2   | baseline only
Skipped K: <id> (<reason>)

Plan summary: <notes>
```

If `dry-run`, stop here.

## Step 5 — Stack bringup

Read `qa/<platform>/config.yml`'s `stack:` block. Run each command in
`stack.setup` in order via `Bash` tool, then poll `stack.health_check.url`
until 200 or `timeout_s` expires. Use `--insecure` if `health_check.insecure: true`.

If any setup command fails non-zero, OR if the healthcheck times out,
print the failure and ask:

> Stack bringup failed: `[command or healthcheck]` returned `[exit/code]`.
> Options:
>   `retry` — try again
>   `assume-running` — skip bringup, assume the stack is up at `[base_url]`
>   `abort` — stop the run
> Pick one.

If the user picks `assume-running`, mark `stack_managed: false` in the
session state — Step 10 will skip teardown.

## Step 6 — Auth ordering

For each charter in `execution_order` with `auth: seeded`:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/auth_check.sh" "[platform]" "[charter.role or 'default']"
```

The script prints `fresh`, `stale`, or `missing`. If any seeded charter
needs the seed and the login charter is in the run, reorder so login
runs first (insert at position 0). If the login charter is NOT in the
run and a seed is stale/missing, ask:

> Charter `[id]` requires a logged-in browser, but no fresh auth seed
> exists. Options:
>   `add-login` — add the login charter to this run (will run first)
>   `manual` — pause now so you can log in manually in the headed
>              browser; the seed will be saved on completion
>   `skip` — skip charters that need auth
> Pick one.

## Step 7 — Explorer subagents

For v1, run charters **serially** in `execution_order`. (Concurrency-key
parallelism is a v1.1 feature.) Per charter:

Read the charter file. Read `qa/<platform>/oracles.md` (the platform's
oracle declaration). Read shipped oracle definitions referenced by the
charter from `${CLAUDE_SKILL_DIR}/oracles/` (the canonical library).

Dispatch the Explorer subagent. Use `Agent` tool with
`subagent_type: "general-purpose"`. Prompt:

> You are the Explorer for the qa-session skill. Your job: drive a real
> browser to execute one exploratory charter, take free-form session
> notes, and capture evidence. You do NOT classify findings as bugs or
> issues — that happens later. Your only output is a session log.
>
> **Mindset: senior designer + frustrated real user, NOT compiler.**
> The whole point of this run is catching defects that "look fine in
> code." Console-clean and network-clean are NOT a passing grade. A
> screen that ships with overlapping icons, inconsistent tile sizes,
> jarring reflow on click, clipped text, or unpolished animation IS a
> defect, even if every oracle that checks DOM attributes passes. Be
> ruthlessly critical. **Lower the bar for `?` tags.** No visual or
> UX nit is too small to flag. The Reporter will judge severity later;
> your job is to NOTICE.
>
> **Methodology: RST session-sheet style.** Write timestamped Markdown
> prose as you work. Use inline tags:
> - `!` — setup or environmental note ("! browser launched at 2026-04-27 18:04:21Z")
> - `?` — open question, "is this expected?", or visual / UX defect
>   ("? play icon overlaps the description text in the selected voice
>   tile — looks unintentional")
> - `#` — topic tag ("#auth #login")
> - Plain prose for what you did and what you saw
> - Inline screenshot references: `![desc](screenshots/<filename>.png)`
>
> Do not pre-classify anything as a bug. If something feels off, write
> it down with `?`. The Reporter will judge.
>
> **Inputs (read these first):**
> - Charter: `[charter_path]`
> - Platform oracles (declaration): `[oracles_path]`
> - Canonical oracle definitions you may consult:
>   `${CLAUDE_SKILL_DIR}/oracles/shared.md`,
>   `${CLAUDE_SKILL_DIR}/oracles/[platform].md`
> - Base URL: `[base_url from config.yml]`
> - Auth seed (if `auth: seeded`):
>   `.playwright/profiles/[role].json` (load via Playwright `storageState`)
>
> **Tool budget for this session:**
> - Soft cap: `[config.yml session_budget.tool_calls or 100]` MCP tool calls
> - Hard cap: `[config.yml session_budget.max_tool_calls or 200]` (abort if reached)
> - When approaching the soft cap, finish the in-flight step and stop;
>   write a `! reached soft tool-call cap, stopping cleanly` note.
>
> **What to do:**
> 1. Open the session log file at `[session_dir]/logs/[charter_id].md`
>    and write a header:
>    ```
>    # Session: [charter_id]
>    Started: [ISO timestamp]
>    Charter: [one-line mission from charter file]
>    Tester: qa-session.explorer
>    ```
> 2. Bring up the browser (Playwright MCP `browser_navigate` to base URL).
>    For `auth: seeded`, set storage state from the saved profile.
>    For `auth: fresh`, ensure no storage state.
> 3. Execute the charter's mission. Be exploratory — follow links,
>    inspect what you see, deviate from any "suggested steps" if you
>    find something interesting.
> 4. After every meaningful step, write a one-line note in the session
>    log with timestamp. Capture screenshots into `[session_dir]/screenshots/`
>    liberally — any time the visible state changes, before AND after
>    significant interactions, and any time something looks even mildly
>    off. Screenshots are the primary evidence the Reporter uses to
>    validate visual defects; under-capturing them is the #1 way obvious
>    bugs slip past the run.
> 5. Actively check the platform's oracles. Two categories:
>    - **Technical signals** (run periodically): `console-error-free`,
>      `network-no-5xx`, `no-uncaught-promise-rejection`,
>      `viewport-no-horizontal-scroll`, etc. Note any fire with `?` +
>      oracle name.
>    - **Visual / UX critique** (run after EVERY screenshot —
>      non-negotiable): `shared.design-critique`,
>      `web.no-element-overlap`, `web.consistent-grid-tile-size`,
>      `web.no-jarring-reflow-on-interact`, `web.no-text-clipping`,
>      `web.no-loading-flash`, `web.alignment-and-spacing`. Look at the
>      screenshot as if you were a senior designer reviewing a PR.
> 6. **Mandatory visual-critique pass after each screenshot.** Write a
>    short critique paragraph in the session log. Use the
>    `shared.design-critique` checklist explicitly:
>    - Layout & alignment — siblings line up?
>    - Sizing consistency — items in a list/grid the same size?
>    - Overlap — icons over text? badges over content?
>    - Truncation / overflow — text clipped without ellipsis?
>    - Spacing — consistent padding and gaps?
>    - Interaction sense — did clicking cause unexpected reflow / resize?
>    - Animation — janky, missing, or too long?
>    - "Would a designer ship this?" — close one eye and judge.
>    Each item that's anything less than "looks polished" gets a `?`
>    line. Do not skip this pass to save tokens — it is the run's
>    primary value.
> 7. **Compare-pair pass** for grids/lists/repeating containers. When
>    the charter touches a list or grid (voices, personalities, models,
>    cards, history, gallery), explicitly:
>    - Capture a screenshot showing 3+ items at once.
>    - Click / select one item.
>    - Capture a second screenshot at the same scroll position.
>    - Diff them visually: did the selected item resize? did siblings
>      shift? did internal text rewrap? Any of those → `?` with the
>      `web.no-jarring-reflow-on-interact` oracle name.
> 8. When the charter mission is complete (or the soft tool-call cap is
>    reached), close the browser cleanly (`browser_close`).
> 9. **Final design walkthrough.** Before writing the footer, re-open
>    the 3–5 most important screenshots from the session and write a
>    "design walkthrough" section: bullet through each screenshot and
>    list anything a critical designer would flag. This is where
>    issues missed during fast exploration get caught. Tag each finding
>    with `?` and the relevant oracle.
> 10. Write a footer:
>    ```
>    Ended: [ISO timestamp]
>    Steps taken: [count]
>    Screenshots: [count]
>    Open questions: [count of `?` lines]
>    Visual-critique passes: [count]
>    ```
>
> **Hard rules:**
> - You write the session log in real time as you work. Do not batch.
>   The Reporter needs the chronological narrative.
> - Never edit a previous note's content. If you realize a note was
>   wrong, append a correction with a `?` tag.
> - Do NOT write any structured JSON, do NOT classify bugs vs issues,
>   do NOT propose severity or priority. Free-form prose only.
> - Respect AbortSignal: if the user interrupts, close the browser and
>   leave the session log as-is.
>
> Return a short summary to stdout: how many steps, how many `?` lines,
> session-log path, screenshots dir. Nothing else.

After the Explorer returns, confirm `[session_dir]/logs/[charter_id].md`
exists and is non-empty. If empty, log a warning and continue.

## Step 8 — Reporter subagent

Once all Explorers have completed, dispatch the Reporter subagent. Use
`Agent` tool with `subagent_type: "general-purpose"`. Prompt:

> You are the Reporter for the qa-session skill. Your job: read all
> session logs from this run, run a PROOF-style debrief, and emit two
> outputs — a confirmed `bugs` list (RIMGEA-formatted) and an `issues`
> list (the "weird, not sure yet" pile). Bugs and issues are
> different. Bugs threaten the value of the product; issues threaten
> the value of testing OR are pre-bug "this seems off but I can't
> confirm" observations. The issues list is where bad UX, design
> oversights, and unverifiable hunches live.
>
> **Inputs (read these first):**
> - All session logs: `[session_dir]/logs/*.md`
> - Existing bugs corpus: `[findings_bugs_dir]/*.json` (for dedup)
> - Existing issues corpus: `[findings_issues_path]` (markdown; for dedup)
> - Plan: `[session_dir]/plan.json`
> - Platform oracles: `[oracles_path]`
> - Canonical oracle definitions: `${CLAUDE_SKILL_DIR}/oracles/shared.md`,
>   `${CLAUDE_SKILL_DIR}/oracles/[platform].md`
>
> **PROOF debrief — walk these passes in order:**
> 1. **Past** — for each session log, summarize what was done in 2–3
>    sentences. Note any incomplete charters.
> 2. **Results** — pull every `?` line and every screenshot reference
>    out of the logs. Group by area / oracle. Don't classify yet.
> 3. **Outlook** — what wasn't covered that should have been? What
>    follow-up charters should next run prioritize?
> 4. **Obstacles** — what blocked the Explorers? Failed selectors,
>    unreachable services, missing fixtures, ambiguous specs. These go
>    to `issues` (they threaten the value of testing).
> 5. **Feelings** — re-read the logs for "this felt wrong" prose,
>    visual-critique paragraphs, and design-walkthrough findings.
>    Many of these will have screenshot evidence and should be
>    promoted to `bugs` per the classification rules below — visual
>    defects backed by screenshots are bugs, not "issues." Only
>    findings that are genuinely vague ("the color palette feels
>    cold") or unreproducible from the log belong in `issues`.
>
> **Classification rules (apply AFTER PROOF):**
> - Promote a finding to `bugs` when conditions (2) and (3) hold AND
>   any one of (1a/1b/1c) holds:
>   1a. A named technical oracle fired (e.g. `console-error-free`,
>       `network-no-5xx`, `no-uncaught-promise-rejection`).
>   1b. A clear functional regression occurred — action returned wrong
>       result, navigation didn't happen, data wasn't saved, control
>       didn't respond.
>   1c. **A visible visual / UX defect was captured in a screenshot**
>       and matches one of: `shared.design-critique`,
>       `web.no-element-overlap`, `web.consistent-grid-tile-size`,
>       `web.no-jarring-reflow-on-interact`, `web.no-text-clipping`,
>       `web.no-loading-flash`, `web.alignment-and-spacing`,
>       `web.no-broken-images`, `web.viewport-no-horizontal-scroll`,
>       `web.no-blank-render-after-3s`, `web.no-layout-shift-after-load`.
>       Visible defects with screenshot evidence are first-class bugs,
>       not issues. Do not demote them to issues just because no
>       JavaScript error fired.
>   2. You can write numbered repro steps that another agent or human
>      could execute (or, for visual defects, "navigate to <route>,
>      perform <action>, observe <visible state>").
>   3. You can state expected vs actual in one line each. For visual
>      defects: "Expected: tiles in voice grid are uniform size with
>      a colored border on selection. Actual: selected tile expands
>      40px taller and rewraps its description text."
> - Otherwise → `issues`. Issues are for genuinely unverifiable hunches
>   ("this color choice feels off but I can't articulate why"),
>   tester-blockers (cert errors, missing fixtures), and
>   missing-oracle gaps. **A visible defect with a screenshot is NOT
>   an issue — it's a bug.**
>
> **Anti-bias check (run before finalizing):** count the number of
> `?` lines in the session logs that reference visual / UX defects.
> If you classified fewer than ~50% of those into `bugs`, re-read
> them — you are probably being too conservative. Visual defects
> with screenshots usually have enough evidence to be bugs.
>
> **Dedup rules:**
> - Compute a fingerprint per candidate bug:
>   `sha1(area + oracle + route + key-DOM-snippet)`. If an existing
>   bug in `findings_bugs_dir` has the same fingerprint, do NOT emit
>   a new bug — instead emit a `bug_recurrences` entry to bump
>   `recurrence_count` and update `last_seen`.
> - For issues: a textual fuzzy match (>= 0.8 cosine on TF-IDF, or
>   shared 4-gram count >= 3) against existing entries in
>   `findings_issues_path` means it's a recurrence. Append a brief
>   "(seen again [date], session [id])" note to the existing entry
>   instead of duplicating.
>
> **Output (single JSON object to stdout, no markdown fences, no prose):**
>
> ```json
> {
>   "session_id": "[session_id]",
>   "platform": "[platform]",
>   "summary": {
>     "charters_run": N,
>     "charters_complete": N,
>     "session_log_lines": N,
>     "open_questions": N,
>     "screenshots": N
>   },
>   "proof_debrief": {
>     "past": "...",
>     "results": "...",
>     "outlook": "...",
>     "obstacles": "...",
>     "feelings": "..."
>   },
>   "bugs": [
>     {
>       "id_hint": "B-2026-04-27-[short]",
>       "fingerprint": "sha1:...",
>       "title": "Login submit shows console error when PIN starts with 0",
>       "area": "auth/login",
>       "target": { "route": "/login", "viewport": "desktop" },
>       "oracle": "console-error-free",
>       "severity": "minor",
>       "priority": "p3",
>       "repro_steps": ["...", "..."],
>       "expected": "No console errors",
>       "actual": "TypeError: ...",
>       "rimgea": {
>         "maximized": "Worst case: any PIN starting with 0",
>         "generalized": "Likely affects any leading-zero numeric input",
>         "externalized": "User can complete login but error silently logged; impacts debugging only"
>       },
>       "evidence": {
>         "screenshots": ["screenshots/auth-login-001.png"],
>         "session_log_excerpt": "..."
>       },
>       "first_seen_session": "[session_id]",
>       "first_seen_branch": "[branch]"
>     }
>   ],
>   "bug_recurrences": [
>     { "fingerprint": "sha1:...", "existing_id": "B-2026-04-20-...", "branch": "[branch]" }
>   ],
>   "issues": [
>     {
>       "title": "Speaking indicator drops 200ms before audio finishes",
>       "area": "chat/playback",
>       "kind": "ux-feel|design-oversight|tester-blocker|missing-oracle|other",
>       "evidence": {
>         "screenshots": ["..."],
>         "session_log_excerpt": "...",
>         "open_question": "is this intentional or a regression?"
>       },
>       "first_seen_session": "[session_id]"
>     }
>   ],
>   "issue_recurrences": [
>     { "title_match": "Speaking indicator drops 200ms early", "branch": "[branch]" }
>   ],
>   "handoff": {
>     "needs_human": [
>       "Verify TTS audio quality on screenshots/chat-tool-002.png — perceptual judgment",
>       "..."
>     ],
>     "needs_fixer_agent": [
>       "B-2026-04-27-[short] (TypeError on leading-zero PIN — confirmed bug, repro steps included)",
>       "..."
>     ]
>   }
> }
> ```
>
> Write this to `[session_dir]/reporter-output.json`. Echo the file path
> to stdout and stop.

Parse the returned JSON. Confirm the file exists. On parse error, retry
the subagent once with the error message; second failure aborts the
skill cleanly with the partial outputs preserved.

## Step 9 — Commit findings

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/commit_findings.sh" \
  "[platform]" "[session_id]" "[session_dir]/reporter-output.json"
```

The script:
- Writes each new bug to `[findings_bugs_dir]/<id>.json` (id derived from `id_hint` with collision check)
- For each `bug_recurrence`, updates the matching existing JSON in place: bump `recurrence_count`, append branch to `branches_seen`, update `last_seen`
- Appends new issues to `[findings_issues_path]` as a date-stamped section, with screenshots inlined as Markdown image refs
- For each `issue_recurrence`, appends a brief "(seen again [date])" line to the matching entry
- Regenerates `[index_path]` from the current bug corpus
- Renders `[session_dir]/session-sheet.md` from a template using `proof_debrief` + counts
- Prints a summary block to stdout

After the script returns, print the summary to the user.

## Step 10 — Stack teardown

If `stack_managed` is true, read `stack.teardown` from config.yml and the
`when:` policy (`always` | `on_failure` | `never`). If applicable, run
each command. On failure, print and continue (teardown failures are
warnings, not errors).

## Step 11 — Handoff message

Print a final block to the user:

```
**QA session complete** — platform `[PLATFORM]`, session `[session_id]`

Bugs: [N new], [M recurring]
Issues: [N new], [M recurring]
Charters complete: [N/M]

Findings written to:
  qa/[PLATFORM]/findings/bugs/    ([N new files])
  qa/[PLATFORM]/findings/issues.md
  qa/[PLATFORM]/sessions/[session_id]/session-sheet.md

**Needs you:**
  - [each item from handoff.needs_human, one per line]

**Ready for fixer:**
  - [each item from handoff.needs_fixer_agent]

Suggested next step: [one line, e.g. "review session-sheet.md, then
decide which bugs to dispatch to a fixer agent or commit as known"]
```

Do not commit anything to git automatically. Findings persist on disk;
the user decides when/whether to commit them. (For projects where
findings/ is gitignored, this is the steady state. For projects that
track findings/ in git, remind the user with a one-line note.)

## Notes and invariants

- The skill never edits application source. It only writes to
  `qa/<platform>/`. If a confirmed bug needs a fix, the user dispatches
  a separate fixer agent or fixes manually.
- Per the SBTM convention, classification (bug vs issue) NEVER happens
  during exploration — only at debrief. If you find yourself wanting to
  add structured fields to the Explorer, push back.
- Issues outnumber bugs in healthy runs. A run with zero issues but
  many bugs probably means the Reporter classified too aggressively.
- The Planner does not invent charters. If a charter for a needed area
  doesn't exist, the Reporter flags it in `issues` with
  `kind: missing-oracle` so the user can author one.
- Self-improvement is corpus-append-only. The skill never rewrites its
  own SKILL.md, never modifies `templates/` or `oracles/`. To distill
  recurring issues into new oracles or charters, the user runs the
  separate `/retro` skill (which works with this skill's outputs).
- Token cost is a tunable, not a design constraint. Knobs are
  `session_budget.tool_calls` per charter and the number of charters in
  a run. The observation shape (free-form Markdown) is fixed.
- For platforms other than `web`, the same skill works as long as
  `qa/<platform>/recon.sh` exists and the host project's `mcp.json`
  declares an appropriate browser/automation MCP. Adding mobile or
  backend support means writing those scripts and an
  `oracles/<platform>.md`, not changing the skill.

# Changelog

All notable changes to the devTools plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## 1.7.1 — 2026-05-06

### Changed

- `ui-refinement` and `skill-distill`: persona files reframed as
  instruction-driven critique / writing guides. Dropped the "you are
  a senior designer" / "you are a frustrated power user" / "you are
  a senior engineer" role-play framings — the model treats role-play
  as noise and the rules as signal. Content (scan order, mantras,
  finding format) is preserved; the framing is now imperatives and
  rules.
- `ui-refinement` Phase 4.2 now dispatches **two parallel subagents**
  per critique pass: one runs the visual-quality guide +
  visual-critique checklist, the other runs the edge-state guide.
  Main agent merges + dedupes findings. Keeps the main context lean
  over long iteration loops; speeds up each pass.
- `ui-refinement` Phase 4.1 now mandates **aggressive exploration**
  before critique: click every interactive element, open every
  entrance, exit every exit, try every input, walk every flow
  end-to-end. Static screenshotting is no longer enough. Standard
  raised explicitly to "would a top-tier team ship this?".
- `skill-distill` Phase 1.2 (magic extraction from transcript)
  dispatches one subagent — large transcripts no longer pollute the
  main context. Phases 2.1 (prior-art search) + 2.3 (destination
  probe) dispatch as two **parallel subagents** since they're
  independent.
- `skill-distill` `references/distill-method.md`: added a note that
  source-session role-play framings ("act as a senior designer")
  must be translated into instruction-driven rules when porting into
  the new skill.

## 1.7.0 — 2026-05-04

### Added

- New skill: `skill-distill`. Promote a great Claude Code session
  into a reusable, generalized Skill. Distilled from the same
  meta-pattern that produced `ui-refinement` itself.
  - Five-phase flow mirroring `ui-refinement` so the experience is
    familiar: Source → Research → Design → Plan + Approval → Ship.
  - Reads source from one of three modes: current session transcript
    (default — `~/.claude/projects/<proj>/<id>.jsonl`), user-supplied
    transcript path, or free-text summary.
  - Three-lens distillation method: user-prompt patterns (persona /
    scope / autonomy framings), agent decisions that paid off (tool
    choices, loop structures, scope guards), and course-corrections
    (every pushback becomes a bright-line rule).
  - Asks destination via `AskUserQuestion`: user-level, repo-level,
    or custom path. Custom path probes for marketplace, single-plugin,
    or plain repo and adapts the bookkeeping (plugin.json +
    marketplace.json + CHANGELOG + README in lockstep when
    applicable).
  - Encodes its own magic ingredients: read before write, user prompts
    are half the magic, course-corrections are bright lines, web-
    search prior art, generalize across axes, description is the
    trigger, bookkeeping in lockstep, commit message records the
    distillation source.
  - Files shipped: `SKILL.md`, three reference docs (skill format,
    distill method, destination conventions), one persona, one
    quality checklist, one design template.

## 1.6.0 — 2026-05-04

### Added

- New skill: `ui-refinement`. A generalized, autonomous UI/UX
  refinement loop driven by browser / simulator MCP tools. Distilled
  from a real session that turned a "this mobile chat is bad" prompt
  into 5 production commits via the live-inspect → critique →
  implement → regression-check loop.
  - Five-phase flow: Define → Setup → Plan → Execute → Done. Each
    iteration pass runs a two-persona critique (senior-designer +
    ruthless-tester) and a regression check across unaffected
    viewports.
  - Platform-agnostic: web (Playwright MCP / Chrome DevTools MCP),
    iOS (simulator MCP / manual loop), Android (emulator MCP / adb).
    Each platform has its own gating and viewport recipes.
  - Encodes the success patterns: live inspection only, find more
    than the listed defects, industry refs as inspiration not gospel,
    design-system guardrail with sign-off escalation, both viewports
    every pass, real running stack with real data, cost protection on
    paid credentials.
  - Files shipped: `SKILL.md`, two persona docs, three platform docs,
    two checklists (visual critique + design-system guard), one plan
    template. No scripts in v1.

## 1.5.3 — 2026-05-02

### Fixed

- `frustration-check`: hook output now uses the fully-qualified
  skill identifier `devTools:frustration-check` instead of the bare
  name `frustration-check`. Bare-name signals were causing Claude to
  guess a wrong namespace (e.g. `superpowers:frustration-check`) and
  fail with `Unknown skill`. With the prefix in the hook message,
  Claude can invoke the Skill tool directly without guessing.

## 1.5.2 — 2026-04-29

### Changed

- `qa-session`: ruthlessly visual. The Explorer was passing console- and
  network-clean runs while obvious defects (overlapping icons in a
  voice tile, click-to-select changing tile size and rewrapping
  description text) sailed past. Three changes:
  1. **New visual oracles** in `oracles/web.md`:
     `web.no-element-overlap`, `web.consistent-grid-tile-size`,
     `web.no-jarring-reflow-on-interact`, `web.no-text-clipping`,
     `web.no-loading-flash`, `web.alignment-and-spacing`. All are
     screenshot-eye checks, not just DOM queries — designed to catch
     defects that look fine in code.
  2. **New `shared.design-critique` meta-oracle** establishing the
     "senior designer + frustrated real user" mindset and a fixed
     critique checklist (alignment, sizing consistency, overlap,
     truncation, spacing, interaction sense, animation, "would a
     designer ship this?").
  3. **Explorer prompt** now mandates a visual-critique pass after
     every screenshot, a compare-pair pass for grids/lists with
     before/after screenshots, and a final design-walkthrough section
     before closing. Lower bar for `?` tags — no visual / UX nit is
     too small to flag.
  4. **Reporter classification loosened**: visible visual / UX defects
     captured in screenshots with reproducible repro steps and clear
     expected-vs-actual descriptions are now first-class **bugs**, not
     just "issues." Issues are reserved for genuinely unverifiable
     hunches and tester-blockers. An anti-bias check tells the Reporter
     to re-read the visual `?` lines if fewer than ~50% became bugs.
  5. **`templates/oracles.md.tmpl`** now enables the new visual
     oracles by default in scaffolded platforms. **Existing platform
     `qa/<platform>/oracles.md` files are not auto-migrated** — add
     the new oracle lines manually if you want them on existing
     projects.

## 1.5.1 — 2026-04-28

### Added

- `qa-session`: support comma-separated charter ids in the invocation
  argument. `/qa-session <platform> <id1>,<id2>,...` runs that exact
  subset; unknown ids fail loud with the available list rather than
  silently skipping. Single-id invocation is unchanged. Lets you run
  e.g. `smoke,design-refresh` together without dragging `login` along
  when the seed is already fresh.

## 1.5.0 — 2026-04-27

### Added

- `qa-session`: new skill. Generalized session-based QA agent that
  catches functional bugs *and* bad UX (visual issues, weird
  behaviors, design oversights) by running risk-ranked exploratory
  charters through a Planner / Explorer / Reporter subagent split.
  Methodology is James Bach's Session-Based Test Management: a
  charter is a one-paragraph mission, the Explorer takes free-form
  Markdown notes during a real browser session (RST session-sheet
  style with inline `!` `?` `#` tags — no pre-classification), and
  the Reporter does a PROOF-style debrief (Past, Results, Outlook,
  Obstacles, Feelings) that lifts items into either confirmed
  `bugs` (RIMGEA-formatted JSON) or `issues` (the "weird, not sure
  yet" pile).
- `qa-session`: per-platform isolation. The skill operates on
  `qa/<platform>/` in the target project — each platform owns its
  own `config.yml`, `charters/`, `findings/{bugs/,issues.md}`,
  `index.json`, `oracles.md`, and `recon.sh`. Adding mobile or
  backend support is "create another platform directory," not a
  skill change.
- `qa-session`: scaffolds the platform tree on first run from
  `templates/` (config, login charter, smoke charter, oracles,
  recon.sh) and gitignores per-run `sessions/` + `.playwright/`
  artifacts.
- `qa-session`: ships a canonical oracle library (`shared.md`,
  `web.md`) covering FEW HICCUPPS, console errors, network
  failures, layout shift, focus visibility, COOP/COEP, broken
  images, blank renders, and tap-target sizing. Charters reference
  oracles by name; new project-specific oracles can be authored in
  the platform's `oracles.md`.
- `qa-session`: parent-branch detection adapted from `retro` —
  `qa-session.baseBranch` git config override → `develop` →
  scan-based newest-merge-base heuristic → fallback chain. Diff
  scoped to that base feeds the Planner's risk ranking.
- `qa-session`: hybrid risk ranking. Skill computes a deterministic
  baseline score (lines changed × weight + recent recurrences +
  recent issue count + days since last run); Planner subagent
  re-ranks where qualitative judgment beats the formula. Charters
  the diff doesn't touch can still run if their corpus footprint
  has high recurrence.
- `qa-session`: bug auto-close after N consecutive runs not seeing
  the same fingerprint (default 3, configurable). Prevents corpus
  rot without losing history — entries flip to `auto-closed-stale`
  rather than being deleted.
- `qa-session`: handoff is multi-trigger and never silent. Reporter
  splits findings into `needs_human` (perceptual judgment, design
  intent decisions) and `needs_fixer_agent` (confirmed bugs with
  repro). Skill never edits application source.

## 1.4.2 — 2026-04-26

### Fixed

- `retro` / `recall-test-knowledge`: fix path typo `agent/docs/` →
  `agents/docs/` across skill instructions, helper scripts, tests, and
  README. Scripts that scaffold and read knowledge dirs (`detect_context.sh`,
  `probe_context.sh`) now use the correct plural path, matching the
  intended convention.

## 1.4.1 — 2026-04-23

### Added

- `frustration-check`: register a `SessionStart` hook that runs
  `init_settings.py` on every session start. Previously the user settings
  file at `~/.ccToolBox/frustration-check/settings.json` was only created
  when someone explicitly ran the init script, so users who never tripped
  the frustration threshold had no visible file to customize. The init is
  idempotent (first-run creates, same-version no-ops, older-version
  migrates) and silent on stdout, so it adds no context overhead.

## 1.4.0 — 2026-04-23

### Added

- `frustration-check`: new skill with auto-triggering `UserPromptSubmit`
  hook. Detects drift/frustration via tiered regex (T1 constraint
  repetition, T2 rage, T3 contradiction) with decay-based scoring across
  turns, plus T4 self-realization phrases for a lighter "assist mode"
  trigger. When fired, runs a consent-gated intervention: step-back one-
  liner → recent-turn reflection → offered drift scan / knowledge-gap
  websearch / push-on → intent re-confirmation. Calibrated against real
  session data: profanity alone (default threshold 5) does NOT fire;
  constraint repetition is the dominant signal.
- `frustration-check`: opt-out via `enabled: false` in
  `~/.ccToolBox/frustration-check/settings.json` or by including the
  substring `skip frustration-check` in a prompt. Settings ship at
  `version: 1` with threshold, decay, TTL, and user-extensible custom
  patterns per tier.

## 1.3.0 — 2026-04-22

### Added

- `retro`: add a dedicated testing-extraction pass to the analysis
  subagent. New candidate types `test-method` and `test-case` enforce a
  strict template (Tool / When / Why this tool / How for methods;
  Scenario / Why added / Steps / Expected for cases). Weak candidates
  route to `learnings` instead of bloating `testing-knowledge.md`.
- `retro`: bootstrap now scaffolds `## Methods` and `## Cases` sections
  in `testing-knowledge.md`. Existing files without those sections prompt
  a one-time migration (legacy content preserved under `## Legacy`).
- `retro`: apply logic routes `test-method` / `test-case` candidates
  into their named section. `last-distilled` header refreshes on any
  write to `testing-knowledge.md`.
- `recall-test-knowledge`: new skill. Auto-loads relevant entries from
  `testing-knowledge.md` and testing-related `.claude/rules/*.md` into
  the current session. Fires on testing-related user intent
  ("how do we test X", "add a smoke test", etc.). Parses the file via a
  deterministic script, dispatches an Explore subagent for relevance
  ranking, confirms the candidate set with the user, then injects
  approved entries verbatim. Read-only; never writes.

## 1.2.0 — 2026-04-20

### Changed

- `retro`: prefer `develop` (or `origin/develop`) as the default parent
  branch in auto-detection when it exists. Previously the heuristic picked
  the ref with the newest merge-base, which could select a sibling feature
  branch over `develop` — wrong for the common "branch off develop" flow.
  Scan-based detection is retained as a fallback when develop is absent.

## 1.1.0 — 2026-04-19

### Changed

- `retro`: detect the actual parent branch instead of assuming `main`.
  `detect_context.sh` now scans all local + remote-tracking branches,
  computes `merge-base` against HEAD, and picks the ref with the newest
  merge-base commit (most recent fork point). Correctly handles branches
  forked from `develop`, another feature branch, or any non-default base.
- `retro`: support `git config retro.baseBranch <ref>` as a manual override
  when auto-detection picks the wrong branch.
- Fallback chain (`origin/HEAD` → `main` → `master` → `develop`) preserved
  for edge cases where no other branches exist.

## 1.0.0 — 2026-04-19

### Added

- Added `retro` skill: branch-scoped retrospective that distills session +
  diff into rule/details/learnings/test-knowledge artifacts via subagent
  analysis and per-candidate user approval.

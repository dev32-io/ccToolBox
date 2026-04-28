# Changelog

## 1.5.0 — 2026-04-27

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

- `retro` / `recall-test-knowledge`: fix path typo `agent/docs/` →
  `agents/docs/` across skill instructions, helper scripts, tests, and
  README. Scripts that scaffold and read knowledge dirs (`detect_context.sh`,
  `probe_context.sh`) now use the correct plural path, matching the
  intended convention.

## 1.4.1 — 2026-04-23

- `frustration-check`: register a `SessionStart` hook that runs
  `init_settings.py` on every session start. Previously the user settings
  file at `~/.ccToolBox/frustration-check/settings.json` was only created
  when someone explicitly ran the init script, so users who never tripped
  the frustration threshold had no visible file to customize. The init is
  idempotent (first-run creates, same-version no-ops, older-version
  migrates) and silent on stdout, so it adds no context overhead.

## 1.4.0 — 2026-04-23

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

- `retro`: prefer `develop` (or `origin/develop`) as the default parent
  branch in auto-detection when it exists. Previously the heuristic picked
  the ref with the newest merge-base, which could select a sibling feature
  branch over `develop` — wrong for the common "branch off develop" flow.
  Scan-based detection is retained as a fallback when develop is absent.

## 1.1.0 — 2026-04-19

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

Initial release.

- Added `retro` skill: branch-scoped retrospective that distills session +
  diff into rule/details/learnings/test-knowledge artifacts via subagent
  analysis and per-candidate user approval.

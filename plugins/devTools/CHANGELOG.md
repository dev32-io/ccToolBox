# Changelog

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

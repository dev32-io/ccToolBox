# Changelog

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

# Changelog

All notable changes to the offline-research plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [3.1.2] — 2026-05-27

### Fixed

- **Critical**: expansion-planner insertion anchor was wrong. New tasks were inserted BEFORE the next `Synthesize`, which caused the current round to bloat infinitely as each `Score:` triggered more expansion tasks ahead of the same Synth — the round-closing Synthesize would never fire. Rule rewritten: each expansion accretes a NEW ROUND (work block + `Score:` per parent) AFTER the next pending `Synthesize` and BEFORE the following `Synthesize`. If no following `Synthesize` exists, expansion-planner appends one. Each `Synthesize` now fires cleanly as a round boundary + presentable artifact. Loop oscillates: `Synth → work → Synth → work → ...`.
- Seed templates dropped the post-Research/pre-C&S `Synthesize` task (`research-probe`, `arch-forge`, `refactor-probe`). That early Synth produced an artifact with no scoring data — wasted iteration. Round-1 close is now the post-C&S Synthesize.
- expansion-planner prompt tightened: removed verbose example diffs and redundant rationale; folded hint_action defaults into a table; insertion rule has its own section. Functional behavior unchanged outside the insertion-anchor + friction-log-driven fixes; ~10 fewer lines.

## [3.1.1] — 2026-05-27

### Fixed

- **Critical**: expansion-planner EXPAND-mode rule was threshold-driven (`dim < 6`), which (a) failed to fire any expansion tasks when all dims scored ≥6 even though friction logs surfaced real gaps, and (b) inconsistently appended `Score:` re-scoring tasks (sometimes appended, sometimes not, due to ambiguous "after dim-driven inserts" wording). Rule rewritten as friction-log-driven: any dim with ≥1 friction entry triggers a hint_action task; `Score:` is ALWAYS emitted (never deduplicated). Natural cap: up to 5 hint-action tasks + 1 Score per expansion. Topics with consistently strong findings still naturally CONCLUDED via plateau math (Δ ≤ 3 + prev_streak ≥ 1); no absolute-score short-circuit.

## [3.1.0] — 2026-05-27

### Changed

- `Synthesize` and `Final report` collapsed into a single `Synthesize` task type. Each `Synthesize` regenerates `<probe_dir>/synthesis.md` as a presentable mission-anchored report. README.md is no longer produced by the synthesizer.
- `templates/research-probe/progress.md` drops the `Expand scope: all topics` task (redundant — probe skill creates topic files) and the `Final report` task (collapsed into `Synthesize`). Now matches arch-forge / refactor-probe template shape.
- Synthesizer output restructured to a thesis-aligned IMRAD shape: Title → Abstract → Table of Contents → Introduction → Methods → Findings Index → Discussion → Mission Deliverables Audit → Conclusion & Recommendations → Open Questions & Suggested Reruns → References & Navigation. Mission deliverables explicitly audited against findings. Conclusion section delivers a prioritized actionable plan (the "now what").
- Workshop-loop dispatch table updated: `Synthesize` row now covers `Synthesize: <variant>` forms (used by arch-forge / refactor-probe templates).
- `plugins/offline-research/README.md` agent table + `docs/architecture.md` updated to reflect single Synthesize task type (no more "Final report" mentions outside CHANGELOG).

### Removed

- `Final report` task type. Use `Synthesize` instead — the last `Synthesize` in the queue IS the final report.
- Word/length caps on synthesizer output. Agent gauges depth from material.
- Synthesizer-generated `README.md` output.

## [3.0.4] — 2026-05-27

### Fixed

- Completes the 3.0.3 topic-slug convention: critique-scorer.md was missed
  in the 3.0.3 commit (read-before-write race). Now critique-scorer's
  Inputs section explicitly says `topic` is the bare slug (strip `NN-` if
  passed in dispatch), and all path references use `<topic-slug>` instead
  of `<topic>`.

## [3.0.3] — 2026-05-27

### Fixed

- **Critical**: topic-slug naming inconsistency. The `topics/` directory uses
  `NN-<topic-slug>.md` filenames for sort order, but probe skills were filling
  the scoreboard and queue tasks with the `NN-` prefix too. Agents (especially
  topic-researcher and critique-scorer) interpreted the topic identifier
  inconsistently — sometimes keeping `NN-`, sometimes stripping it — resulting
  in duplicate findings files (`01-foo.md` AND `foo.md`) and mismatched
  scores/queue references. Fix: clarified across all three probe skills
  (`/research-probe`, `/arch-forge`, `/refactor-probe`) and agent definitions
  (`topic-researcher`, `critique-scorer`) that the `NN-` ordinal lives ONLY
  on the `topics/` filename. Scoreboard, queue tasks, findings, scores, and
  all expansion-planner outputs use the **bare `<topic-slug>`**.

## [3.0.2] — 2026-05-27

### Fixed

- **Critical**: expansion-planner was appending new `Investigate:`/`Score:` tasks
  at the END of the task queue, but for multi-topic runs the queue still had
  pending `Critique & Score:` tasks for other topics after the just-completed
  one. Result: the orchestrator dove into re-investigating topic 01 before
  scoring topics 02..N at the current findings round. Fix: expansion-planner
  now inserts new tasks AFTER the last `Critique & Score:` / `Score:` task
  in the queue and BEFORE any `Synthesize` / `Final report` task. All topics
  get a first-round score before any single topic gets re-improved.

## [3.0.1] — 2026-05-27

### Fixed

- Probe skills, templates, README, CHANGELOG, architecture.md, and container
  shell-mode hints all said `/workshop-loop` (which fails — slash commands
  resolve under the plugin namespace). Replaced with `/offline-research:workshop-loop`.
  Internal file paths (`commands/workshop-loop.md`, `hooks/workshop-loop-stop.sh`)
  and transcript markers (`[workshop-loop-active|done]`) unchanged.

## [Unreleased]

## [3.0.0] — 2026-05-26

### Breaking

- **Removed `./launch.sh run` subcommand.** Driving iteration via host-side
  `docker exec ... claude -p` would move to Anthropic's separate Agent SDK
  credit pool on 2026-06-15. Use `/offline-research:workshop-loop <probe-dir>` from an
  interactive Claude Code session instead. The session can be local
  (subscription billing) or inside `./launch.sh shell` for PoC sandboxing
  (still subscription billing — interactive `claude`, not `claude -p`).
- **Removed light entrypoints** (`entrypoint-light.sh`, `entrypoint-light-opencode.sh`).
  All container profiles now use the same interactive `entrypoint.sh`.
- **Probe seed file shape changed.** `prompt.md` → `mission.md` (slimmed —
  no embedded loop instructions). `critique-loop.md` and `expansion-loop.md`
  files removed; their procedural logic now lives in the plugin-shipped
  subagent definitions. `ralph-command.md` removed.
- **For `refactor-probe` rubrics**, the `hint_action` column folds into
  `scoring-rubric.md`. `expansion-planner` reads it; `critique-scorer`
  ignores it.

### Added

- **`/offline-research:workshop-loop <probe-dir> [--max-iter N]`** slash command. Runs the
  master orchestrator in the user's interactive Claude Code session.
  Validates the probe directory via `scripts/validate-probe-dir.sh`,
  emits an activation marker, dispatches subagents per task.
- **5 plugin-shipped subagents** under `agents/`:
  - `topic-researcher` (opus) — Research/Improve/Investigate/Explore/etc.
  - `critique-scorer` (sonnet, isolated) — Score/Critique & Score
  - `expansion-planner` (sonnet) — applies plateau math + hint_action expansion
  - `poc-builder` (opus) — PoC/Build, sandbox-aware via `$WORKSHOP_CONTAINER`
  - `synthesizer` (opus) — Synthesize + Final report (with Suggested Reruns
    retrospective)
- **`hooks/workshop-loop-stop.sh`** Stop hook. Derives state from
  `progress.md` (no external state file). Termination on RUN COMPLETE
  promise, all-CONCLUDED-empty-queue, or `max_iter` reached.
- **`./launch.sh shell <probe-dir>`** mounts the probe dir as `/workspace`
  and sets `WORKSHOP_CONTAINER=1` so `poc-builder` can run code freely.
- **`scripts/validate-probe-dir.sh`** — pre-orchestration param validation
  with test harness.
- **Parallel topic execution** — orchestrator dispatches up to
  `max_parallel` (default 4) topic-researcher agents per iteration for
  distinct-topic Research/Improve/Investigate/Explore/Connect tasks.
- **`connections.md`** — cross-topic insights, created lazily; integrated
  into `topic-researcher` (read on Improve/Explore, write on cross-topic
  observations) and `expansion-planner` (can append `Connect:` tasks).
- **End-of-run rubric retrospective** — `synthesizer` surfaces
  `Suggested Reruns` for topics that plateaued early or at low totals.
  Suggestions only; no mid-run rubric change.

### Changed

- Probe skills (`/research-probe`, `/arch-forge`, `/refactor-probe`) now
  recommend `<cwd>/<short-title>/` for seed file location (was
  `~/offline-research/<short-title>/`). Rationale: repo-level plugin
  install scopes hooks to the project.
- All three probe skills' final run-command emission now points at
  `/offline-research:workshop-loop` (single recommended path) with sandboxed
  `./launch.sh shell` as the second option.
- Container Dockerfiles preserved; only the host-side runner scripts +
  light entrypoints removed.

### Migration

- v1 probe directories still readable in v3.0.0, but you cannot run them
  via the orchestrator until you regenerate seed files with the new
  templates (or manually add a `max_iter: N` header to existing
  `progress.md`, rename `prompt.md` → `mission.md`, and split topics into
  `topics/NN-<slug>.md` files). For new work, just re-invoke the probe
  skill into a new dated directory.

## 2.4.2

### Changed

- All runners: replace permission error detection with general error logging (`errors.log` in workspace)
- Error log captures: exceptions, panics, crashes, connection failures, subagent failures, API errors

## 2.4.1

### Fixed

- Refactor-probe skill: add stop gates so agent waits for user input before writing files and before showing run commands
- Refactor-probe skill: use `./launch.sh` instead of resolving absolute plugin path
- Refactor-probe skill: restore `/ralph-loop` slash command format for manual options
- Refactor-probe skill: add codebase copy step for container execution
- Refactor-probe prompt template: point agent to `codebase/` directory inside workspace

## 2.4.0

### Added

- `/refactor-probe` skill with rubric co-design, dimension-aware expansion, and PoC building
- Refactor-probe templates (prompt, progress, expansion-loop, scoring-rubric-template)
- Unified `containers/workshop/` with per-profile Dockerfiles (`--container=research|arch|refactor`)

### Changed

- Consolidated `containers/offline-research/` and `containers/arch-tool/` into `containers/workshop/`
- `launch.sh` now requires `--container` flag to select profile
- Renamed `run-arch.sh` to `run-arch-forge.sh`
- Updated research-probe and arch-forge run commands to use workshop container

### Fixed

- Subagent rate-limit detection — all runners now use broad regex patterns to catch `429`, `too many requests`, `quota exceeded`, etc. (backported from source refactor-probe runner)

> Deep dive: [docs/architecture.md](docs/architecture.md)

## 2.3.2

### Fixed

- Container auth and security handling for both containers
- Runner display issues
- Topic mount isolation -- each run gets its own /workspace
- Runner crash on unexpected state
- Expansion ordering in arch-forge loop

## 2.3.1

### Fixed

- Skill frontmatter -- removed invalid `version` field, switched to `allowed-tools`

## 2.3.0

### Added

- `/arch-forge` skill with interactive refinement flow
- arch-tool container with PoC sandbox (`poc` user isolation via sudo + gosu)
- Scoring rubric, expansion loop, prompt, and progress templates for arch-forge
- Bidirectional poc sandbox enforcement
- Test suite for poc isolation, auth, workspace, and system paths

### Changed

- Reorganized templates into per-skill subdirectories

### Fixed

- Removed yarn from arch-tool Dockerfile (conflicts with node:20-slim)
- Enforced `.private/` directory traversal block for poc user

## 2.2.0

### Added

- `launch.sh` rewritten with `setup`, `run`, and `shell` subcommands
- Auto-resume run option in research-probe skill
- Python3, ripgrep, and build tools added to container image
- Testing suite for schedule logic and container behavior

### Fixed

- Deferred `CLAUDE_CODE_RESEARCH_TOOL` check to `ensure_container`
- Octal parsing in schedule logic

## 2.1.0

### Added

- Research runner with schedule-aware auto-resume (`run-research.sh`)
- `.env.example` for runner configuration (RESEARCH_HOURS, TZ, CONTAINER_NAME)
- Default timezone in Dockerfile

## 2.0.0

### Changed

- Rewrote to checklist-driven model -- prompt, progress, critique-loop, and skill all rewritten
- Task queue with placeholders in progress.md
- Critique loop with flowchart, plateau rules, and scoring example
- New max-iterations formula: `topics * 8 + 10`

## 1.2.0

### Changed

- Consolidated all templates under `plugins/` directory

### Fixed

- Added CRITICAL plain-text completion warning to critique-loop

## 1.1.0

### Added

- Scoring rubric template for Sonnet subagents
- Critique loop template
- Phase 6 gate and PoC workspace in prompt template
- Max-iterations calculation in research-probe skill

### Changed

- Replaced progress checklist with scoreboard format

## 1.0.0

### Added

- Plugin scaffold with marketplace registration
- `/research-probe` skill
- Prompt and progress templates
- Offline-research container with launch UI and spinner
- Task list, run options, and clipboard copy in research-probe

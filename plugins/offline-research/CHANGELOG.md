# Changelog

All notable changes to the offline-research plugin.

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

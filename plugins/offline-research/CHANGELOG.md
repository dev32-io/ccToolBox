# Changelog

All notable changes to the offline-research plugin.

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

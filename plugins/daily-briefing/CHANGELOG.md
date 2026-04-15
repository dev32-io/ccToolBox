# Changelog

All notable changes to the daily-briefing plugin.

## 2.1.0

### Changed

- `scripts/init_settings.py` now prints a structured envelope `{settings, paths, date}`. `paths` contains pre-computed absolute paths (`staging_dir`, `out_txt`, `out_mp3`, `out_json`, `out_html`). `date` contains `iso` and `human` fields. Accepts an optional `--date YYYY-MM-DD` arg. Creates the staging subdirectory.
- `SKILL.md` rewritten to use the literal absolute paths from `init_settings.py` — no more shell-style `$OUT_JSON` variables. Fetch agents now write directly to staging files instead of returning content.

### Added

- `scripts/build_data_json.py` — assembles the nested briefing JSON (the input to `render_html.py`) from per-source staging files. Moves the schema-assembly cognition out of the model so small local models (e.g., Qwen3 Coder 30B via LM Studio) can execute the skill reliably.
- `tests/test_build_data_json.py` with 10 black-box tests.

### Fixed

- Small local models (Qwen3 Coder 30B) could not execute v2.0.0's SKILL.md because it relied on the model mentally substituting shell variables across tool calls, and required the model to hand-compose a 5-key nested JSON object. The v2.1.0 changes remove both cognitive loads entirely.

## 2.0.0

### Changed (breaking)

- Flattened architecture: orchestrator agent removed, skill itself dispatches fetch and generation subagents.
- Settings format: `settings.default.md` (markdown frontmatter) → `settings.default.json` (pure JSON). Old user settings at `~/.ccToolBox/daily-briefing/settings.md` are NOT migrated — users will see a fresh default on first run.
- Settings version: integer (2) instead of semver string.
- Storage path canonicalized to `~/.ccToolBox/daily-briefing/`. The `~/.config/ccToolBox/daily-briefing/` path referenced in some v1 docs is no longer used.
- All assets (`scripts/tts.sh`, new `scripts/init_settings.py`, new `scripts/render_html.py`, `settings.default.json`) moved INSIDE the skill dir for self-containment and reliable path discovery via `${CLAUDE_SKILL_DIR}`.

### Added

- `scripts/init_settings.py` — deterministic first-run, malformed-reset, version migration, and retention cleanup. Replaces prose-driven logic in the old orchestrator.
- `scripts/render_html.py` — renders the newspaper HTML from structured JSON. Eliminates inline CSS/layout spec in the skill prompt.
- Black-box test suite (`tests/test_init_settings.py`, `tests/test_render_html.py`) using stdlib `unittest`.
- Sibling `plugins/daily-briefing-opencode` plugin for OpenCode users (not registered in the CC marketplace).

### Removed

- `agents/daily-briefing-agent.md` orchestrator (~332 lines).
- `settings.default.md` (replaced by JSON).
- `docs/simplified-instructions.md` (stale auto-generated content).

## 1.5.1

### Fixed

- Ensure TTS audio is ready before opening the page in browser
- Reduce chattiness in agent output

## 1.5.0

### Changed

- Split into thin skill trigger + Sonnet orchestrator agent for better token efficiency

## 1.4.3

### Changed

- Use Haiku for fetch agents, Sonnet for generation (cost optimization)

## 1.4.2

### Changed

- Trim verbose explanations from SKILL.md

## 1.4.1

### Changed

- Consolidate agent rules and improve URL quality enforcement

## 1.4.0

### Added

- New trigger phrases ("good morning", "get my daily briefing", etc.)
- Creative greeting at the top of each briefing
- Retention system (configurable days, default 14)
- System date injection for accurate "today" references

## 1.3.3

### Fixed

- Cleanup temporary files after generation
- Limit agent tool access to prevent unintended side effects

## 1.3.2

### Fixed

- Use Write tool with Read-first pattern for /tmp/ file writes

## 1.3.1

### Fixed

- Use Bash heredoc for /tmp/ writes instead of Write tool

## 1.3.0

### Added

- Sonnet subagents for parallel source fetching
- Parallel TTS and HTML generation pipelines

### Changed

- Semver-based settings with automatic version migration

## 1.2.0

### Added

- Closing section with today-in-history fact and inspiration quote

## 1.1.0

### Added

- Vintage broadsheet newspaper layout with 3/4 column design
- 12 content sources (up from 5)
- Dark/light mode toggle with Dark Reader lock
- Lead story selection with image fetching
- Responsive layout

### Fixed

- Default to light mode instead of dark
- Audio timing race condition on page load
- Link quality enforcement -- fill sparse sections, no invented URLs

## 1.0.0

### Added

- Initial release -- daily briefing skill with weather, tech news, Reddit, AP headlines, and TTS audio

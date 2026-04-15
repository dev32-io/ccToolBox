# Changelog

All notable changes to the daily-briefing-opencode plugin.

## 1.1.0

### Changed

- Mirrors daily-briefing (Claude Code) v2.1.0: structured `init_settings.py` output with absolute paths and date, new `build_data_json.py` assembler, flat SKILL.md flow with literal paths and staging-file writes.

### Fixed

- Small local models via LM Studio (e.g., Qwen3 Coder 30B) were producing `undefined` bash tool calls and malformed nested JSON in v1.0.0. The v1.1.0 scripts eliminate the shell-variable substitution and JSON-assembly cognition required of the model.

## 1.0.0

### Added

- Initial OpenCode-targeted daily briefing skill.
- Mirrors Claude Code `daily-briefing` v2.0.0 behavior: 12 content sources, lead-story selection, image fetching, newspaper-style HTML, TTS audio via Docker.
- Self-contained skill directory: `SKILL.md` + `scripts/init_settings.py` + `scripts/render_html.py` + `scripts/tts.sh` + `settings.default.json`.
- Storage at `~/.ccToolBox/daily-briefing/` (shared path with the Claude Code version — running one does not conflict with the other, they read the same settings).

# Changelog

All notable changes to the daily-briefing-opencode plugin.

## 1.0.0

### Added

- Initial OpenCode-targeted daily briefing skill.
- Mirrors Claude Code `daily-briefing` v2.0.0 behavior: 12 content sources, lead-story selection, image fetching, newspaper-style HTML, TTS audio via Docker.
- Self-contained skill directory: `SKILL.md` + `scripts/init_settings.py` + `scripts/render_html.py` + `scripts/tts.sh` + `settings.default.json`.
- Storage at `~/.ccToolBox/daily-briefing/` (shared path with the Claude Code version — running one does not conflict with the other, they read the same settings).

# daily-briefing Plugin

Generates a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

## Components

- `skills/daily-briefing/SKILL.md` — main skill definition (invoked via `/daily-briefing` or "good morning")
- `scripts/tts.sh` — TTS generation using Docker (openai-edge-tts)
- `settings.default.md` — versioned default settings template

## Dependencies

- **Docker** — required for TTS audio generation (`scripts/tts.sh` runs a container)
- **curl, jq** — used by `tts.sh` for API calls

## Settings

- Default settings ship in `settings.default.md` with `version: N` frontmatter
- User settings live at `~/.config/ccToolBox/daily-briefing/settings.md`
- The skill handles first-run copy and version migration automatically
- **When changing the settings structure, bump the `version` integer in `settings.default.md`**

## Testing Locally

Invoke the skill with `/daily-briefing` or say "good morning" in a Claude Code session where this marketplace is registered.

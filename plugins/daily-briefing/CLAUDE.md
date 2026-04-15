# daily-briefing Plugin

Generates a personalized daily briefing as a vintage broadsheet newspaper-styled HTML page with TTS audio. Features 12 content sources, dynamic lead story selection, image fetching, and dark/light mode toggle.

## Components

- `skills/daily-briefing/SKILL.md` — main skill definition (invoked via `/daily-briefing` or "good morning")
- `scripts/tts.sh` — TTS generation using Docker (openai-edge-tts)
- `skills/daily-briefing/settings.default.json` — versioned default settings template

## Dependencies

- **Docker** — required for TTS audio generation (`scripts/tts.sh` runs a container)
- **curl, jq** — used by `tts.sh` for API calls

## Content Sources (12)

**Tech:** Hacker News, Dev.to, GitHub Trending, TechCrunch, r/ClaudeAI, AI/ML (arXiv + The Batch)
**Non-tech:** Space/Science (NASA APOD), Gaming, Maker/Hobby (Instructables, r/3Dprinting)
**News:** AP News
**User-defined:** Extra (customizable via settings)
**Weather:** Location-based summary

## Features

- **Lead story selection** — Claude picks the most impactful tech story and promotes it to the big left column
- **Image fetching** — 2-3 images via WebSearch (lead story + NASA APOD)
- **Dark/light mode** — toggle button, defaults to light, respects `prefers-color-scheme`
- **Dark Reader lock** — `<meta name="darkreader-lock">` prevents extension interference
- **Responsive layout** — collapses from 3/4 columns to 2 to 1 on narrow screens

## Settings

- Default settings ship in `settings.default.json` with a `version` key
- User settings live at `~/.ccToolBox/daily-briefing/settings.json`
- The skill handles first-run copy and version migration automatically
- **When changing the settings structure, bump the `version` integer in `settings.default.json`**

## Testing Locally

Invoke the skill with `/daily-briefing` or say "good morning" in a Claude Code session where this marketplace is registered.

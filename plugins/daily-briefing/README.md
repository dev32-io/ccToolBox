# daily-briefing

A Claude Code skill that generates a personalized daily briefing as a newspaper-styled HTML page with embedded TTS audio.

## What It Does

When you say "good morning" or invoke `/daily-briefing`, Claude will:

1. Fetch weather, tech news (Hacker News, Dev.to), Reddit (r/ClaudeAI), and AP headlines
2. Generate a newspaper-styled HTML page with all sections
3. Generate TTS audio narration
4. Open the briefing in your browser with an embedded audio player

## Prerequisites

- **Docker** — used to run the TTS engine
- **Claude Code** with this marketplace registered

## Setup

Install via the ccToolBox marketplace:

```bash
claude plugins install daily-briefing
```

## Customization

Settings are stored at `~/.config/ccToolBox/daily-briefing/settings.md`.

On first run, default settings are copied there automatically. Edit the file to customize:

```markdown
---
version: 1
---
# Daily Briefing Settings

## General
- voice: en-US-AvaMultilingualNeural
- location: Burnaby, BC, Canada

## Sources (in order of appearance)
- weather: short summary for {location}
- tech-hn: 2-5 items from Hacker News (AI, CS, tech)
- tech-devto: 2-5 items from Dev.to (AI, CS, tech)
- reddit-claudeai: 2-5 hot new posts from r/ClaudeAI
- news-ap: 2-5 very short headlines from AP News
- extra: (add your own sections here)
```

- **voice** — any Azure TTS voice identifier
- **location** — your city for weather lookups
- **sources** — reorder, add, or remove sections

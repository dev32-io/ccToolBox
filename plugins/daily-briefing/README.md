# daily-briefing

Vintage broadsheet daily briefing with 12 content sources, TTS audio narration, and dark/light mode.

**Version:** 1.5.1

## Skills

### /daily-briefing

**Trigger:** `/daily-briefing`, "good morning", "get my daily briefing", "what's the news today"

**What it does:**

1. Fetches content from 12 sources (weather, tech, news, science, gaming, maker)
2. Selects a lead story and promotes it to the big left column
3. Fetches 2-3 images (lead story + NASA APOD)
4. Generates a newspaper-styled HTML page with responsive 3/4 column layout
5. Generates TTS audio narration via Docker
6. Opens the briefing in your browser with an embedded audio player

### Content sources

| Source | Items | Category |
|--------|-------|----------|
| Weather | Summary for your location | General |
| Hacker News | 2-5 | Tech |
| Dev.to | 2-5 | Tech |
| GitHub Trending | 3-5 | Tech |
| TechCrunch | 2-3 | Tech |
| r/ClaudeAI | 2-5 | Tech |
| AI/ML (arXiv + The Batch) | 2-3 | Tech |
| Space/Science (NASA APOD) | 1-2 | Science |
| Gaming | 2-3 | Entertainment |
| Maker/Hobby (Instructables, r/3Dprinting) | 1-2 | Maker |
| AP News | 2-5 | News |
| Extra (user-defined) | Custom | Custom |

### Features

- **Lead story selection** -- Claude picks the most impactful tech story for the big left column
- **Image fetching** -- lead story image + NASA APOD
- **Dark/light mode** -- toggle button, defaults to light, respects `prefers-color-scheme`
- **Dark Reader lock** -- `<meta name="darkreader-lock">` prevents extension interference
- **Responsive layout** -- collapses from 3/4 columns to 2 to 1 on narrow screens
- **Retention** -- keeps last 14 days of briefings (configurable)
- **Closing section** -- today-in-history fact and inspiration quote

### Architecture

Thin skill trigger dispatches to a Sonnet orchestrator agent, which spawns Haiku fetch subagents in parallel for each source. TTS generation runs in parallel with HTML generation.

## Prerequisites

- **Docker** -- required for TTS audio generation
- **Claude Code** with ccToolBox marketplace registered

## Setup

```bash
claude plugins install daily-briefing@ccToolBox
```

## Settings

Settings are stored at `~/.config/ccToolBox/daily-briefing/settings.md`. On first run, defaults are copied there automatically. Version migration is handled by the skill.

```markdown
---
version: 1.4.0
---
# Daily Briefing Settings

## General
- voice: en-US-AvaMultilingualNeural
- location: Burnaby, BC, Canada

## Sources (in order of appearance)
- weather: short summary for {location}
- tech-hn: 2-5 items from Hacker News (AI, CS, tech)
- tech-devto: 2-5 items from Dev.to (AI, CS, tech)
- tech-github: 3-5 trending repositories from GitHub
- tech-tc: 2-3 top TechCrunch headlines
- reddit-claudeai: 2-5 hot new posts from r/ClaudeAI
- ai-ml: 2-3 items from arXiv AI + The Batch
- space-science: 1-2 items from NASA, SpaceX, space news
- gaming: 2-3 items from r/gaming, game releases
- maker-hobby: 1-2 items from Instructables, r/3Dprinting
- news-ap: 2-5 very short headlines from AP News
- extra: (add your own sections here)

## Retention
- days: 14

## Closing Section
- today-in-history: true
- inspiration-quote: true
```

- **voice** -- any Azure TTS voice identifier
- **location** -- your city for weather lookups
- **sources** -- reorder, add, or remove sections
- **days** -- number of days to retain past briefings

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

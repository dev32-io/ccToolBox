# Daily Briefing v2 Design

**Date:** 2026-03-14
**Status:** Approved

## Overview

Redesign the daily-briefing skill's HTML output to match a vintage broadsheet newspaper layout with multi-column grid, aged paper palette, and dark/light mode toggle. Add new content sources (12 total) and image fetching for lead story and space section.

## Layout

### Structure
- Top row: 3 columns — wide lead story (2fr) with image + 2 narrow columns (1fr each) with stacked sections separated by thin horizontal dividers
- Bottom row: 4 equal columns for non-tech content
- Column dividers: thin vertical lines (`1px solid`), no borders/cards
- Section breaks: horizontal rules within columns, double-rule between rows

### Masthead
- Centered newspaper title "DAILY BRIEFING" in large serif uppercase
- Date line above, subtitle "Your Personal Morning Paper" below
- Double-rule border bottom

### Audio Player
- Styled bar at top with actual "Play Briefing" button (not just an icon)
- Track scrubber and time display
- Themed to match the newspaper palette

### Weather Bar
- Single-line centered bar below masthead
- Location, temperature, conditions, high/low, wind

### Color Palette

**Light mode (default):**
- Page background: `#E8DCC8`
- Paper: `#F2E8D0` / `#EDE3C7` / `#E9DDBF` (gradient)
- Accent background: `#E5D9BF`
- Title text: `#3E3830`
- Body text: `#5A5245`
- Muted text: `#8A7E6E`
- Faint text: `#9A8E7E`
- Heavy border: `#6B6155`
- Light border: `#C8BC9F`
- Image placeholder: `#DDD1B5`
- Button: `#5A5245` bg, `#F2E8D0` text

**Dark mode:**
- Page background: `#1A1610`
- Paper: `#252015` / `#221D13` / `#201C12` (gradient)
- Accent background: `#2A2418`
- Title text: `#D4C8A8`
- Body text: `#B0A48A`
- Muted text: `#7A6E5A`
- Faint text: `#5A5040`
- Heavy border: `#8A7E6A`
- Light border: `#3D362A`
- Image placeholder: `#2E2820`
- Button: `#D4C8A8` bg, `#1A1610` text

### Dark Mode Toggle
- Fixed position top-right corner
- Pill-shaped button: "🌙 Dark Mode" / "☀ Light Mode"
- CSS custom properties (`--bg-paper`, `--text-body`, etc.) switched via `data-theme` attribute on `<html>`
- `<meta name="darkreader-lock">` to prevent Dark Reader interference

### Typography
- Font: Georgia / 'Times New Roman' / serif
- Justified body text with hyphens
- Section labels: 8px uppercase with letter-spacing
- Headers: big (22px), medium (15px), small (12px) — all uppercase, serif

## Sources (12 total)

### Existing
1. **weather** — short summary for {location}
2. **tech-hn** — 2-5 items from Hacker News (AI, CS, tech)
3. **tech-devto** — 2-5 items from Dev.to (AI, CS, tech)
4. **reddit-claudeai** — 2-5 hot new posts from r/ClaudeAI
5. **news-ap** — 2-5 very short headlines from AP News

### New Tech
6. **tech-github** — 3-5 trending repositories from GitHub (stars today, language, description)
7. **tech-tc** — 2-3 top TechCrunch headlines (startups, funding, industry)
8. **ai-ml** — 2-3 items from arXiv AI papers + The Batch (Andrew Ng's newsletter)

### New Non-Tech
9. **space-science** — 1-2 items from NASA APOD, SpaceX, space/science news
10. **gaming** — 2-3 items from r/gaming, game releases, industry news
11. **maker-hobby** — 1-2 items from Instructables featured projects + r/3Dprinting
12. **extra** — (user-defined sections)

All sources listed in `settings.default.md` as a flat list. User removes lines they don't want.

## Lead Story Selection

After all fetch agents return, Claude evaluates all tech source results and picks the single most interesting/impactful story to promote as the lead. Criteria:
- Broad significance (affects many developers/users)
- Novelty (breaking news over ongoing stories)
- Engagement (high vote count, comment count)

The lead story gets the big left column with header-big styling and an image.

## Image Fetching

- 2-3 images total, fetched via WebSearch
- **Lead story image**: search for a relevant image after the lead story is selected
- **Space/science image**: search for NASA APOD or relevant space image
- Other sections remain text-only (like a real newspaper — not every article has a photo)
- Images are referenced by URL in `<img>` tags in the HTML (not downloaded locally)

## Settings Changes

### settings.default.md

Version bumped from 1 to 2. New entries added to the sources list:

```markdown
---
version: 2
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
```

Since the structure changes (new fields added), version is bumped to 2. The migration flow in SKILL.md will handle existing users: preserve their voice/location, merge in new source entries.

## SKILL.md Changes Summary

### Step 2: Fetch Data
- Add 5 new fetch agents (GitHub Trending, TechCrunch, AI/ML, Space/Science, Gaming, Maker/Hobby) to the parallel dispatch
- Add 1-2 image search agents that run after lead story is selected

### New Step 2.5: Lead Story Selection
- After all agents return, Claude evaluates results across tech sources
- Picks the most significant story as lead
- Dispatches image search agent for the lead story

### Step 3: HTML Generation
- Complete rewrite of HTML spec to match the broadsheet layout
- CSS custom properties for dark/light theming
- `<meta name="darkreader-lock">`
- Dark/light toggle button with JavaScript
- Multi-column grid layout with thin dividers
- Image tags for lead story and space section
- Actual "Play Briefing" button for audio

### Step 3: TTS Generation
- Same pipeline, just more content sections to narrate

## Implementation Tasks

1. Update `settings.default.md` — add new sources, bump version to 2
2. Update SKILL.md Step 2 — add new fetch agents for all new sources
3. Add SKILL.md Step 2.5 — lead story selection + image search
4. Rewrite SKILL.md HTML spec — full broadsheet layout with CSS variables, dark mode, toggle
5. Update SKILL.md Step 3 — reference new HTML spec, image tags
6. Update TTS text generation to include new sections
7. Commit and push

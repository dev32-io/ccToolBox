# Daily Briefing v2 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the daily-briefing skill with vintage broadsheet layout, 12 content sources, image fetching, and dark/light mode toggle.

**Architecture:** Update the SKILL.md instructions to add 6 new fetch agents, a lead story selection step, image searching, and a complete HTML spec rewrite with CSS custom properties for theming. Update settings.default.md with new sources (version 1 → 2).

**Tech Stack:** Claude Code plugin system (markdown skills), HTML/CSS/JS (inline in generated output)

**Spec:** `docs/superpowers/specs/2026-03-14-daily-briefing-v2-design-v2.md`

---

## Chunk 1: Settings and SKILL.md Updates

### Task 1: Update settings.default.md

**Files:**
- Modify: `plugins/daily-briefing/settings.default.md`

- [ ] **Step 1: Replace settings.default.md content**

Write the full updated content to `plugins/daily-briefing/settings.default.md`:

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

- [ ] **Step 2: Commit**

```bash
git add plugins/daily-briefing/settings.default.md
git commit -m "feat(daily-briefing): add new sources and bump settings version to 2"
```

---

### Task 2: Rewrite SKILL.md — Step 2 (Fetch Data)

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md`

- [ ] **Step 1: Replace the Step 2 section**

Find the current Step 2 section (lines 62-73 of SKILL.md) and replace it with:

```markdown
## Step 2: Fetch Data (parallel subagents)

Dispatch all agents in a SINGLE message so they run concurrently. Each agent should use WebSearch and return structured data: title, 1-line summary, URL for each item.

Launch these agents simultaneously:
- **weather agent**: Search "[location] weather today [current date]". Return 1-2 sentence summary with temperature, conditions, high/low, wind.
- **tech-hn agent**: Search "Hacker News top stories today [current date]". Return 2-5 items (title, summary, URL).
- **tech-devto agent**: Search "Dev.to top posts today [current date] AI programming". Return 2-5 items (title, summary, URL).
- **tech-github agent**: Search "GitHub trending repositories today [current date]". Return 3-5 items (repo name, stars today, language, description, URL).
- **tech-tc agent**: Search "TechCrunch top stories today [current date]". Return 2-3 items (title, summary, URL).
- **reddit-claudeai agent**: Search "reddit r/ClaudeAI hot posts [current date]". Return 2-5 items (title, summary, URL).
- **ai-ml agent**: Search "arXiv AI machine learning papers today [current date]" AND "Andrew Ng The Batch newsletter [current date]". Return 2-3 items (title, summary, URL).
- **space-science agent**: Search "NASA astronomy picture of the day [current date]" AND "space science news today [current date]". Return 1-2 items (title, summary, URL). **Also return the NASA APOD image URL if found.**
- **gaming agent**: Search "reddit r/gaming hot posts [current date]" AND "video game news today [current date]". Return 2-3 items (title, summary, URL).
- **maker-hobby agent**: Search "Instructables featured projects [current date]" AND "reddit r/3Dprinting hot posts [current date]". Return 1-2 items (title, summary, URL).
- **news-ap agent**: Search "AP News top headlines today [current date]". Return 2-5 short headlines with URLs.
- **extra agent** (only if user has customized the extra source — skip if it still says "(add your own sections here)"): Search based on the user's description text. Return 1-3 items (title, summary, URL).

All agents are research-only — they do NOT write files.
```

- [ ] **Step 2: Verify no old Step 2 content remains**

```bash
grep -n "tech-hn agent\|tech-devto agent\|reddit-claudeai agent\|news-ap agent" plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

Expected: only the new agent lines appear, no duplicates.

---

### Task 3: Add SKILL.md — Step 2.5 (Lead Story Selection)

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md`

- [ ] **Step 1: Insert Step 2.5 between Step 2 and Step 3**

After the Step 2 section's closing line ("All agents are research-only — they do NOT write files."), insert:

```markdown
## Step 2.5: Lead Story Selection + Lead Image

Once all Step 2 agents have returned:

1. **Select the lead story:** Evaluate results across all tech sources (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML). Pick the single most interesting/impactful story based on:
   - Broad significance (affects many developers/users)
   - Novelty (breaking news over ongoing stories)
   - Engagement (high vote count, comment count, stars)

2. **Fetch lead story image:** Dispatch one Agent to search for a relevant image for the lead story:
   - **lead-image agent**: Search "[lead story title] image" or "[lead story topic] photo". Return a single image URL suitable for embedding in HTML. The image should be a direct URL to a .jpg/.png/.webp file, not a page URL.

   If no suitable image is found, the lead story will render as text-only.

The lead story will be placed in the big left column of the top row. The remaining items from its original source still appear in their normal column position.
```

---

### Task 4: Rewrite SKILL.md — Step 3 (Generate TTS + HTML + Audio)

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md`

- [ ] **Step 1: Replace the Step 3 section**

Find the current Step 3 section (lines 75-101) and replace with:

```markdown
## Step 3: Generate TTS + HTML + Audio (parallel)

Once the lead story image agent has returned (or confirmed no image), do the following in a SINGLE message with parallel tool calls:

**Tool call 1 — Write TTS text** (`Write` tool): Write speech-optimized plain text to `/tmp/daily-briefing-YYYY-MM-DD.txt`
- Start with: "Good morning. Here is your daily briefing for [day of week], [month] [day], [year]."
- **Lead story first**, regardless of settings order: "Our top story today..." then the lead story summary.
- Then remaining sources in settings order, with natural transitions: "Next, in tech news from Dev.to...", "Moving to space and science...", "In gaming news...", "From the maker community..."
- For GitHub repos, narrate the description rather than the "user/repo" path (e.g., "A trending repository for building AI agents" not "anthropics slash claude code")
- NO URLs — never read a URL aloud
- Expand abbreviations: "S and P 500" not "S&P 500", "AI" can stay as "AI"
- End with: "That's your briefing. Have a great day."

**Tool call 2 — Write HTML** (`Write` tool): Write the full HTML to `/tmp/daily-briefing-YYYY-MM-DD.html` (see HTML spec below). The audio tag already points to the known MP3 path.

Then, once the TTS text file is written:

**Tool call 3 — Generate audio** (`Bash` tool): Run:
```
<plugin-root>/scripts/tts.sh /tmp/daily-briefing-YYYY-MM-DD.txt /tmp/daily-briefing-YYYY-MM-DD.mp3 [voice]
```

**Tool call 4 — Open browser** (`Bash` tool): Run simultaneously with TTS generation:
```
open /tmp/daily-briefing-YYYY-MM-DD.html
```

The HTML opens immediately (the audio player will load the MP3 once tts.sh finishes writing it).
```

---

### Task 5: Rewrite SKILL.md — HTML Spec

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md`

- [ ] **Step 1: Replace the HTML Spec section**

Find the current "## HTML Spec" section (lines 103-127) and replace with the complete new spec:

```markdown
## HTML Spec

Single self-contained HTML file with inline CSS and JavaScript. Must include `<meta name="darkreader-lock">` in `<head>` to prevent Dark Reader browser extension interference.

### Theme System

Use CSS custom properties on `:root[data-theme]` for all colors. Default to light mode via `<html data-theme="light">`.

**Light mode variables:**
```css
:root[data-theme="light"] {
  --bg-page: #E8DCC8;
  --bg-paper: #F2E8D0;
  --bg-paper-mid: #EDE3C7;
  --bg-paper-end: #E9DDBF;
  --bg-accent: #E5D9BF;
  --border-heavy: #6B6155;
  --border-light: #C8BC9F;
  --text-title: #3E3830;
  --text-body: #5A5245;
  --text-muted: #8A7E6E;
  --text-faint: #9A8E7E;
  --img-bg: #DDD1B5;
  --btn-bg: #5A5245;
  --btn-text: #F2E8D0;
  --btn-hover: #6B6155;
  --shadow: rgba(0,0,0,0.15);
}
```

**Dark mode variables:**
```css
:root[data-theme="dark"] {
  --bg-page: #1A1610;
  --bg-paper: #252015;
  --bg-paper-mid: #221D13;
  --bg-paper-end: #201C12;
  --bg-accent: #2A2418;
  --border-heavy: #8A7E6A;
  --border-light: #3D362A;
  --text-title: #D4C8A8;
  --text-body: #B0A48A;
  --text-muted: #7A6E5A;
  --text-faint: #5A5040;
  --img-bg: #2E2820;
  --btn-bg: #D4C8A8;
  --btn-text: #1A1610;
  --btn-hover: #E0D4B4;
  --shadow: rgba(0,0,0,0.4);
}
```

**All** color references in CSS must use `var(--name)`, never hardcoded hex values.

### Dark Mode Toggle

Fixed-position pill button in the top-right corner. On page load, check `window.matchMedia('(prefers-color-scheme: dark)')` to set initial theme. Clicking toggles between light ("🌙 Dark Mode" label) and dark ("☀ Light Mode" label) by switching `data-theme` on `<html>`.

### Page Structure

```
body (background: var(--bg-page))
└── .newspaper (max-width: 960px, centered, background: gradient of paper vars)
    ├── .audio-bar
    │   ├── button.play-btn "▶ Play Briefing"
    │   ├── .audio-track (scrubber)
    │   └── .audio-time
    ├── .masthead
    │   ├── .masthead-date (e.g., "SATURDAY, MARCH 14, 2026")
    │   ├── .masthead-title "DAILY BRIEFING"
    │   ├── .masthead-subtitle "YOUR PERSONAL MORNING PAPER"
    │   └── hr.masthead-rule
    ├── .weather-bar (single line, centered)
    ├── .row.row-top (grid: 2fr 1fr 1fr)
    │   ├── .col (LEAD STORY — big header, image, full summary)
    │   ├── .col (2-3 stacked sources separated by hr.col-divider)
    │   └── .col (2-3 stacked sources separated by hr.col-divider)
    └── .row.row-bottom (grid: 1fr 1fr 1.2fr 1fr)
        ├── .col (space-science with APOD image)
        ├── .col (gaming + maker-hobby stacked)
        ├── .col (AP News headlines)
        └── .col (extra + quote)
```

### Audio Player

The `.audio-bar` contains a real `<audio>` element (hidden) pointing to `file:///tmp/daily-briefing-YYYY-MM-DD.mp3`. The visible `.play-btn` button toggles play/pause via JavaScript. The `.audio-track` shows progress. Style the button as a proper rectangular button with padding, background color, and hover state — not just an icon.

### Column Layout

- Columns separated by `border-right: 1px solid var(--border-light)` — no cards or box borders
- First column has no left padding, last column has no right padding
- Within a column, stacked sections separated by `hr.col-divider` (1px solid var(--border-light))
- Top row and bottom row separated by `border-bottom: 1.5px solid var(--border-heavy)` on the top row

### Typography Classes

- `.header-big` — 22px, bold, uppercase, var(--text-title). Used for lead story.
- `.header-medium` — 15px, bold, uppercase, var(--text-title). Used for section lead items.
- `.header-small` — 12px, bold, var(--text-title). Used for subsections.
- `.section-label` — 8px, uppercase, letter-spacing 2px, var(--text-faint). Source name labels.
- `.body-text` — 10px, line-height 1.55, var(--text-body), justified with hyphens.

### Lead Story

The lead story occupies the full left column (2fr) of the top row:
- `.section-label` with the source name (e.g., "HACKER NEWS")
- `.header-big` with the headline
- `<img>` with the lead story image (if found). Style: `width:100%; max-height:150px; object-fit:cover; border:1px solid var(--border-light)`. Add `onerror="this.style.display='none'"` to hide on load failure.
- `.body-text` paragraphs with the full summary

### Images

- Lead story and space/science sections may have `<img>` tags
- Images use `width:100%; object-fit:cover; border:1px solid var(--border-light)`
- Fallback: `onerror="this.style.display='none'"` — if the image fails to load, it disappears and the section flows as text-only
- If no image URL was found during fetching, simply omit the `<img>` tag entirely

### Links

All article titles/headlines are clickable links (`<a href="..." target="_blank">`). Style: `color: var(--text-title); text-decoration: none; border-bottom: 1px solid var(--border-light)`. On hover: `border-bottom-color: var(--border-heavy)`.

### Responsive Breakpoints

```css
@media (max-width: 900px) {
  .row-top { grid-template-columns: 1fr 1fr; }
  .row-top .col:first-child { grid-column: 1 / 3; }
  .row-bottom { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 600px) {
  .row-top, .row-bottom { grid-template-columns: 1fr; }
  .row-top .col:first-child { grid-column: 1; }
  .col { border-right: none !important; padding: 0 !important; border-bottom: 1px solid var(--border-light); padding-bottom: 10px !important; margin-bottom: 10px; }
}
```

### Section Placement in Grid

**Top row (tech):**
- Column 1 (2fr): Lead story (promoted from whichever tech source was selected)
- Column 2 (1fr): Stack of 2-3 tech sources (e.g., TechCrunch, GitHub Trending, Dev.to)
- Column 3 (1fr): Stack of 2-3 tech sources (e.g., r/ClaudeAI, AI/ML with announcement box for The Batch)

Distribute non-lead tech sources across columns 2 and 3 to balance height. The lead story's original source still appears in its normal column but without the promoted item.

**Bottom row (non-tech + news):**
- Column 1: Space & Science (with APOD image if available)
- Column 2: Gaming (top) + Maker/Hobby (bottom), stacked with divider
- Column 3: AP News headlines
- Column 4: Extra (if present) + optional closing quote in italics
```

---

### Task 6: Update SKILL.md — Important Notes

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md`

- [ ] **Step 1: Replace the Important Notes section**

Find the current "## Important Notes" section (lines 129-135) and replace with:

```markdown
## Important Notes

- All web searches should include the current date for freshness
- If a source search returns no results, skip that section gracefully — do not leave empty columns
- The TTS script and HTML are generated from the SAME fetched data — do not fetch twice
- Container cleanup is handled by tts.sh — do not manage Docker directly
- Minimize round-trips: batch as many tool calls as possible into single messages
- The lead story is always narrated first in TTS, regardless of settings order
- For GitHub repos in TTS, narrate descriptions not repo paths ("a trending project for..." not "user slash repo-name")
- If the `extra` source still has the default placeholder text "(add your own sections here)", skip it entirely — do not search or render
```

- [ ] **Step 2: Verify the complete SKILL.md is consistent**

```bash
grep -c "## Step" plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

Expected: 5 (Step 0, Step 1, Step 2, Step 2.5, Step 3)

- [ ] **Step 3: Commit all SKILL.md changes**

```bash
git add plugins/daily-briefing/skills/daily-briefing/SKILL.md
git commit -m "feat(daily-briefing): v2 redesign — new sources, lead story, broadsheet layout, dark mode"
```

---

### Task 7: Update plugin CLAUDE.md

**Files:**
- Modify: `plugins/daily-briefing/CLAUDE.md`

- [ ] **Step 1: Replace CLAUDE.md content**

Write the updated content to `plugins/daily-briefing/CLAUDE.md`:

```markdown
# daily-briefing Plugin

Generates a personalized daily briefing as a vintage broadsheet newspaper-styled HTML page with TTS audio. Features 12 content sources, dynamic lead story selection, image fetching, and dark/light mode toggle.

## Components

- `skills/daily-briefing/SKILL.md` — main skill definition (invoked via `/daily-briefing` or "good morning")
- `scripts/tts.sh` — TTS generation using Docker (openai-edge-tts)
- `settings.default.md` — versioned default settings template

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

- Default settings ship in `settings.default.md` with `version: N` frontmatter
- User settings live at `~/.config/ccToolBox/daily-briefing/settings.md`
- The skill handles first-run copy and version migration automatically
- **When changing the settings structure, bump the `version` integer in `settings.default.md`**

## Testing Locally

Invoke the skill with `/daily-briefing` or say "good morning" in a Claude Code session where this marketplace is registered.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/daily-briefing/CLAUDE.md
git commit -m "docs(daily-briefing): update CLAUDE.md for v2 features"
```

---

### Task 8: Final verification and push

- [ ] **Step 1: Verify settings version is 2**

```bash
head -3 plugins/daily-briefing/settings.default.md
```

Expected:
```
---
version: 2
---
```

- [ ] **Step 2: Verify SKILL.md has all steps**

```bash
grep "^## Step" plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

Expected:
```
## Step 0: Settings Initialization
## Step 1: Read Settings
## Step 2: Fetch Data (parallel subagents)
## Step 2.5: Lead Story Selection + Lead Image
## Step 3: Generate TTS + HTML + Audio (parallel)
```

- [ ] **Step 3: Verify no old path references**

```bash
grep -n "Development/notes" plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

Expected: no matches.

- [ ] **Step 4: Verify HTML spec references dark mode**

```bash
grep -c "darkreader-lock\|data-theme\|prefers-color-scheme" plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

Expected: at least 3 matches.

- [ ] **Step 5: Push to both remotes**

```bash
git push origin main
git push lab main
```

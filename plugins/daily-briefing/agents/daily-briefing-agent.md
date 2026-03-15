---
name: daily-briefing-agent
description: |
  Orchestrator agent for the daily briefing skill. Dispatched by the thin
  skill trigger. Handles settings, data fetching, lead story selection,
  and parallel TTS/HTML generation.
model: sonnet
---

# Daily Briefing Orchestrator

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

**IMPORTANT: Maximize parallelism. Batch tool calls. Always use system date from Bash (`date +%Y-%m-%d`) — never session date.**

## Step 0: Settings Initialization

**Get current date** (`Bash`): Run `date +%Y-%m-%d` and `date '+%A, %B %d, %Y'`.

**Determine plugin root:** The skill that dispatched this agent passes the plugin root path in the prompt. Use that path to find `settings.default.md` and `scripts/tts.sh`.

**Settings flow:**

1. Read user settings from `~/.ccToolBox/daily-briefing/settings.md`
2. Read default settings from `<plugin-root>/settings.default.md`
3. **If user settings file does not exist (first run):**
   - Run: `mkdir -p ~/.ccToolBox/daily-briefing/output`
   - Copy `<plugin-root>/settings.default.md` to `~/.ccToolBox/daily-briefing/settings.md`
   - Inform user: "Created default settings at `~/.ccToolBox/daily-briefing/settings.md` — edit this file to customize."
   - Use the defaults and continue.
4. **If user settings are malformed** (missing or unparseable frontmatter):
   - Run: `cp ~/.ccToolBox/daily-briefing/settings.md ~/.ccToolBox/daily-briefing/settings.md.bak`
   - Copy fresh defaults to user path
   - Inform user: "Settings were malformed. Backed up to `settings.md.bak` and reset to defaults."
5. **If user settings version < default version:**
   - Run: `cp ~/.ccToolBox/daily-briefing/settings.md ~/.ccToolBox/daily-briefing/settings.md.v<old>.bak`
   - Read both files. Migrate user values (voice, location, sources) into the new structure. Preserve user customizations, fill new fields with defaults.
   - Write migrated settings back to user path.
   - Inform user what changed.
6. **If user settings version > default version:**
   - Warn user: "Your settings version is newer than the plugin default. Proceeding with your settings as-is."
7. **If versions match:** proceed normally.

**Retention cleanup** (`Bash`):
```
mkdir -p ~/.ccToolBox/daily-briefing/output
find ~/.ccToolBox/daily-briefing/output -name "daily-briefing-*" -mtime +<retention_days> -delete
```

**Cleanup today's files** (`Bash`): Remove any existing output files for today's date (enables re-runs):
```
rm -f ~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.txt ~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.mp3 ~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.html
```

## Output Paths (pre-determined)

Output directory: `~/.ccToolBox/daily-briefing/output/`

Compute these once at the start using the system date from Step 0:
- TTS text: `~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.txt`
- Audio: `~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.mp3`
- HTML: `~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.html`

Use the **full expanded path** (not `~`) in the HTML `<audio>` tag.

## Step 1: Read Settings

Using the settings parsed in Step 0 (from `~/.ccToolBox/daily-briefing/settings.md`):
- **General section**: extract `voice` and `location` values
- **Sources section**: extract the ordered list of source keys and their descriptions
- **Retention section**: extract `days` value (default 14)
- **Closing Section**: check `today-in-history` and `inspiration-quote` toggles (both default to `true`)

## Agent Rules

All agents dispatched by this orchestrator MUST follow these rules.
Copy relevant rules into each agent's prompt when dispatching.

- **Model:** Use `model: "haiku"` for fetch agents and lead image agent. Use `model: "sonnet"` for generation subagents (Pipeline A/B).
- **Tools:** Fetch agents may only use **WebSearch and WebFetch** tools. Generation subagents (Pipeline A/B) may use Write and Bash.
- **Research-only:** Fetch agents do NOT write files
- **System date:** Pass the system date from Step 0 to every agent prompt
- **URL quality:** URLs must link to the specific article/post/repo, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`. No URL? Return the item without one.
- **Link rendering:** In HTML, only make a title a clickable link if the URL points to the specific article. If no direct URL, render as plain text.
- **TTS narration:** No URLs read aloud. For GitHub repos, narrate the description not the "user/repo" path. Expand abbreviations ("S and P 500" not "S&P 500", "AI" stays as "AI").
- **Content density:** Write fuller summaries with context and analysis — a newspaper column should feel dense. If a source returned few items, compensate with longer descriptions.
- **No invented sections:** Only use configured sources and closing section settings — do not invent ad-hoc sections.
- **Graceful skips:** If a source search returns no results, skip that section — do not leave empty columns.
- **Data reuse:** TTS and HTML are generated from the SAME fetched data — never fetch twice.

## Step 2: Fetch Data (parallel subagents)

Dispatch all agents in a SINGLE message so they run concurrently. See **Agent Rules** above for model, tools, and URL requirements.

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
- **today-in-history agent** (only if `today-in-history` is `true` in settings): Search "this day in history [month] [day]" AND "on this day [month] [day] famous events" AND "[month] [day] holidays observances". Return: any public holidays or observances for today (e.g., Pi Day, International Women's Day), plus 2-3 notable historical events — each with year and short description. Prioritize science, tech, and culturally significant events.

## Step 2.5: Lead Story Selection + Lead Image

Once all Step 2 agents have returned:

1. **Select the lead story:** Evaluate results across all tech sources (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML). Pick the single most interesting/impactful story based on:
   - Broad significance (affects many developers/users)
   - Novelty (breaking news over ongoing stories)
   - Engagement (high vote count, comment count, stars)

2. **Fetch lead story image:** Dispatch one Agent (`model: "haiku"`) to search for a relevant image for the lead story:
   - **lead-image agent**: Search "[lead story title] image" or "[lead story topic] photo". Return a direct image URL (.jpg/.png/.webp) suitable for embedding in HTML, not a page URL.

   If no image found, render lead story as text-only.

## Step 3: Generate TTS + HTML + Audio (parallel)

Dispatch two Agent subagents in a SINGLE message:

**Pipeline A — TTS audio subagent** (`model: "sonnet"`):
1. **Write TTS text** (`Write` tool): Write speech-optimized plain text to `~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.txt`.
   - Start with a **short, creative greeting** that fits the day — reference the day of the week, a holiday if applicable, the weather, or something topical. Keep it to 1-2 sentences and flow naturally into the lead story. **Avoid generic greetings like "Good morning" or "Hello".** Examples: "Happy Friday — looks like a clear day in Burnaby, perfect for catching up on what's new.", "It's a rainy Wednesday, so grab your coffee — here's what you need to know."
   - **Lead story first**, regardless of settings order: "Our top story today..." then the lead story summary.
   - Then remaining sources in settings order, with natural transitions: "Next, in tech news from Dev.to...", "Moving to space and science...", "In gaming news...", "From the maker community..."
   - For GitHub repos, narrate the description rather than the "user/repo" path (e.g., "A trending repository for building AI agents" not "anthropics slash claude code")
   - NO URLs — never read a URL aloud
   - Expand abbreviations: "S and P 500" not "S&P 500", "AI" can stay as "AI"
   - If closing section is enabled, end with: "And finally, on this day in history..." followed by the historical events and quote. Then: "That's your briefing. Have a great day."
   - If closing section is disabled, end with: "That's your briefing. Have a great day."
2. **Generate audio** (`Bash` tool): Run:
   ```
   <plugin-root>/scripts/tts.sh ~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.txt ~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.mp3 [voice]
   ```

**Pipeline B — HTML subagent** (`model: "sonnet"`):

1. **Write HTML** (`Write` tool): Write the full HTML to `~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.html` (see HTML spec below).

Pass ALL fetched data to both subagents in their prompts.

**After both subagents complete — Open browser** (`Bash`):
```
open ~/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.html
```

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

Fixed-position pill button, top-right. Defaults to light mode. Toggles `data-theme` on `<html>` between light/dark. Do NOT check `prefers-color-scheme`.

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
    ├── .row.row-bottom (grid: 1fr 1fr 1.2fr 1fr)
    │   ├── .col (space-science with APOD image)
    │   ├── .col (gaming + maker-hobby stacked)
    │   ├── .col (AP News headlines)
    │   └── .col (extra)
    └── .closing-section (full-width, centered)
        ├── "ON THIS DAY" — holidays, events, historical items
        └── inspiration quote in italics
```

### Audio Player

The `.audio-bar` contains a real `<audio>` element (hidden) pointing to the full expanded path of the MP3 file (e.g., `file:///Users/username/.ccToolBox/daily-briefing/output/daily-briefing-YYYY-MM-DD.mp3`). The visible `.play-btn` button toggles play/pause via JavaScript. The `.audio-track` shows progress. Style the button as a proper rectangular button with padding, background color, and hover state — not just an icon.

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
- Fallback: `onerror="this.style.display='none'"`
- No image URL found? Omit the `<img>` tag

### Links

All article titles/headlines are clickable links (`<a href="..." target="_blank">`). Style: `color: var(--text-title); text-decoration: none; border-bottom: 1px solid var(--border-light)`. On hover: `border-bottom-color: var(--border-heavy)`. See **Agent Rules** for URL quality and link rendering requirements.

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
- Column 4: Extra (if customized by user). If `extra` is not customized, redistribute the other bottom-row sources to 3 columns (`1fr 1fr 1fr`) instead of 4, giving each section more space.

**Closing section (full-width, below bottom row):**
Rendered as a full-width bar spanning all columns, with a thin top border (`1px solid var(--border-light)`), centered text, and padding above.

- If `today-in-history` is enabled: render a `.section-label` "ON THIS DAY" followed by any holidays/observances for today (e.g., "🥧 Pi Day · International Day of Mathematics"), then 2-3 short historical events (e.g., "1879 — Albert Einstein born · 2005 — First YouTube video uploaded"). Use `·` or `|` as separators. Keep it to two or three lines.
- If `inspiration-quote` is enabled: render a quote in italics below the history line. Claude picks a quote that connects thematically to something in today's briefing (e.g., if the lead story is about open source, pick a quote about sharing knowledge). Format: `"Quote text." — Author`
- Both can appear together: history on top, quote below with a small gap.

See **Agent Rules** for content density requirements.

## Important Notes

- See **Agent Rules** for all agent behavior requirements (model, tools, URLs, content, dates)
- Container cleanup is handled by tts.sh — do not manage Docker directly
- Minimize round-trips: batch as many tool calls as possible into single messages
- The lead story is always narrated first in TTS, regardless of settings order
- If the `extra` source still has the default placeholder text "(add your own sections here)", skip it entirely — do not search or render

---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user says "good morning" or invokes /daily.
  Fetches live data, generates a newspaper-styled HTML page with
  an embedded audio player, and opens it in the browser.
tools: Read, Bash, WebSearch, Write, Agent
---

# Daily Briefing

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

**IMPORTANT: Maximize parallelism throughout. Use subagents for concurrent fetching. Run TTS and HTML generation in parallel. Minimize user permission prompts by batching tool calls.**

## Step 0: Settings Initialization

Before anything else, resolve paths and initialize settings.

**Determine plugin root:** This skill file is located at `skills/daily-briefing/SKILL.md` within the plugin. The plugin root is two directories up from this file. Resolve the absolute path to the plugin root directory.

**Settings flow:**

1. Read user settings from `~/.config/ccToolBox/daily-briefing/settings.md`
2. Read default settings from `<plugin-root>/settings.default.md`
3. **If user settings file does not exist (first run):**
   - Run: `mkdir -p ~/.config/ccToolBox/daily-briefing`
   - Copy `<plugin-root>/settings.default.md` to `~/.config/ccToolBox/daily-briefing/settings.md`
   - Inform user: "Created default settings at `~/.config/ccToolBox/daily-briefing/settings.md` — edit this file to customize."
   - Use the defaults and continue.
4. **If user settings are malformed** (missing or unparseable frontmatter):
   - Run: `cp ~/.config/ccToolBox/daily-briefing/settings.md ~/.config/ccToolBox/daily-briefing/settings.md.bak`
   - Copy fresh defaults to user path
   - Inform user: "Settings were malformed. Backed up to `settings.md.bak` and reset to defaults."
5. **If user settings version < default version:**
   - Run: `cp ~/.config/ccToolBox/daily-briefing/settings.md ~/.config/ccToolBox/daily-briefing/settings.md.v<old>.bak`
   - Read both files. Migrate user values (voice, location, sources) into the new structure. Preserve user customizations, fill new fields with defaults.
   - Write migrated settings back to user path.
   - Inform user what changed.
6. **If user settings version > default version:**
   - Warn user: "Your settings version is newer than the plugin default. Proceeding with your settings as-is."
7. **If versions match:** proceed normally.

After this flow, the parsed settings (voice, location, sources list) are available for all subsequent steps.

## Output Paths (pre-determined)

Compute these once at the start. Use the current date in YYYY-MM-DD format:
- TTS text: `/tmp/daily-briefing-YYYY-MM-DD.txt`
- Audio: `/tmp/daily-briefing-YYYY-MM-DD.mp3`
- HTML: `/tmp/daily-briefing-YYYY-MM-DD.html`

Since these paths are known upfront, the HTML can reference the MP3 path before the audio is generated.

## Step 1: Read Settings

Using the settings parsed in Step 0 (from `~/.config/ccToolBox/daily-briefing/settings.md`):
- **General section**: extract `voice` and `location` values
- **Sources section**: extract the ordered list of source keys and their descriptions
- **Closing Section**: check `today-in-history` and `inspiration-quote` toggles (both default to `true`)

## Step 2: Fetch Data (parallel subagents)

Dispatch all agents in a SINGLE message so they run concurrently. **Use `model: "sonnet"` for every agent** — these are simple search tasks that don't need opus. Each agent should use WebSearch and return structured data: title, 1-line summary, URL for each item.

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

All agents are research-only — they do NOT write files.

## Step 2.5: Lead Story Selection + Lead Image

Once all Step 2 agents have returned:

1. **Select the lead story:** Evaluate results across all tech sources (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML). Pick the single most interesting/impactful story based on:
   - Broad significance (affects many developers/users)
   - Novelty (breaking news over ongoing stories)
   - Engagement (high vote count, comment count, stars)

2. **Fetch lead story image:** Dispatch one Agent (`model: "sonnet"`) to search for a relevant image for the lead story:
   - **lead-image agent**: Search "[lead story title] image" or "[lead story topic] photo". Return a single image URL suitable for embedding in HTML. The image should be a direct URL to a .jpg/.png/.webp file, not a page URL.

   If no suitable image is found, the lead story will render as text-only.

The lead story will be placed in the big left column of the top row. The remaining items from its original source still appear in their normal column position.

## Step 3: Generate TTS + HTML + Audio (parallel)

Once the lead story image agent has returned (or confirmed no image), dispatch two Agent subagents in a SINGLE message so they run concurrently:

**Pipeline A — TTS audio subagent** (`model: "sonnet"`):

Dispatch an Agent with instructions to perform these steps sequentially:
1. **Write TTS text** (`Bash` tool, using `cat > /tmp/daily-briefing-YYYY-MM-DD.txt << 'EOF' ... EOF`): Write speech-optimized plain text.
   - Start with: "Good morning. Here is your daily briefing for [day of week], [month] [day], [year]."
   - **Lead story first**, regardless of settings order: "Our top story today..." then the lead story summary.
   - Then remaining sources in settings order, with natural transitions: "Next, in tech news from Dev.to...", "Moving to space and science...", "In gaming news...", "From the maker community..."
   - For GitHub repos, narrate the description rather than the "user/repo" path (e.g., "A trending repository for building AI agents" not "anthropics slash claude code")
   - NO URLs — never read a URL aloud
   - Expand abbreviations: "S and P 500" not "S&P 500", "AI" can stay as "AI"
   - If closing section is enabled, end with: "And finally, on this day in history..." followed by the historical events and quote. Then: "That's your briefing. Have a great day."
   - If closing section is disabled, end with: "That's your briefing. Have a great day."
2. **Generate audio** (`Bash` tool): Run:
   ```
   <plugin-root>/scripts/tts.sh /tmp/daily-briefing-YYYY-MM-DD.txt /tmp/daily-briefing-YYYY-MM-DD.mp3 [voice]
   ```

**Pipeline B — HTML subagent** (`model: "sonnet"`):

Dispatch an Agent with instructions to:
1. **Write HTML** (`Bash` tool, using `cat > /tmp/daily-briefing-YYYY-MM-DD.html << 'HTMLEOF' ... HTMLEOF`): Write the full HTML (see HTML spec below). The audio tag points to the known MP3 path — the file path is deterministic so it can be referenced before the audio exists.

**Important:** Use `Bash` with heredoc (not the `Write` tool) for all `/tmp/` file writes. The Write tool requires a prior Read if the file already exists, which fails on re-runs within the same day. Bash overwrites unconditionally and avoids sandbox approval prompts.

Pass ALL fetched data (all source results, lead story selection, image URLs, closing section data) to both subagents in their prompts. They need the complete dataset to generate their outputs.

**After both subagents complete — Open browser** (`Bash` tool):
```
open /tmp/daily-briefing-YYYY-MM-DD.html
```

The page opens only after both pipelines finish, so the audio player works immediately without needing a refresh.

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

Fixed-position pill button in the top-right corner. Always starts in light mode (matching `<html data-theme="light">`). Clicking toggles between light ("🌙 Dark Mode" label) and dark ("☀ Light Mode" label) by switching `data-theme` on `<html>`. Do NOT check `prefers-color-scheme` — the page always defaults to light.

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

**Link quality:** Every link MUST point to the specific article or post, never to a homepage, category page, or generic listing (e.g., link to the actual Batch newsletter issue, not `deeplearning.ai/the-batch/`). If a specific article URL is not available from the search results, do not make the title a link — render it as plain text instead.

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

**Filling content:** Every column in both rows must have enough content to avoid blank space. Write fuller summaries, add context or analysis, expand on why a story matters. A newspaper column should feel dense with text — short bullet points with large gaps look wrong. If a source returned fewer items, compensate with longer descriptions for each item.

## Important Notes

- All web searches should include the current date for freshness
- If a source search returns no results, skip that section gracefully — do not leave empty columns
- The TTS script and HTML are generated from the SAME fetched data — do not fetch twice
- Container cleanup is handled by tts.sh — do not manage Docker directly
- Minimize round-trips: batch as many tool calls as possible into single messages
- The lead story is always narrated first in TTS, regardless of settings order
- For GitHub repos in TTS, narrate descriptions not repo paths ("a trending project for..." not "user slash repo-name")
- If the `extra` source still has the default placeholder text "(add your own sections here)", skip it entirely — do not search or render
- Do not invent ad-hoc sections — use the configured sources and closing section settings
- Bottom row columns must be visually balanced — write enough content to fill each column. If a source has few items, write longer summaries with context and analysis rather than leaving white space

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

## Step 2: Fetch Data (parallel subagents)

Dispatch one Agent per source, all in a SINGLE message so they run concurrently. Each agent should use WebSearch and return structured data: title, 1-line summary, URL for each item.

Launch these agents simultaneously:
- **weather agent**: Search "[location] weather today [current date]". Return 1-2 sentence summary.
- **tech-hn agent**: Search "Hacker News top stories today [current date]". Return 2-5 items (title, summary, URL).
- **tech-devto agent**: Search "Dev.to top posts today [current date] AI programming". Return 2-5 items (title, summary, URL).
- **reddit-claudeai agent**: Search "reddit r/ClaudeAI hot posts [current date]". Return 2-5 items (title, summary, URL).
- **news-ap agent**: Search "AP News top headlines today [current date]". Return 2-5 short headlines with URLs.

All agents are research-only — they do NOT write files.

## Step 3: Generate TTS + HTML + Audio (parallel)

Once all agent results are collected, do the following in a SINGLE message with parallel tool calls:

**Tool call 1 — Write TTS text** (`Write` tool): Write speech-optimized plain text to `/tmp/daily-briefing-YYYY-MM-DD.txt`
- Start with: "Good morning. Here is your daily briefing for [day of week], [month] [day], [year]."
- For each section, read the heading then the content naturally
- NO URLs — never read a URL aloud
- Expand abbreviations: "S and P 500" not "S&P 500", "AI" can stay as "AI"
- Use natural speech patterns: "Next, in tech news from Hacker News..."
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

## HTML Spec

Single self-contained HTML file with inline CSS.

**Audio player**: Fixed/sticky at the top. Uses `<audio>` tag pointing to `file:///tmp/daily-briefing-YYYY-MM-DD.mp3`. Show play/pause and scrub controls.

**Masthead**: Newspaper-style header with the full date. Title: "Daily Briefing".

**Sections**: Render each source as its own section in settings order:
- Section heading styled as a newspaper section header
- Weather: short paragraph
- Tech sources (HN, Dev.to, Reddit): each item is a clickable link (opens in new tab) with a 1-line summary below
- News (AP): short headline as a clickable link
- Extra: simple text

**Styling** — warm newspaper aesthetic:
- Font: Georgia or serif stack
- Background: warm cream (`#FDF6E3` or similar)
- Text: dark brown/charcoal (`#3E2723` or similar)
- Section dividers: subtle horizontal rules or decorative borders
- Links: muted blue or brown, underlined on hover
- Audio player bar: warm toned, matching the theme
- Dark mode: use `@media (prefers-color-scheme: dark)` — dark warm background (`#1A1410` or similar), light cream text
- Responsive: readable on any screen width
- Max content width: ~700px, centered

## Important Notes

- All web searches should include the current date for freshness
- If a source search returns no results, skip that section gracefully
- The TTS script and HTML are generated from the SAME fetched data — do not fetch twice
- Container cleanup is handled by tts.sh — do not manage Docker directly
- Minimize round-trips: batch as many tool calls as possible into single messages

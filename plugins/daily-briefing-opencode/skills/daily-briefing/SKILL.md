---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user asks for their daily briefing, e.g. "get my daily briefing",
  "give me my daily", "show me what's happening today", "what's the news today",
  or invokes /daily-briefing.
  Do NOT trigger on casual greetings like "good morning" or "hello".
---

# Daily Briefing (OpenCode)

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

The opencode-skills plugin injects the skill's base directory as "Base directory for this skill: <DIR>" at the top of your context. Substitute `<DIR>` in every script invocation below.

**Maximize parallelism. Batch `task` calls.**

## Fetch rules (used in Step 3)

- URLs must link to specific articles/posts/repos, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, bare subreddit roots.
- No URL available? Omit the `url` field.
- Write dense summaries with context and analysis.
- Use only sources and closing toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, the section disappears entirely (no empty columns).
- Pass the system date (from Step 1) to every fetch prompt — never the session date.
- Fetch subagents should only use `webfetch` / web-search tools; they do NOT write files.
- Be terse in status output. Only speak up on failures; suggest a retry or a fix.

## TTS narration rules (used in Step 6)

- Start with a short, creative greeting tied to the day/weather/holidays. Avoid "Good morning" / "Hello".
- Lead story is narrated FIRST, regardless of settings order: "Our top story today..."
- Then remaining sources in settings order with natural transitions ("Next, in tech news from Dev.to...", "Moving to space and science...").
- GitHub repos: narrate the description, not the "user/repo" path.
- Expand abbreviations (`S&P 500` → "S and P 500"). Keep `AI` as "AI".
- Never read URLs aloud.
- Closing: if `today_in_history` is enabled, narrate it; then `inspiration_quote` if enabled. End: "That's your briefing. Have a great day."

## Step 1 — Initialize settings and get the system date

Run:

```bash
python3 <DIR>/scripts/init_settings.py
date +%Y-%m-%d
date '+%A, %B %d, %Y'
```

From the JSON on `init_settings.py`'s stdout, extract: `voice`, `location`, `sources[]`, `today_in_history`, `inspiration_quote`.
Record `DATE_ISO` and `DATE_HUMAN` from the two `date` outputs.

## Step 2 — Compute output paths and clear today's files

- `OUT_DIR  = ~/.ccToolBox/daily-briefing/output`
- `OUT_TXT  = $OUT_DIR/daily-briefing-$DATE_ISO.txt`
- `OUT_MP3  = $OUT_DIR/daily-briefing-$DATE_ISO.mp3`
- `OUT_JSON = $OUT_DIR/daily-briefing-$DATE_ISO.json`
- `OUT_HTML = $OUT_DIR/daily-briefing-$DATE_ISO.html`

```bash
rm -f "$OUT_TXT" "$OUT_MP3" "$OUT_JSON" "$OUT_HTML"
```

Record the absolute MP3 path (with `$HOME` expanded).

## Step 3 — Fetch sources in parallel

Dispatch ONE message containing multiple `task` calls — one per source, plus one for `today_in_history` if enabled. In OpenCode, each `task` inherits the primary model and tool access; see the README for an optional `opencode.json` snippet that creates a dedicated haiku+WebSearch subagent for cost optimization.

Each fetch task prompt:

```
You are the {SOURCE_KEY} fetch agent. Today's date: {DATE_ISO}.

Search: {QUERY}

Return ONLY a JSON array of items: [{"title": "...", "url": "...", "summary": "..."}]
- url must point to a specific article/post/repo. Never homepages.
- If no URL available, omit the url field.
- Include 1-2 sentence summary giving context and analysis.
- No commentary outside the JSON array.
```

### Per-source queries (preserved from v1.5.1)

| Source key       | Query hint                                                                      |
|------------------|---------------------------------------------------------------------------------|
| weather          | `{location} weather today {DATE_ISO}` — return 1-2 sentence summary (temp/conditions/high-low/wind) |
| tech-hn          | `Hacker News top stories today {DATE_ISO}` — 2-5 items                          |
| tech-devto       | `Dev.to top posts today {DATE_ISO} AI programming` — 2-5 items                  |
| tech-github      | `GitHub trending repositories today {DATE_ISO}` — 3-5 items (repo, stars, lang) |
| tech-tc          | `TechCrunch top stories today {DATE_ISO}` — 2-3 items                           |
| reddit-claudeai  | `reddit r/ClaudeAI hot posts {DATE_ISO}` — 2-5 items                            |
| ai-ml            | `arXiv AI machine learning papers today {DATE_ISO}` AND `Andrew Ng The Batch newsletter {DATE_ISO}` — 2-3 items |
| space-science    | `NASA astronomy picture of the day {DATE_ISO}` AND `space science news today {DATE_ISO}` — 1-2 items. **Also return the NASA APOD image URL if found (field: `apod_image_url`).** |
| gaming           | `reddit r/gaming hot posts {DATE_ISO}` AND `video game news today {DATE_ISO}` — 2-3 items |
| maker-hobby      | `Instructables featured projects {DATE_ISO}` AND `reddit r/3Dprinting hot posts {DATE_ISO}` — 1-2 items |
| news-ap          | `AP News top headlines today {DATE_ISO}` — 2-5 short headlines                  |
| extra            | (only if user customized the description — skip if it still says `(add your own sections here)`). Search based on the user's description text. 1-3 items. |

If `today_in_history` is enabled, also dispatch:

| Task key          | Query                                                                           |
|-------------------|---------------------------------------------------------------------------------|
| today_in_history  | `this day in history {month} {day}` AND `[month] [day] famous events` AND `[month] [day] holidays observances` — return `{holidays, events}` object |

## Step 4 — Select the lead story and fetch its image

Pick the single most impactful tech item (broad significance + novelty + engagement). Dispatch one more `task`:

```
Find one direct image URL (.jpg/.png/.webp) relevant to: "{LEAD_TITLE}".
Return the URL as plain text, or the literal string NONE if nothing suitable.
```

Record `LEAD_IMAGE_URL` (or `null`).

## Step 5 — Build the data JSON and write it to disk

Assemble the JSON matching `scripts/render_html.py`'s input contract:

```json
{
  "date_iso": "...",
  "date_human": "...",
  "audio_path_absolute": "/absolute/path/to/daily-briefing-YYYY-MM-DD.mp3",
  "weather": "...",
  "lead": { "source_label": "...", "title": "...", "url": "...", "image_url": "...", "summary_paragraphs": ["...", "..."] },
  "top_row_sources": [
    { "key": "tech-hn", "label": "HACKER NEWS", "items": [{"title","url","summary"}] }
  ],
  "bottom_row_sources": {
    "space_science": { "items": [...], "apod_image_url": "..." },
    "gaming":        { "items": [...] },
    "maker_hobby":   { "items": [...] },
    "news_ap":       { "items": [...] },
    "extra":         { "items": [...] }
  },
  "closing": {
    "today_in_history": { "holidays": "...", "events": "..." },
    "quote":            { "text": "...", "author": "..." }
  }
}
```

Rules:
- `lead` holds the story from Step 4; the lead's original source entry in `top_row_sources` omits the promoted item.
- `top_row_sources` contains non-weather tech sources.
- Omit empty-items keys from `bottom_row_sources`. Omit `extra` if not customized.
- If both closing subkeys are disabled, omit `closing`.
- Pick the quote thematically.

Write to `$OUT_JSON` using the write tool.

## Step 6 — Generate TTS + audio + HTML in parallel

Dispatch TWO `task` calls in ONE message:

### Task A — TTS + audio

Prompt:

```
Write the briefing narration to $OUT_TXT, following the TTS narration rules at the top of SKILL.md.
Then run: bash <DIR>/scripts/tts.sh "$OUT_TXT" "$OUT_MP3" "{voice}"

IMPORTANT: Run tts.sh as a foreground Bash command. NEVER run it in the background.
```

### Task B — HTML rendering

Prompt:

```
Run: python3 <DIR>/scripts/render_html.py "$OUT_JSON" "$OUT_HTML"

Do NOT edit HTML. Do NOT open the file. Just run the script and report success or the script's stderr.
```

## Step 7 — Verify audio and open the page

```bash
test -s "$OUT_MP3" && echo "Audio ready" || echo "Audio missing"
```

If ready: `open "$OUT_HTML"` (on macOS; Linux users should substitute `xdg-open`).

If missing, report the TTS failure and suggest re-running.

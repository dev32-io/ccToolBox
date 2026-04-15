---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user asks for their daily briefing, e.g. "get my daily briefing",
  "give me my daily", "show me what's happening today", "what's the news today",
  or invokes /daily-briefing.
  Do NOT trigger on casual greetings like "good morning" or "hello".
tools: Agent, Bash, Write
---

# Daily Briefing

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

**Maximize parallelism. Batch tool calls. Always use system date from Bash.**

## Fetch rules (used in Step 3)

- URLs must link to specific articles/posts/repos, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, bare subreddit roots.
- No URL available? Omit the `url` field.
- Write dense summaries with context and analysis.
- Use only sources and closing toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, the section disappears entirely (no empty columns).
- Pass the system date (from Step 1) to every fetch prompt — never the session date.
- Fetch agents use only `WebSearch` and `WebFetch`; they do NOT write files.
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

Run the bootstrap script. Its stdout is JSON; capture and parse it.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/init_settings.py"
date +%Y-%m-%d
date '+%A, %B %d, %Y'
```

From the JSON, extract: `voice`, `location`, `sources[]`, `today_in_history`, `inspiration_quote`.
From the `date` outputs, record: `DATE_ISO` (e.g., `2026-04-15`) and `DATE_HUMAN` (e.g., `Wednesday, April 15, 2026`).

## Step 2 — Compute output paths and clear today's files

Compute once using `DATE_ISO`:

- `OUT_DIR  = ~/.ccToolBox/daily-briefing/output`
- `OUT_TXT  = $OUT_DIR/daily-briefing-$DATE_ISO.txt`
- `OUT_MP3  = $OUT_DIR/daily-briefing-$DATE_ISO.mp3`
- `OUT_JSON = $OUT_DIR/daily-briefing-$DATE_ISO.json`
- `OUT_HTML = $OUT_DIR/daily-briefing-$DATE_ISO.html`

Remove any existing files at these paths (enables re-runs):

```bash
rm -f "$OUT_TXT" "$OUT_MP3" "$OUT_JSON" "$OUT_HTML"
```

Record the absolute MP3 path (with `$HOME` expanded) — it is needed for the HTML audio `<audio src>`.

## Step 3 — Fetch sources in parallel

Dispatch ONE message containing ALL fetch agents (and the today-in-history agent if enabled).

Each fetch agent uses:
- `model: haiku`
- `tools: [WebSearch, WebFetch]`
- `description`: short (e.g., "Fetch HN stories")
- `prompt`: copy the template below, substituting `{DATE_ISO}`, `{SOURCE_KEY}`, and `{QUERY}`.

### Fetch agent prompt template

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

| Agent key         | Query                                                                           |
|-------------------|---------------------------------------------------------------------------------|
| today_in_history  | `this day in history {month} {day}` AND `[month] [day] famous events` AND `[month] [day] holidays observances` — return `{holidays, events}` object |

Collect each agent's returned JSON.

## Step 4 — Select the lead story and fetch its image

From the collected tech results (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML), pick the single most impactful item:
- Broad significance (affects many developers/users)
- Novelty (breaking news over ongoing stories)
- Engagement (high vote/comment/star count)

Dispatch one more Agent (`model: haiku`, `tools: [WebSearch, WebFetch]`) with a short prompt:

```
Find one direct image URL (.jpg/.png/.webp) relevant to: "{LEAD_TITLE}".
Return the URL as plain text, or the literal string NONE if nothing suitable.
```

Record `LEAD_IMAGE_URL` (or `null` if NONE).

## Step 5 — Build the data JSON and write it to disk

Assemble a JSON object with this exact shape (see `scripts/render_html.py` for the contract):

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
- `lead` holds the story selected in Step 4. The lead's original source still appears in `top_row_sources`, but WITHOUT the promoted item (avoid duplication).
- `top_row_sources` contains the non-weather tech sources (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML), each minus the promoted lead item if it came from that source.
- `bottom_row_sources` contains the non-tech sources. Omit any key whose items list is empty.
- If `extra` was not customized by the user, omit the `extra` key entirely.
- If `today_in_history` or `inspiration_quote` is disabled in settings, omit those subkeys. If both are disabled, you may omit `closing` entirely.
- For the `quote`, pick one thematically connected to something in today's briefing.

Write the JSON to `$OUT_JSON` using the Write tool.

## Step 6 — Generate TTS + audio + HTML in parallel

Dispatch TWO agents in a SINGLE message:

### Agent A — TTS + audio (`model: sonnet`)

Prompt summary (fill in with actual data):

```
Write the briefing narration to $OUT_TXT, following the TTS narration rules at the top of SKILL.md.
Then run: bash "${CLAUDE_SKILL_DIR}/scripts/tts.sh" "$OUT_TXT" "$OUT_MP3" "{voice}"

IMPORTANT: Run tts.sh as a foreground Bash command. NEVER use run_in_background.
```

Pass the fully-built data from Step 5 (the JSON already on disk at `$OUT_JSON`) in the prompt so the agent can compose narration without re-fetching.

### Agent B — HTML rendering (`model: haiku` — script-only)

Prompt:

```
Run:
bash -c 'python3 "${CLAUDE_SKILL_DIR}/scripts/render_html.py" "$OUT_JSON" "$OUT_HTML"'

Do NOT edit HTML. Do NOT open the file. Just run the script and report success or the script's stderr.
```

## Step 7 — Verify audio and open the page

After both Step 6 agents return:

```bash
test -s "$OUT_MP3" && echo "Audio ready" || echo "Audio missing"
```

If audio is ready:

```bash
open "$OUT_HTML"
```

If audio is missing, report the TTS failure to the user and suggest re-running the skill. Do not open the HTML.

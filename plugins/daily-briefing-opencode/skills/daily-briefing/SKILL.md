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

The opencode-skills plugin injects the skill's base directory as "Base directory for this skill: <DIR>" at the top of your context. Substitute `<DIR>` in every script invocation below with that absolute path — do not leave the literal `<DIR>` in any command.

**Maximize parallelism. Batch `task` calls.**

## Fetch rules (used in Step 2)

- URLs must link to specific articles/posts/repos, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, bare subreddit roots.
- No URL available? Omit the `url` field from that item.
- Write dense summaries with context and analysis.
- Use only sources and closing toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, the section disappears entirely (no empty columns).
- Be terse in status output. Only speak up on failures; suggest a retry or a fix.

## TTS narration rules (used in Step 5)

- Start with a short, creative greeting tied to the day/weather/holidays. Avoid "Good morning" / "Hello".
- Lead story is narrated FIRST, regardless of settings order: "Our top story today..."
- Then remaining sources in settings order with natural transitions ("Next, in tech news from Dev.to...", "Moving to space and science...").
- GitHub repos: narrate the description, not the "user/repo" path.
- Expand abbreviations (`S&P 500` → "S and P 500"). Keep `AI` as "AI".
- Never read URLs aloud.
- Closing: if `today_in_history` is enabled, narrate it; then `inspiration_quote` if enabled. End: "That's your briefing. Have a great day."

## Step 1 — Initialize

Run the bootstrap script. Parse its stdout — it is a single JSON object with three top-level keys: `settings`, `paths`, `date`.

```bash
python3 <DIR>/scripts/init_settings.py
```

From the output, record these exact literal values (copy the strings verbatim — do NOT use shell variables):

- `VOICE`, `LOCATION`, `SOURCES`, `TODAY_IN_HISTORY`, `INSPIRATION_QUOTE` from `settings`
- `STAGING_DIR`, `OUT_TXT`, `OUT_MP3`, `OUT_JSON`, `OUT_HTML` from `paths` (all absolute)
- `DATE_ISO`, `DATE_HUMAN` from `date`

Clear any existing output files at those paths:

```bash
rm -f "<OUT_TXT literal>" "<OUT_MP3 literal>" "<OUT_JSON literal>" "<OUT_HTML literal>"
```

## Step 2 — Fetch sources in parallel

Dispatch ONE message containing multiple `task` calls — one per configured source, plus today-in-history if enabled. Each task writes its result directly to a file in STAGING_DIR.

In OpenCode, `task` subagents inherit the primary model and tools. See the README for an optional `opencode.json` snippet that creates a dedicated haiku+WebFetch subagent for cost optimization.

### Generic fetch task prompt

```
You are the {SOURCE_KEY} fetch agent.

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch, Write (or your platform's equivalents: webfetch, write).
FORBIDDEN — do NOT call any of these: skills (any skill, including dispatching-parallel-agents), MCP resources or tools, Bash, Read, Glob, Grep, other Agents/Tasks, sub-agent dispatch. Do NOT explore the toolbox looking for something that fits.
ON FAILURE — if search fails or returns nothing useful, write an empty JSON array `[]` to the target file with the write tool, then stop. Do not retry. Do not switch tools.

Today's date: {DATE_ISO}.
Search: {QUERY}

Write your result to: {STAGING_DIR}/{SOURCE_KEY}.json

The file MUST be a JSON array of items: [{"title": "...", "url": "...", "summary": "..."}]
- url must point to a specific article/post/repo. Never homepages.
- If no URL available, omit the url field.
- Include a 1-2 sentence summary with context and analysis.
- No commentary outside the JSON array.

Use the write tool to create the file. Return "done" after writing.
```

### Weather task

```
You are the weather agent.

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch, Write (or your platform's equivalents).
FORBIDDEN — do NOT call skills, MCP resources or tools, Bash, Read, Glob, Grep, other Agents/Tasks. Do NOT explore the toolbox.
ON FAILURE — if search fails, write an empty file and stop. Do not retry. Do not switch tools.

Today's date: {DATE_ISO}.
Search: {LOCATION} weather today {DATE_ISO}

Write a 1-2 sentence summary (temperature, conditions, high/low, wind) to:
{STAGING_DIR}/weather.txt

Plain text only. Use the write tool.
```

### Space-science extra instruction

Add to the space-science prompt: `For the NASA APOD item, include an "image_url" field with the direct image URL.`

### Per-source queries (preserved from v1.5.1)

| Source key       | Query hint                                                                                                                        |
|------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| weather          | `{LOCATION} weather today {DATE_ISO}` — 1-2 sentence to `weather.txt`                                                            |
| tech-hn          | `Hacker News top stories today {DATE_ISO}` — 2-5 items                                                                            |
| tech-devto       | `Dev.to top posts today {DATE_ISO} AI programming` — 2-5 items                                                                    |
| tech-github      | `GitHub trending repositories today {DATE_ISO}` — 3-5 items (repo, stars, language in summary)                                    |
| tech-tc          | `TechCrunch top stories today {DATE_ISO}` — 2-3 items                                                                              |
| reddit-claudeai  | `reddit r/ClaudeAI hot posts {DATE_ISO}` — 2-5 items                                                                               |
| ai-ml            | `arXiv AI machine learning papers today {DATE_ISO}` AND `Andrew Ng The Batch newsletter {DATE_ISO}` — 2-3 items                    |
| space-science    | `NASA astronomy picture of the day {DATE_ISO}` AND `space science news today {DATE_ISO}` — 1-2 items. **Include `image_url` on the APOD item.** |
| gaming           | `reddit r/gaming hot posts {DATE_ISO}` AND `video game news today {DATE_ISO}` — 2-3 items                                          |
| maker-hobby      | `Instructables featured projects {DATE_ISO}` AND `reddit r/3Dprinting hot posts {DATE_ISO}` — 1-2 items                            |
| news-ap          | `AP News top headlines today {DATE_ISO}` — 2-5 short headlines                                                                     |
| extra            | (only if user customized the description — skip if it still says `(add your own sections here)`). Search based on the description. 1-3 items. |

If `TODAY_IN_HISTORY` is true, also dispatch a today-in-history task:

```
You are the today-in-history agent.

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch, Write (or your platform's equivalents).
FORBIDDEN — do NOT call skills, MCP resources or tools, Bash, Read, Glob, Grep, other Agents/Tasks. Do NOT explore the toolbox.
ON FAILURE — if search fails, write `{"holidays": "", "events": ""}` to the file and stop. Do not retry. Do not switch tools.

Today's date: {DATE_ISO}.
Search: this day in history {month} {day} famous events AND {month} {day} holidays observances

Write JSON to: {STAGING_DIR}/today_in_history.json
Shape: {"holidays": "...", "events": "..."}
- holidays: any holidays/observances for today. Empty string if none.
- events: 2-3 notable historical events, each with year. Use · or | as separators.
Prioritize science, tech, culturally significant events. Use the write tool.
```

Inspiration quote is authored by the main skill (not a task) — see Step 3.

## Step 3 — Select lead, fetch lead image, write lead + quote files

1. Read the top tech source files to pick the most impactful item (significance, novelty, engagement).

2. Dispatch one `task` to find a lead image URL:

```
Find one direct image URL (.jpg/.png/.webp) relevant to: "{LEAD_TITLE}".

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch (or your platform's equivalents).
FORBIDDEN — do NOT call Write, Bash, Read, skills, MCP resources, Agents/Tasks, or anything else.

Return ONLY the URL as plain text, or the literal string NONE if nothing suitable.
```

3. Write `{STAGING_DIR}/lead.json` using the write tool:

```json
{
  "source_key": "tech-hn",
  "title": "<exact title of the chosen item>",
  "url": "<exact url>",
  "image_url": "<URL from step 2, or null>",
  "summary_paragraphs": [
    "<paragraph 1 — richer than the single-sentence fetch summary>",
    "<paragraph 2 — add context, stakes, implications>"
  ]
}
```

The `title` must match the title in that source's staging file exactly (so `build_data_json.py` can strip it).

4. If `INSPIRATION_QUOTE` is true, write `{STAGING_DIR}/quote.json`:

```json
{ "text": "<quote text>", "author": "<author>" }
```

Pick a quote thematically connected to today's briefing.

## Step 4 — Build the briefing data JSON

```bash
python3 <DIR>/scripts/build_data_json.py <DATE_ISO literal>
```

On success: stdout is the path of the written file. On failure: stderr has a one-line error; report and stop.

## Step 5 — Generate TTS audio + HTML in parallel

Dispatch TWO `task` calls in ONE message:

### Task A — TTS narration + audio

```
You are the TTS agent.

1. Read the briefing data from: <OUT_JSON literal>
2. Write speech-optimized narration to: <OUT_TXT literal>
   Follow the TTS narration rules at the top of the parent skill.
3. Run (foreground, NEVER in background):
   bash <DIR>/scripts/tts.sh "<OUT_TXT literal>" "<OUT_MP3 literal>" "<VOICE literal>"
4. Report "done" or the script's stderr.
```

### Task B — HTML render

```
Run this single command and report stdout/stderr:
python3 <DIR>/scripts/render_html.py "<OUT_JSON literal>" "<OUT_HTML literal>"
```

## Step 6 — Verify and open

```bash
test -s "<OUT_MP3 literal>" && echo "Audio ready" || echo "Audio missing"
```

If ready: `open "<OUT_HTML literal>"` (macOS) or `xdg-open "<OUT_HTML literal>"` (Linux).

If missing, report the TTS failure and suggest re-running.

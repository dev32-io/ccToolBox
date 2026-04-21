---
name: daily-briefing
description: >
  Generate a daily news/tech/weather briefing with TTS audio.
  Use when the user asks for their daily briefing, e.g. "get my daily briefing",
  "give me my daily", "show me what's happening today", "what's the news today",
  or invokes /daily-briefing.
  Do NOT trigger on casual greetings like "good morning" or "hello".
tools: Agent, AskUserQuestion, Bash, Write
---

# Daily Briefing

Generate a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

**Maximize parallelism. Batch tool calls.**

## Fetch rules (used in Step 2)

- URLs must link to specific articles/posts/repos, never homepages. Bad: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, bare subreddit roots.
- No URL available? Omit the `url` field from that item.
- Write dense summaries with context and analysis.
- Use only sources and closing toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, the section disappears entirely (no empty columns).
- Fetch agents use only `WebSearch`, `WebFetch`, and `Write`; they do NOT write files other than their assigned staging file.
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
python3 "${CLAUDE_SKILL_DIR}/scripts/init_settings.py"
```

From the output, record these exact literal values (copy the strings verbatim from the script's stdout — do NOT use shell-style placeholders, do NOT substitute `$HOME` yourself):

- `VOICE`              = `settings.voice`
- `LOCATION`           = `settings.location`
- `SOURCES`            = `settings.sources` (array)
- `TODAY_IN_HISTORY`   = `settings.today_in_history` (boolean)
- `INSPIRATION_QUOTE`  = `settings.inspiration_quote` (boolean)
- `STAGING_DIR`        = `paths.staging_dir` (absolute path, already created)
- `OUT_TXT`            = `paths.out_txt` (absolute path)
- `OUT_MP3`            = `paths.out_mp3` (absolute path)
- `OUT_JSON`           = `paths.out_json` (absolute path)
- `OUT_HTML`           = `paths.out_html` (absolute path)
- `DATE_ISO`           = `date.iso` (e.g., `2026-04-15`)
- `DATE_HUMAN`         = `date.human` (e.g., `Wednesday, April 15, 2026`)

Clear any existing files at the output paths (enables re-runs). Use the literal paths you just captured, not variables:

```bash
rm -f "<OUT_TXT literal path>" "<OUT_MP3 literal path>" "<OUT_JSON literal path>" "<OUT_HTML literal path>"
```

## Step 2 — Fetch sources in parallel

Dispatch ONE message containing ALL fetch agents (and the today-in-history + quote agents if enabled). Each agent writes its result directly to a known file inside `STAGING_DIR`, so the main skill never holds per-source data in its context.

Each fetch agent uses:
- `model: haiku`
- `tools: [WebSearch, WebFetch, Write]`
- `description`: short (e.g., "Fetch HN stories")
- `prompt`: the template below, substituting `{SOURCE_KEY}`, `{QUERY}`, `{DATE_ISO}`, and `{STAGING_DIR}` with their literal values.

### Generic fetch agent prompt template

```
You are the {SOURCE_KEY} fetch agent.

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch, Write.
FORBIDDEN — do NOT call any of these: skills, MCP resources or tools, Bash, Read, Glob, Grep, other Agents/Tasks, sub-agent dispatch.
Write whatever items you can find. Only write `[]` if you truly found nothing after 2 search attempts with different queries.

Today's date: {DATE_ISO}.
Topic: {SOURCE_DESCRIPTION}

Start with WebSearch. Form 1-2 good search queries from the topic above. Include related community names, subreddits, and synonyms to broaden coverage (e.g. "3D printing" → "3D printing news, r/3Dprinting, 3D printing community"). Add the current date or month to bias toward recent results. Optionally use WebFetch on promising URLs from the search results to get richer context — but if WebFetch fails on a domain, just use the WebSearch summary instead.

Write your result to: {STAGING_DIR}/{SOURCE_KEY}.json

The file MUST be a JSON array of items: [{"title": "...", "url": "...", "summary": "..."}]
- Limit to 3-5 items — pick the most impactful/interesting ones using your best judgment. Quality over quantity.
- url must point to a specific article/post/repo. Never homepages.
- If no URL available, omit the url field.
- Include a 1-2 sentence summary with context and analysis.
- No commentary outside the JSON array.

Use the Write tool to create the file. Return "done" after writing.
```

### Weather agent prompt

Weather is a special case — it's plain text, not an item array:

```
You are the weather agent.

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch, Write.
FORBIDDEN — do NOT call any of these: skills, MCP resources or tools, Bash, Read, Glob, Grep, other Agents/Tasks, sub-agent dispatch.
Write whatever you can find. If nothing, write an empty file and stop.

Today's date: {DATE_ISO}.
Search: {LOCATION} weather today {DATE_ISO}

Write a 1-2 sentence summary (temperature, conditions, high/low, wind) to:
{STAGING_DIR}/weather.txt

Plain text only. No JSON, no Markdown. Use the Write tool.
```

### Per-source notes

- **weather**: use the weather agent prompt (above), not the generic template.
- **space-science**: add this line to the generic prompt: "For any item with an associated image (e.g. NASA APOD), include an `image_url` field with the direct image URL."
- **extra**: skip if the description still says `(add your own sections here)`.

The agent forms its own search queries from each source's `description` field — no hardcoded queries.

If `TODAY_IN_HISTORY` is true, ALSO dispatch:

```
You are the today-in-history agent.

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch, Write.
FORBIDDEN — do NOT call any of these: skills, MCP resources or tools, Bash, Read, Glob, Grep, other Agents/Tasks, sub-agent dispatch.
Write whatever you can find. If nothing, write `{"holidays": "", "events": ""}` and stop.

Today's date: {DATE_ISO}.
Search: this day in history {month} {day} famous events AND {month} {day} holidays observances

Write JSON to: {STAGING_DIR}/today_in_history.json
Shape: {"holidays": "...", "events": "..."}
- holidays: any holidays/observances for today (e.g., "Pi Day · International Day of Mathematics"). Empty string if none.
- events: 2-3 notable historical events, each with year (e.g., "1879 — Einstein born · 2005 — First YouTube video"). Use · or | as separators.
Prioritize science, tech, and culturally significant events. Use the Write tool.
```

If `INSPIRATION_QUOTE` is true, after all fetches complete you (the main skill) will author a quote thematically connected to today's content. Do not dispatch a quote agent — you will write `quote.json` yourself in Step 3.

## Step 3 — Select lead, fetch lead image, write lead+quote files

After all fetch agents return:

1. **Read the fetched source files** you care about (HN, Dev.to, GitHub, TechCrunch, r/ClaudeAI, AI/ML) to pick the single most impactful item. Criteria:
   - Broad significance (affects many developers/users)
   - Novelty (breaking news over ongoing stories)
   - Engagement (high vote/comment/star counts in the summary)

2. **Dispatch one more Agent** (`model: haiku`, `tools: [WebSearch, WebFetch]`) to find a lead image URL. This agent returns a plain-text URL — NOT a file write:

```
Find one direct image URL (.jpg/.png/.webp) relevant to: "{LEAD_TITLE}".

ALLOWED TOOLS — the ONLY tools you may call: WebSearch, WebFetch.
FORBIDDEN — do NOT call Write, Bash, Read, skills, MCP resources, Agents/Tasks, or anything else.

Use WebSearch to find candidates, then WebFetch to verify the image URL if needed.
Return ONLY the URL as plain text, or the literal string NONE if nothing suitable.
```

3. **Write `lead.json` to STAGING_DIR** using the Write tool. Shape:

```json
{
  "source_key": "tech-hn",
  "title": "<exact title of the chosen item>",
  "url": "<exact url>",
  "image_url": "<the URL from step 2, or null>",
  "summary_paragraphs": [
    "<paragraph 1 — richer than the single-sentence fetch summary>",
    "<paragraph 2 — add context, stakes, implications>"
  ]
}
```

The `source_key` must match one of the source keys in SOURCES. The `title` must match a title in that source's staging file exactly (so `build_data_json.py` can strip it).

4. **If `INSPIRATION_QUOTE` is true**, write `quote.json` to STAGING_DIR:

```json
{ "text": "<quote text>", "author": "<attributed author>" }
```

Pick a quote thematically connected to something in today's briefing (e.g., lead topic).

## Step 4 — Build the briefing data JSON

Run the assembler. Use the literal `DATE_ISO` value:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/build_data_json.py" <DATE_ISO literal>
```

The script writes `OUT_JSON`. On success, stdout is the path of the written file. On failure, stderr has a single-line error. If it fails, report the error to the user and stop — do not proceed to Step 5.

## Step 5 — Generate TTS audio + HTML in parallel

Dispatch TWO Agents in ONE message:

### Agent A — TTS narration + audio (`model: sonnet`)

Pass the `OUT_JSON` path and the `VOICE` literal in the prompt. Agent A reads the JSON, writes narration text, and runs `tts.sh`.

```
You are the TTS agent.

1. Read the briefing data from: <OUT_JSON literal path>
2. Write speech-optimized narration to: <OUT_TXT literal path>
   Follow the TTS narration rules at the top of the parent skill.
3. Run (foreground, NEVER run_in_background):
   bash "${CLAUDE_SKILL_DIR}/scripts/tts.sh" "<OUT_TXT literal>" "<OUT_MP3 literal>" "<VOICE literal>"
4. Report "done" or the script's stderr.
```

### Agent B — HTML render (`model: haiku`, script-only)

```
Run this single command and report stdout/stderr:
python3 "${CLAUDE_SKILL_DIR}/scripts/render_html.py" "<OUT_JSON literal>" "<OUT_HTML literal>"
```

Do NOT write HTML directly. Only invoke the script.

## Step 6 — Verify and open

Wait for BOTH Step 5 agents to finish. Do NOT proceed until both have returned.

```bash
test -s "<OUT_MP3 literal>" && echo "Audio ready" || echo "Audio missing"
```

**If "Audio ready":**

```bash
open "<OUT_HTML literal>"
```

**If "Audio missing":** use `AskUserQuestion` to let the user choose:

- **Retry TTS** (description: "Re-run TTS and wait for it to finish before opening the briefing")
- **Open without audio** (description: "Open the briefing now — audio won't work")

If they choose retry: re-run `tts.sh` in the **foreground** (never `run_in_background`), re-check the file, then open. If retry also fails, report the error.
If they choose open without audio: open the HTML immediately.

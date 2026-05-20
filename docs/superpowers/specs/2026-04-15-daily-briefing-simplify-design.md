# Daily Briefing Skill — Simplification Design (v2.0.0)

**Date:** 2026-04-15
**Status:** Design approved, pending implementation plan
**Target:** `plugins/daily-briefing` (Claude Code) + new `plugins/daily-briefing-opencode` (OpenCode)

## Goal

Flatten the daily-briefing skill so smaller models can execute it reliably without hallucination. Three pillars:

1. Delete the orchestrator agent layer — skill itself orchestrates.
2. Ship a dedicated OpenCode plugin alongside the Claude Code one.
3. Replace prose-driven complexity (path discovery, settings migration, HTML/CSS spec) with deterministic scripts.

## Current architecture (v1.5.1)

```
User trigger
    ↓
SKILL.md (19 lines) — dispatches agent
    ↓
daily-briefing-agent.md (332 lines) — orchestrator
    ↓
12 parallel fetch subagents (haiku) → lead selection → lead-image subagent → 2 generation subagents (sonnet)
```

### Hallucination sources

- "Two directories up from this skill file" path discovery
- 6-branch settings migration executed as prose instructions
- ~160 lines of inlined HTML/CSS spec
- Path inconsistency between agent (`~/.ccToolBox/`) and OpenCode INSTALL.md (`~/.config/ccToolBox/`)
- Agent Rules separated from the dispatch sites that reference them
- Four architectural layers (skill → agent → fetch subagents → generation subagents)

## Target architecture (v2.0.0)

```
User trigger
    ↓
SKILL.md (linear steps, ~120-150 lines) — orchestrates directly
    ↓
12 parallel fetch subagents → inline lead selection → lead-image subagent → 2 parallel generation subagents
```

### Principles

1. **Complexity in code, not prose.** Settings migration, HTML rendering, path resolution all move to scripts. The skill invokes scripts and trusts their output.
2. **Scripts self-locate via `__file__`.** The skill needs only to know the script entry point; the script finds its own siblings (settings template, helpers).
3. **Platform-specific path idioms.** CC uses `${CLAUDE_SKILL_DIR}` in bash injection. OC uses the injected `Base directory for this skill` context. No model-computed paths.
4. **Two fully independent plugins.** No shared files. CC and OC versions can evolve separately, each with its own CHANGELOG and version.

## Repo layout

```
plugins/
├── daily-briefing/                          # Claude Code plugin (stays in marketplace.json)
│   ├── .claude-plugin/plugin.json           # version: 2.0.0
│   ├── skills/daily-briefing/
│   │   ├── SKILL.md                         # Linear flow, uses ${CLAUDE_SKILL_DIR}
│   │   ├── scripts/
│   │   │   ├── init_settings.py             # First-run + version migration
│   │   │   ├── render_html.py               # JSON → HTML file
│   │   │   └── tts.sh                       # Unchanged from v1.5.1
│   │   └── settings.default.json            # Version integer, not semver
│   ├── CLAUDE.md                            # Updated paths
│   ├── CHANGELOG.md                         # 2.0.0 entry
│   └── README.md                            # Updated paths
│
└── daily-briefing-opencode/                 # OpenCode plugin (NOT in marketplace.json)
    ├── skills/daily-briefing/
    │   ├── SKILL.md                         # Uses injected base dir, no per-dispatch model
    │   ├── scripts/                         # Identical scripts to CC (duplicated, not symlinked)
    │   └── settings.default.json
    ├── CHANGELOG.md                         # starts at 1.0.0
    └── README.md                            # copy-install instructions + optional opencode.json tip
```

### Path discovery

All assets live inside the skill directory — no `../..` traversal from SKILL.md.

**Claude Code invocation pattern** (bash injection, harness expands the env var):

```
!`python3 "${CLAUDE_SKILL_DIR}/scripts/init_settings.py"`
!`bash "${CLAUDE_SKILL_DIR}/scripts/tts.sh" "$TXT" "$MP3" "$VOICE"`
!`python3 "${CLAUDE_SKILL_DIR}/scripts/render_html.py" "$DATA_JSON" "$OUT_HTML"`
```

**OpenCode invocation pattern** (platform injects `Base directory for this skill: <DIR>` at the top of the prompt context):

```
Run: python3 <DIR>/scripts/init_settings.py
```

The model substitutes `<DIR>` with the injected absolute path. OpenCode's skill runner places the base dir in context before the model sees the SKILL.md body.

### User-facing storage path

`~/.ccToolBox/daily-briefing/` — for both versions. Contents:

- `settings.json` — user settings (copied from default on first run)
- `settings.json.bak` — backup when malformed reset occurs
- `settings.json.v<N>.bak` — backup before each version migration
- `output/` — generated files

The stale `~/.config/ccToolBox/` path in `CLAUDE.md` (repo root), `.opencode/plugins/INSTALL.md`, `plugins/daily-briefing/CLAUDE.md`, and `plugins/daily-briefing/README.md` gets corrected in the same commit as the implementation.

## Component: `init_settings.py`

### Contract

| | |
|---|---|
| **Invocation** | `python3 init_settings.py` — no args |
| **Self-location** | Uses `__file__` to find `settings.default.json` sibling |
| **Side effects** | Creates `~/.ccToolBox/daily-briefing/output/`. Creates/backs up/migrates `~/.ccToolBox/daily-briefing/settings.json`. Applies retention cleanup. |
| **Stdout** | Merged settings as JSON (skill parses this) |
| **Stderr** | Human-readable status line per branch taken |
| **Exit** | `0` success, `1` fatal (e.g., unwritable `$HOME`) |

### Branches (executed in order)

1. **User file missing (first run)** — copy default, stderr: `"Created default settings at ~/.ccToolBox/daily-briefing/settings.json — edit this file to customize."`
2. **Malformed (JSON parse fails)** — back up to `settings.json.bak`, copy default, stderr: `"Settings malformed. Backed up to settings.json.bak and reset to defaults."`
3. **user.version < default.version** — back up to `settings.json.v{old}.bak`, merge (user values win for existing keys, new keys filled from default), write back, stderr: `"Migrated from v{old} to v{new}. New fields: [list]."`
4. **user.version > default.version** — stderr warn: `"User settings version is newer than plugin default. Proceeding as-is."`
5. **Versions match** — no-op, stderr: `"Settings OK (v{n})."`

### Retention cleanup

After settings resolution, run:

```
find ~/.ccToolBox/daily-briefing/output -name "daily-briefing-*" -mtime +{retention_days} -delete
```

Move all of this out of the skill prompt.

### `settings.default.json` shape

```json
{
  "version": 2,
  "voice": "en-US-AvaMultilingualNeural",
  "location": "Burnaby, BC, Canada",
  "sources": [
    {"key": "weather",         "description": "short summary for {location}"},
    {"key": "tech-hn",         "description": "2-5 items from Hacker News (AI, CS, tech)"},
    {"key": "tech-devto",      "description": "2-5 items from Dev.to (AI, CS, tech)"},
    {"key": "tech-github",     "description": "3-5 trending repositories from GitHub"},
    {"key": "tech-tc",         "description": "2-3 top TechCrunch headlines"},
    {"key": "reddit-claudeai", "description": "2-5 hot new posts from r/ClaudeAI"},
    {"key": "ai-ml",           "description": "2-3 items from arXiv AI + The Batch"},
    {"key": "space-science",   "description": "1-2 items from NASA, SpaceX, space news"},
    {"key": "gaming",          "description": "2-3 items from r/gaming, game releases"},
    {"key": "maker-hobby",     "description": "1-2 items from Instructables, r/3Dprinting"},
    {"key": "news-ap",         "description": "2-5 very short headlines from AP News"},
    {"key": "extra",           "description": "(add your own sections here)"}
  ],
  "retention_days": 14,
  "today_in_history": true,
  "inspiration_quote": true
}
```

Version is integer `2` (not semver `"1.4.0"`) — trivial comparison, no parsing.

### No legacy migration

Old `settings.md` files (v1.5.1 and below) are ignored. `init_settings.py` sees no `settings.json`, treats this as a first run, copies the default. Previous customizations are lost. Acceptable for a 2.0.0 major bump.

## Component: `render_html.py`

### Contract

| | |
|---|---|
| **Invocation** | `python3 render_html.py <input.json> <output.html>` |
| **Stdlib only** | No pip dependencies. Uses `json`, `html`, `sys`, `pathlib`. |
| **Output** | Self-contained HTML file with inline CSS/JS and absolute audio path |
| **Exit** | `0` success, `1` on malformed input or write failure |

### Input JSON shape

```json
{
  "date_iso": "2026-04-15",
  "date_human": "Wednesday, April 15, 2026",
  "audio_path_absolute": "/Users/.../daily-briefing-2026-04-15.mp3",
  "weather": "17°C, light clouds, high 19° low 11°, wind 8 km/h.",
  "lead": {
    "source_label": "HACKER NEWS",
    "title": "...",
    "url": "https://...",
    "image_url": "https://.../img.jpg",
    "summary_paragraphs": ["...", "..."]
  },
  "top_row_sources": [
    { "key": "tech-hn", "label": "HACKER NEWS", "items": [{"title": "...", "url": "...", "summary": "..."}] }
  ],
  "bottom_row_sources": {
    "space_science": { "items": [...], "apod_image_url": "..." },
    "gaming":        { "items": [...] },
    "maker_hobby":   { "items": [...] },
    "news_ap":       { "items": [...] },
    "extra":         { "items": [...] }
  },
  "closing": {
    "today_in_history": { "holidays": "🥧 Pi Day", "events": "1879 — Einstein born · 2005 — First YouTube video" },
    "quote":            { "text": "...", "author": "..." }
  }
}
```

### Layout rules (enforced in code, not prose)

- **Top row grid**: `2fr 1fr 1fr` when `top_row_sources.length >= 2`, else `2fr 1fr`.
- **Bottom row grid**: `1fr 1fr 1.2fr 1fr` when `extra` is present; `1fr 1fr 1fr` otherwise. Script omits `extra` column entirely if missing or empty.
- **Empty sources**: any bottom-row key with no items is absent from the JSON and rendered as zero columns; grid rebalances.
- **Lead image**: if `image_url` is null/missing, `<img>` tag is not emitted (no broken-image box).
- **Lead summary**: all paragraphs render; no truncation. Uneven column heights accepted.
- **Stacked subsections inside a column**: joined by `<hr class="col-divider">` in order.
- **Closing section**: outer block omitted entirely if both subkeys absent. Each subkey renders independently.
- **Responsive breakpoints**:
  - `@media (max-width: 900px)` — 2-column collapse
  - `@media (max-width: 600px)` — 1-column with horizontal dividers
- **Theme CSS, audio player JS, Dark Reader lock meta** — all baked into the script as constants.

### URL and content enforcement (moved from LLM rules into script)

- Items with missing/empty `url`: title renders as plain text, not a link.
- URLs matching a homepage denylist (`news.ycombinator.com/news`, `dev.to/`, `github.com/trending`, `reddit.com/r/<sub>` bare): dropped, title renders as plain text.
- All user-facing strings pass through `html.escape()`.

### Failure mode

If required top-level keys are missing or `input.json` is malformed, exit `1` with clear stderr. Never write a partial HTML.

## Component: SKILL.md (both CC and OC)

Both versions share identical step-by-step wording for Steps 1-7. Only the invocation idioms (script paths, subagent dispatch syntax) differ.

### Common flow

```
Step 1 — Initialize settings + get date
  Run init_settings.py — capture stdout as SETTINGS_JSON
  Run `date +%Y-%m-%d` → DATE_ISO
  Run `date '+%A, %B %d, %Y'` → DATE_HUMAN
  Parse SETTINGS_JSON to extract: voice, location, sources[], today_in_history, inspiration_quote

Step 2 — Compute output paths (5 strings)
  OUT_DIR = "$HOME/.ccToolBox/daily-briefing/output"
  OUT_TXT  = "$OUT_DIR/daily-briefing-$DATE_ISO.txt"
  OUT_MP3  = "$OUT_DIR/daily-briefing-$DATE_ISO.mp3"
  OUT_HTML = "$OUT_DIR/daily-briefing-$DATE_ISO.html"
  OUT_JSON = "$OUT_DIR/daily-briefing-$DATE_ISO.json"
  Remove any existing files at these paths (enables re-run)

Step 3 — Dispatch fetch subagents IN PARALLEL (single message, N dispatches)
  For each source in settings.sources[], dispatch one subagent with:
    - prompt: "You are the <source> fetch agent. Date is {DATE_ISO}.
               Search <source-specific query>. Return JSON: [{title, url, summary}].
               URL rules: must be specific article/post/repo, never homepages.
               No URL available? Omit the url field."
  Plus one today_in_history subagent if enabled in settings.
  Collect all returned JSONs.

  Source-specific search queries (weather, tech-hn, tech-devto, tech-github, tech-tc,
  reddit-claudeai, ai-ml, space-science, gaming, maker-hobby, news-ap, extra) are
  preserved verbatim from v1.5.1 and embedded in SKILL.md as a per-source table the
  model consults when building the dispatch prompt.

Step 4 — Select lead story + fetch lead image
  Pick the single most impactful tech-source item. Criteria:
    - Broad significance (affects many developers/users)
    - Novelty (breaking news over ongoing stories)
    - Engagement (high vote/comment/star count)
  Dispatch one more subagent to find a lead image URL.
  Result: { lead_source, lead_item, lead_image_url (or null) }

Step 5 — Build briefing-data JSON (matches render_html.py input shape)
  Assemble all fetched data into the JSON shape specified above.
  Write to OUT_JSON via Write tool.

Step 6 — Generate TTS text + audio + HTML IN PARALLEL (dispatch 2 subagents)
  Subagent A (CC: sonnet; OC: primary):
    - Write TTS text to OUT_TXT per TTS narration rules (below)
    - Run tts.sh to generate OUT_MP3 (foreground, NEVER run_in_background)
  Subagent B (CC: haiku — script-only invocation; OC: primary):
    - Run render_html.py OUT_JSON OUT_HTML
    - Subagent B has no HTML knowledge to apply — it only invokes the script

Step 7 — Verify + open
  Verify OUT_MP3 exists and is non-empty
  If OK: `open "$OUT_HTML"`
  If not: report TTS failure to user, suggest retry
```

### Fetch rules (top of SKILL.md, referenced by Step 3)

Kept as a short bullet list — no separate "Agent Rules" section.

- URLs must link to specific articles/posts/repos, never homepages. Bad examples: `news.ycombinator.com/news`, `dev.to/`, `github.com/trending`.
- No URL found? Omit the url field.
- Write dense summaries with context and analysis.
- Only use sources and closing-section toggles from settings. Do not invent ad-hoc sections.
- If a source returns no items, that section disappears entirely (no empty columns).
- System date (from Step 1) is passed to every fetch prompt — never use session date.
- Fetch subagents only use WebSearch/WebFetch (on CC, enforced via tool restriction at dispatch; on OC, enforced by the optional custom subagent definition or trusted to the model).
- Be terse in status output. Only speak up on failures; suggest a retry or a fix.

### TTS narration rules (top of SKILL.md, referenced by Step 6)

- Start with a short, creative greeting tied to the day/weather/holidays. Avoid "Good morning" / "Hello".
- Lead story narrated first, regardless of settings order: "Our top story today..."
- Then remaining sources in settings order with natural transitions.
- GitHub repos: narrate description, not "user/repo" path.
- Expand abbreviations ("S and P 500"); keep "AI" as "AI".
- Never read URLs aloud.
- Closing: if `today_in_history` enabled, narrate; then `inspiration_quote` if enabled. End: "That's your briefing. Have a great day."

### Claude Code vs OpenCode differences

| Step | CC | OpenCode |
|---|---|---|
| Invoke scripts | `` !`python3 "${CLAUDE_SKILL_DIR}/scripts/X.py"` `` | `python3 <DIR>/scripts/X.py` where `<DIR>` is injected base dir |
| Dispatch subagents | `Agent` tool — `subagent_type: general-purpose`, `model: haiku` or `sonnet`, explicit `tools: [WebSearch, WebFetch]` per dispatch | `task` tool — prompt only. Model and tools inherit from primary. |
| Parallel | Multiple `Agent` tool uses in one message | Multiple `task` tool uses in one message |
| Optional cost tuning | N/A (models set per dispatch) | README documents an optional `opencode.json` snippet defining a `ccToolbox-fetcher` subagent with haiku + WebSearch-only tool access |

### Estimated size

Target: **~120-150 lines** per SKILL.md (down from 19 thin + 332 fat = 351 lines total).

## Cost and performance trade-offs

### Claude Code

Unchanged from v1.5.1: haiku for fetches (cheap), sonnet for generation (quality). Model selection happens at dispatch time.

### OpenCode

All 12 fetch subagents run on the user's primary model (whatever's configured in `opencode.json`). If the user is on sonnet, all 12 fetches use sonnet — more expensive and slower than the CC pattern, but aligned with how OpenCode expects users to manage model selection.

The OC README documents an optional `opencode.json` snippet that declares a dedicated subagent with haiku + WebSearch-only tools. Users who want the CC-equivalent cost profile opt into this.

## Versioning

| File | Change |
|---|---|
| `plugins/daily-briefing/.claude-plugin/plugin.json` | `2.0.0` (major — breaking architecture, settings format, storage path) |
| `.claude-plugin/marketplace.json` | matching `2.0.0` for the daily-briefing entry |
| `plugins/daily-briefing/CHANGELOG.md` | New `2.0.0` entry documenting: flattened architecture, JSON settings, script-based rendering, path assets move inside skill dir, scripts replace migration/HTML prose, old agent deleted |
| `plugins/daily-briefing/settings.default.json` | `"version": 2` (new file, replaces `settings.default.md`) |
| `plugins/daily-briefing-opencode/` | New plugin dir, starts at `1.0.0`, own CHANGELOG |

## Deletions

- `plugins/daily-briefing/agents/daily-briefing-agent.md`
- `plugins/daily-briefing/agents/` (directory, now empty)
- `plugins/daily-briefing/settings.default.md` (replaced by `.json`)
- `plugins/daily-briefing/docs/simplified-instructions.md` (if still present — outdated speculation)

## Doc corrections (stale `~/.config/ccToolBox/` paths)

- `CLAUDE.md` (repo root) — convention note
- `.opencode/plugins/INSTALL.md` — install paths and file-locations table
- `plugins/daily-briefing/CLAUDE.md` — plugin-level notes
- `plugins/daily-briefing/README.md` — settings section
- `plugins/daily-briefing/agents/daily-briefing-agent.md` — being deleted, no action needed

Replace all with `~/.ccToolBox/<plugin-name>/`.

## Testing plan (verification, not part of implementation)

1. **CC run with default model** — confirm parity with v1.5.1 behavior.
2. **CC run with Haiku primary** — the real small-model test. Confirm no path hallucination, no skipped steps, no invented HTML.
3. **OC run** via copy-install per updated INSTALL.md. Confirm task-tool dispatch works, scripts execute, HTML opens.
4. **Variable-content run** — run on a day where some sources return zero items; confirm grid rebalances, no empty columns rendered.
5. **First-run path** — delete `~/.ccToolBox/daily-briefing/`, run skill, confirm `init_settings.py` bootstraps cleanly.

## Out of scope

- Reducing the number of content sources (kept at 12).
- Migrating users' existing `settings.md` customizations to the new JSON format.
- Moving assets between `~/.ccToolBox/` and `~/.config/ccToolBox/` for existing users.
- Converting other ccToolBox plugins (`offline-research`) to the same pattern — separate decision.
- Any changes to `tts.sh` (unchanged).

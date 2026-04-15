# daily-briefing-opencode

Daily briefing skill for **OpenCode**. Sibling to the Claude Code-targeted `daily-briefing` plugin.

**Version:** 1.0.0

## What it does

Fetches news, tech, weather, and optional closing content from 12 sources, promotes a lead story, fetches a lead image, generates a newspaper-style HTML page with embedded audio player, and produces a TTS narration via Docker.

Same 12 sources, same layout, same `~/.ccToolBox/daily-briefing/` storage as the Claude Code version. The difference is platform idioms: subagent dispatch via `task`, path discovery via the injected "Base directory for this skill" context, and no per-dispatch model/tool restrictions.

## Prerequisites

- [OpenCode](https://opencode.ai) with the community `opencode-skills` plugin installed (so skill directories in `~/.config/opencode/skills/` get auto-discovered).
- **Docker** — required for TTS audio generation (via `scripts/tts.sh`).
- **Python 3** — required by the bundled scripts (macOS ships with it; `python3 --version` should succeed).

## Install

```bash
# Copy the skill directory into your OpenCode skills location
cp -r plugins/daily-briefing-opencode/skills/daily-briefing ~/.config/opencode/skills/

# Ensure scripts are executable
chmod +x ~/.config/opencode/skills/daily-briefing/scripts/*.py
chmod +x ~/.config/opencode/skills/daily-briefing/scripts/*.sh
```

Restart OpenCode. The skill is discovered as `daily-briefing`.

## First run

Invoke via `/daily-briefing` or say "get my daily briefing".

On first run, `scripts/init_settings.py` creates `~/.ccToolBox/daily-briefing/settings.json` with defaults. Edit that file to customize voice, location, and content sources.

## Settings

Stored at `~/.ccToolBox/daily-briefing/settings.json`:

```json
{
  "version": 2,
  "voice": "en-US-AvaMultilingualNeural",
  "location": "Burnaby, BC, Canada",
  "sources": [
    { "key": "weather", "description": "short summary for {location}" },
    { "key": "tech-hn", "description": "2-5 items from Hacker News (AI, CS, tech)" }
  ],
  "retention_days": 14,
  "today_in_history": true,
  "inspiration_quote": true
}
```

Edit `sources` to reorder, add, or remove sections. Set `retention_days` to change how many past briefings are kept in `output/`. Set `today_in_history` or `inspiration_quote` to `false` to disable those closing blocks.

## Optional: cost-optimized subagent

In OpenCode, all 12 fetch subtasks inherit whatever model your primary agent is using. If that is a premium model, fetches can be slow and expensive. To run fetches on a cheaper model, add this snippet to your `opencode.json`:

```json
{
  "agent": {
    "ccToolbox-fetcher": {
      "description": "Lightweight fetcher for the daily-briefing skill",
      "mode": "subagent",
      "model": "anthropic/claude-haiku-4-20250514",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false,
        "webfetch": true
      }
    }
  }
}
```

Then adjust the fetch prompts in your local copy of `SKILL.md` to dispatch `ccToolbox-fetcher` specifically.

## Storage layout

```
~/.ccToolBox/daily-briefing/
├── settings.json                          # user settings
├── settings.json.bak                      # backup after malformed-reset
├── settings.json.v<N>.bak                 # backup before each migration
└── output/
    ├── daily-briefing-YYYY-MM-DD.json     # structured data (input to render_html.py)
    ├── daily-briefing-YYYY-MM-DD.txt      # TTS narration text
    ├── daily-briefing-YYYY-MM-DD.mp3      # generated audio
    └── daily-briefing-YYYY-MM-DD.html     # final page (opens in browser)
```

## Troubleshooting

**TTS audio not produced**
- Verify Docker is running (`docker ps` succeeds).
- Try invoking the TTS script directly: `bash ~/.config/opencode/skills/daily-briefing/scripts/tts.sh test-input.txt /tmp/test.mp3`.
- Check for port conflicts on 5050 (the TTS container binds to it).

**Settings reset unexpectedly**
- `init_settings.py` backs up malformed JSON to `~/.ccToolBox/daily-briefing/settings.json.bak` and restores defaults. Restore manually if needed.

**Skill not discovered**
- Confirm `opencode-skills` plugin is loaded. Verify `~/.config/opencode/skills/daily-briefing/SKILL.md` exists and has valid frontmatter.

## Changelog

See `CHANGELOG.md`.

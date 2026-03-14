# ccToolBox Plugin Repo Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure ccToolBox as a Claude Code third-party marketplace with the daily-briefing plugin properly organized, documented, and ready to share.

**Architecture:** Marketplace repo pattern matching `claude-plugins-official` conventions. Plugin root at `plugins/daily-briefing/` with skill, scripts, and versioned settings. User settings stored at `~/.config/ccToolBox/` with LLM-driven migration.

**Tech Stack:** Claude Code plugin system (markdown skills, JSON manifests), shell scripts, git

**Spec:** `docs/superpowers/specs/2026-03-14-cctoolbox-plugin-repo-design-v2.md`

---

## Chunk 1: Repository Structure and Manifests

### Task 1: Restructure directories

**Files:**
- Move: `daily-briefing/` → `plugins/daily-briefing/`
- Move: `daily-briefing/skills/SKILL.md` → `plugins/daily-briefing/skills/daily-briefing/SKILL.md`
- Move: `daily-briefing/scripts/tts.sh` → `plugins/daily-briefing/scripts/tts.sh`
- Move: `daily-briefing/settings.md` → (will become `settings.default.md` in Task 4)

- [ ] **Step 1: Create the new directory structure**

```bash
mkdir -p plugins/daily-briefing/.claude-plugin
mkdir -p plugins/daily-briefing/skills/daily-briefing
mkdir -p plugins/daily-briefing/scripts
mkdir -p .claude-plugin
```

- [ ] **Step 2: Move files to new locations**

```bash
mv daily-briefing/scripts/tts.sh plugins/daily-briefing/scripts/tts.sh
mv daily-briefing/skills/SKILL.md plugins/daily-briefing/skills/daily-briefing/SKILL.md
mv daily-briefing/settings.md plugins/daily-briefing/settings.default.md
```

- [ ] **Step 3: Remove the old directory**

```bash
rm -rf daily-briefing/
```

- [ ] **Step 4: Verify structure**

```bash
find plugins/ -type f
```

Expected output:
```
plugins/daily-briefing/scripts/tts.sh
plugins/daily-briefing/skills/daily-briefing/SKILL.md
plugins/daily-briefing/settings.default.md
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: restructure repo as marketplace with daily-briefing plugin"
```

---

### Task 2: Create marketplace manifest

**Files:**
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Write marketplace.json**

Write to `.claude-plugin/marketplace.json`:

```json
{
  "name": "ccToolBox",
  "description": "Personal Claude Code plugin collection by dev32-io",
  "owner": {
    "name": "dev32-io"
  },
  "plugins": [
    {
      "name": "daily-briefing",
      "description": "Generate a personalized daily news/tech/weather briefing with TTS audio",
      "source": "./plugins/daily-briefing",
      "category": "productivity"
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: add marketplace manifest"
```

---

### Task 3: Create plugin manifest

**Files:**
- Create: `plugins/daily-briefing/.claude-plugin/plugin.json`

- [ ] **Step 1: Write plugin.json**

Write to `plugins/daily-briefing/.claude-plugin/plugin.json`:

```json
{
  "name": "daily-briefing",
  "description": "Generate a personalized daily news/tech/weather briefing with TTS audio",
  "author": {
    "name": "dev32-io"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/daily-briefing/.claude-plugin/plugin.json
git commit -m "feat: add daily-briefing plugin manifest"
```

---

### Task 4: Add version frontmatter to settings.default.md

**Files:**
- Modify: `plugins/daily-briefing/settings.default.md`

- [ ] **Step 1: Add version frontmatter**

The file currently contains:

```markdown
# Daily Briefing Settings

## General
- voice: en-US-AvaMultilingualNeural
- location: Burnaby, BC, Canada

## Sources (in order of appearance)
- weather: short summary for {location}
- tech-hn: 2-5 items from Hacker News (AI, CS, tech)
- tech-devto: 2-5 items from Dev.to (AI, CS, tech)
- reddit-claudeai: 2-5 hot new posts from r/ClaudeAI
- news-ap: 2-5 very short headlines from AP News
- extra: (add your own sections here)
```

Prepend YAML frontmatter so the file becomes:

```markdown
---
version: 1
---
# Daily Briefing Settings

## General
- voice: en-US-AvaMultilingualNeural
- location: Burnaby, BC, Canada

## Sources (in order of appearance)
- weather: short summary for {location}
- tech-hn: 2-5 items from Hacker News (AI, CS, tech)
- tech-devto: 2-5 items from Dev.to (AI, CS, tech)
- reddit-claudeai: 2-5 hot new posts from r/ClaudeAI
- news-ap: 2-5 very short headlines from AP News
- extra: (add your own sections here)
```

- [ ] **Step 2: Commit**

```bash
git add plugins/daily-briefing/settings.default.md
git commit -m "feat: add version frontmatter to default settings"
```

---

## Chunk 2: Update SKILL.md

### Task 5: Rewrite SKILL.md with new paths and settings flow

**Files:**
- Modify: `plugins/daily-briefing/skills/daily-briefing/SKILL.md`

This is the largest task. The SKILL.md needs two categories of changes:

1. **Path references** — replace hardcoded `~/Development/notes/dailyBriefing/` paths
2. **New Step 0** — add settings initialization flow before the existing Step 1

- [ ] **Step 1: Add plugin root resolution and settings flow as new Step 0**

Insert after the frontmatter and intro paragraph (after line 15 "Minimize user permission prompts..."), before "## Output Paths":

```markdown
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
```

- [ ] **Step 2: Update Step 1 path reference**

Replace line 28:
```
Read `~/Development/notes/dailyBriefing/settings.md` and parse:
```

With:
```
Using the settings parsed in Step 0 (from `~/.config/ccToolBox/daily-briefing/settings.md`):
```

- [ ] **Step 3: Update Step 3 TTS script path reference**

Replace lines 62-64:
```
**Tool call 3 — Generate audio** (`Bash` tool): Run:
```
~/Development/notes/dailyBriefing/tts.sh /tmp/daily-briefing-YYYY-MM-DD.txt /tmp/daily-briefing-YYYY-MM-DD.mp3 [voice]
```
```

With:
```
**Tool call 3 — Generate audio** (`Bash` tool): Run:
```
<plugin-root>/scripts/tts.sh /tmp/daily-briefing-YYYY-MM-DD.txt /tmp/daily-briefing-YYYY-MM-DD.mp3 [voice]
```
```

Where `<plugin-root>` is the absolute path resolved in Step 0.

- [ ] **Step 4: Verify no remaining old path references**

```bash
grep -n "Development/notes/dailyBriefing" plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add plugins/daily-briefing/skills/daily-briefing/SKILL.md
git commit -m "feat: update SKILL.md with plugin-relative paths and settings flow"
```

---

## Chunk 3: Git Remotes

### Task 6: Configure git remotes

- [ ] **Step 1: Rename existing origin to lab**

```bash
git remote rename origin lab
```

- [ ] **Step 2: Add new origin pointing to GitHub**

```bash
git remote add origin git@github.com:dev32-io/ccToolBox.git
```

- [ ] **Step 3: Verify remotes**

```bash
git remote -v
```

Expected:
```
lab     git@lab.null32.com:kevin-ye/cctoolbox.git (fetch)
lab     git@lab.null32.com:kevin-ye/cctoolbox.git (push)
origin  git@github.com:dev32-io/ccToolBox.git (fetch)
origin  git@github.com:dev32-io/ccToolBox.git (push)
```

---

## Chunk 4: Documentation and Housekeeping

### Task 7: Write project-level CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write CLAUDE.md**

```markdown
# ccToolBox

A personal Claude Code third-party marketplace containing reusable plugins.

## Repository Structure

This repo is a Claude Code marketplace. Plugins live under `plugins/`, each with its own `.claude-plugin/plugin.json` manifest.

```
ccToolBox/
├── .claude-plugin/marketplace.json   # marketplace registry
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/plugin.json
│       ├── skills/
│       ├── scripts/
│       ├── settings.default.md
│       └── README.md
```

## Adding a New Plugin

1. Create `plugins/<name>/` with the structure above
2. Add a `.claude-plugin/plugin.json` with `name`, `description`, `author`
3. Add the plugin entry to `.claude-plugin/marketplace.json`
4. If the plugin has user-configurable settings, use versioned `settings.default.md` (see below)

## Settings Convention

Plugins with user settings follow this pattern:
- Ship `settings.default.md` with `version: N` frontmatter in the plugin root
- User settings live at `~/.config/ccToolBox/<plugin-name>/settings.md`
- Skills handle first-run copy, version migration, and malformed settings recovery
- **When bumping a plugin version with settings changes, always bump the settings version integer in the same commit**

## Remotes

- `origin` → `git@github.com:dev32-io/ccToolBox.git` (main)
- `lab` → `git@lab.null32.com:kevin-ye/cctoolbox.git` (mirror)
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add project-level CLAUDE.md"
```

---

### Task 8: Write project-level README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

```markdown
# ccToolBox

A personal Claude Code plugin marketplace. Add it once per machine, get access to all plugins.

## Setup

Add this marketplace to Claude Code:

```bash
claude plugins add-marketplace github:dev32-io/ccToolBox
```

Then install individual plugins:

```bash
claude plugins install daily-briefing
```

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [daily-briefing](plugins/daily-briefing/) | Personalized daily news/tech/weather briefing with TTS audio |

## Adding Plugins

See [CLAUDE.md](CLAUDE.md) for the plugin directory template and conventions.

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add project-level README.md"
```

---

### Task 9: Write plugin-level CLAUDE.md

**Files:**
- Create: `plugins/daily-briefing/CLAUDE.md`

- [ ] **Step 1: Write CLAUDE.md**

```markdown
# daily-briefing Plugin

Generates a personalized daily briefing as a newspaper-styled HTML page with TTS audio.

## Components

- `skills/daily-briefing/SKILL.md` — main skill definition (invoked via `/daily-briefing` or "good morning")
- `scripts/tts.sh` — TTS generation using Docker (openai-edge-tts)
- `settings.default.md` — versioned default settings template

## Dependencies

- **Docker** — required for TTS audio generation (`scripts/tts.sh` runs a container)
- **curl, jq** — used by `tts.sh` for API calls

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
git commit -m "docs: add daily-briefing CLAUDE.md"
```

---

### Task 10: Write plugin-level README.md

**Files:**
- Create: `plugins/daily-briefing/README.md`

- [ ] **Step 1: Write README.md**

```markdown
# daily-briefing

A Claude Code skill that generates a personalized daily briefing as a newspaper-styled HTML page with embedded TTS audio.

## What It Does

When you say "good morning" or invoke `/daily-briefing`, Claude will:

1. Fetch weather, tech news (Hacker News, Dev.to), Reddit (r/ClaudeAI), and AP headlines
2. Generate a newspaper-styled HTML page with all sections
3. Generate TTS audio narration
4. Open the briefing in your browser with an embedded audio player

## Prerequisites

- **Docker** — used to run the TTS engine
- **Claude Code** with this marketplace registered

## Setup

Install via the ccToolBox marketplace:

```bash
claude plugins install daily-briefing
```

## Customization

Settings are stored at `~/.config/ccToolBox/daily-briefing/settings.md`.

On first run, default settings are copied there automatically. Edit the file to customize:

```markdown
---
version: 1
---
# Daily Briefing Settings

## General
- voice: en-US-AvaMultilingualNeural
- location: Burnaby, BC, Canada

## Sources (in order of appearance)
- weather: short summary for {location}
- tech-hn: 2-5 items from Hacker News (AI, CS, tech)
- tech-devto: 2-5 items from Dev.to (AI, CS, tech)
- reddit-claudeai: 2-5 hot new posts from r/ClaudeAI
- news-ap: 2-5 very short headlines from AP News
- extra: (add your own sections here)
```

- **voice** — any Azure TTS voice identifier
- **location** — your city for weather lookups
- **sources** — reorder, add, or remove sections
```

- [ ] **Step 2: Commit**

```bash
git add plugins/daily-briefing/README.md
git commit -m "docs: add daily-briefing README.md"
```

---

### Task 11: Add .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Write .gitignore**

```
.DS_Store
*.mp3
/tmp/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

### Task 12: Add LICENSE

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Write MIT license**

Standard MIT license with copyright `2026 dev32-io`.

- [ ] **Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license"
```

---

### Task 13: Final verification

- [ ] **Step 1: Verify directory structure**

```bash
find . -not -path './.git/*' -type f | sort
```

Expected:
```
./.claude-plugin/marketplace.json
./.gitignore
./CLAUDE.md
./LICENSE
./README.md
./docs/superpowers/plans/2026-03-14-cctoolbox-plugin-repo.md
./docs/superpowers/specs/2026-03-14-cctoolbox-plugin-repo-design-v2.md
./docs/superpowers/specs/2026-03-14-cctoolbox-plugin-repo-design.md
./plugins/daily-briefing/.claude-plugin/plugin.json
./plugins/daily-briefing/CLAUDE.md
./plugins/daily-briefing/README.md
./plugins/daily-briefing/scripts/tts.sh
./plugins/daily-briefing/settings.default.md
./plugins/daily-briefing/skills/daily-briefing/SKILL.md
```

- [ ] **Step 2: Verify remotes**

```bash
git remote -v
```

- [ ] **Step 3: Verify no old path references remain**

```bash
grep -r "Development/notes/dailyBriefing" plugins/
```

Expected: no matches.

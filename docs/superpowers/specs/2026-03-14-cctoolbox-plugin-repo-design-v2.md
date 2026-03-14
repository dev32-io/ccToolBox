# ccToolBox Plugin Repo Design

**Date:** 2026-03-14
**Status:** Approved

## Overview

Structure the ccToolBox repo as a Claude Code third-party marketplace containing reusable plugins (starting with daily-briefing). The marketplace can be registered on any machine, giving access to all plugins within it.

## Repo Structure

```
ccToolBox/
├── .claude-plugin/
│   └── marketplace.json              # marketplace registry listing all plugins
├── plugins/
│   └── daily-briefing/
│       ├── .claude-plugin/
│       │   └── plugin.json           # plugin manifest (name, description, author only)
│       ├── skills/
│       │   └── daily-briefing/
│       │       └── SKILL.md          # skill definition
│       ├── scripts/
│       │   └── tts.sh               # TTS generation script
│       ├── settings.default.md       # versioned default settings template
│       ├── CLAUDE.md                 # plugin-level dev guidance
│       └── README.md                # plugin-level docs
├── CLAUDE.md                         # project-level dev guidance
├── README.md                         # project-level docs
├── LICENSE
└── .gitignore
```

## Git Remotes

- `origin` → `git@github.com:dev32-io/ccToolBox.git` (main, public)
- `lab` → `git@lab.null32.com:kevin-ye/cctoolbox.git` (private mirror)

## Marketplace Manifest

`.claude-plugin/marketplace.json` registers the repo as a marketplace and lists all available plugins:

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

## Plugin Manifest

Each plugin has a minimal `.claude-plugin/plugin.json` following official conventions (no version or component pointers — version lives in marketplace.json, components discovered by directory convention):

```json
{
  "name": "daily-briefing",
  "description": "Generate a personalized daily news/tech/weather briefing with TTS audio",
  "author": {
    "name": "dev32-io"
  }
}
```

## Settings System

### Problem

When installed, plugins are cached in `~/.claude/plugins/cache/...` — a buried path that gets overwritten on updates. Users need a stable, discoverable location to customize settings.

### Design

**Versioned default settings** ship with the plugin as `settings.default.md`:

```markdown
---
version: 1
---
# Daily Briefing Settings
...
```

The `version` field is a monotonically increasing integer (not semver). It tracks settings schema changes only, independent of plugin version.

**User settings** live at `~/.config/ccToolBox/<plugin-name>/settings.md`.

### Settings Flow (in SKILL.md)

Executed before the main skill logic:

1. Determine the plugin root directory (parent of the `skills/` directory containing the skill file)
2. Read user settings from `~/.config/ccToolBox/daily-briefing/settings.md`
3. **If file missing (first run):**
   - Create `~/.config/ccToolBox/daily-briefing/` directory if needed
   - Copy `settings.default.md` from plugin root to user path
   - Inform user: "Created default settings at `~/.config/ccToolBox/daily-briefing/settings.md` — edit this file to customize."
   - Proceed with defaults
4. **If user settings are malformed** (missing frontmatter, unparseable):
   - Back up to `settings.md.bak`
   - Copy fresh defaults to user path
   - Inform user what happened
5. **If version mismatch** (user version < default version):
   - Back up current settings to `settings.md.v<old-version>.bak`
   - Read both files
   - Migrate user values into the new structure (Claude understands both schemas and merges intelligently)
   - Preserve user customizations, adopt new fields with defaults
   - Write migrated settings back to user path
   - Inform user what changed
6. **If user version > default version** (downgrade scenario):
   - Leave user settings untouched, warn user of version mismatch
   - Proceed with user settings as-is
7. **If versions match:** proceed normally

### Version Sync Rule

When bumping a plugin version and the settings structure has changed, always bump the `version` field in `settings.default.md` in the same commit.

## SKILL.md Path References

The SKILL.md uses paths relative to the plugin root, resolved at runtime:

- Settings default: `<plugin-root>/settings.default.md`
- TTS script: `<plugin-root>/scripts/tts.sh`
- User settings: `~/.config/ccToolBox/daily-briefing/settings.md`

The skill instructs Claude to determine the plugin root by navigating up from the skill file's location (the skill is at `skills/daily-briefing/SKILL.md`, so plugin root is `../../`).

## CLAUDE.md Files

### Project-level (`/CLAUDE.md`)

- Repo purpose: personal Claude Code plugin marketplace
- Marketplace structure conventions
- How to add a new plugin (directory template)
- Remote setup (origin = GitHub, lab = private mirror)
- Settings versioning rule

### Plugin-level (`plugins/daily-briefing/CLAUDE.md`)

- Plugin purpose and components
- Settings versioning rule
- Script dependencies (Docker for TTS)
- How to test the skill locally

## README.md Files

### Project-level (`/README.md`)

- What ccToolBox is
- How to add the marketplace to Claude Code
- List of available plugins
- How to contribute / add plugins

### Plugin-level (`plugins/daily-briefing/README.md`)

- What daily-briefing does
- Prerequisites (Docker)
- How to customize settings
- Settings file location and format

## Implementation Tasks

1. Restructure directories: move `daily-briefing/` → `plugins/daily-briefing/`, reorganize internals
2. Create `.claude-plugin/marketplace.json` at repo root
3. Create `plugins/daily-briefing/.claude-plugin/plugin.json`
4. Convert `settings.md` → `settings.default.md` with version frontmatter
5. Update SKILL.md: fix path references, add settings flow (first-run copy, version migration, edge cases)
6. Update git remotes: rename `origin` → `lab`, add new `origin` for GitHub
7. Write project-level CLAUDE.md
8. Write project-level README.md
9. Write plugin-level CLAUDE.md
10. Write plugin-level README.md
11. Add .gitignore
12. Add LICENSE (MIT)
13. Commit and verify marketplace registration works

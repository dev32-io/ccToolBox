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
│       ├── scripts/                  # optional — plugins may also place scripts inside skills/<name>/scripts/
│       ├── settings.default.json     # or settings.default.md (legacy)
│       └── README.md
```

## Adding a New Plugin

1. Create `plugins/<name>/` with the structure above
2. Add a `.claude-plugin/plugin.json` with `name`, `description`, `author`
3. Add the plugin entry to `.claude-plugin/marketplace.json`
4. If the plugin has user-configurable settings, use versioned `settings.default.md` (see below)

## Settings Convention

Plugins with user settings follow this pattern:
- Ship a versioned settings default in the plugin's skill directory (e.g., `settings.default.json` with integer `version`). Older plugins may still use `settings.default.md` with YAML frontmatter.
- User settings live at `~/.ccToolBox/<plugin-name>/settings.{json,md}`.
- Skills handle first-run copy, version migration, and malformed settings recovery — preferably via a dedicated script (see `daily-briefing` as reference).
- **When bumping a plugin version with settings changes, always bump the settings version integer in the same commit.**

## Remotes

- `origin` → `git@github.com:dev32-io/ccToolBox.git` (main)

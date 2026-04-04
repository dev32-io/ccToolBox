# Changelog

All notable changes to the daily-briefing plugin.

## 1.5.1

### Fixed

- Ensure TTS audio is ready before opening the page in browser
- Reduce chattiness in agent output

## 1.5.0

### Changed

- Split into thin skill trigger + Sonnet orchestrator agent for better token efficiency

## 1.4.3

### Changed

- Use Haiku for fetch agents, Sonnet for generation (cost optimization)

## 1.4.2

### Changed

- Trim verbose explanations from SKILL.md

## 1.4.1

### Changed

- Consolidate agent rules and improve URL quality enforcement

## 1.4.0

### Added

- New trigger phrases ("good morning", "get my daily briefing", etc.)
- Creative greeting at the top of each briefing
- Retention system (configurable days, default 14)
- System date injection for accurate "today" references

## 1.3.3

### Fixed

- Cleanup temporary files after generation
- Limit agent tool access to prevent unintended side effects

## 1.3.2

### Fixed

- Use Write tool with Read-first pattern for /tmp/ file writes

## 1.3.1

### Fixed

- Use Bash heredoc for /tmp/ writes instead of Write tool

## 1.3.0

### Added

- Sonnet subagents for parallel source fetching
- Parallel TTS and HTML generation pipelines

### Changed

- Semver-based settings with automatic version migration

## 1.2.0

### Added

- Closing section with today-in-history fact and inspiration quote

## 1.1.0

### Added

- Vintage broadsheet newspaper layout with 3/4 column design
- 12 content sources (up from 5)
- Dark/light mode toggle with Dark Reader lock
- Lead story selection with image fetching
- Responsive layout

### Fixed

- Default to light mode instead of dark
- Audio timing race condition on page load
- Link quality enforcement -- fill sparse sections, no invented URLs

## 1.0.0

### Added

- Initial release -- daily briefing skill with weather, tech news, Reddit, AP headlines, and TTS audio

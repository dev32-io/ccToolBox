# docs/

Process artifacts for ccToolBox.

Every plugin in this repo started as a design spec under [`superpowers/specs/`](superpowers/specs/), became an executable plan with checkbox-tracked tasks under [`superpowers/plans/`](superpowers/plans/), then shipped as code. The trail stays visible because the process is the work. ccToolBox is built with [Claude Code](https://claude.com/claude-code) via the [superpowers](https://github.com/anthropics/claude-plugins-official) + [agentic-dev-harness](https://github.com/dev32-io/agentic-dev-harness) setup.

For per-plugin design rationale (the *why*, not the *how-to-use*), see each plugin's `docs/` directory:

- [`plugins/devTools/docs/`](../plugins/devTools/docs/): frustration-check, skill-distill, ui-refinement, 2026-05-06 v1.7.1 refactor postmortem
- [`plugins/offline-research/docs/`](../plugins/offline-research/docs/): container architecture

Per-skill usage lives in each skill's `SKILL.md`.

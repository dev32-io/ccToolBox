# Claude Code skill format reference

Hard rules for SKILL.md and the skill directory. Violations make the
skill not load or not trigger.

## Directory shape

```
<skill-name>/
├── SKILL.md                # required — entry point + frontmatter
├── references/             # optional — progressive-disclosure docs
├── personas/               # optional — role mindsets
├── checklists/             # optional — discipline lists
├── templates/              # optional — output shapes
├── scripts/                # optional — executable helpers
└── assets/                 # optional — binary / template files
```

The skill name is the directory name. Must match the `name` field in
SKILL.md frontmatter.

## YAML frontmatter

Required fields, between `---` markers at the very top of `SKILL.md`:

```yaml
---
name: <lowercase-hyphen-name>
description: >
  <multi-line description that explains what the skill does, when to
  use it, and key capabilities. Maximum 1024 chars.>
tools: <optional comma-separated allowlist>
---
```

### `name`

- Lowercase letters, numbers, hyphens only. No spaces, no underscores,
  no XML tags.
- Maximum 64 characters.
- Reserved words forbidden: `anthropic`, `claude`. Avoid generic verbs
  that conflict with built-ins: `init`, `clear`, `help`, `config`.
- Must match the directory name.

### `description` — the most important field

This is what the model reads to decide whether to invoke the skill.
Bad description = skill never triggers OR triggers on everything.

**Formula:** *what it does* + *when to use it* + *key capabilities* +
*explicit "do not trigger on" near-misses if relevant*.

**Maximum 1024 characters.** The block-scalar `>` form (folded) is
preferred for multi-line.

**Bad:**

```yaml
description: A skill for working with UIs.
```

**Good:**

```yaml
description: >
  Drive an autonomous, MCP-powered UI/UX refinement loop on a live
  running app. Targets one or more screens / components, agrees on
  success criteria + design-system constraints, surfaces required
  setup, shows an iteration plan, then loops capture → critique →
  implement → regression-check until the agent's own quality bar is
  met. Use when the user says "refine this UI", "improve mobile UX",
  "polish the chat screen", or invokes /ui-refinement. Do NOT trigger
  on casual mentions like "the colors look off" — those are direct
  one-shot edits.
```

Triple-check the description names:

- The trigger verbs / phrases the user will say.
- The boundary cases that should NOT fire.
- The slash command (`/<name>`) so explicit invocation works.

### `tools` (optional)

A comma-separated allowlist of tools the skill is permitted to invoke.
Omit to inherit the parent agent's full toolset (most common).

```yaml
tools: Agent, AskUserQuestion, Bash, Read, Write, Edit, Grep, Glob, ToolSearch, WebSearch, WebFetch
```

Use the allowlist when:

- The skill must be sandboxed (no Write / no Bash).
- The skill is shipped to other users and you want to reduce surprise.

### `disable-model-invocation` (optional)

Set `true` to disable auto-invocation by the model. The skill becomes
explicit-only (slash command or programmatic call). Use sparingly.

## Body content

After the closing `---`, the body is plain Markdown.

- **Soft cap: 500 lines.** Beyond that, split into `references/*.md`
  files and link from SKILL.md (progressive disclosure).
- First line typically `# <skill-name> — <one-line tagline>`.
- Use headings, lists, fenced code blocks. No HTML.
- Reference relative paths (`references/foo.md`) for any doc the skill
  loads later — the model reads the SKILL.md first and pulls in the
  referenced docs on demand.

## Scripts directory

Place executable helpers in `scripts/`. Conventions:

- `*.sh` — bash; mark executable (`chmod +x`); use `#!/usr/bin/env
  bash` shebang; assume bash 3.2+ (macOS default).
- `*.py` — python 3.x; `#!/usr/bin/env python3`; pin major version in
  the script if needed.
- Reference scripts from SKILL.md by relative path; the skill is
  responsible for invoking them via Bash.

## Templates and assets

- `templates/*` — markdown / text files the skill copies or emits as
  a starting point.
- `assets/*` — binary / non-text files (images, fonts, fixtures).

Reference both via relative paths in SKILL.md.

## Sources

- [Extend Claude with skills — Claude Code docs](https://code.claude.com/docs/en/skills)
- [Skill authoring best practices — Claude API docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Claude Code Skill Frontmatter: every YAML option explained](https://allahabadi.dev/blogs/ai/claude-code-skills-frontmatter-complete-guide/)
- [The Complete Guide to Building Skills for Claude (Anthropic PDF)](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)

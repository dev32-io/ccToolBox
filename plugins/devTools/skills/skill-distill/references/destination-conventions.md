# Destination conventions

Three destinations. The skill writes to one of them in Phase 5,
following the conventions per kind.

## 1. User-level

**Path:** `~/.claude/skills/<skill-name>/`

**Use when:** the skill is broadly useful across many projects, the
user wants it personally available without sharing.

**Bookkeeping:** none. The skill loads automatically on next Claude
Code session start. No version, no marketplace, no commit needed
(unless `~/.claude/` is itself dotfile-tracked — check
`git -C ~/.claude status` to see).

**Trigger:** the user can invoke `/<skill-name>` or use a phrase from
the description's trigger list.

**Reverting:** delete the directory.

## 2. Repo-level

**Path:** `<project-root>/.claude/skills/<skill-name>/`

**Use when:** the skill is project-specific (uses project paths,
fixtures, conventions) and should be shared with anyone who clones the
repo.

**Bookkeeping:** ensure the project's `.claude/` is git-tracked. Check
`.gitignore`; if `.claude/` is excluded, ask the user how to handle
(unignore the skills subdir vs. add the skill at a different path
they prefer).

**Commit:** standard project conventions (read recent commit log to
match `type(scope): summary` style). Commit message records the
distillation source.

**Reverting:** delete the dir + commit.

## 3. Custom path

The user supplies a path. Probe to detect what kind of destination it
is. The path can be:

### 3a. Marketplace plugin repo

**Detection:** path contains `.claude-plugin/marketplace.json` at root
AND `plugins/<name>/.claude-plugin/plugin.json` for one or more
plugins.

**Layout:**

```
<custom-path>/
├── .claude-plugin/marketplace.json
└── plugins/
    └── <plugin-name>/
        ├── .claude-plugin/plugin.json
        ├── skills/<skill-name>/
        ├── README.md
        └── CHANGELOG.md
```

**Workflow:**

1. List the plugins in the marketplace; ask user which plugin to add
   the skill to (single plugin → confirm; multiple → multi-choice).
2. Write the skill to `plugins/<chosen>/skills/<skill-name>/`.
3. Bump version in `plugins/<chosen>/.claude-plugin/plugin.json`. Use
   semver:
   - **Minor** for new skill addition.
   - **Patch** for fix-only edits to an existing skill.
   - **Major** for breaking changes.
4. Bump the same version in the marketplace entry at
   `.claude-plugin/marketplace.json`.
5. Add a section to `plugins/<chosen>/CHANGELOG.md` with the new
   version + ISO date + 1-paragraph summary.
6. Add a section to `plugins/<chosen>/README.md` under `## Skills`
   describing the skill, trigger phrases, platform support.
7. Single commit covering all of the above.

### 3b. Single-plugin repo

**Detection:** path contains `.claude-plugin/plugin.json` at root, but
no `marketplace.json`.

**Layout:**

```
<custom-path>/
├── .claude-plugin/plugin.json
├── skills/<skill-name>/
├── README.md
└── CHANGELOG.md (if present)
```

**Workflow:** like 3a, minus the marketplace step.

### 3c. Plain repo with `.claude/`

**Detection:** path is a git repo that has `.claude/skills/` (or has
`.claude/` and the user wants `skills` added).

**Workflow:** write to `<custom>/.claude/skills/<skill-name>/`,
respect any `.gitignore` excluding `.claude/` (ask user). Match repo's
commit style.

### 3d. Plain repo without skill dir

**Detection:** path is a git repo with no skill convention.

**Workflow:** ask the user where they want the skill placed. Common
choices: `<repo>/skills/<name>/`, `<repo>/.claude/skills/<name>/`, or
something repo-specific. Don't guess.

## Detection helpers

```bash
# Marketplace?
test -f "<custom>/.claude-plugin/marketplace.json" && echo marketplace

# Single plugin?
test -f "<custom>/.claude-plugin/plugin.json" && echo single-plugin

# Plain repo?
git -C "<custom>" rev-parse --is-inside-work-tree 2>/dev/null && echo repo

# Has .claude/ dir?
test -d "<custom>/.claude" && echo claude-dir
```

## Version strategy (marketplace / single-plugin)

The plugin's version is shared across all its skills. Adding a skill is
typically a minor bump:

- 1.5.3 → 1.6.0 (new skill).
- 1.6.0 → 1.6.1 (fix to an existing skill).

Major (1.6.0 → 2.0.0) is rare — reserve for backwards-incompatible
changes (renaming a skill, changing a frontmatter contract).

The marketplace.json plugin entry's `version` MUST match the plugin's
own `plugin.json` `version`. If they drift, the marketplace shows a
stale version. Always update both in the same commit.

## What never gets committed

- `~/.ccToolBox/<plugin>/settings.json` — user-specific runtime
  settings. Ship a `settings.default.json` in the plugin if needed.
- Per-project state the skill writes during execution (logs,
  screenshots, scratch). Add to `.gitignore`.

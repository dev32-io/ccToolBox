# Skill quality checklist

Run this before declaring the skill ready in Phase 5. Any "no" is a
fix.

## 1. Frontmatter

- [ ] `name` is lowercase + hyphens + numbers only.
- [ ] `name` ≤ 64 chars.
- [ ] `name` does not contain reserved words (`anthropic`, `claude`,
      generic verbs that conflict with built-ins).
- [ ] `name` matches the directory name.
- [ ] `description` ≤ 1024 chars.
- [ ] `description` answers what + when + key capabilities.
- [ ] `description` lists 3+ trigger phrases.
- [ ] `description` lists 1+ "do not trigger on" near-miss.
- [ ] `tools:` allowlist includes everything the skill actually uses
      (or is omitted to inherit the parent agent's full toolset).

## 2. Body

- [ ] Body ≤ 500 lines (split into supporting docs if longer).
- [ ] Opens with a one-line tagline + one-paragraph "what / when".
- [ ] Has explicit "When NOT to use" section.
- [ ] Has anti-pattern callouts for non-obvious failure modes.
- [ ] Has a flow diagram (graphviz or list) showing phase transitions.
- [ ] Has a `Magic ingredients` section encoding the load-bearing
      rules from distillation.
- [ ] References supporting files via relative paths.

## 3. Supporting files

- [ ] Each supporting doc has a clear single purpose.
- [ ] No supporting doc duplicates content the body already covers.
- [ ] Templates / checklists / personas are split by axis (don't mix
      a checklist into a persona doc).
- [ ] Scripts are executable (`chmod +x`) and have shebangs.

## 4. Generalization

- [ ] No project-specific paths hard-coded.
- [ ] No project-specific tool / model / service names assumed
      (unless surfaced as a dependency to check).
- [ ] Platform variations (web / iOS / Android / desktop) addressed
      where relevant.
- [ ] Input / output shapes covered (different trigger forms, optional
      args, alternative outputs).

## 5. Magic preservation

- [ ] All ≥3 of the most load-bearing rules from the source session
      are encoded in SKILL.md or a checklist.
- [ ] Course-corrections from the source session became bright-line
      rules.
- [ ] User-prompt framings (persona, scope, autonomy grants) are
      reflected in the skill's behavior.

## 6. Bookkeeping (if writing to a marketplace / plugin repo)

- [ ] Plugin's `plugin.json` `version` bumped.
- [ ] Marketplace `marketplace.json` plugin entry `version` matches.
- [ ] `CHANGELOG.md` has a new section with version + date + summary.
- [ ] `README.md` describes the new skill.
- [ ] All bookkeeping committed in the same commit as the skill files.

## 7. Final read

- [ ] Re-read SKILL.md cold (forget the source session). Could you
      run it correctly? If not, where did you stumble? Fix that.
- [ ] Send the user the path + commit SHA + one trigger phrase to
      try in a fresh session.

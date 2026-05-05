# Distillation method

How to read a session and pull the magic out. Apply this in Phase 1.2.

## Three lenses

Apply each lens to the source independently. The same line can show up
under multiple lenses.

### Lens 1 — User-prompt patterns

What did the user say that gave the model permission, scope, autonomy,
or a specific framing? These are usually the load-bearing words.

Look for:

- **Persona / mindset framing.** "be EXTREMELY ruthless", "act as a
  senior designer", "you are a frustrated power user".
- **Scope-cap phrases.** "chat only for now", "in a feature branch",
  "don't touch unrelated files".
- **Autonomy grants.** "use your best judgment", "you are free to run
  whatever messages", "take as much time as you need".
- **Reference framings.** "industry refs are inspiration not gospel",
  "chatgpt is gold standard but not blind".
- **Explicit "find more" instructions.** "DO NOT only look at the
  issues I listed, take as much iteration as you need".
- **Cost / safety constraints.** "I intentionally don't give you the
  Fish key so you can do hard testing without costing me".
- **Cadence directions.** "feature branch off develop, commit while
  you go".

Capture verbatim where possible. These become quoted `>` blocks or
encoded rules in the skill's `Magic ingredients` section.

### Lens 2 — Agent decisions that paid off

What choices the agent made (with or without nudging) that turned out
load-bearing later?

Look for:

- **Tool choices.** Picked Playwright MCP over chrome-devtools because
  X. Picked Edit over Write because Y.
- **Loop structures.** Two-pass critique. Capture-baseline-first.
  Regression-check-after-edit.
- **Scope guards.** Mobile media-query gating. Branch-off-develop.
  Commit per pass.
- **Iteration controls.** Exit on quality bar, not iteration count.
- **Failure recovery.** When the dev server served a stale bundle, the
  agent's diagnosis path. When HMR didn't pick up, the workaround.

These become technique sections in the skill body.

### Lens 3 — Course-corrections

Every time the user pushed back. These are bright lines.

Look for:

- "no, don't do that" — direct correction.
- "actually, keep X" — affirmation of an existing pattern after the
  agent dropped it.
- "you are being lazy and this is a hack" — process violation, often
  reveals an unstated convention.
- "i specifically requested X" — durable constraint the skill must
  encode.
- "stop and ask before you do Y" — escalation rule.

For each correction, write a one-line rule the skill must enforce.
These usually go into `checklists/<aspect>.md` or as inline rules in
SKILL.md.

## How to access the session

### Current Claude Code session transcript

```bash
~/.claude/projects/<encoded-project-path>/<session-id>.jsonl
```

The encoded project path replaces `/` with `-`. Find the active session:

```bash
ls -t ~/.claude/projects/*/*.jsonl | head -1
```

Each line is a JSON message. Filter for user messages:

```bash
jq -c 'select(.type == "user") | {role: .message.role, content: .message.content}' transcript.jsonl
```

Or use `Read` tool with offset / limit for narrow windows.

### Other transcript

User supplies a path. Read directly. JSONL format may differ; adapt
the parser.

### Free-text summary

User describes what worked. No transcript to parse — the description
IS the source. Apply the three lenses to the description.

## Writing the magic-ingredients list

Format: numbered list, one rule per line, ≤120 chars per rule, action
voice.

Example (from the ui-refinement run):

> 1. Live MCP inspection only — no theoretical critique.
> 2. User-listed defects = seed not cap (ruthless-tester finds more).
> 3. Industry refs are inspiration; design-system guardrail wins.
> 4. Both viewports regression-checked every pass.
> 5. Real running stack + real data.
> 6. Cost protection on paid credentials.
> 7. Two-persona critique (senior-designer + ruthless-tester).
> 8. Scope-guard every edit against unaffected surfaces.
> 9. Commit each meaningful pass.
> 10. Exit on quality bar, not iteration count.

Target 8–12 rules. Fewer = under-distilled. More = the skill is doing
too many things; consider splitting.

## Anti-patterns when distilling

- **Verbatim transcript dump.** The skill body is not the source
  session. Distill the rules, not the dialogue.
- **Project-specific magic baked in.** "Always use kimi-k2.6:cloud" is
  not a rule, it's a Sentient-specific config. Generalize to "pick a
  cloud LLM appropriate for the test cost budget".
- **Implicit assumptions.** If the source session relied on a tool /
  service the user has running, the skill must check or surface the
  dependency.
- **Padding.** A 500-line skill that says less than a 200-line skill.
  Cut.

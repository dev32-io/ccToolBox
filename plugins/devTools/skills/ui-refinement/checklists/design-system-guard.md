# Design-system guardrail

The most common ui-refinement failure mode is **drift**: the agent
imports a pattern from ChatGPT/Claude/Linear that "looks better" in
isolation but breaks the host app's design language. Before any edit,
run this guard.

## What is the design system?

A combination of:

1. **Tokens** — colors, spacing, type scale, radius, shadow,
   motion-duration. Usually CSS custom properties (`--color-*`,
   `--space-*`, `--font-size-*`) or platform equivalents.
2. **Components** — repeated atoms with established shape grammar
   (bubbles, cards, pills, buttons, inputs).
3. **Patterns** — repeated layouts (avatar + meta-row + content; sidebar
   + main + footer; tab strip + panel).
4. **Voice** — the unique character: a tail corner on a bubble; a
   specific accent color used for AI-output; a particular animation
   curve.

Discover all four before refining. They usually live in
`tokens.css`, `theme.ts`, `design-system/` directory, or a Figma file.

## The bright line

Every edit must be one of:

- **A.** Use an existing token at a new place. ✅ allowed.
- **B.** Tighten a value within the system (e.g. mobile media query
  picks a smaller existing token instead of the desktop one). ✅
  allowed.
- **C.** Add a new token to the system (rare, requires user sign-off).
  ⚠️ escalate.
- **D.** Use a magic value the system can't express. ❌ blocked.
- **E.** Replace a system pattern with a new one (e.g. drop the
  meta-row). ❌ blocked without sign-off.

If a fix requires C, D, or E, **stop and ask the user**. The user's
clarification becomes part of the guardrail for the rest of the
session.

## The drift smell test

Before adopting an industry pattern, ask:

1. **Is the host app already using a different pattern for the same
   purpose?** If yes, the host pattern is the answer — refine it,
   don't replace it.
2. **Is the industry pattern compatible with the host's voice?** A
   ChatGPT-style hidden-on-touch hover affordance fights an app whose
   voice is "rich on every device".
3. **What's the user's stated constraint?** "Maintain similar design
   system and principle" → host pattern wins. "Make it like X" → still
   filter through host system; X is inspiration only.

## Sign-off escalation template

When you need to break the bright line:

> **Proposed change:** drop the user-side avatar + meta-row on mobile to
> match ChatGPT's user-side density.
>
> **Trade-off:** gains ~28px of vertical space per user message. Loses
> the host's voice (avatar + meta is part of the family-AI design
> language).
>
> **Alternatives staying inside the system:**
> 1. Keep avatar + meta but tighten font sizes.
> 2. Keep avatar + meta, drop only the redundant `name` text.
> 3. Reduce the meta line-height + padding only.
>
> Which direction?

Don't do the change until the user picks a direction.

## Common drift patterns to avoid

- **Replacing a custom radius / shadow with Material/Tailwind defaults.**
  These are off-the-shelf; they erase voice.
- **Pulling a third-party "perfect" spacing scale.** If the host has 4 /
  8 / 12 / 16 / 24, don't add 6 because some article said 6 is the new 8.
- **Importing motion language.** Spring vs ease-out vs custom cubic — the
  host has a curve. Use it.
- **Changing the type pairing.** A serif heading + sans body is voice. A
  monospace inline-code style is voice. Replacing them is redesign, not
  refinement.

## When in doubt

- Re-read the user's brief from Phase 1.
- Re-read the design-system docs / tokens file.
- Ask the user.

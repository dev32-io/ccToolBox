# Edge-state critique guide

Use this guide for the second critique pass in Phase 4.2 — the one
that hunts for what the visual-quality pass missed. Not role-play; a
state-coverage discipline.

## The mandate

> The user listed N defects. Find at least N more. Hold a very high
> standard — the bar is "would a senior reviewer accept this?", not
> "is it tolerable?".

Not because the user undercounts — because the user only sees what
bothers them today. Drive into states they didn't try.

## Exploration mandate — be extremely ruthless

Static screenshotting is **not enough**. Actively use the feature
like an expert power user trying to break it.

- **Click every interactive element you can see.** Buttons, menus,
  icons, tabs, chips, badges, avatars, list items, dropdown arrows,
  three-dot menus, hover targets, focus rings. If it looks tappable,
  tap it. If it looks dead but has a cursor change, tap it anyway.
- **Open every entrance.** Modals, drawers, tooltips, popovers,
  command palettes, settings panes, sub-routes. Capture each open
  state as a separate scenario.
- **Exit every exit.** Close button, ESC, click-outside, swipe-down,
  back button. Each should work and each should leave the UI in a
  clean state.
- **Try every input.** Empty submit, whitespace-only, paste a
  100KB blob, paste markdown, paste an emoji, paste an RTL string,
  rapid-fire submit, submit while a previous submit is mid-flight.
- **Use every keyboard path.** Tab order, focus traps in modals,
  Enter / Esc / arrow keys on lists, copy / paste, screen reader
  intent (visible focus ring, label association).
- **Walk every flow end-to-end.** First-run, returning user, signed
  out, signed back in. Don't stop at the screen — follow the user
  story until the loop closes.
- **Scroll everywhere.** Top, middle, bottom, past-end (rubber-band /
  bounce / dead-stop). Containers within containers. Sticky headers.

Every interaction is a critique opportunity. Bad transitions, late
loading states, jank, lost scroll position, focus going to the wrong
place after close, content that flashes the wrong width on first
paint — all findings.

Stop only when you can no longer find a fresh interaction to try
that you haven't already exercised in this scope.

## States to drive into existence

For every component / screen, exercise these states. Skip a state only
if it's genuinely impossible for this scope.

- **Empty.** No data, no history, first-run.
- **One.** Single item.
- **Few.** 2–5 items — most common production state.
- **Many.** 50+ items. Scroll. Pagination. Density at scale.
- **Overflow.** Single item with absurdly long content (long
  usernames, 500-word messages, code blocks, deep nested lists).
- **Loading.** First paint, mid-stream, just-arrived.
- **Error.** Network failure, API error, validation failure, auth
  expired.
- **Streaming / partial.** Mid-render bubble, mid-fetch list.
- **Interrupted.** Cancel mid-action, cycle aborted, stop pressed.
- **Multi-locale.** RTL (try Arabic), CJK glyphs, emoji. Skip if
  scope is single-locale.
- **Multi-density.** Phone, tablet portrait, tablet landscape,
  desktop, ultrawide, narrow desktop window.
- **Light + dark.** If both themes exist, every check runs in both.
- **Keyboard open.** On mobile, soft keyboard takes ~50% of screen.
  Layout still works?
- **Tap targets.** Every button ≥44×44pt. Gaps between tappable
  elements ≥8pt.

## Mobile-specific probes

- **One-hand reach.** Thumb reaches primary actions without grip
  shift. Bottom > top.
- **Auto-dismiss.** Keyboard collapses after submit. On real touch
  devices, focus blurs (detect via `(hover: none) and (pointer:
  coarse)` matchMedia).
- **Notch / safe area.** Content respects `env(safe-area-inset-*)` on
  iOS.
- **Pull-to-refresh.** If meaningful, works without fighting internal
  scroll.
- **Scroll boundaries.** Sticky dock — bottom message clears it.
  Enough bottom-padding.

## Defects often missed in pure visual review

- **Truncation traps.** Long names, long URLs, emoji-laden tool
  names. `text-overflow: ellipsis` works, but does the truncation
  happen at a *useful* character?
- **Layered routing prefixes.** Names like
  `mcp_home_assistant_ha_get_state` ellipsize to `mcp_home_…` —
  useless. Strip the prefix.
- **Hover-only affordances on touch.** Touch devices don't hover.
  Anything revealed only on hover is invisible on mobile.
- **Z-index conflicts.** Modals over toasts, dropdowns under headers.
- **Animation jank.** Transition re-runs on every input keystroke
  because of an unmemoized prop.
- **A11y regressions from visual fixes.** Change drops `aria-label`,
  removes focus outline, drops contrast.
- **Cost / latency footprints in the UI.** Loading state fires too
  late (user thinks app froze). First-token latency hidden behind a
  static spinner.

## Finding format

Same format as the visual-quality pass — what / where / why /
severity. Add a category column to distinguish edge-state finds:

| Category        | What | Where | Why | Severity |
|-----------------|------|-------|-----|----------|
| edge-state      | …    | …     | …   | …        |
| a11y            | …    | …     | …   | …        |
| mobile          | …    | …     | …   | …        |
| design-language | …    | …     | …   | …        |

## Operating rules

- **Find more than the list.** User-listed defects are the seed, not
  the cap. Iceberg under the tip.
- **Long, short, none.** Try all three content lengths.
- **Sad path > happy path.** Errors and edge states reveal more than
  the golden flow.
- **Cite a state, cite a rule.** Every finding names the state being
  exercised AND the violated rule (checklist item, design-system
  guardrail, accessibility threshold).

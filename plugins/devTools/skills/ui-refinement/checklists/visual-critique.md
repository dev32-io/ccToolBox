# Visual critique checklist

Run this checklist on every screenshot in Phase 4.2. Twelve points,
each with a 1-line yes/no test. Any "no" is a finding.

## 1. Hierarchy

- [ ] Does my eye land where it should land first?
- [ ] Is the primary action visually heavier than secondary?
- [ ] Is supporting metadata (timestamps, captions) visibly demoted
      via size, weight, or color?

## 2. Alignment

- [ ] Are repeating elements left-edge or right-edge aligned without
      drift?
- [ ] Are baselines aligned within a row (text-with-icon, label-with-
      input)?
- [ ] Are siblings within a container using the same horizontal
      padding from the container edge?

## 3. Spacing rhythm

- [ ] Do gaps between sibling elements match a consistent value
      (token, not magic)?
- [ ] Is the gap between groups visibly larger than the gap within a
      group?
- [ ] Does padding around a card match top/bottom and left/right?

## 4. Sizing consistency

- [ ] Same kind of element → same size? (avatars, pills, buttons,
      cards)
- [ ] If sizes vary, is there a clear reason (selected state, primary
      vs secondary)?
- [ ] Do all icons in a group share the same render size and visual
      weight?

## 5. Density

- [ ] Does the density match the device convention? (mobile chat:
      tight; desktop dashboard: airy)
- [ ] Is there empty space that feels intentional vs accidental?
- [ ] Do tap targets feel comfortable on this device?

## 6. Type

- [ ] Is the type scale used consistently — heading sizes match each
      other; body matches body?
- [ ] Is line-height comfortable for the font and density (typically
      1.4–1.6 for body)?
- [ ] Are all numbers / dates rendered with the same monospace or
      proportional treatment?
- [ ] Does long content wrap reasonably (no forced single-line
      truncation where multi-line would be fine)?

## 7. Color

- [ ] Body text contrast ≥ WCAG AA (4.5:1 for normal, 3:1 for large)?
- [ ] Are accent colors used sparingly enough to mean something?
- [ ] Does the user-vs-system distinction read on the actual
      background?
- [ ] Light + dark mode both reviewed?

## 8. Motion

- [ ] Do transitions share a consistent duration / easing across
      similar interactions?
- [ ] Is loading / streaming / "in progress" obviously animated, not
      static?
- [ ] Does motion slow down or pause for `prefers-reduced-motion`?

## 9. Edges

- [ ] Border radii consistent across atoms of the same kind?
- [ ] Shadow / elevation language consistent (no random drop-shadows
      mixed with flat cards)?
- [ ] Do the visual atoms share a shape grammar (all rounded vs all
      square)?

## 10. Affordance

- [ ] Can a user tell what's clickable from what's decorative?
- [ ] Tap targets ≥ 44×44 pt on mobile?
- [ ] Spacing between adjacent tap targets ≥ 8 pt?
- [ ] Hover / focus / active / disabled states all visibly distinct?

## 11. Edge states

- [ ] Empty state designed (not blank)?
- [ ] Error state designed and recoverable?
- [ ] Loading state present and not jarring?
- [ ] Long-content overflow handled (ellipsis, scroll, wrap, modal)?
- [ ] Mid-stream / partial state readable?

## 12. Mobile-specific (when in mobile scope)

- [ ] Soft keyboard doesn't hide the input or just-sent content?
- [ ] One-hand reach: primary actions thumb-accessible?
- [ ] Safe-area / notch / home-indicator respected?
- [ ] Does the layout still work when the OS scales up text by 2×?
- [ ] Horizontal scroll on grids / strips legible (peeking next item
      as scroll affordance)?

## How to apply

Walk the list once per screenshot. Skip points that are out-of-scope
(e.g. don't check Color contrast on a screenshot of an empty state —
re-evaluate when content is present).

Findings format:

| # | What | Where | Severity |
|---|------|-------|----------|
| 6 | line-height 1.6 too loose for 14px on phone | `.bubble-text` mobile | minor |
| 11 | empty conversation has no illustration | `.message-list--empty` | nit |

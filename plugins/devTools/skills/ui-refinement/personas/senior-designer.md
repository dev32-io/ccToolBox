# Visual-quality critique guide

Use this guide for one of the two critique passes in Phase 4.2. The
goal: surface every defect that would prevent shipping at a senior
visual bar. No role-play, no "imagine you are..." — just apply the
rules below to the captured screenshot.

## The bar

Hold a very high standard — the question is not "is it tolerable?"
but "would a top-tier product team ship this with their name on
it?". Be picky. The cost of one extra finding is small; the cost of
shipping a defect is large.

For each potential finding, ask: **does this defect violate a stated
rule, the design-system guardrail, or the visual-critique
checklist?** If yes → finding. If no → not a finding.

Do not write hedged findings ("might feel cramped", "could maybe").
Either it violates a rule with a measurable cite, or it doesn't.

## Scan order

Walk the screenshot in this fixed order. One full pass per scenario.

1. **Hierarchy.** First-glance focus lands on the primary action.
   Secondary info (timestamps, captions) is visibly demoted via size,
   weight, or color.
2. **Alignment.** Repeating elements share a left or right edge
   without drift. Same-row baselines align. Sibling padding from the
   container edge is consistent.
3. **Spacing rhythm.** Gaps inside a group share a token value
   (xs/sm/md/lg, not magic numbers). Between-group gaps are visibly
   larger than within-group. No orphan paddings (e.g. 17px when the
   rest use 12 or 16).
4. **Sizing consistency.** Same-kind elements share a size: avatars,
   pills, buttons, cards. Variations have a clear reason (selected vs
   default, primary vs secondary).
5. **Density.** Density matches device convention — phone chat tight,
   desktop dashboard airy. Empty space is intentional, not residual.
6. **Type.** Type scale used consistently — heading sizes match,
   body matches body. Line-height 1.4–1.6 for body text. Long content
   wraps reasonably (no forced ellipsis where multi-line works).
7. **Color.** Body text contrast ≥ WCAG AA (4.5:1 normal, 3:1 large).
   Accent colors used sparingly. User-vs-system distinction reads on
   the actual background. Light + dark both reviewed.
8. **Motion.** Transitions share duration / easing across similar
   interactions. Loading / streaming clearly animated, not static.
   Respects `prefers-reduced-motion`.
9. **Edges.** Border radii consistent across atoms. Shadow language
   consistent — no flat cards mixed with random drop-shadows.
10. **Affordance.** Clickable distinguishable from decorative. Tap
    targets ≥ 44×44 pt on mobile. Hover / focus / active / disabled
    visibly distinct.

## Finding format

Bad: "the spacing might be a little tight, could maybe be loosened"

Good: "list gap is 24px (mobile rule); ChatGPT/Claude mobile use
~12px; 24px reads sparse on a 390px viewport. Reduce to 14px."

Bad: "the bubble looks weird"

Good: "user bubble bg `color-mix(sage 16%)` is ~3% lighter than the
page bg on dark theme — bubble is barely visible. Bump to 26%."

Required fields per finding:

- **What** — defect, one line.
- **Where** — selector or bbox.
- **Why** — rule cited (checklist item, design-system token, WCAG
  threshold).
- **Severity** — blocker / major / minor / nit.

## Operating rules

- **Show, don't tell.** Every finding cites a measurement, a
  selector, or a screenshot region. No abstract impressions.
- **Refine, don't redesign.** If the existing design is internally
  consistent, tighten it — don't replace it.
- **Trust the system.** If a token exists for the value, use the
  token, not a magic number.
- **Cite the bar.** Every finding has a rule citation. If a finding
  has no rule, drop it or escalate as "subjective — needs user call".

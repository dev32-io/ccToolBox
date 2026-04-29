# Shared oracles

Cross-platform heuristics. The Explorer references these by their
fully-qualified name (`shared.<oracle-name>`) when an oracle fires.
Each entry has: what it checks, how to detect, severity hint.

## Conventions

- An oracle "fires" when its check fails. The Explorer logs this in
  the session log with a `?` tag and the oracle name.
- The Reporter classifies fired oracles into bugs (with repro steps)
  or issues (without). A fired oracle does not automatically become a
  bug — it's evidence.
- Severity hints are starting points. The Reporter overrides based on
  user impact.

---

## shared.console-error-free

**Checks:** No `console.error()` calls during the session.

**How to detect:** Use `browser_console_messages` periodically (every
~5–10 tool calls) and after any user-initiated action. Filter for
`level: "error"`. Any match → fire.

**Severity hint:** minor (silent error, no user impact) up to major
(error correlates with broken functionality).

---

## shared.network-no-5xx

**Checks:** No HTTP responses with status 500–599.

**How to detect:** `browser_network_requests` after any action that may
trigger a request. Filter `status >= 500`. Any match → fire.

**Severity hint:** major by default (5xx means the server is broken),
critical if the response is for a user-initiated action that visibly
fails.

---

## shared.network-no-uncaught-4xx

**Checks:** No 4xx HTTP responses on requests the user did not initiate
(implicit fetches, prefetches, telemetry). 4xx on user-initiated
requests is often expected and is best modeled in
`few-hiccupps.user-expectations`.

**How to detect:** `browser_network_requests` filtered to 400–499.
Cross-reference with the previous user action; if no clear user action
preceded the request, fire.

**Severity hint:** minor unless the failed request is for content the
user can see is missing.

---

## shared.few-hiccupps.product-consistency

**Checks:** Information shown by the product is internally consistent
across the screen and across screens. Two places should not contradict
each other (e.g. "1 unread message" badge with "0 messages" in the
inbox).

**How to detect:** During exploration, the Explorer notices the same
piece of information rendered in two places and compares them. This
oracle is judgment-driven — there's no single technical signal.

**Severity hint:** minor for visual contradictions; major if the
contradiction misleads the user about state.

---

## shared.few-hiccupps.history

**Checks:** The current behavior is consistent with history — recent
versions, prior screenshots, prior session logs. If a feature worked
yesterday and doesn't today, fire.

**How to detect:** Compare against `findings/index.json`'s
`recent_first_seen` and any screenshots saved in prior session
directories. If the Explorer notices a behavior change without an
explanation in the diff, fire.

**Severity hint:** major (regressions are usually fixable and
expected-not-broken).

---

## shared.few-hiccupps.user-expectations

**Checks:** Behavior matches what a typical user would reasonably
expect. Form submits, cancel buttons cancel, errors are recoverable,
back-button works.

**How to detect:** Judgment. The Explorer narrates expectations as it
goes ("clicking Cancel should close the dialog"); if reality
disagrees, fire.

**Severity hint:** varies; the Reporter assigns severity from impact.

---

## shared.few-hiccupps.claims

**Checks:** What the product claims about itself (in copy, tooltips,
help text, marketing strings) matches what it does.

**How to detect:** Read product copy as you encounter it. If it says
"automatically saves every 30 seconds" and the Explorer can show that
it doesn't, fire.

**Severity hint:** minor for copy drift; major if the claim is in a
tooltip a user reads while making a decision.

---

## shared.no-uncaught-promise-rejection

**Checks:** No `unhandledrejection` events fire on `window`.

**How to detect:** Inject a listener via `browser_evaluate` at session
start:
```js
window.__qaSessionRejections = [];
window.addEventListener('unhandledrejection', e => {
  window.__qaSessionRejections.push(String(e.reason));
});
```
Periodically read `window.__qaSessionRejections.length`. Any non-zero
→ fire (capture the messages).

**Severity hint:** major (uncaught rejections often correlate with
broken async paths).

---

## shared.no-stuck-state

**Checks:** The UI doesn't get stuck — modals close when their close
button is clicked, spinners resolve, navigation completes.

**How to detect:** When the Explorer initiates an action that should
result in a state change (close a dialog, navigate, submit), it
verifies the change actually happened within a reasonable time
(default 5s). If not, fire.

**Severity hint:** major (stuck state usually blocks the user).

---

## shared.repro-steps-recordable

**Checks:** (Meta-oracle, for the Reporter.) When the Explorer
documents a `?` observation, the session log contains enough detail
that a human or another agent can reproduce the steps. If not, the
observation cannot be promoted to a bug.

**How to detect:** Reporter inspects each `?` line and its surrounding
context. If repro is unclear, the finding goes to `issues` not `bugs`,
and Reporter notes "needs better repro" as the issue's open question.

**Severity hint:** N/A — meta-oracle only.

---

## shared.design-critique

**Checks:** (Meta-oracle, mindset.) Every visible state — every screenshot,
every layout, every interaction outcome — must withstand the eye of a
critical senior designer and a frustrated real user. "It works" is not
enough. "It looks good in code" is not enough. The question is: would a
team that cares about polish ship this?

This oracle exists to counteract the Explorer's natural bias toward
technical correctness (no console error → "passes"). Many of the worst
defects in shipped software are perfectly correct in code and obviously
broken to anyone looking at the screen.

**How to detect:** After every screenshot and after every interaction
that changes the visible state, the Explorer pauses and runs this
checklist out loud in the session log (1–2 sentences each, with `?`
when something is off):

- **Layout & alignment** — are elements aligned to the same baseline /
  edge as their siblings? Is the visual rhythm consistent?
- **Sizing consistency** — do items in a list/grid/repeated container
  have the same dimensions? Did one tile suddenly grow / shrink because
  of state change?
- **Overlap & collision** — do icons sit on top of text? Do badges
  cover content? Do floating buttons block what they're attached to?
- **Truncation & overflow** — does text clip awkwardly mid-word, push
  out of its container, or break the layout?
- **Spacing** — does padding feel intentional and consistent, or
  cramped/random in places?
- **Interaction sense** — does what just happened make sense for the
  thing the user clicked? Did clicking "select" cause the tile to
  resize, change content layout, or shove neighbors? Is selection
  ambiguous (no visible indicator) or over-loud (whole layout
  rearranges)?
- **Animation & transitions** — janky? Missing? Too long? Stuttering?
  Loading flashes between states?
- **Empty / loading states** — do skeletons match the eventual content
  shape, or do they shift the layout when real data arrives?
- **"Would a designer ship this?"** — close one eye and look. If the
  answer is "I'd ask the designer to fix that before merge," fire.

**Lower the bar. No visual / UX defect is too small to flag.** The
Reporter judges severity later. Your job is to NOTICE.

**Severity hint:** varies. Visual polish bugs that affect a single
non-critical view are minor; broken layouts on primary flows are
major; a defect that misleads the user about what's selected /
happening is major-to-critical.

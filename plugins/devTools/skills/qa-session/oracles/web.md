# Web oracles

Web-platform-specific heuristics. Reference as `web.<oracle-name>`.

---

## web.tap-target-min-44px

**Checks:** Interactive elements (buttons, links, form controls) have
a minimum tap-target size of 44×44 CSS pixels (Apple HIG / Material).

**How to detect:** For each interactive element discovered via
`browser_snapshot`, run `browser_evaluate` to read `getBoundingClientRect()`
and check both `width >= 44` and `height >= 44`. Allow inline links
inside text blocks to be smaller (heuristic: parent has `display:
inline` or is a `<p>` / `<li>`).

**Severity hint:** minor for desktop, major for mobile-viewport
charters (when `target.viewport == "mobile"`).

---

## web.viewport-no-horizontal-scroll

**Checks:** The page does not produce a horizontal scrollbar at
common viewport widths (375, 768, 1024, 1440 px).

**How to detect:** After load, `browser_evaluate`:
```js
document.documentElement.scrollWidth > document.documentElement.clientWidth
```
Returns true → fire. Capture which element overflows by walking the
tree for elements with `getBoundingClientRect().right > window.innerWidth`.

**Severity hint:** minor on desktop, major on mobile.

---

## web.aria-required-fields

**Checks:** Form fields marked as required (visible asterisk, "required"
label, or HTML `required` attribute) also have `aria-required="true"`
or the HTML attribute.

**How to detect:** `browser_evaluate` over `document.querySelectorAll('input, textarea, select')`,
inspect each for visual required indicators in the surrounding label.
Compare against the element's `required` and `aria-required`
attributes. Mismatch → fire.

**Severity hint:** minor (accessibility), but accumulating these is a
sign the project lacks an a11y review.

---

## web.no-broken-images

**Checks:** No `<img>` element fails to load (zero `naturalWidth` after
`load` event).

**How to detect:** `browser_evaluate`:
```js
Array.from(document.images)
  .filter(img => img.complete && img.naturalWidth === 0)
  .map(img => img.src);
```
Non-empty result → fire (one issue per src).

**Severity hint:** minor for decorative images, major for content
images, critical for icons that convey meaning (button icons, etc.).

---

## web.no-blank-render-after-3s

**Checks:** After navigation, the rendered page has visible content
within 3 seconds. A blank-white screen for >3s is almost always a bug.

**How to detect:** After `browser_navigate`, wait for `networkidle`,
then `browser_evaluate`:
```js
document.body.innerText.trim().length > 0 ||
document.body.querySelectorAll('img, svg, canvas, video').length > 0
```
False → fire.

**Severity hint:** critical (user sees nothing).

---

## web.no-layout-shift-after-load

**Checks:** Visible elements don't jump around after the initial
render (Cumulative Layout Shift).

**How to detect:** Inject a PerformanceObserver for `layout-shift`
entries at session start; read accumulated CLS after the page is
"stable" (no network for ~1s):
```js
let cls = 0;
new PerformanceObserver(list => {
  for (const entry of list.getEntries()) {
    if (!entry.hadRecentInput) cls += entry.value;
  }
}).observe({ type: 'layout-shift', buffered: true });
```
CLS > 0.1 → fire (Google's "needs improvement" threshold).

**Severity hint:** minor for cosmetic shifts, major when shifting
elements cause misclicks (button moves under the cursor).

---

## web.focus-visible-on-keyboard

**Checks:** Keyboard focus produces a visible focus ring.

**How to detect:** Tab through the page (`browser_press_key` "Tab"
several times). After each press, take a screenshot. Inspect each
shot: is there a visible ring/outline on the newly-focused element?
Use `browser_evaluate` to query
`document.activeElement` and confirm `getComputedStyle(el).outline`
is not `none` and `outlineWidth > 0`.

**Severity hint:** minor (a11y), but a focus-trap or invisible focus
during keyboard navigation is major.

---

## web.no-zombie-network-requests

**Checks:** No network requests fire after the page is "settled" (no
user interaction for 10+ seconds).

**How to detect:** After any settled period, capture
`browser_network_requests` count. After waiting another 10s with no
user action, capture again. New requests in that window with no
clear cause (heartbeat, websocket, telemetry) → fire.

**Severity hint:** minor, but accumulating zombie requests is a sign
of poll loops or leaked subscriptions.

---

## web.no-element-overlap

**Checks:** Visible UI elements don't unintentionally overlap each other.
Icons don't sit on top of text. Action buttons don't cover content.
Badges / decorations don't collide with the labels they're attached to.

**How to detect:** This is primarily a **screenshot judgment** call,
not a DOM query — overlapping elements often pass `getBoundingClientRect`
sanity checks because they're absolutely positioned by design. After
every screenshot, look at it as a user. Trace each interactive element
and ask: is anything sitting on top of something else? Is text legible
where icons / play buttons / checkmarks land?

A useful complement: `browser_evaluate` to inspect `z-index` stacks and
overlapping bounding boxes for elements within the same container, but
the screenshot eye is the primary detector.

**Severity hint:** minor for decorative overlaps a user can ignore;
major when overlap obscures content or controls; critical when it
makes the action ambiguous (which button am I clicking?).

---

## web.consistent-grid-tile-size

**Checks:** Items in a repeating list / grid / row container have
consistent dimensions. If one card is taller, wider, or laid out
differently from its siblings without an obvious design reason
(e.g. "featured" badge, hovered state), fire.

**How to detect:** When a screen contains a list/grid of similar items
(voices, personalities, models, conversation history, etc.), capture
a screenshot showing several at once. Look at them side by side. Are
all tiles the same height? Same width? Same internal layout?

If clicking one tile changes its size or internal layout while the
siblings remain unchanged, that's almost always a defect — fire and
record both before/after screenshots.

`browser_evaluate` can confirm:
```js
Array.from(document.querySelectorAll('[data-tile-selector]'))
  .map(el => ({ w: el.offsetWidth, h: el.offsetHeight }));
```
Variance > a few pixels in a "should be uniform" container → fire.

**Severity hint:** minor for slight rendering differences; major when
the inconsistency makes the active selection ambiguous or breaks the
visual rhythm of the page.

---

## web.no-jarring-reflow-on-interact

**Checks:** Clicking, selecting, hovering, or focusing an element
should not cause significant layout shift in surrounding content.
Selecting a tile in a grid should NOT make that tile resize, push
neighbors, or change its internal text wrapping.

**How to detect:** Before any meaningful interaction (click on a tile,
toggle, expand), take a screenshot. Perform the interaction. Take
another screenshot. Compare the two visually:

- Did the clicked element change dimensions?
- Did siblings shift position?
- Did text rewrap inside the clicked element?
- Did the page jump / scroll position change unexpectedly?

If any of those occurred, fire. Capture both screenshots.

A confirmed-selected indicator (border, checkmark, color change) is
expected and good. A reflow that resizes the tile or rearranges its
contents is the defect this oracle catches.

**Severity hint:** minor for tiny reflows; major when the reflow is
disorienting or pushes content the user was aiming at.

---

## web.no-text-clipping

**Checks:** Text doesn't clip mid-word, get cut off by container
edges, or overflow into adjacent elements. Designed truncation (CSS
`text-overflow: ellipsis` with the `…` glyph visible) is acceptable;
hard clipping, unintended truncation, or text that visibly extends
past its container is not.

**How to detect:** Screenshot judgment. Read every visible text block
in each screenshot. If you see text that ends abruptly mid-word
without an ellipsis, or text bleeding past its container's apparent
boundary, fire.

DOM complement:
```js
Array.from(document.querySelectorAll('*'))
  .filter(el => el.scrollWidth > el.clientWidth + 1
             || el.scrollHeight > el.clientHeight + 1)
  .filter(el => getComputedStyle(el).overflow === 'hidden')
  .map(el => ({ tag: el.tagName, text: el.innerText.slice(0,60) }));
```
Non-empty result → fire (cross-check against intentional truncation
patterns by inspecting whether ellipsis CSS is set).

**Severity hint:** minor for cosmetic clip; major when clipping hides
information the user needs (e.g. truncated description, cut-off
button label).

---

## web.no-loading-flash

**Checks:** No visibly jarring content flash during initial render,
hot reactions, or state transitions. Examples: page renders
unstyled-then-styled, component pops in late, skeleton briefly shows
then real content with different layout, modal appears at wrong size
then resizes.

**How to detect:** During every navigation or significant action that
re-renders content, watch attentively. If you see two distinct visual
states in rapid succession that don't feel like a designed transition
(fade, slide, etc.), fire.

`PerformanceObserver` for `layout-shift` (see `web.no-layout-shift-after-load`)
helps quantify, but the human-eye signal is primary: "did I see
something flash that shouldn't have flashed?"

**Severity hint:** minor for sub-100ms cosmetic flashes; major when
the flash makes the page feel broken or unprofessional, or when it
flashes content the user shouldn't see (e.g. error state briefly
visible during a successful flow).

---

## web.alignment-and-spacing

**Checks:** Elements within and across containers are aligned and
spaced consistently. Cards in a row align to the same top baseline.
Form fields share a consistent gutter. Buttons in a button row don't
have random gaps. Internal padding of similar containers matches.

**How to detect:** Screenshot inspection. For each composite layout,
trace imaginary alignment lines:

- Do the tops / bottoms / left edges of sibling cards line up?
- Is the spacing between siblings the same throughout the row?
- Do labels and their fields share the same baseline?
- Does the internal padding of cards / panels feel intentional and
  uniform across siblings?

Misalignments of more than ~2px that aren't designed asymmetry → fire.

**Severity hint:** minor (polish issues), but cumulative misalignment
in a primary flow is a major sign that something rendered wrong.

---

## web.coop-coep-headers-when-needed

**Checks:** If the app uses `SharedArrayBuffer` (AudioWorklet,
WebAssembly threads, OffscreenCanvas), the response headers include
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`.

**How to detect:** `browser_network_requests` for the document
request — inspect response headers. Cross-reference with `browser_evaluate`:
```js
typeof SharedArrayBuffer !== 'undefined'
```
If SAB is undefined but the app appears to need it (audio, threads),
fire.

**Severity hint:** critical for audio/worklet apps.

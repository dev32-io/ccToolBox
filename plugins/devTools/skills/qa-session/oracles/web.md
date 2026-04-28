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

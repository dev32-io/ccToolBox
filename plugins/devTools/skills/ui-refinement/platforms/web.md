# Web — Playwright / Chrome DevTools MCP

The default and most-tested platform for `ui-refinement`. The agent
drives a real Chromium / WebKit / Firefox via MCP tools that return
both DOM accessibility snapshots (good for clicking + reading state)
and rasterized screenshots (good for visual critique).

## MCP gating (deferred tools)

Run this `ToolSearch` call once at the start of Phase 2 to load the
Playwright MCP tool schemas into context:

```
ToolSearch query="select:mcp__plugin_playwright_playwright__browser_navigate,mcp__plugin_playwright_playwright__browser_resize,mcp__plugin_playwright_playwright__browser_snapshot,mcp__plugin_playwright_playwright__browser_click,mcp__plugin_playwright_playwright__browser_fill_form,mcp__plugin_playwright_playwright__browser_type,mcp__plugin_playwright_playwright__browser_take_screenshot,mcp__plugin_playwright_playwright__browser_evaluate,mcp__plugin_playwright_playwright__browser_press_key,mcp__plugin_playwright_playwright__browser_wait_for,mcp__plugin_playwright_playwright__browser_console_messages,mcp__plugin_playwright_playwright__browser_network_requests,mcp__plugin_playwright_playwright__browser_close"
```

If the Playwright MCP plugin is not installed, fall back to Chrome
DevTools MCP:

```
ToolSearch query="select:mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page,mcp__plugin_chrome-devtools-mcp_chrome-devtools__resize_page,mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_snapshot,mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot,mcp__plugin_chrome-devtools-mcp_chrome-devtools__click,mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill,mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script,mcp__plugin_chrome-devtools-mcp_chrome-devtools__wait_for,mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages"
```

If neither is installed, surface the gap to the user and stop:

> `ui-refinement` (web) needs the Playwright MCP plugin (preferred) or
> Chrome DevTools MCP. Install one via the Claude Code plugin marketplace
> and re-run.

## Viewport recipes

Common phone / tablet / desktop sizes the loop should cover when
"mobile + desktop" is in scope:

| Profile        | Width | Height |
|----------------|-------|--------|
| iPhone SE      | 320   | 568    |
| iPhone 14      | 390   | 844    |
| iPhone 14 Pro Max | 430 | 932    |
| Pixel 7        | 412   | 915    |
| iPad mini portrait | 768 | 1024 |
| iPad Pro portrait  | 1024| 1366 |
| Narrow desktop | 1280  | 900    |
| Standard desktop | 1440| 900    |
| Wide desktop   | 1920  | 1080   |

Phone-first phase: drive at least 320, 390, and one tablet width to
catch breakpoint regressions. Skip 1920 unless the design has wide-
specific layout.

## HMR-friendly dev loop

Most modern web stacks ship a HMR dev server (Vite, Next.js dev,
webpack-dev-server). The skill's per-pass cycle is fastest when the
agent edits source files and the dev server picks them up automatically.

Common dev-server URLs:

- Vite default: `http://localhost:5173`
- Next.js default: `http://localhost:3000`
- Storybook: `http://localhost:6006`
- Custom proxy: check `vite.config.ts` / `next.config.js` for the proxy
  block — the dev server typically proxies `/api` to the backend.

> **Stale-bundle pitfall.** If a CSS / TS edit doesn't appear after
> reload, the dev server may be running from a different working
> directory (worktree leftover, abandoned process). Verify by:
>
> ```bash
> lsof -p $(lsof -iTCP:5173 -sTCP:LISTEN -t) -d cwd
> ps -p <pid> -o pid,command
> ```
>
> If the path doesn't match your current checkout, kill the stale
> process and start fresh.

## Inspecting state without re-driving

When the user has already navigated through a multi-step flow and you
just want to capture without re-entering everything, prefer:

- `browser_evaluate` with a small JS snippet to inject test state or
  click an internal route directly — faster than re-doing wizard steps
  and only valid in dev.
- `localStorage` / `sessionStorage` poking via evaluate to skip auth
  walls in dev environments.

For real critique you usually want the actual rendered state from a
real flow — invoke that flow once at the start of Phase 4 and reuse the
session.

## Screenshot vs snapshot

`browser_take_screenshot` returns a PNG — use for visual critique.

`browser_snapshot` returns a structured accessibility tree with element
refs and (with `boxes: true`) bounding boxes — use for measurements and
for getting `ref` IDs to pass to `click` / `type`.

For a single critique pass: take both. The screenshot tells you what
the user sees; the snapshot tells you what the code thinks it
rendered. Mismatches between them are bugs.

## Common gotchas

- **Self-signed cert.** Many local dev stacks use HTTPS with a
  self-signed cert. Playwright MCP accepts the cert by default in dev.
  If you hit cert errors, the user must visit the URL once in their
  real browser to accept it.
- **Auth walls.** First-run setup wizards / login flows block the
  critique. Either drive through the wizard once and reuse the session,
  or seed credentials directly via the dev API.
- **WebSockets.** If the screen relies on a WS for live updates (chat
  apps, dashboards), `browser_navigate` opens it — don't refresh
  unnecessarily; refresh resets WS state.
- **Animation timing.** Screenshots taken mid-animation show a frozen
  frame. For motion critique, capture multiple frames or use
  `prefers-reduced-motion` to disable animation in the critique pass.

# iOS — Simulator-driven inspection

> **Status: best-effort.** Native iOS UI refinement via an MCP is less
> mature than web. The skill works in two modes: (a) an iOS-simulator
> MCP if installed, (b) a manual screenshot loop where the user drives
> the simulator and pastes screenshots, the agent critiques + edits.

## Mode A — iOS simulator MCP

If a plugin like `xcodebuild-mcp` or `ios-simulator-mcp` is installed,
gate the deferred tools via `ToolSearch`:

```
ToolSearch query="ios simulator screenshot tap launch" max_results=10
```

Surface the matched tools to the user; if none are MCP-shaped tools for
driving a simulator, fall back to Mode B.

A working iOS-simulator MCP typically exposes:

- `boot_simulator(device, runtime)`
- `launch_app(bundle_id)`
- `screenshot()` → PNG of current simulator state
- `tap(x, y)` / `tap_element(accessibility_id)`
- `type_text(text)`
- `set_orientation(portrait | landscape)`

Use them in the same per-pass loop as web: capture → critique → edit
SwiftUI/UIKit source → rebuild (slow, see below) → re-capture.

## Mode B — Manual screenshot loop (fallback)

When no MCP is available, run a back-and-forth loop:

1. Agent: "Please run the app on iPhone 15 simulator at iOS 17, navigate
   to the chat screen with at least 3 messages, and paste a screenshot
   here."
2. User: drives the simulator, pastes screenshot.
3. Agent: critiques, proposes edits.
4. User: applies, rebuilds (or asks the agent to apply via `Edit`).
5. Agent: "Please re-screenshot at the same state."
6. Repeat.

Slower than web (every change requires a Cmd-R rebuild), but still
delivers the live-inspection magic.

## Build cycle protection

Native iOS builds take 30s–5min depending on project size. Set
expectations early:

- Bundle 3–5 visual fixes per build cycle when possible.
- Ask the user before triggering `xcodebuild` — they may want to drive
  the build themselves to avoid Xcode lock conflicts.
- Use SwiftUI previews (`#Preview` blocks) for the tightest iteration
  loop on individual views — preview rebuilds are sub-second. The skill
  can edit a Preview file with controlled fixture data and the user
  watches the canvas update live.

## Device matrix

| Profile        | Logical width | Logical height |
|----------------|---------------|----------------|
| iPhone SE (3rd) | 375          | 667            |
| iPhone 15      | 393           | 852            |
| iPhone 15 Pro Max | 430        | 932            |
| iPad mini      | 744           | 1133           |
| iPad Pro 11    | 834           | 1194           |

Plus Dynamic Type (Accessibility sizes) — the ruthless-tester pass
should at least mentally walk through XL / XXL text sizes.

## Common gotchas

- **Safe-area insets.** Top notch + bottom home indicator each take
  ~34pt. Content must respect `safeAreaInsets` or use
  `.safeAreaPadding`.
- **Tab bar height.** ~83pt with home indicator. Bottom-anchored
  content needs to clear it.
- **Keyboard height.** ~336pt portrait. The view controller must shift
  content up via `keyboard avoidance` or the input vanishes behind the
  keyboard.
- **Dark mode.** iOS triggers system-level dark mode; ensure your
  app's appearance follows or explicitly opts out.
- **Dynamic Type.** Body text scales 12–48pt across user settings.
  Hard-coded fonts break this.

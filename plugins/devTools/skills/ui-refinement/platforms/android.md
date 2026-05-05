# Android — Emulator / adb-driven inspection

> **Status: best-effort.** Like iOS, native Android refinement via MCP
> is less mature than web. Two modes: (a) an Android emulator MCP if
> installed, (b) `adb` + manual screenshot loop.

## Mode A — Android emulator MCP

Look for plugins like `android-mcp`, `adb-mcp`, or
`uiautomator-mcp`. Gate via `ToolSearch`:

```
ToolSearch query="android emulator adb screenshot tap" max_results=10
```

If matched tools include `screenshot`, `tap_at`, `input_text`,
`key_event`, drive the loop the same way as web.

## Mode B — adb + manual screenshot loop

`adb` exposes everything needed; just slower than MCP-mediated.

```bash
# Capture a screenshot of the current emulator state
adb exec-out screencap -p > screen.png

# Tap at coordinates (x y in screen pixels)
adb shell input tap 540 1200

# Type text into the focused field (replace spaces with %s)
adb shell input text "hello%sworld"

# Press enter / back / home
adb shell input keyevent 66    # KEYCODE_ENTER
adb shell input keyevent 4     # KEYCODE_BACK
adb shell input keyevent 3     # KEYCODE_HOME
```

The skill can run these via `Bash`. The user pastes the resulting
screenshot back when the agent doesn't have direct MCP read access.

## Build cycle protection

Android builds via `./gradlew assembleDebug` take 20s–3min. Use Compose
Previews for sub-second iteration on individual composables — the
preview canvas in Android Studio updates live as the agent edits the
preview's fixture data.

## Device matrix

| Profile        | dp width | dp height |
|----------------|----------|-----------|
| Compact phone  | 360      | 640       |
| Pixel 7        | 411      | 891       |
| Pixel Tablet portrait | 800 | 1280   |
| Foldable inner | 673      | 841       |

Plus font-scale sliders 0.85x–2.0x — verify large-font scaling for
accessibility.

## Common gotchas

- **System UI insets.** Status bar (24dp), navigation bar (48dp gesture
  / 48dp 3-button). Use `WindowInsets` APIs.
- **Edge-to-edge.** Modern Android wants edge-to-edge content with
  proper inset handling — easy to break by hard-coding paddings.
- **Material 3 vs custom.** Most apps use Material; if the project
  uses a custom design system, the design-system guardrail is doubly
  important — Material defaults can creep in via Compose.
- **Keyboard.** Soft keyboard ~280dp portrait. `WindowSoftInputMode`
  controls whether content shifts or resizes.

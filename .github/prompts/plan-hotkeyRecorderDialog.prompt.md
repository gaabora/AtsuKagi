# Plan: Rewrite HotkeyRecorderDialog to Use AHK-Level Recording

## TL;DR
Replace the JS `keydown`-based hotkey capture in `HotkeyRecorderController` with an AHK-level low-level keyboard hook (`WH_KEYBOARD_LL`). The web UI remains the dialog shell (open/close, display, options, apply/cancel) with some changes and needed additions like "distinguish L/R modifiers", "capture mouse" and  "capture gamepad" flags (on by defaut), "Modifiers-only hotkey", etc, but delegates actual key recording to AHK, which pushes captured hotkey strings back to JS for live display.

## Problem
The current `HotkeyRecorderController._onRecordKey(ev)` uses browser `keydown` events. This fails for:
- Keys suppressed by WebView2/Chromium (e.g., F-keys, media keys, Print Screen)
- Keys that trigger browser shortcuts (e.g., Ctrl+W, Ctrl+T)
- Distinguishing L/R modifiers (JS sees only "Control", not LCtrl vs RCtrl)
- Mouse buttons, joystick, special hardware keys

## Approach
Port the core keyboard hook logic from `tmp/Hotkey-master/Hotkey.ahk` (v1) to AHK v2, wrapped as a self-contained "HotkeyRecorder" class. The class installs a temporary LL hook during recording, tracks modifier state, builds the hotkey string, and pushes updates to the JS UI via `ExecuteScriptAsync`.

---

## Steps

### Phase 1: AHK — HotkeyRecorder Class (new file)

**File:** `includes/HotkeyRecorder.ahk`

1. Create class `HotkeyRecorder` with these methods/properties:
   - `StartRecording(options)` — Install `WH_KEYBOARD_LL` hook via `DllCall("SetWindowsHookExW", ...)`. Store options (keyboard, mouse, distinguish L/R, wildcard, passthrough).
   - `StopRecording()` — Unhook via `DllCall("UnhookWindowsHookEx", ...)`. Reset state.
   - `GetResult()` → `Map("raw", "<^+A", "display", "LCtrl + Shift + A")`
   - Internal: `_LowLevelKeyboardProc(nCode, wParam, lParam)` — callback that extracts VK/SC from `KBDLLHOOKSTRUCT`, routes to modifier tracking or key capture.
   - Internal: `_ProcessKey(vk, sc, isDown)` — state machine: track modifiers on down/up, on non-modifier keydown build `prefix + keyName` string.
   - Internal: `_BuildPrefix()` — concatenate active modifier prefixes (`<^`, `>!`, etc.)
   - Internal: `_VkToName(vk, sc)` — map VK/SC to AHK key name (reuse `GetKeyName("vk" hex)` in v2).
   - Property: `OnKeyRecorded` — callback invoked with `(rawHotkey, displayString)` every time the captured hotkey changes (so UI updates live).
   - Property: `IsRecording` — bool state flag.

2. **Port from v1 reference** — Specific logic to convert from `tmp/Hotkey-master/Hotkey.ahk`:
   - `Hotkey_LowLevelKeyboardProc()` (lines 100-130) → `_LowLevelKeyboardProc()` — same VK/SC extraction via `NumGet`, same heap-copy pattern replaced with simpler v2 Buffer approach.
   - `Hotkey_Main("Mod"|"ModUp"|VK,SC)` (lines 26-85) → `_ProcessKey()` — same modifier state map (`K.MLCtrl`, `K.PRCtrl`, etc.), same prefix building.
   - `Hotkey_SetWindowsHookEx()` → v2 `DllCall("SetWindowsHookExW", "Int", 13, "Ptr", callback, "Ptr", DllCall("GetModuleHandle","Ptr",0,"Ptr"), "UInt", 0, "Ptr")` with `CallbackCreate`.
   - `Hotkey_HKToStr()` → `_ToDisplayString()` — convert `<^+A` to `LCtrl + Shift + A`.
   - Modifier map (static): `{vkA4:"LAlt", vkA5:"RAlt", vkA2:"LCtrl", vkA3:"RCtrl", vkA0:"LShift", vkA1:"RShift", vk5B:"LWin", vk5C:"RWin"}`
   - English symbol map: `{vkBB:"=", vkBC:",", ...}` for layout-independent key names.

3. **v1→v2 conversion notes:**
   - `RegisterCallback("fn", "F")` → `CallbackCreate(this._LowLevelKeyboardProc.Bind(this), "F", 3)`
   - `NumGet(lParam+0, "UInt")` → `NumGet(lParam, 0, "UInt")` (same but 3-arg syntax)
   - `DllCall("HeapAlloc"...)` pattern → use AHK v2 `Buffer(16)` + `DllCall("RtlMoveMemory",...)`
   - Static/class variables instead of function-static
   - `Format("vk{:X}", ...)` stays the same
   - `GetKeyName()` works in v2 as-is
   - Labels (`Hotkey_PressName:`) → method calls
   - `#IF` context sensitivity not needed (hook is manually installed/removed)

### Phase 2: AHK — Integration into AKGui

**File:** `includes/AKGui.ahk`

4. Add `#Include HotkeyRecorder.ahk` and instantiate recorder in the GUI class.

5. Register two new JS→AHK callbacks:
   - `StartHotkeyRecording(optionsJson)` — parse options (wildcard, passthrough, mouse, L/R distinguish), call `this.recorder.StartRecording(options)`. Set `OnKeyRecorded` to push updates to JS.
   - `StopHotkeyRecording()` — call `this.recorder.StopRecording()`, return final result JSON.

6. In `OnKeyRecorded` callback, push live updates to JS:
   ```ahk
   nw.ExecuteScriptAsync("window._onAhkHotkeyRecorded(" jsonPayload ")")
   ```
   Where payload = `{"raw": "<^+A", "display": "LCtrl + Shift + A"}`

### Phase 3: JS — Refactor HotkeyRecorderController

**File:** `includes/ui/classes/HotkeyRecorderController.js`

7. Remove `_onRecordKey(ev)` method and its `keydown` event listener.

8. Remove `_toAhkHotkey(ev, wildcard, passthrough)` method (no longer needed).

9. In `_onRecordButtonClick()`:
   - After showing the dialog, call AHK to start recording:
     ```js
     const opts = { wildcard: ..., passthrough: ..., mouse: false };
     window.chrome.webview.hostObjects.sync.StartHotkeyRecording(JSON.stringify(opts));
     ```

10. Add global receiver function:
    ```js
    window._onAhkHotkeyRecorded = function({ raw, display }) {
      // Update dialog display
      document.getElementById('hotkeyRecordReadable').textContent = display;
      document.getElementById('hotkeyRecordStatus').textContent = 'Captured. Press Apply...';
      // Store pending
      hotkeyRecorderInstance.pendingRaw = raw;
    };
    ```

11. In `close()`/`cancel()` and at the end of `apply()`:
    - Call `window.chrome.webview.hostObjects.sync.StopHotkeyRecording()` to unhook.

12. `apply()` logic stays mostly the same — it already uses `pendingRaw` to save via `hostBridge.saveHotkey()` or `hostBridge.addHotkey()`.

### Phase 4: Options Handling

13. The wildcard (`*`) and passthrough (`~`) checkboxes in the dialog should be read at recording start (passed to AHK) OR applied as prefix decorators at apply-time in JS (simpler). **Recommendation:** Apply them in JS at apply-time since they're just string prefixes — no need to complicate the AHK recorder with them.

---

## Relevant Files

| File | Role |
|------|------|
| `tmp/Hotkey-master/Hotkey.ahk` | v1 reference: `Hotkey_LowLevelKeyboardProc`, `Hotkey_Main`, modifier maps |
| `tmp/Hotkey-master/Current/Hotkey.ahk` | Most evolved v1 version (v2.09), cleaner structure |
| `includes/ui/classes/HotkeyRecorderController.js` | Current JS recorder — refactor target |
| `includes/ui/classes/AhkHostBridge.js` | JS→AHK bridge — add new method calls |
| `includes/AKGui.ahk` | Register new `AddCallbackToScript` entries |
| `includes/AKApp.ahk` | Existing `BindHotkey()`, `convertToUniversalVkHotkey()` — reuse |
| `lib/WebViewToo-main/Lib/WebViewToo.ahk` | `ExecuteScriptAsync()` for AHK→JS push |

## Verification

1. Click recorder button → dialog opens, LL hook installs
2. Press any key combo (media keys, F-keys, LCtrl vs RCtrl, mouse buttons/wheel) → live display updates
3. Apply → saves correctly, dialog closes, hook removed
4. Cancel/Escape → hook removed, no side effects
5. Confirm no residual hook (keys work normally after close)
6. Existing `BindHotkey()` still works with new recorder output format

## Decisions

- **IN scope:** Keyboard LL hook, L/R modifier distinction, live push to JS, integration with existing save flow
- **IN scope:** Mouse buttons, joystick, double-click/chord, ban keys, group collision
- **Wildcard/passthrough:** String prefix applied in JS, not in AHK recorder
- **Hook lifetime:** Installed only during active recording, removed immediately on dialog close
- **No native AHK GUI controls:** The recorder dialog remains a web UI element; only the key capture moves to AHK

## Further Considerations

1. **Mouse capture** — Need to add `WH_MOUSE_LL` (hook 14)
2. **Modifiers-only hotkeys** — "just LCtrl" as a hotkey (option "Z" in v1 lib). Recommend basic support since it's a few extra lines in the state machine (detect all-released after modifiers-only press).
3. **InputHook alternative** — AHK v2's built-in `InputHook` is simpler but can't distinguish L/R modifiers or capture all special keys. LL hook is the right choice.

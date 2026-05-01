# app.js Rewrite Plan

## Status

Implemented. This file is kept as a historical planning reference; current-state details are tracked in [APP_JS_REWRITE_IMPLEMENTATION_SUMMARY.md](APP_JS_REWRITE_IMPLEMENTATION_SUMMARY.md).

## Scope

Rewrite the settings page client code in [includes/ui/app.js](includes/ui/app.js) using modern JavaScript, class-based structure, and stricter separation of concerns, while preserving compatibility with [includes/ui/settings.html](includes/ui/settings.html) and the WebView2 bridge in [includes/AKGui.ahk](includes/AKGui.ahk).

This is a surgical rewrite of the settings UI behavior. It is not a visual redesign and it should not change the persisted config contract unless explicitly planned in a later phase.

## Current Problems

1. UI logic, host interop, formatting helpers, and modal behavior all live in one file.
2. The script depends on globals such as `ahk`, `showSection`, `settingsUiState`, and `window.SettingsUiBridge`.
3. Event wiring is split between JavaScript and inline HTML handlers.
4. The AHK layer populates the page by executing many direct DOM statements instead of applying a single state payload.
5. DOM lookup is repetitive and scattered, which makes the code brittle and harder to maintain.
6. Some control flow is easy to misread, especially around event handlers that rely on single-line `if` statements.
7. Initialization relies on repeated refresh calls instead of a deterministic lifecycle.

## Rewrite Goals

1. Replace global function sprawl with a small set of focused classes.
2. Keep one-way flow where possible: host payload -> page state -> rendered DOM.
3. Hide WebView2 host details behind a dedicated bridge class.
4. Centralize DOM lookup and field serialization.
5. Make modal controllers self-contained.
6. Remove inline event handlers from the HTML.
7. Preserve the existing save payload and user-facing behavior unless there is a clear bug fix.

## Non-Goals

1. Do not redesign the page layout or CSS.
2. Do not change config keys or plugin semantics.
3. Do not refactor unrelated AHK code outside the settings bridge path.
4. Do not introduce a bundler, framework, or TypeScript for this rewrite.

## Proposed Architecture

### 1. `AhkHostBridge`

Purpose: isolate all WebView2 host-object access.

Responsibilities:

1. Resolve `window.chrome.webview.hostObjects.sync` safely.
2. Expose methods:
   - `saveSettings(payload)`
   - `cancel()`
   - `browseForFile(currentPath)`
   - `minimize()`
3. Convert page payload into the positional `SettingsSave(...)` argument order expected by AHK.
4. Fail safely when the host object is unavailable.

### 2. `SettingsDom`

Purpose: cache frequently used elements and provide DOM helpers.

Responsibilities:

1. Collect key elements once during initialization.
2. Provide helpers for:
   - field access by id
   - section lookup
   - nav item lookup
   - plugin checkbox collection
3. Reduce repeated `document.getElementById(...)` calls.

### 3. `SettingsForm`

Purpose: own settings state projection between DOM and data.

Responsibilities:

1. Read values from the form into a normalized payload.
2. Apply incoming state to the form.
3. Refresh derived UI:
   - transparency slider label and fill
   - hotkey readable previews
   - border color swatch
4. Render plugin list, hotkeys table, logs, and problems.

Suggested payload shape:

```js
{
  general: {
    WelcomeMessage: '',
    DarkTheme: '-1',
    ToolTipTimeoutMs: '',
    WindowTransparencyValue: '128',
    WindowOnTopBorderColor: '0xFFFFFF',
    StartupSound: '',
    NotificationSound: '',
    ReloadAppHotkey: '',
    SuspendAppHotkey: '',
    SwapMouseXButtons: false,
  },
  plugins: [
    { name: "KDEMoverSizer", 
        description: "..." // from ahk plugins class __UsageHelp 
        config: [], // __ConfigHelp
        actions: [ { name: "...", help: "...", ...}, ... ] //__ActionsHelp
        ...
    }, ...
  ],
  hotkeys: [
    { hotKey: "Win + Alt + MButton", action: 'ToggleHoveredWindowFullScreen',  ahkKey: "#!MButton", ... },
    ...
  ],
  logsText: '', // to be parsed to timestamp + loglevel + text
  problemsText: '', // to be parsed to timestamp + loglevel + text
  theme: 'light',
  title: 'Settings',
}
```

### 4. `ColorPickerController`

Purpose: own the LCH color picker dialog.

Responsibilities:

1. Initialize `LchColorWheel` if available.
2. Sync input value, preview swatch, RGB/LCH readouts, and AHK hex value.
3. Handle invalid hex input safely.
4. Expose methods such as:
   - `syncFromForm()`
   - `apply()`
   - `destroy()` if needed later

### 5. `HotkeyRecorderController`

Purpose: own recording lifecycle for the hotkey modal.

Responsibilities:

1. Track active target field.
2. Capture keydown events only while recording.
3. Ignore modifier-only input.
4. Maintain readable preview and raw AHK hotkey string.
5. Apply the result back to the correct hidden input and refresh display text.

### 6. `SettingsPage`

Purpose: composition root for the entire page.

Responsibilities:

1. Construct `AhkHostBridge`, `SettingsDom`, `SettingsForm`, and dialog controllers.
2. Bind all events.
3. Manage section navigation.
4. Provide a single public bridge on `window`, for example `window.SettingsPageBridge`.
5. Expose methods used by AHK, such as:
   - `applyState(state)`
   - `refresh()`

## HTML Changes Required

The rewrite should include small companion changes to [includes/ui/settings.html](includes/ui/settings.html).

### Replace inline handlers

Current examples:

```html
<button onclick="ahk.SettingsSave()">
<button onclick="ahk.gui.Minimize()">
<button onclick="ahk.SettingsCancel()">
<button onclick="showSection('general', this)">
```

Target approach:

```html
<button data-action="save-settings">
<button data-action="minimize-window">
<button data-action="cancel-settings">
<button class="nav-item" data-section="general">
```

Benefits:

1. No global functions needed for UI actions.
2. All event binding lives in one place.
3. The page becomes easier to test and reason about.

## AHK Changes Required

The biggest structural improvement is in [includes/AKGui.ahk](includes/AKGui.ahk).

### Current population model

`_populateSettingsPage()` builds a long JavaScript string containing many direct DOM assignments.

### Target population model

`_populateSettingsPage()` should build a single state object and pass it to the page bridge.

Target call shape:

```js
window.SettingsPageBridge.applyState({...})
```

Practical AHK options:

1. Build JSON and call one script entrypoint.
2. Build a JS object literal and call one script entrypoint.

Preferred outcome:

1. One AHK-to-JS bootstrap call.
2. No direct field-by-field DOM scripting from AHK.
3. JS owns rendering details.

## Implementation Phases

### Phase 1: Restructure `app.js` without changing AHK contract

Deliverables:

1. Introduce classes and instance-based lifecycle.
2. Keep `SettingsSave(...)`, `SettingsCancel(...)`, and `BrowseForFile(...)` bridge behavior compatible.
3. Remove most globals.
4. Move navigation and button wiring into JavaScript.

Verification:

1. Settings page opens.
2. Save, cancel, and minimize still work.
3. Slider preview, color preview, and hotkey preview still work.

### Phase 2: Replace inline HTML handlers

Deliverables:

1. Update [includes/ui/settings.html](includes/ui/settings.html) to use `data-action` and `data-section` attributes.
2. Remove dependency on global `ahk` and `showSection` from HTML.

Verification:

1. All toolbar buttons work.
2. Nav switching works for every section.

### Phase 3: Move AHK population to state application

Deliverables:

1. Add `window.SettingsPageBridge.applyState(state)` in JS.
2. Change [includes/AKGui.ahk](includes/AKGui.ahk) to send one bootstrap payload.
3. Move rendering responsibility fully into JS.

Verification:

1. Initial form population matches existing behavior.
2. Plugins, hotkeys, logs, problems, theme, and title render correctly.

### Phase 4: Tighten validation and cleanup

Deliverables:

1. Clamp transparency values.
2. Normalize hex color handling.
3. Ensure hotkey recorder ignores invalid input consistently.
4. Remove leftover refresh shims and transitional globals.

Verification:

1. No delayed second refresh is needed.
2. Invalid input fails safely without breaking the page.

## Recommended File Layout

If staying with one file:

```js
class AhkHostBridge {}
class SettingsDom {}
class SettingsForm {}
class ColorPickerController {}
class HotkeyRecorderController {}
class SettingsPage {}

window.SettingsPageBridge = ...
```

If splitting later without a build step:

1. `includes/ui/app.js` as entrypoint
2. `includes/ui/settings-host-bridge.js`
3. `includes/ui/settings-form.js`
4. `includes/ui/settings-color-picker.js`
5. `includes/ui/settings-hotkey-recorder.js`

For the first rewrite, a single well-structured file is the safer choice.

## Best Practices To Apply

1. Use `const` and `let`, not `var`.
2. Use class instance fields and explicit private-ish methods by naming convention if true private fields feel too heavy for this codebase.
3. Prefer event delegation for nav items and action buttons.
4. Keep pure helpers separate from DOM mutation.
5. Keep DOM reads and writes localized.
6. Avoid hidden state stored in mutable globals.
7. Use early returns for guard clauses.
8. Keep save serialization in one method.
9. Keep rendering idempotent where practical.
10. Do not introduce abstractions unless they pay for themselves immediately.

## Compatibility Notes

1. The rewrite runs inside WebView2, so modern ES2015+ syntax is acceptable.
2. Avoid depending on a bundler or module loader unless the HTML loading strategy changes.
3. Keep the public bridge API stable during migration so AHK changes can be rolled out incrementally.

## Risks

1. Rewriting event wiring without updating HTML at the same time will leave broken controls.
2. Changing AHK population and JS rendering in the same step increases debugging cost.
3. Over-abstracting the page into too many tiny classes will make a small UI harder to follow.

## Recommended Execution Order

1. Rewrite [includes/ui/app.js](includes/ui/app.js) into class-based structure while preserving the existing external contract.
2. Update [includes/ui/settings.html](includes/ui/settings.html) to remove inline handlers and rely on delegated events.
3. Change [includes/AKGui.ahk](includes/AKGui.ahk) to send one initial state payload.
4. Remove transitional globals and refresh shims.

## Acceptance Criteria

The rewrite is done when all of the following are true:

1. [includes/ui/app.js](includes/ui/app.js) is organized around a clear class-based page controller.
2. [includes/ui/settings.html](includes/ui/settings.html) no longer depends on inline JS handlers.
3. [includes/AKGui.ahk](includes/AKGui.ahk) initializes the page through one bridge call rather than many DOM assignments.
4. Save, cancel, minimize, section switching, file picking, color picking, and hotkey recording all behave the same or better.
5. The page can refresh from config without timing hacks.

## Suggested Next Step

Implement Phase 1 first and keep the save payload unchanged. That gives the UI a modern internal structure without forcing AHK and HTML changes all at once.
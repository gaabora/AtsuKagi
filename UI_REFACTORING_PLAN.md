# UI & Architecture Refactoring Plan

Status: **Draft** — Analysis complete, implementation pending.

## Executive Summary

The app has a solid foundation: descriptor-driven plugin settings, one-way state flow (AHK→JS), and a class-based JS UI layer (completed in the APP_JS_REWRITE). However, significant friction remains in three areas:

1. **The AHK→JS bridge** — manual JS string concatenation in AKGui.ahk to pass state
2. **AKGui.ahk** — 400+ lines of repetitive `_AhkXxxToJs()` serialization methods
3. **SettingsForm.js** — 1100-line monolith mixing rendering, serialization, hotkey management, and diffing

This plan proposes surgical improvements targeting these pain points, ordered by impact.

---

## Problem 1: AHK→JS Bridge Is Manual String Concatenation

**Current state**: `_populateSettingsPage()` builds a giant JavaScript string by calling 8+ `_AhkXxxToJs()` methods that manually concatenate `"key: " . this._wrapQuotes(...)` for every field of every object. This pattern:
- Is ~200 lines of nearly identical code
- Is fragile — one missing comma or quote breaks silently
- Requires `WebViewCtrl.EscapeJavaScript()` on every value
- Makes adding a new field to the schema a multi-file change

**Root cause**: There's no generic AHK Map/Array → JSON serializer, so each nested shape is hand-serialized.

### Proposed Fix: Generic `toJson()` Serializer

Add a single `_toJson(value)` method to AKGui (or a standalone function in helpers.ahk) that recursively serializes AHK values to JSON:

```ahk
; Handles: Map → {}, Array → [], String → "escaped", Number → number, Bool → true/false
_toJson(value) {
  if (value is Array) {
    parts := ""
    for item in value
      parts .= this._toJson(item) ","
    return "[" RTrim(parts, ",") "]"
  }
  if (value is Map) {
    parts := ""
    for k, v in value
      parts .= '"' WebViewCtrl.EscapeJavaScript(k) '": ' this._toJson(v) ","
    return "{" RTrim(parts, ",") "}"
  }
  if (value is Integer || value is Float)
    return String(value)
  if (value = "true" || value = "false")
    return value
  return '"' WebViewCtrl.EscapeJavaScript(String(value)) '"'
}
```

Then `_populateSettingsPage()` collapses to:

```ahk
_populateSettingsPage(nw) {
  state := Map(
    "generalPage", this.App.GetGeneralSettingsPage(),
    "plugins", Map(
      "available", this.App._getAvailablePlugins(),
      "disabled",  this.App._getDisabledPlugins(),
      "pages",     this.App.GetPluginSettingsPages()
    ),
    "hotkeys",      this._getHotkeysList(),
    "logsText",     AKBase.GetUiLogsText(),
    "problemsText", AKBase.GetUiProblemsText(),
    "theme",        this.IsDarkTheme() ? "dark" : "light",
    "title",        this.App.ScriptName " — Settings"
  )
  js := "(() => { let s = " this._toJson(state) "; "
     .  "if (window.SettingsPageBridge) { try { window.SettingsPageBridge.applyState(s); } catch(e) { console.error(e); } } })();"
  if (this.App.Config.GENERAL.DebugLevel >= 4)
    FileOpen(A_ScriptDir "\ak_settings_debug.js", "w", "UTF-8").Write(js)
  nw.ExecuteScriptAsync(js)
}
```

**Impact**: Deletes ~200 lines of `_AhkXxxToJs()` methods. Adding a field to the descriptor schema automatically appears in JSON with zero AKGui changes.

**Effort**: Low — the serializer is <30 lines, and the state-building methods already return Maps/Arrays.

---

## Problem 2: AKGui.ahk Has Too Many Responsibilities

**Current**: AKGui handles:
- Theme management (dark mode, accent color)
- WebView lifecycle (create, configure, destroy settings window)
- State serialization (8 `_AhkXxxToJs` methods — eliminated by Problem 1 fix)
- Settings deserialization (3 `_applyEncodedXxxConfig` methods)
- File browser dialog
- DevTools toggle

After fixing Problem 1, the file shrinks significantly, but deserialization still doesn't belong in the GUI layer.

### Proposed Fix: Move Deserialization to AKApp

The `_applyEncodedGeneralConfig()`, `_applyEncodedPluginConfig()`, and `_applyEncodedHotkeysConfig()` methods read and write `this.App.Config` directly. They belong in AKApp, not AKGui. Move them:

```
AKGui._saveSettings(encoded...)
  → calls this.App.ApplyEncodedSettings(generalEncoded, disabledPlugins, pluginConfigEncoded, hotkeysEncoded)
    → AKApp parses and saves internally

AKGui keeps only:
  - Theme management
  - WebView lifecycle (show/close/populate)
  - File browser / DevTools helpers
```

**Impact**: Clear separation — AKGui is presentation-only; AKApp owns config. Also enables testing config parsing without a GUI.

**Effort**: Low — move 3 methods + `_decodeEscapedLinePart`, update 1 call site.

---

## Problem 3: JS→AHK Data Encoding Is Fragile

**Current**: JS sends settings back as 4 tab-delimited escape-sequence strings:
```
generalEncoded:  "key\tvalue\nkey2\tvalue2"
pluginConfigEncoded: "pluginId\tkey\tvalue\n..."
hotkeysEncoded: "hotkey\taction\n..."
```
AHK parses these with manual `StrSplit` + `_decodeEscapedLinePart()`.

**Problems**:
- Custom encoding/decoding is asymmetric — AHK sends JSON-like objects to JS, but JS sends tab-separated text back
- If a config value contains `\t` or `\n` literally, the escaping can break
- Adding a field requires updating both JS serializer and AHK parser

### Proposed Fix: Use JSON Both Ways

Since WebView2 supports `postMessage`, and AHK can parse JSON via `Jxon` or a simple parser:

**Option A (minimal)**: Keep the callback approach but send a JSON string instead of tab-delimited. AHK parses it with a lightweight JSON parser. This is symmetric with the AHK→JS direction.

**Option B (cleaner, requires more work)**: Use WebView2 `postMessage` / `addEventListener` for both directions instead of sync host callbacks. This is more modern but requires changes to the WebView library.

**Recommendation**: Option A — swap the encoding format to JSON while keeping the callback mechanism. Add a simple `fromJson()` AHK function (pair to the `_toJson()` from Problem 1).

**Impact**: Eliminates 3 `_applyEncodedXxx` parsers in AHK + 3 `encodeXxxLines` methods in JS. Both sides speak JSON.

**Effort**: Medium — need a JSON parser in AHK (there are well-known v2 implementations, ~60 lines). Test carefully for edge cases in config values.

---

## Problem 4: SettingsForm.js Does Too Much

**Current**: 1100 lines covering:
- Schema diffing (signature generation, comparison)
- DOM rendering (general page, plugin pages, fields, actions)
- Form serialization (reading DOM → object)
- Hotkey entry management (add/remove/query/sync badges)
- Tab-delimited encoding (static methods)

### Proposed Fix: Extract Focused Modules

Split into 3 files (~350 lines each):

| New File | Responsibility |
|----------|---------------|
| `SettingsFormRenderer.js` | `renderGeneralPage()`, `_renderField()`, `_renderPluginSettingsPages()`, `_reconcilePluginFieldRows()`, `_reconcilePluginSections()` — all DOM creation |
| `SettingsFormSerializer.js` | `serializeObject()`, `encodeXxxLines()` (or `toJson()` if Problem 3 is done), `escapeLinePart()`, `_buildStateSignatures()` |
| `SettingsForm.js` (slimmed) | `applyState()` orchestration, field value application, imports from the above |

Hotkey management methods (`getHotkeysForAction`, `assignActionHotkey`, `removeHotkeyByRaw`, `_syncPluginActionHotkeys`) can stay in SettingsForm since they're tightly coupled to form state, or become a `HotkeyEntryManager.js` if they grow further.

**Impact**: Each file is focused, testable, and <400 lines. No behavioral change.

**Effort**: Medium — mostly moving methods between files and updating imports (these are plain `<script>` tags, not modules, so classes must be loaded in order, or switch to ES modules).

### Sub-consideration: Switch to ES Modules

Currently all JS files are loaded as `<script>` tags in settings.html. Switching to `<script type="module">` with `import/export` would:
- Enable proper dependency management
- Allow tree-shaking if ever bundled
- Make the extraction above cleaner

**Risk**: WebView2 supports ES modules, but need to verify with the local file:// protocol used. Low risk — WebView2 Chromium handles this fine.

---

## Problem 5: Duplicated Utility Code

### `_humanizeHotkey()` — exists in both HotkeyRecorderController.js and SettingsForm.js

Extract to a shared `hotkeyUtils.js`:
```javascript
export function humanizeAhkHotkey(hk) { ... }
export function parseAhkModifiers(hk) { ... }
```

### Color hex parsing — scattered across ColorPickerController.js

`_parseAhkHexColor()`, `_normalizeHex6()`, `_toCssColor()`, `_toAhkHex()` are general-purpose. Extract to `colorUtils.js` if reused elsewhere, or leave as-is if they stay contained.

**Impact**: Deduplication, single source of truth.

**Effort**: Low.

---

## Problem 6: AKApp.ahk God Object

**Current**: AKApp (~700 lines) handles:
- App lifecycle (init, reload, suspend)
- Plugin management (scan, load, register, descriptors)
- Hotkey management (bind, unbind, validate, throttle)
- Action management (register, parse, dispatch, deprecation)
- Config management (load, defaults, save)
- Blocklist management
- Settings page data building
- Tray menu
- Tooltips and notifications

### Proposed Fix: Extract Manager Objects

This is the largest refactor and should be done incrementally:

| Extract To | Methods to Move | Lines Saved |
|------------|----------------|-------------|
| `AKHotkeyManager.ahk` | `BindAllHotkeys`, `UnbindAllHotkeys`, `RebindAllHotkeys`, `BindHotkey`, `_runHotkeyAction`, `_validateHotkeysConfig`, `_bindControlHotkeys` | ~150 |
| `AKActionManager.ahk` | `RunAction`, `_registerAction`, `_parseActionInfo`, `_getActionHandler`, `_actionExists`, `_callActionHandler`, `_resolveDeprecatedActionName`, `_warnIfActionNameIsNonConventional` | ~120 |
| `AKPluginManager.ahk` | `AddPlugin`, `_getAvailablePlugins`, `_getDisabledPlugins`, `_getDynamicallyEnabledPlugins`, `_generateDynamicPlugins`, `_initPlugins`, registries | ~120 |

AKApp becomes a thin coordinator:
```ahk
class AKApp extends AKBase {
  __New() {
    this._initConfig()
    this.Plugins := AKPluginManager(this)
    this.Actions := AKActionManager(this)
    this.Hotkeys := AKHotkeyManager(this)
    this.GUI := AKGui(this)
    ; ...
  }
}
```

**Impact**: Each concern is isolated and testable. AKApp drops from ~700 to ~250 lines.

**Effort**: High — many internal references to refactor. Do this last, after Problems 1-5.

**Risk**: AHK v2 class/method references use `ObjBindMethod` extensively for hotkey callbacks; need to verify these survive the extraction.

---

## Problem 7: Minor Issues

| Issue | Fix | Effort |
|-------|-----|--------|
| `ProcessGereralConfigSection` typo | Rename to `ProcessGeneralConfigSection` | Trivial |
| Debug artifacts `console.log("ASS1")` in ColorPickerController.js | Remove | Trivial |
| PLUGIN_API.md still documents legacy `__ConfigHelp()`/`__ActionsHelp()` as primary API | Update to document `__DescribePlugin()` as the canonical approach | Low |
| Legacy methods in AKPlugin (`__ConfigHelp`, `__UsageHelp`, `__ActionsHelp`, `__HooksHelp`) | Mark deprecated with clear comment, or remove if no plugin uses them directly | Low — verify no direct callers first |
| Repo memory is stale (says app.js doesn't render plugin pages — it does now) | Update /memories/repo/settings-architecture.md | Trivial |
| No client-side validation despite `validation` metadata in field schema | Wire up `validation.required`/`min`/`max` on the JS side for immediate feedback | Medium |

---

## Recommended Execution Order

| Phase | Items | Dependency | Risk |
|-------|-------|------------|------|
| **1** | Problem 1 (toJson serializer) + Problem 7 trivial fixes | None | Low |
| **2** | Problem 2 (move deserialization to AKApp) | Phase 1 | Low |
| **3** | Problem 5 (deduplicate JS utils) + Problem 4 (split SettingsForm.js) | None (parallel with Phase 1-2) | Low |
| **4** | Problem 3 (JSON both ways) | Phase 1 (toJson exists) | Medium |
| **5** | Problem 6 (extract AKApp managers) | Phases 1-4 stable | High |

Each phase is independently shippable and testable. Phase 1 alone eliminates the most pain (~200 lines of boilerplate deleted).

---

## Out of Scope

- Plugin hot-loading (mentioned in dynamicPlugins.ahk pain points) — requires AHK runtime changes
- JSON config file format (mentioned in TODO.txt) — separate initiative
- New features (WinDrag, battery alerts, etc.) — separate plans exist
- Test expansion — tracked in RELEASE_PLAN.md Phase 5

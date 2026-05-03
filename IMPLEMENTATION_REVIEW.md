# Implementation Review: Atomic Settings & Logs Overhaul

## Overall Status

| Area | Status | Notes |
|------|--------|-------|
| Atomic settings — AHK side | ✅ Done | All 6 callbacks, type coercion, side effects, validation |
| Atomic settings — JS side | ✅ Done | Per-field save, optimistic update, revert on error |
| Structured logs — AHK side | ✅ Done | Map objects, id/time/level/text, buffer 500, ClearLogs |
| Structured logs — JS side | ✅ Done | LogsController with filter, search, time toggle, clear |
| Problems page removed | ✅ Done | HTML, nav, serializer, state all cleaned up |
| Setting highlight CSS | ✅ Done | `highlight-pulse` animation present |
| `_goToSetting` navigation | ✅ Done | Navigates to page, scrolls, highlights |
| `OnConfigChanged` plugin hook | ✅ Done | Base class + called in `SavePluginSetting` |
| Reactive log push (AHK→JS) | ❌ Missing | Not implemented; logs only update on full state apply |
| `outputDebugLine` meta param | ❌ Missing | No `source`/`settingRef` support → "Go to setting" buttons never appear |
| `_hasBindingProblems` auto-open | ❌ Missing | TODO comment in `BindAllHotkeys` but no implementation |
| Additional logging calls | ❌ Missing | No new log calls in save/load/bind/plugin paths |
| `appendLogs` bridge function | ❌ Missing | `SettingsPageBridge` doesn't expose `appendLogs` |
| `SetLogPageActive` AHK callback | ❌ Missing | Not registered in AKGui, no `_isLogPageActive` tracking |

---

## Bugs

### 1. Orphaned `LogsController` in `app.js` (Medium)

[app.js](includes/ui/app.js#L65-L70) creates a global `LogsController` without a `goToSettingCallback`, then `SettingsPage` creates its own instance with the callback and mounts it over the same container. The global instance is abandoned, and `app.js` then assigns it to `form.logsController` — but `SettingsPage._mountLogsController()` overwrites that immediately.

```js
// app.js — creates orphan
window.logsController = new LogsController(hostBridge);          // no callback
if (logsContentEl) window.logsController.mount(logsContentEl);

// SettingsPage constructor — creates the real one
this.logs = new LogsController(this.hostBridge, (ref) => this._goToSetting(ref));

// SettingsPage._mountLogsController() — overwrites orphan's mount
this.logs.mount(container);
```

**Impact:** The orphan doesn't cause runtime errors, but it's dead code and confusing. The `window.logsController` global points to the wrong instance.

**Fix:** Remove the `LogsController` creation from `app.js`. Let `SettingsPage` own it entirely. Remove the `window.settingsPage.form.logsController = window.logsController` assignment too.

---

### 2. `_normalizeEntry` loses `settingRef` (High — when meta is implemented)

[LogsController.js](includes/ui/classes/LogsController.js#L70-L76) `_normalizeEntry` strips everything except `id`, `time`, `level`, `text`:

```js
_normalizeEntry(entry) {
  return {
    id:    Number(entry.id ?? -1),
    time:  `${entry.time ?? ''}`,
    level: Number(entry.level ?? 4),
    text:  `${entry.text ?? ''}`
    // settingRef, source — stripped!
  };
}
```

When `settingRef` is added to AHK log entries, it will be dropped here and the "Go to setting" button will never render.

**Fix:** Pass through `settingRef` and `source`:
```js
_normalizeEntry(entry) {
  const norm = { id: ..., time: ..., level: ..., text: ... };
  if (entry.settingRef) norm.settingRef = entry.settingRef;
  if (entry.source) norm.source = entry.source;
  return norm;
}
```

---

### 3. `logsChanged` always true (Low-Medium)

[SettingsForm.js](includes/ui/classes/SettingsForm.js#L90):
```js
const logsChanged = Array.isArray(state.logs);
```

This is `true` whenever state has a `logs` array (i.e., always). Every `applyState()` call will re-set all logs via `logsController.setLogs()`, even when logs haven't changed.

This works but is wasteful — causes full DOM rebuild of the logs container on every state apply (e.g., after theme change or title change).

**Fix:** Compare log array length + last ID:
```js
const logsChanged = Array.isArray(state.logs) && (
  !prevState ||
  !Array.isArray(prevState.logs) ||
  state.logs.length !== prevState.logs.length ||
  (state.logs.length > 0 && state.logs[state.logs.length - 1]?.id !== prevState.logs[prevState.logs.length - 1]?.id)
);
```

---

### 4. `buildToolbar()` document click listener leak (Low)

[LogsController.js](includes/ui/classes/LogsController.js#L101) adds a `document.addEventListener('click', ...)` every time `buildToolbar()` is called. No guard prevents re-invocation.

```js
document.addEventListener('click', () => filterDropdown.classList.remove('open'));
```

In practice `buildToolbar` is only called once from `_mountLogsController`, so this is not an active bug. But it's fragile.

**Fix:** Add a guard:
```js
buildToolbar(toolbarEl) {
  if (!toolbarEl || toolbarEl.dataset.bound === '1') return;
  toolbarEl.dataset.bound = '1';
  // ...
}
```

---

### 5. `_render()` full DOM rebuild every time (Medium)

[LogsController.js](includes/ui/classes/LogsController.js#L106-L116) rebuilds the entire log container on every render — creates DOM elements for all filtered entries, clears `innerHTML`, appends fragment.

With 500 log entries and frequent filter/search changes, this can cause visible lag.

**Fix (later):** Incremental rendering — track `_lastRenderedId`, only append new lines. Full rebuild only on filter/search change.

---

## Not-a-Bug Observations

### `_bindActions()` no duplicate guard

The save/cancel/minimize button listeners in `SettingsPage._bindActions()` have no `dataset.bound` guard. However, since `SettingsPage` is constructed exactly once and `init()` is only called from the constructor, this is not an active problem.

### `HotkeyRecorderController` / `ColorPickerController` listener accumulation

Both add document-level listeners in `init()`. These controllers are constructed once per page load, so no active leak. But if the architecture ever changes to re-create them, it would leak.

### `_parseHostResult` accepts objects without `ok` property

```js
if (typeof result === 'object') return result;  // might not have 'ok'
```

All AHK callbacks use `_jsonAtomicResult` which returns JSON strings (not objects), so this branch is unlikely to hit. The callers use `result?.ok` which is safe.

---

## Missing Features (per plan)

### 1. `outputDebugLine` meta parameter — needed for "Go to Setting"

Current signature: `outputDebugLine(line, level:=4)`
Plan required: `outputDebugLine(line, level:=4, meta:=0)`

Without this, no log entry will ever have `settingRef`, so the "Go to setting" button never appears. This is the core blocker for the navigation feature.

Also need to update `_bufferLogMessage` to store meta fields in the Map.

### 2. `SetLogPageActive` callback — needed for reactive push

Not registered in `AKGui.ShowSettings()`. The JS side (`LogsController.onPageActive/onPageInactive`) calls `hostBridge.setLogPageActive()` but `AhkHostBridge` doesn't have that method, and AHK doesn't have the callback.

Needed chain:
1. Add `setLogPageActive(active)` to `AhkHostBridge.js`
2. Register `SetLogPageActive` callback in `AKGui.ahk`
3. Track `_isLogPageActive` flag in AKGui
4. On `_bufferLogMessage`, if active + settings window open, push via `ExecuteScriptAsync`
5. Register `appendLogs` on `SettingsPageBridge` in `app.js`

### 3. `_hasBindingProblems` + auto-open logs page

`BindAllHotkeys()` has a TODO comment but no implementation. Need:
1. Set `AKBase._hasBindingProblems := (configProblems.Length > 0)` in `BindAllHotkeys`
2. In `_populateSettingsPage`, if `_hasBindingProblems`, add `"openPage": "logs"` and `"logLevelFilter": [0, 1]` to state
3. In JS `applyState`, read `state.openPage` and `state.logLevelFilter`, navigate to logs and set filter

### 4. Additional logging calls

The plan specified logging for settings save/load, hotkey binding, plugin loading, etc. Currently the atomic save methods (`SaveGeneralSetting`, `SavePluginSetting`, etc.) don't log anything — they should log at DEBUG level on success and WARNING on failure.

---

## Optimizations

### 1. `_buildGeneralTypeIndex()` and `_buildPluginTypeIndex()` called per save

These rebuild the type-to-field mapping from scratch on every atomic save call. They iterate over all schema field definitions.

```ahk
SaveGeneralSetting(key, valuePayload) {
  typeIndex := this._buildGeneralTypeIndex()   // rebuilt every call
  ...
}
```

**Suggestion:** Cache the type indexes after first build, invalidate only on plugin load/unload (which requires reload anyway). Add `_generalTypeIndex` and `_pluginTypeIndex` instance fields.

### 2. Logs signature comparison bypassed but logs always re-applied

Since `logsChanged` is always `true` (see bug #3), every `applyState` does `logsController.setLogs(state.logs)` which does a full DOM rebuild. This nullifies the signature-based optimization the rest of the form uses.

### 3. `_hotkeyEntriesFromConfig()` creates array from Map on every hotkey operation

`SaveHotkey`, `RemoveHotkey`, `AddHotkey` all call `_hotkeyEntriesFromConfig()` which rebuilds the array each time. Then `_saveHotkeyEntries()` converts back to Map. For single operations this is fine, but it's worth noting.

---

## Code Quality Notes

### Good patterns used throughout:
- `_jsonAtomicResult` provides consistent response format across all atomic callbacks
- `_parseAtomicValue` safely handles JSON parse with fallback to raw string
- Type coercion via schema ensures values are correctly typed before storage
- `_validateHotkeyEntry` is thorough: checks empty, unknown action, duplicates
- Optimistic update with revert is correctly implemented in JS
- `_findPluginInstanceById` handles both class-name and descriptor-id lookups
- `BindHotkey` restoration on failure (re-binds old key if new one fails)
- CSS `logs-show-time` class toggle for timestamps is elegant (no re-render needed)

### Minor style inconsistencies:
- Some AHK methods use `Trim("" key)` while others use direct string coercion — both work, but inconsistent
- `_scheduleFieldSave` uses `saveKey` strings like `"general:DebugLevel"` and `"plugin:WindowManager:SnapSize"` — clean approach

---

## Recommended Priority

**Quick wins (low effort, high impact):**
1. Fix `_normalizeEntry` to preserve `settingRef` and `source` fields
2. Remove orphaned `LogsController` from `app.js`
3. Fix `logsChanged` to actually compare, not always be true
4. Add `buildToolbar` guard

**Core features (medium effort, needed for plan completion):**
5. Add `meta` parameter to `outputDebugLine` + `_bufferLogMessage`
6. Add `SetLogPageActive` callback chain (AHK + JS bridge + `SettingsPageBridge.appendLogs`)
7. Implement `_hasBindingProblems` auto-open logic
8. Add logging calls to atomic save methods and plugin loading

**Performance (defer unless bottleneck observed):**
9. Cache type indexes in AKApp
10. Incremental log rendering in LogsController

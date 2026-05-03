# Plan: Atomic Settings Contract + Logs Overhaul

## Current State Summary (from code analysis)

### JS-to-AHK Contract (current)

Every setting change follows this heavy cycle:

1. User edits one field → 350ms debounce fires
2. `ЫуеештпыАщкь.serializeObject()` serializes **entire form** (all general settings, all plugin configs, all hotkeys)
3. `hostBridge.saveSettings(fullPayload)` sends full JSON to AHK
4. AHK `ApplySettingsPayload()` re-applies **all** general, plugin, and hotkey configs
5. `cfg.Save()` writes **entire** config.ini
6. `ApplySettings()` calls `RebindAllHotkeys()` (unbinds all → validates all → rebinds all)
7. `_populateSettingsPage()` builds **entire** state object (all sections, all plugins, all logs)
8. `ExecuteScriptAsync` sends full state JSON to JS
9. JS `applyState()` diffs signatures and re-renders changed sections (efficient on JS side, but AHK did all the work already)

**Problems:**
- Changing one text field rebinds all hotkeys
- Changing one plugin config rebuilds all plugin pages state
- The full JSON payload grows with each plugin added
- IniFile writes the entire file every save
- No way to save just one setting atomically

### Logs System (current)

- Stored as `AKBase._uiLogs[]` (max 300 strings) and `AKBase._uiProblems[]` (max 200 strings)
- Format: plain text `"[2026-05-03 14:32:15] [ERROR] message"`
- Sent to JS as one big joined string (`logsText`, `problemsText`)
- Displayed in `<div id="logs-content" class="console-box">` via `.textContent = ...`
- No filtering, no search, no structured data
- Problems page is separate nav item, separate HTML section, duplicate of warn+error logs
- Logs only update when full state re-populates (on settings save or settings window open)

---

## Phase 1: Atomic Settings Contract

### Goal
Change of one setting/hotkey should only save and apply that specific change, not trigger a full round-trip of all settings.

### 1.1 New AHK Callback Endpoints

Add granular save callbacks in `AKGui.ShowSettings()`:

```
SaveGeneralSetting(key, value)     → save single [GENERAL] key, apply side effects
SavePluginSetting(pluginId, key, value) → save single [PluginId] key, notify plugin
SaveHotkey(index, hotKey, action)  → save single hotkey, rebind only that one
RemoveHotkey(index)                → remove hotkey, unbind only that one
AddHotkey(hotKey, action)          → add new hotkey, bind only that one
TogglePlugin(pluginId, enabled)    → enable/disable plugin (this still requires reload)
```

Registered in AKGui via `nw.AddCallbackToScript(...)`.

### 1.2 AHK Implementation Details

**`SaveGeneralSetting(key, value)`:**
- Type-coerce using existing `_coerceConfigValue()` with schema lookup
- Write only `Config.GENERAL[key] := value`
- `cfg.Save()` (still full file write — IniFile doesn't support partial, acceptable for now) //TODO: make ini file support partial writes later
- Apply only the relevant side effect:
  - `DebugLevel` → call `this.Debug(value)`
  - `DarkTheme` → call `GUI.ApplyThemeMode()`
  - `WelcomeMessage`, `ToolTipTimeoutMs`, etc → no side effect, just save
  - `ReloadAppHotkey`, `SuspendAppHotkey` → rebind only control hotkeys
- Do NOT rebuild full state, do NOT re-populate settings page
- Return `{ ok: true }` or `{ ok: false, error: "..." }` as JSON

**`SavePluginSetting(pluginId, key, value)`:**
- Type-coerce using plugin's config schema
- Write `Config[pluginId][key] := value`
- `cfg.Save()`
- Notify plugin: call `plugin.OnConfigChanged(key, value)` if plugin implements it
- Do NOT rebuild full state
- Return status JSON

**`SaveHotkey(index, hotKey, action)`:**
- Unbind old hotkey at index (if exists)
- Validate and bind new one via `BindHotkey()`
- Update `Config.HOTKEYS`
- `cfg.Save()`
- Return `{ ok: true, problems: [...] }` — include validation result so JS can show inline

**`RemoveHotkey(index)` / `AddHotkey(hotKey, action)`:**
- Unbind/bind respectively, update Config, save
- Return status + problems

**`TogglePlugin(pluginId, enabled)`:**
- Update `DisabledPlugins` in Config
- `cfg.Save()`
- `_generateDynamicPlugins()`
- Return `{ ok: true, requiresReload: true }`

### 1.3 JS-Side Changes

**AhkHostBridge — new methods:**
```js
saveGeneralSetting(key, value)         → host.SaveGeneralSetting(key, JSON.stringify(value))
savePluginSetting(pluginId, key, value) → host.SavePluginSetting(pluginId, key, JSON.stringify(value))
saveHotkey(index, hotKey, action)      → host.SaveHotkey(index, hotKey, action)
removeHotkey(index)                     → host.RemoveHotkey(index)
addHotkey(hotKey, action)              → host.AddHotkey(hotKey, action)
togglePlugin(pluginId, enabled)        → host.TogglePlugin(pluginId, enabled ? 1 : 0)
```

**SettingsPage — change event handling:**
- Replace `_scheduleAutoSave()` (full form serialize) with field-level handlers
- On general field change → `hostBridge.saveGeneralSetting(key, value)`
- On plugin field change → `hostBridge.savePluginSetting(pluginId, key, value)`
- On hotkey edit → `hostBridge.saveHotkey(index, hotKey, action)`
- On hotkey delete → `hostBridge.removeHotkey(index)`
- On hotkey add → `hostBridge.addHotkey(hotKey, action)`
- On plugin toggle → `hostBridge.togglePlugin(pluginId, enabled)`
- Keep debounce (350ms) per field, but scope it per-field, not global //TODO: make time configurable later

**Remove full-form serialize path:**
- Remove `SettingsForm.serializeObject()` call from auto-save
- Remove `SaveSettingsJson` callback from AHK (or keep as fallback for bulk operations)
- Keep `SettingsFormSerializer` for signature comparison (still used for incoming state diffs)

### 1.4 State Refresh Strategy

After atomic save, AHK should NOT send full state back. Instead:
- JS applies the change optimistically to local state
- If AHK returns error, JS reverts the field to previous value and shows error
- Full state refresh only on: settings window open, plugin toggle (reload), explicit refresh button

For hotkeys specifically, AHK returns validation problems inline, so JS can show per-row error indicators without full refresh.

### 1.5 Migration Path

1. Implement new atomic callbacks in AHK alongside existing `SaveSettingsJson`
2. Update JS to use atomic calls for individual field changes
3. Keep `SaveSettingsJson` as fallback (remove later when stable) //TODO: remove later
4. Test that individual saves work correctly
5. Remove the full-serialize auto-save path

### 1.6 AKPlugin Base Class Addition

Add `OnConfigChanged(key, value)` virtual method to `AKPlugin`:
```ahk
OnConfigChanged(key, value) {
  ; Override in plugin to react to individual config changes
  ; Default: no-op
}
```

Plugins that need to react to config changes (e.g., WindowManager's snap grid size) override this.

---

## Phase 2: Logs Overhaul

### Goal
Structured log objects, reactive log updates, filters, search, and merge problems into logs.

### 2.1 Structured Log Object

**AHK side — replace string entries with Map objects:**

```ahk
logEntry := Map(
  "id",    AKBase._nextLogId++,   ; auto-increment, for stable DOM diffing
  "time",  FormatTime(, "yyyy-MM-dd HH:mm:ss"),
  "level", level,                 ; 0=ERROR, 1=WARNING, 2=NOTICE, 3=INFO, 4+=DEBUG
  "text",  line,                  ; the message text
  "source", source,               ; optional: plugin name or "core" or "hotkeys"
  "settingRef", settingRef        ; optional: Map("section","GENERAL","key","DebugLevel") for "go to setting"
)
```

**`_uiLogs[]`** stores these Map objects instead of strings.
**`_uiProblems[]`** is removed entirely (problems = filtered view of logs).

### 2.2 Log Retrieval API

Replace `GetUiLogsText()` and `GetUiProblemsText()` with:

```ahk
static GetUiLogs() {
  return AKBase._uiLogs   ; Return array of Map objects
}

static GetUiLogsSince(lastId) {
  ; Return only logs with id > lastId (for incremental updates)
  result := []
  for entry in AKBase._uiLogs {
    if (entry["id"] > lastId)
      result.Push(entry)
  }
  return result
}

static ClearLogs() {
  AKBase._uiLogs := []
}
```

### 2.3 Reactive Log Updates

**New AHK callback for polling/push:**

Option A — **JS polls on timer when logs page is active:**
- Register `GetLogsSince(lastId)` callback
- JS calls it every ~500ms when logs page is visible
- Returns JSON array of new log entries since lastId
- JS appends to its local log array and re-renders only new entries

Option B (preferred) — **AHK pushes on log write when settings window is open:**
- When settings window is open and logs page is active: `AKGui._isLogPageActive := true`
- On new log entry, if `_isLogPageActive`, immediately `ExecuteScriptAsync` to push the new entry
- JS receives via `window.SettingsPageBridge.appendLogs([...newEntries])`
- This gives real-time log streaming

**Hybrid approach (recommended):**
- Use Option B (push) for real-time when logs page is active
- Use full log transfer on initial page open (existing `applyState` path, but now with structured objects)
- Add `SetLogPageActive(active)` callback so JS tells AHK when user navigates to/from logs page
- Add `GetLogsSince(lastId)` as fallback for catch-up after reconnect

**New callbacks:**
```
SetLogPageActive(active)   → AHK tracks whether to push logs
GetLogsSince(lastId)       → returns incremental logs as JSON
ClearLogs()                → clears log buffer
```

**New bridge function (AHK → JS):**
```
window.SettingsPageBridge.appendLogs(entries)  → appends new log entries to UI
```

### 2.4 State Object Changes

In `_populateSettingsPage()`, replace:
```
"logsText" → string
"problemsText" → string
```
With:
```
"logs" → array of log objects
```
Remove `problemsText` entirely.

### 2.5 JS Log Page Rendering

**Remove:** `#section-problems` HTML section and its nav item.

**Replace `#section-logs`** with rich log viewer:

```html
<div id="section-logs" class="settings-section section-console">
  <div class="setting-group">
    <h2>Logs</h2>
    <div class="logs-toolbar">
      <input type="text" id="logs-search" class="logs-search-input" placeholder="Search logs..." />
      <div id="logs-level-filter" class="logs-level-filter">
        <!-- multiselect dropdown for levels: ERROR, WARNING, NOTICE, INFO, DEBUG -->
      </div>
      <label class="logs-toggle">
        <input type="checkbox" id="logs-show-time" /> Show time
      </label>
      <button id="logs-clear" class="btn-small">Clear logs</button>
    </div>
    <div id="logs-content" class="console-box logs-container">
      <!-- log lines rendered here -->
    </div>
  </div>
</div>
```

### 2.6 New JS Class: `LogsController`

Create `includes/ui/classes/LogsController.js`:

```
class LogsController {
  constructor(hostBridge, dom) { ... }

  // State
  _logs = []              // full log objects array
  _filteredLogs = []      // after applying filters
  _searchQuery = ''       // text search filter
  _levelFilter = new Set([0,1,2,3,4])  // selected levels (all by default)
  _showTime = false       // toggle for timestamps
  _lastRenderedId = 0     // last log id in DOM

  // API
  setLogs(entries)        // replace all (called from applyState on page open)
  appendLogs(entries)     // add new entries (called from push updates)
  clear()                 // clear all, call AHK ClearLogs()

  // Filters
  setSearchQuery(query)   // filter by text
  setLevelFilter(levels)  // filter by level set
  setShowTime(show)       // toggle timestamps
  showProblemsOnly()      // convenience: set level filter to [0,1] — replaces problems page

  // Rendering
  _applyFilters()         // recompute _filteredLogs from _logs + filters
  _render()               // render _filteredLogs to DOM (virtual scroll or simple)
  _renderLogLine(entry)   // render single log line element

  // Navigation
  goToSetting(settingRef) // navigate to setting from log line, called on button click

  // Lifecycle
  onPageActive()          // called when user navigates to logs tab
  onPageInactive()        // called when user leaves logs tab
}
```

### 2.7 Log Line Rendering

Each log line is a DOM element:

```html
<div class="log-line log-level-{LOG_LEVEL_DISPLAY(level)}" data-log-id="{id}">
  <span class="log-time" style="display:none">{time}</span>
  <span class="log-level-badge">{LOG_LEVEL_DISPLAY(level)}</span>
  <span class="log-text">{text}</span>
  <button class="log-goto-setting" data-section="{section}" data-key="{key}" title="Go to setting">⚙</button>
  <!-- goto button only shown if entry has settingRef -->
</div>
```

CSS classes per level for color coding:
- `.log-level-ERROR` → red
- `.log-level-WARNING` → orange/yellow
- `.log-level-NOTICE` → blue
- `.log-level-INFO` → default
- `.log-level-DEBUG` → gray/dim

### 2.8 Level Filter Multiselect Dropdown

Custom dropdown (no external lib) that shows checkboxes for each level:

```
[▼ Filter levels ]
  ☑ ERROR
  ☑ WARNING
  ☑ NOTICE
  ☑ INFO
  ☑ DEBUG
```

- All checked by default
- Deselecting removes those levels from view
- The dropdown label shows active filter summary: "All levels" or "ERROR, WARNING" etc.

### 2.9 Search Input

- Simple text input above the log list
- Filters `_filteredLogs` to entries where `text` includes query (case-insensitive)
- Debounced (200ms) to avoid excessive re-renders
- Highlights matching text in log lines (optional, low priority)

### 2.10 "Show Time" Toggle

- Checkbox toggle, off by default
- When on: `.log-time` elements get `display:inline`
- When off: `.log-time` elements get `display:none`
- Just a CSS class toggle on the container, very cheap

### 2.11 "Clear Logs" Button

- Calls `hostBridge.clearLogs()` → AHK `ClearLogs()` empties `_uiLogs[]`
- JS `LogsController.clear()` empties local array, re-renders empty state
- Shows "No logs yet." placeholder

### 2.12 Remove Problems Page

- Remove `<div id="section-problems">` from settings.html
- Remove `<button data-section="problems">` nav item
- Remove `problemsText` from state object
- Remove `GetUiProblemsText()` from AKBase
- Remove `_uiProblems[]` from AKBase
- Remove `ClearProblems()` from AKBase (replace with `ClearLogs()`)
- Remove problems-related signature comparison in `SettingsFormSerializer`
- Remove problems rendering in `SettingsForm.applyState()`

The "problems" view becomes: logs page with level filter set to ERROR + WARNING.

### 2.13 Auto-Open Logs on Problems

**In `BindAllHotkeys()`:**

Currently calls `_updateStartupDiagnostics()` at the end. Modify to:
- Track `hasProblems` flag: `AKBase._hasBindingProblems := configProblems.Length > 0`
- When settings window opens (`ShowSettings()`), check `AKBase._hasBindingProblems`
- If true, send initial state with `"openPage": "logs"` and `"logLevelFilter": [0, 1]`
- JS `applyState()` reads `openPage` → navigates to logs tab
- JS `applyState()` reads `logLevelFilter` → sets level filter to show only errors+warnings

```ahk
; In _populateSettingsPage():
if (AKBase._hasBindingProblems) {
  state["openPage"] := "logs"
  state["logLevelFilter"] := [0, 1]  ; ERROR + WARNING
}
```

### 2.14 "Go to Setting" from Log Lines

**AHK side — add `settingRef` to relevant log entries:**

When logging a problem about a specific setting, include a reference:

```ahk
; Example in _validateHotkeysConfig():
problem := "[HOTKEYS] 'Ctrl+A' references unknown action 'NonExistent'"
this.outputDebugLine(problem, 1, {source: "hotkeys", settingRef: {page: "hotkeys", index: 3}})

; Example in config validation:
this.outputDebugLine("Invalid value for DebugLevel", 1, {source: "core", settingRef: {page: "general", section: "General", key: "DebugLevel"}})

; Example in plugin config:
this.outputDebugLine("Invalid WindowManager.SnapSize", 1, {source: "WindowManager", settingRef: {page: "WindowManager", section: "Behavior", key: "SnapSize"}})
```

Extend `outputDebugLine` signature:
```ahk
outputDebugLine(line, level:=4, meta:=0) {
  ; meta is optional Map with source, settingRef
}
```

Extend `_bufferLogMessage` to accept and store meta.

**JS side — "Go to Setting" button:**

On click:
1. Read `settingRef` from log entry: `{ page, section, key, index }`
2. Navigate to the target page: `settingsPage._showSection(page)`
3. Scroll to the field:
   - For general/plugin pages: find `[data-field-key="{key}"]` in the section, `scrollIntoView()`
   - For hotkeys page: find the row at `index`, `scrollIntoView()`
4. Highlight the field briefly: add `.setting-highlight` CSS class, remove after 2s

```css
.setting-highlight {
  animation: highlight-pulse 2s ease-out;
}
@keyframes highlight-pulse {
  0% { background-color: rgba(255, 200, 0, 0.4); }
  100% { background-color: transparent; }
}
```

### 2.15 Add More Logging

Add `outputDebugLine` calls to these code paths:

**Settings load/save:**
- `_initConfig()`: `"Config loaded from {path}"` (INFO)
- `SaveGeneralSetting()`: `"Setting saved: GENERAL.{key} = {value}"` (DEBUG)
- `SavePluginSetting()`: `"Setting saved: {pluginId}.{key} = {value}"` (DEBUG)
- `cfg.Save()`: `"Config written to disk"` (DEBUG)
- Config validation errors: `"Invalid value for {section}.{key}: {reason}"` (WARNING, with settingRef)

**Hotkey binding:**
- `BindHotkey()` success: already logged as INFO — keep
- `BindHotkey()` failure: already logged as ERROR — add settingRef
- `RebindAllHotkeys()` start/end: `"Rebinding all hotkeys..."` / `"Hotkeys rebound: {n} active, {m} failed"` (INFO)

**Plugin loading:**
- `AddPlugin()` success: `"Plugin loaded: {name}"` (INFO) — add if missing
- `AddPlugin()` failure: `"Plugin failed to load: {name} — {error}"` (ERROR, with settingRef to plugins page)
- `_processPluginConfig()`: `"Plugin config loaded: {name}"` (DEBUG)
- Plugin config validation failure: `"Plugin {name}: invalid config {key}={value}"` (WARNING, with settingRef)
- Action registration: `"Action registered: {actionName} from {pluginName}"` (DEBUG)
- Action collision: already logged as WARNING — add settingRef

**Plugin runtime errors:**
- `_callActionHandler()` catch block: `"Action {name} failed: {error}"` (ERROR)
- `_runHotkeyAction()` throttle: already logged — keep

**Settings window:**
- `ShowSettings()`: `"Settings window opened"` (DEBUG)
- `_closeSettings()`: `"Settings window closed"` (DEBUG)

---

## Phase 3: Implementation Order

### Step 1 — Structured Logs (AHK side)
1. Change `_bufferLogMessage()` to create Map objects instead of strings
2. Add `_nextLogId` counter
3. Extend `outputDebugLine()` to accept optional meta parameter
4. Add `GetUiLogs()` returning array of Maps
5. Add `GetLogsSince(lastId)`
6. Add `ClearLogs()`
7. Add `_hasBindingProblems` flag to `BindAllHotkeys()`
8. Keep `GetUiLogsText()` and `GetUiProblemsText()` temporarily for backward compat
9. Update `_populateSettingsPage()` to send `logs` array + `openPage` + `logLevelFilter`
10. Add more logging calls throughout the codebase (settings, hotkeys, plugins)

### Step 2 — Logs UI (JS side)
1. Create `LogsController.js` class
2. Update `settings.html`: remove problems section, update logs section with toolbar
3. Update `settings.css`: add log line styles, level colors, toolbar, highlight animation
4. Update `app.js`: instantiate LogsController
5. Update `SettingsPage.js`: wire LogsController to navigation (onPageActive/onPageInactive)
6. Update `SettingsForm.js`: remove logs/problems text handling, delegate to LogsController
7. Update `SettingsFormSerializer.js`: remove logsText/problemsText signatures
8. Remove problems nav item from HTML
9. Implement level filter multiselect dropdown
10. Implement search input
11. Implement "show time" toggle
12. Implement "clear logs" button
13. Implement "go to setting" button + navigation + highlight

### Step 3 — Reactive Log Push
1. Add `SetLogPageActive` callback in AHK
2. Track active state in AKGui
3. Push new logs via `ExecuteScriptAsync` → `appendLogs()` when logs page is active
4. Add `GetLogsSince` callback as fallback
5. Add `ClearLogs` callback

### Step 4 — Atomic Settings (AHK side)
1. Add `SaveGeneralSetting` callback
2. Add `SavePluginSetting` callback
3. Add `SaveHotkey` / `RemoveHotkey` / `AddHotkey` callbacks
4. Add `TogglePlugin` callback
5. Implement side-effect routing per setting key
6. Add `OnConfigChanged()` to AKPlugin base class
7. Test each callback independently

### Step 5 — Atomic Settings (JS side)
1. Add new methods to `AhkHostBridge`
2. Replace `_scheduleAutoSave()` with per-field save handlers
3. Implement optimistic update pattern (apply locally, revert on error)
4. Wire hotkey row operations to individual callbacks
5. Wire plugin toggle to `togglePlugin()`
6. Remove or deprecate full `saveSettings()` path

### Step 6 — Cleanup
1. Remove `SaveSettingsJson` callback (or keep as hidden fallback)
2. Remove `GetUiLogsText()`, `GetUiProblemsText()` from AKBase
3. Remove `_uiProblems[]` array from AKBase
4. Remove `ClearProblems()` from AKBase
5. Remove problems-related code from `SettingsFormSerializer`
6. Remove `serializeObject()` from SettingsForm if no longer used
7. Update any remaining references

---

## Risks and Notes

- **IniFile still writes full file on save**: Atomic setting changes on AHK side still trigger full file write. This is fine for now — the key win is avoiding full state rebuild + re-render + all-hotkeys-rebind. Partial file writes can be optimized later if needed.
- **Plugin enable/disable still requires reload**: This is inherent to AHK's `#Include` mechanism (compile-time). Cannot be made atomic without major architecture changes. Keep as-is.
- **Log buffer size**: 300 entries may be tight with more logging. Consider increasing to 500-1000, or making it configurable.
- **WebView2 sync bridge limitations**: `hostObjects.sync` calls are synchronous from JS perspective but cross-process. Atomic saves are still fast enough for individual field changes.
- **Backward compatibility**: Keep `SaveSettingsJson` during migration. Remove only after atomic path is stable.
- **Log push concurrency**: AHK is single-threaded, so `ExecuteScriptAsync` for log push won't race with other callbacks. Safe.

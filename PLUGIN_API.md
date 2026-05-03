# Plugin Authoring Guide

This guide helps you create new plugins for Haribol!. Plugins are AutoHotkey v2 classes that extend `AKPlugin` and register hotkey actions.

## Quick Start

1. Create a file in `plugins/` directory: `MyPlugin.ahk`
2. Extend `AKPlugin` class with your plugin name
3. Implement `__DescribePlugin()` metadata descriptor
4. Add action methods that plugins will call
5. Test with `app.LoadPlugin("MyPlugin")`

## Minimal Plugin Template

```autohotkey
#Requires AutoHotkey v2.0

class MyPlugin extends AKPlugin {
  ; Canonical metadata entrypoint
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "MyPlugin",
        "title", "My Plugin",
        "description", "What this plugin does",
        "icon", "icons10-puzzle"
      ),
      "config", [
        Map(
          "key", "MyConfigKey",
          "label", "My Config Key",
          "description", "Description of what this controls",
          "type", "string",
          "control", "text",
          "default", "default_value"
        )
      ],
      "actions", [
        Map(
          "action", "MyAction",
          "label", "My action",
          "description", "Does something useful"
        ),
        Map(
          "action", "MyActionWithArg",
          "label", "My action with arg",
          "description", "Does something with params"
        )
      ],
      "settingsPage", Map(
        "navOrder", 100,
        "hidden", false
      )
    )
  }
 
  ; Optional: internal hooks that other plugins can listen to
  __HooksHelp() {
    texts := Map()
    texts["OnMyEvent"] := "OnMyEvent(data) - fired when X happens. Usage: app.RegisterHook('OnMyEvent', myCallbackFn)"
    return texts
  }
  
  ; Called by framework after plugin is loaded
  _init() {
    ; Set up config defaults, DLL loading, registry monitoring, etc.
    ; Use this.Config to access plugin's config section
    if (!this.Config.Has("MyConfigKey"))
      this.Config.MyConfigKey := "default_value"
  }
  
  ; Optional: process plugin-specific config from INI
  _processPluginConfig() {
    ; Parse and validate this.Config entries
  }
  
  ; Optional: process blocklist config for this plugin
  _processBlocklistConfig() {
    ; Declare what blocklist names this plugin uses
  }
  
  ; User-callable action (registered in hotkey config)
  MyAction() { ;;;
    MsgBox("MyAction called!")
  }
  
  ; Action with parameters
  MyActionWithArg(param1, param2) { ;;;
    this.ShowInfo("Param1=" param1 ", Param2=" param2)
  }
  
  ; Internal event handler
  _onMyEvent(data) {
    ; Handle event
  }
}
```

## Metadata Descriptor (Canonical)

### `__DescribePlugin()`
Returns a descriptor `Map` that defines plugin metadata, config schema, actions, and settings-page behavior.

**Used for:** Settings UI rendering, hotkey validation, action catalog generation, plugin metadata.

---

## Legacy Metadata Helpers (Compatibility)

`__ConfigHelp()`, `__UsageHelp()`, and `__ActionsHelp()` are legacy compatibility helpers.
Prefer `__DescribePlugin()` for all new plugins.

Deprecation note:
These helpers are maintained for backward compatibility only and may be removed in a future cleanup pass.
Treat `__DescribePlugin()` as the single source of truth for plugin metadata.

### `__ConfigHelp()`
Returns a string describing all config keys this plugin uses.

**Example:**
```autohotkey
__ConfigHelp() {
  return "EnableFeature (default: true): enable/disable core feature. ThresholdMs (default: 500): timeout in milliseconds"
}
```

**Used for:** Settings UI documentation, plugin configuration validation.

---

### `__UsageHelp()`
Returns a one-sentence user-friendly description of what plugin does.

**Example:**
```autohotkey
__UsageHelp() {
  return "Switch between keyboard layouts and convert mistyped text between EN/RU online"
}
```

**Used for:** Plugin status display, user reference.

---

### `__ActionsHelp()`
Returns a `Map` of `actionName => "actionName(params) - description"`.

**Example:**
```autohotkey
__ActionsHelp() {
  texts := Map()
  texts["ToggleFeature"]    := "ToggleFeature() - enable/disable feature"
  texts["ShowStatus"]       := "ShowStatus() - display current status in tooltip"
  texts["SetThreshold"]     := "SetThreshold(ms) - set timeout threshold"
  return texts
}
```

**Rules:**
- Action names should follow naming conventions: `VerbNoun`, `ToggleX`, `ShowX`, `EnterX`, `SwitchX`, etc.
- Include parameters in signature
- One action per line in format: `name := "name(params) - description"`
- Return empty Map() if plugin has no user-callable actions

**Used for:** Hotkey validation, ACTION_CATALOG.md generation, help display.

---

### `__HooksHelp()`
Returns a `Map` of internal hook names and signatures (optional).

**Example:**
```autohotkey
__HooksHelp() {
  texts := Map()
  texts["OnWindowMoved"] := "OnWindowMoved(hwnd, xNew, yNew) - fired when window is moved by plugin"
  texts["OnGestureEnd"]  := "OnGestureEnd(gestureType) - fired when gesture recognition completes"
  return texts
}
```

**Used for:** Hook registration, plugin integration documentation.

---

## Action Method Patterns

### Simple Action (no parameters)
```autohotkey
MyAction() { ;;;
  MsgBox("Action executed!")
}
```

### Action with Parameters
```autohotkey
ToggleFeature(enabledFlag:=1) { ;;;
  if (enabledFlag)
    MsgBox("Enabled!")
  else
    MsgBox("Disabled!")
}
```

### Action that Validates Input
```autohotkey
SetThreshold(ms) { ;;;
  if (ms < 100 || ms > 5000) {
    this.ShowWarning("Threshold must be 100-5000ms, got: " ms)
    return false
  }
  this.Config.ThresholdMs := ms
  return true
}
```

### Action that Uses Window/Mouse Context
```autohotkey
ActionOnHoveredWindow(ByValue:=10) { ;;;
  MouseGetPos(,, &hwnd)
  if (hwnd = 0)
    return this.ShowWarning("No window under cursor")
  
  if (this.IsWindowBlocklisted(hwnd, A_ThisFunc))
    return this.ShowWarning("Window is blocklisted for this action")
  
  ; Do something with hwnd...
  WinSetTransparent(WinGetTransparent("ahk_id " hwnd) - ByValue, "ahk_id " hwnd)
}
```

### Async Action (long-running)
```autohotkey
ProcessFileAsync(filePath) { ;;;
  critical := Critical()
  Critical(0) ; Allow interrupts
  
  try {
    ; Long operation
    Loop Parse, FileRead(filePath)
      Sleep(10) ; Simulate processing
  } finally {
    Critical(critical) ; Restore
  }
}
```

---

## Common Patterns

### Check for Active Window
```autohotkey
if (!WinExist("ahk_id " hwnd)) {
  return this.ShowWarning("Window no longer exists")
}
```

### Use Blocklist
```autohotkey
if (this.IsWindowBlocklisted(hwnd, "MyBlocklistName"))
  return
```

### Run Another Action
```autohotkey
this.RunAction("SomeOtherAction(param1, param2)")
```

### Show Temporary Tooltip
```autohotkey
toolTipId := this.ToolTip("Processing...", x, y, 2000)
```

### Access Plugin Config
```autohotkey
value := this.Config.Has("MyKey") ? this.Config.MyKey : "default"
```

### Register Hook (from `_init`)
```autohotkey
_init() {
  this.App.RegisterHook("OnWindowMoved", this.OnWindowMoved.Bind(this))
}

OnWindowMoved(hwnd, x, y) {
  ; Handle event
}
```

---

## Testing Your Plugin

### In Script Mode
```autohotkey
; At end of your plugin file (for testing)
if (A_ScriptName = "test-MyPlugin.ahk") {
  app := AKApp()
  app.LoadPlugin("MyPlugin")
  app.Config.MyPlugin.MyConfigKey := "test_value"
  
  MsgBox(app.RunAction("MyAction()"))
  MsgBox(app.RunAction("MyActionWithArg(a, b)"))
  
  ExitApp()
}
```

### Full Integration Test
See `tests/` directory for test framework examples using Yunit.

---

## Naming Conventions

Use these prefixes consistently for clarity:

| Prefix | Meaning | Examples |
|--------|---------|----------|
| `Toggle*` | binary state changes | ToggleWindowOnTop, ToggleFeature |
| `Show*` | display UI/info | ShowWindowInfo, ShowCurrentLayout |
| `Enter*` | mode transitions | EnterGestureMode, EnterMovingMode |
| `Switch*`, `GoTo*` | navigation/targets | SwitchLayout, GoToDesktop |
| `Increase*`, `Decrease*` | bounded numeric adjustments | IncreaseTransparency |
| `Set*` | explicit value setters | SetThreshold, SetWindowBorderColor |
| `Is*` | boolean conditions (for IfThenElse) | IsWindowBlocklisted, IsFeatureEnabled |
| `Get*` | data retrieval (info-only, no side-effects) | GetDesktopCount, GetWindowTitle |
| `Run*` | higher-level orchestration | RunFullWorkflow |

---

## Best Practices

1. **Keep actions small.** one action = one clear behavior. Use `IfThenElse` in config to combine.

2. **Validate input early.** return errors with `this.ShowWarning()` if params are invalid.

3. **Handle window context gracefully.** Many actions work on hovered window or active window. Use clear param names: `hwnd:=0` means "0 = active window", not "0 = do nothing".

4. **Document dependencies.** If your plugin requires DLLs, document them in the descriptor and `_init()`.

5. **Respect user blocklists.** Always check `IsWindowBlocklisted()` before modifying windows.

6. **Test before release.** Build exe, test plugin enable/disable and a few key actions.

7. **Use comments sparingly.** Action code should be self-documenting. Complex logic goes in private `_helper()` methods.

---

## Integration with AKPlugin Base Class

Your plugin inherits these useful methods:

```autohotkey
; Run another action from your plugin
this.RunAction(actionString)

; Window management (from AKApp)
this.IsWindowBlocklisted(hwnd, actionName)
this.IsInBlocklist(blocklistName, hwnd)
this.ToolTip(text, x, y, duration)
this.ShowInfo(text, title, timeout)    ; Info popup
this.ShowWarning(text)                 ; Warning box

; Output
this.outputDebugLine(text)             ; Debug logging (visible in settings UI Logs tab)

; Config access
this.Config                            ; Map of this plugin's config section
this.App                               ; Reference to AKApp instance
```

---

## Directory Structure

After creating your plugin, place it here:
```
Haribol!/
├── plugins/
│   ├── MyPlugin.ahk              ← Your new plugin
│   ├── WindowManager.ahk
│   ├── VirtualDesktopManager.ahk
│   └── ...
├── includes/
│   ├── AKPlugin.ahk              ← Base class
│   ├── AKApp.ahk                 ← Application core
│   └── ...
└── Haribol!.ahk                 ← Main script
```

---

## Troubleshooting

**"Too many parameters" error on plugin load:**
- Check `__New(App)` signature. It must accept exactly one param (App reference).

**"No property named '__Item'" error:**
- Config values must be stored in `Map()` or use `.Have()` check before accessing via `[key]` syntax.

**Action not appearing in ACTION_CATALOG.md:**
- Verify action is listed in `__DescribePlugin()["actions"]` (or legacy `__ActionsHelp()` if still used).
- Run ACTION_CATALOG generation step (CI/CD task).

**Blocklist not working:**
- Verify blocklist name matches entries in config.ini under `[Blocklists]` section.
- Use exact case: "NoMoveResize" not "nomoreresize".

---

## Next Steps

1. Copy this template and fill in your plugin name
2. Implement `__DescribePlugin()`
3. Add 1-2 simple actions
4. Test with app instance
5. Add to plugins directory
6. Test with generated executable

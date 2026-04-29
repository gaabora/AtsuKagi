# Plugin Settings UI Plan

## Status

Planning only. This document defines the target architecture for plugin metadata, generated settings pages, and centralized action/config registration.

## Problem Summary

Current plugin metadata is split across several weak contracts:

1. `_processPluginConfig()` sets defaults imperatively.
2. `__ConfigHelp()` returns one free-form string.
3. `__UsageHelp()` returns one summary string.
4. `__ActionsHelp()` returns a `Map` of action name to signature-like text.
5. The settings UI only knows about core `GENERAL` fields plus plugin enable/disable state.

This creates three problems:

1. The UI cannot generate plugin-specific pages because config fields have no structured schema.
2. Actions, config, and help text are duplicated and can drift.
3. The AHK <-> WebView save path is positional and only supports a fixed set of built-in fields.

## Goals

1. Make plugin metadata structured enough to generate settings pages automatically.
2. Make actions and config definitions centralized so runtime registration, help text, docs, and UI all use the same source of truth.
3. Support both plugin-wide settings and settings related to one or more specific actions.
4. Add dynamic plugin pages to the settings sidebar after the Plugins section.
5. Support per-field reset and Reset All for each plugin.
6. Preserve the existing INI layout where practical so migration stays incremental.

## Non-Goals

1. Do not rely on parsing `__ConfigHelp()` strings for UI generation. That would be too brittle.

## Design Principles

1. Structured metadata is the source of truth.
2. Human-readable help strings are derived from structured metadata, not the other way around.
3. Defaults are declared once and reused by `_processPluginConfig()`, reset logic, validation, and UI rendering.
4. Action relations must be explicit in metadata so the UI can show what each config value affects.

## Proposed Model

### 1. Central Plugin Descriptor

Each plugin should expose one structured descriptor method. Recommended name:

```ahk
__DescribePlugin() {
  return Map(
    "plugin", Map(...),
    "settingsPage", Map(...),
    "config", [ ... ],
    "actions", [ ... ],
    "hooks", [ ... ]
  )
}
```

This is preferable to spreading logic across many unrelated methods because it removes ambiguity about which definition is authoritative.

For migration, `AKPlugin` will keep legacy methods as compatibility wrappers during the transition:

1. `__UsageHelp()` — derives from descriptor
2. `__ConfigHelp()` — derives from descriptor
3. `__ActionsHelp()` — derives from descriptor
4. `__HooksHelp()` — derives from descriptor

**Migration note:** These legacy methods will be marked with `// TODO: remove after Phase 5` so they can be deleted once all active plugins have migrated to `__DescribePlugin()`.

### 2. Descriptor Sections

#### `plugin`

Core identity used by runtime and docs.

```ahk
Map(
  "id", "KDEMoverSizer",
  "title", "KDE Mover-Sizer",
  "description", "Enhanced window moving/resizing with drag from any place on window instead of titlebar/borders.",
  "icon", "icons10-keyboard",
  "version", "1.0",
  "category", "Window Management"
)
```

#### `settingsPage`

Defines whether the plugin gets a dedicated settings page and how it appears in the sidebar.

```ahk
Map(
  "visible", true,
  "navOrder", 100,
  "icon", "icons10-keyboard"
)
```

This replaces the need for a separate `_settingsPageConfig()` unless that name is preferred as a thin wrapper around `__DescribePlugin()`.

#### `config`

Array of config field descriptors used for defaults, validation, save/reset, and form generation.

Each field should define:

```ahk
Map(
  "key", "LockAxisHotkey",
  "label", "Lock axis hotkey",
  "description", "Hold during move or resize to lock movement to one axis.",
  "type", "hotkey",
  "default", "Shift",
  "section", "Movement",
  "scope", "plugin",
  "validation", Map(
    "required", false
  )
)
```

Common `type` values:

1. `boolean`
2. `string`
3. `integer`
4. `number`
5. `hotkey`
6. `color`
7. `select`
8. `path`
9. `textarea`

Common UI hints:

1. `control: switch`
2. `control: hotkey`
3. `control: slider`
4. `control: color`
5. `control: select`
6. `control: text`

#### `actions`

Array of structured action descriptors. This should replace string-only `__ActionsHelp()` as the primary runtime definition.

```ahk
Map(
  "action", "EnterWindowMovingMode",
  "label", "", // optional, by default parsed from 'action' from PacalCase to Sentence case: to "Enter window moving mode" in this example
  "description", "Drag a window from any point on its surface.",
  "params", [],
  "category", "Window Movement",
  "visibleInCatalog", true,
  "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "ShowWindowContent", "BringToFront"]
)
```

Each action descriptor should be sufficient for:

1. runtime action registration
2. action catalog generation
3. hotkey table descriptions
4. settings-page relation badges

#### `hooks`

Optional structured hook descriptors, same idea as actions.

## Config Scope and Action Relation Model

The UI needs to represent both plugin-level settings and action-related settings.

Recommended model:

1. `scope: plugin`
   Used when the setting affects the plugin generally.
2. `scope: action`
   Used when the setting is specific to a single action.

<!-- on js level later `affectsActions` array should be filled to quick back-reference action.settings.relatedConfig? -->

## UI Plan

### 1. Sidebar Navigation

Current sidebar is static:

1. General
2. Plugins
3. Hotkeys
4. Logs
5. Problems

Target sidebar:

1. General
2. Plugins
3. One nav item per plugin settings page, inserted after Plugins
4. Hotkeys
5. Logs
6. Problems

Rules:

1. Only plugins with `settingsPage.visible = true` get a page.
2. Pages should be sorted by `navOrder`, then title.
3. Disabled plugins show their settings pages with a "disabled" badge at the top. Settings remain editable and save immediately (plugin will load them on next enable).
4. The nav item icon comes from `settingsPage.icon`.

### 2. Plugin Page Layout

Each generated plugin page should contain:

1. Header card
   Shows title, icon, description, enabled or disabled state.
2. Settings groups (`scope: plugin`)
   Generated from each field's `section`.
3. Actions summary block grouped by category
    - Left column: label and description like 
        EnterWindowMovingMode
        desc...
    - Right column: assigned hotkeys rows like 
        [ Win + LButton ] [Rec] [X]
        [ Win + Alt + MButton ] [Rec] [X]
        [+]   [reset]
3.1. related settings with `scope: action`

4. Reset All button
   Resets all values on that plugin page to descriptor defaults.

Recommended field row layout for config setting:

1. Left column: label and description.
2. Center column: input control.
3. Right column: Reset button.



### 3. Field Controls

Initial control mapping:

1. `hotkey` -> current hotkey recorder pattern
2. `boolean` -> switch
3. `color` -> current color-picker pattern
4. `integer` with `min` and `max` -> slider or number input with slider
5. `select` -> select menu
6. `string` -> text input
7. `path` -> text input with Browse button

The UI should not infer control type from the current value. It must use the schema.

### 4. Reset Behavior

Each field supports:

1. `Reset` button beside the input
2. Restores the descriptor default in the form immediately
3. Marks the page as dirty until Save

Each plugin page supports:

1. `Reset All`
2. Resets every field belonging to that plugin
3. Only affects in-memory UI state until Save

Optional later enhancement:

1. `Reset Section`
2. `Reset Action Settings`

## Runtime Architecture Changes

### 1. `AKPlugin`

`AKPlugin` should become the normalization layer for plugin descriptors.

Recommended additions:

1. `__DescribePlugin()`
2. `__GetPluginDescriptor()`
   Returns normalized descriptor with defaults filled in.
3. `__GetConfigSchema()`
4. `__GetActionDefinitions()`
5. `__GetSettingsPageDefinition()`
6. `__ApplyDefaultConfig()`
   Replaces most custom `_processPluginConfig()` boilerplate.
7. `__ResetConfigValue(key)`
8. `__ResetAllConfig()`
9. `__ValidateConfigValue(key, value)`

`_processPluginConfig()` can stay during transition, but the long-term target is:

1. defaults from schema
2. optional plugin-specific post-processing only when needed

### 2. `AKApp`

`AKApp.AddPlugin()` should register more than action strings.

Recommended registries:

1. `this.PluginRegistry[pluginName] := descriptor`
2. `this.ActionRegistry[actionName] := actionDescriptor`
3. `this.PluginConfigRegistry[pluginName] := configDescriptors`

This registry becomes the source for:

1. action registration
2. settings payload generation
3. action catalog generation
4. future validation warnings

### 3. `AKGui`

`_populateSettingsPage()` currently sends:

1. `general`
2. `plugins.available`
3. `plugins.disabled`
4. `hotkeys`
5. logs and problems

It should be extended to send structured plugin settings metadata and current values.

Recommended state shape:

```js
{
  general: { ... },
  plugins: [...], // 'enabled': true is a flag in the common object array
  pages: [
    {
      id: "KDEMoverSizer",
      title: "KDE Mover-Sizer",
      description: "...",
      icon: "icons10-keyboard",
      enabled: true,
      actions: [ ... ],
      sections: [
          {
          id: "movement",
          title: "Movement",
          fields: [
            {
              key: "LockAxisHotkey",
              label: "Lock axis hotkey",
              description: "...",
              type: "hotkey",
              control: "hotkey",
              value: "Shift",
              defaultValue: "Shift",
              scope: "plugin",
              affectsActions: ["EnterWindowMovingMode", "EnterWindowResizingMode"] // this should be filled on js level based on page actions, not in ahk
            }
          ]
        }
      ]
    },
  ]
  },
  hotkeys: [ ... ],
  logsText: "",
  problemsText: "",
  theme: "light",
  title: "Settings"
}
```

### 4. Save Contract

The current `SettingsSave(...)` positional contract will not scale.

Target direction:

1. Keep existing general settings save behavior temporarily.
2. Add a new object-based save path for plugin settings.

Recommended shape:

```js
{
  general: { ... },
  disabledPlugins: ["PluginA"],
  pluginConfigs: {
    KDEMoverSizer: {
      LockAxisHotkey: "Shift",
      QuickPositionHotkey: "LWin",
      EnableSnapping: true,
      ShowWindowContent: true,
      BringToFront: false
    }
  }
}
```

`app.js` can still call one host bridge method, but that method should send a serialized object or JSON string instead of a long ordered parameter list.

## KDEMoverSizer Draft Descriptor

```ahk
__DescribePlugin() {
  return Map(
    "plugin", Map(
      "id", "KDEMoverSizer",
      "title", "KDE Mover-Sizer",
      "description", "Enhanced window moving/resizing with drag from any place on window instead of titlebar/borders.",
      "icon", "icons10-keyboard",
      "category", "Window Management"
    ),
    "settingsPage", Map(
      // "hidden", false, // default visible, optional
      // "navOrder", 100, // optional, default 100
      "description", "Configure drag-anywhere movement, resizing, snapping, and preview behavior.",
      "icon", "icons10-keyboard"
    ),
    "config", [
      Map(
        "key", "LockAxisHotkey",
        "description", "Hold during move or resize to lock the dominant axis.",
        "type", "hotkey",
        "default", "Shift",
        "section", "Movement",
        "scope", "plugin",
      ),
      Map(
        "key", "QuickPositionHotkey",
        "description", "Hold to snap the window into quick-position regions.",
        "type", "hotkey",
        "default", "LWin",
        "section", "Movement",
        "scope", "plugin",
      ),
      Map(
        "key", "EnableSnapping",
        "description", "Snap dragged or resized windows to monitor edges.",
        "type", "boolean",
        "default", true,
        "section", "Snapping",
        "scope", "plugin",
      ),
      Map(
        "key", "ShowWindowContent",
        "label", "Show window content while dragging",
        "description", "When disabled, show only a frame preview instead of moving the live window.",
        "type", "boolean",
        "default", true,
        "section", "Visuals",
        "scope", "plugin",
      ),
      Map(
        "key", "BringToFront",
        "label", "Bring window to front",
        "description", "Activate the target window when move or resize mode begins.",
        "type", "boolean",
        "default", false,
        "section", "Behavior",
        "scope", "plugin",
      )
    ],
    "actions", [
      Map(
        "action", "EnterWindowMovingMode",
        "label", "Move window",
        "description", "Move a window by dragging from anywhere on it.",
        "params", [],
        "category", "Window Movement",
        "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "ShowWindowContent", "BringToFront"]
      ),
      Map(
        "action", "EnterWindowResizingMode",
        "label", "Resize window",
        "description", "Resize a window by dragging from anywhere on it.",
        "params", [],
        "category", "Window Movement",
        "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "ShowWindowContent", "BringToFront"]
      )
    ],
    "hooks", []
  )
}
```

### WindowManager Example

`WindowOnTopBorderColor` is a good example of a field that should not be modeled as purely plugin-generic.

Recommended descriptor shape:

```ahk
Map(
  "key", "WindowOnTopBorderColor",
  "label", "On-top border color",
  "description", "Border color used when a window is toggled to always-on-top.",
  "type", "color",
  "default", "0xAACCFF",
  "section", "On-top Actions",
  "scope", "plugin",
  "affectsActions", ["ToggleHoveredWindowOnTop", "ToggleWindowOnTop"],
)
```


## Migration Strategy

### Phase 1. Metadata Foundation

1. Add descriptor support to `AKPlugin`.
2. Add normalization helpers in `AKPlugin`.
3. Keep legacy methods working by deriving them from the new descriptor when present.
4. Register structured plugin, action, and config metadata in `AKApp`.

Success criteria:

1. Existing plugins still load.
2. Migrated plugins can expose structured metadata.
3. Runtime action registration uses structured action definitions.

### Phase 2. Settings State Extension

1. Extend `AKGui._populateSettingsPage()` to send plugin page metadata and current values.
2. Keep current General and Plugins sections intact.
3. Do not add save behavior yet beyond state display if needed.

Success criteria:

1. WebView receives a complete plugin settings model.
2. No plugin pages are hardcoded in HTML.

### Phase 3. Dynamic UI Rendering

1. Update `includes/ui/app.js` to render plugin nav items.
2. Generate plugin sections dynamically.
3. Reuse existing hotkey recorder and color picker components for plugin field types.
4. Add per-field Reset and Reset All.

Success criteria:

1. KDEMoverSizer page is rendered from metadata only.
2. No KDEMoverSizer-specific HTML is added.
3. Field types render correctly.

### Phase 4. Object-Based Save Contract

1. Replace positional plugin save handling with object-based payload parsing.
2. Persist plugin config values back to the existing config store.
3. Add reset support based on schema defaults.
4. Re-run `_processPluginConfig()` only where post-processing is still required.

Success criteria:

1. Plugin settings can be changed and saved from the UI.
2. Plugin reset behavior is consistent.
3. General settings still save correctly.

### Phase 5. Plugin Migration

1. Migrate KDEMoverSizer first.
2. Migrate WindowManager next.
3. Migrate remaining plugins gradually.
4. Remove old string-only metadata methods after all active plugins have moved.

## Recommended First Slice

The first implementation slice should be intentionally narrow:

1. Add `__DescribePlugin()` support to `AKPlugin`.
2. Migrate KDEMoverSizer to the new descriptor.
3. Extend `AKGui` state payload with one plugin page model.
4. Render one generated plugin page in `app.js`.
5. Keep saving read-only or partially implemented until the rendering path is stable.

This reduces risk because it proves the metadata shape before the save contract changes.

## Decisions on Open Questions

1. **Disabled plugins:** Show editable settings with a "disabled" badge. Changes save immediately, applied when plugin is re-enabled. ✓ Resolved
2. **Action-specific config on Hotkeys page:** Deferred to Phase 2+. Not required for Phase 1 slice. ✓ Deferred
3. **Helper builders:** Keep as Phase 2+ optimization. Manual `Map()` calls are sufficient to start. ✓ Deferred
4. **Reset behavior:** Restore descriptor defaults only. `defaultConfig.ahk` will be removed/deprecated in a later phase. ✓ Resolved
5. **Legacy method removal:** Keep legacy methods as wrapping stubs during Phases 1–5, marked `// TODO: remove after Phase 5`. ✓ Resolved

## Recommendation

Use a single structured plugin descriptor (`__DescribePlugin()`) as the long-term source of truth. During migration, legacy help methods serve as compatibility wrappers. Generate plugin settings pages entirely from descriptor metadata, and move the save contract to an object-based payload before adding many plugin pages.
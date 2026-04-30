# DevTools State Export/Import Guide

Quick reference for exporting and importing AHK settings state for debugging across browsers.

## Setup

1. Include the utility script in `settings.html`:
```html
<script src="devtools-state-export.js"></script>
```

2. Open DevTools Console (F12 → Console tab)

## Export State

### Option 1: Export to Console (manual copy)
```javascript
exportAhkState()
```
- Logs JSON to console
- Right-click → Copy
- Paste in another browser

### Option 2: Export to Clipboard (automatic)
```javascript
exportAhkStateToClipboard()
```
- Copies state directly to clipboard
- Paste using `Ctrl+V` in target console

## Import State

### Option 1: From JSON string
```javascript
importAhkState('{"general":{"DebugLevel":"1"},...}')
```

### Option 2: From clipboard
```javascript
navigator.clipboard.readText().then(importAhkState)
```
Then paste the copied state.

### Option 3: From variable
```javascript
let state = exportAhkState();
// ... do something ...
importAhkState(state)
```

## Compare States

Check what changed between two exports:
```javascript
let before = exportAhkState();
// ... make changes ...
let after = exportAhkState();
compareAhkStates(before, after)
```

Outputs a table showing differences in a structured format.

## Workflow Example

1. **Browser A (Source):**
   ```javascript
   exportAhkStateToClipboard()
   ```

2. **Browser B (Target):**
   ```javascript
   // Paste and import
   importAhkState(`<paste here>`)
   ```

3. **Verify:**
   ```javascript
   compareAhkStates(stateA, stateB)
   ```

## Troubleshooting

- **"Settings form not available"** → Settings dialog not fully loaded yet
- **Parse error on import** → JSON is malformed; check quote escaping
- **Fields not updating** → Reload page after import, or manually trigger field change events

## Available Functions

| Function | Purpose |
|----------|---------|
| `exportAhkState()` | Export state as JSON, return object |
| `importAhkState(json)` | Import and apply state from JSON string |
| `exportAhkStateToClipboard()` | Export directly to browser clipboard |
| `compareAhkStates(s1, s2)` | Show diff table between two states |

## State Structure

Exported state follows this schema:
```json
{
  "general": {
    "DebugLevel": "value",
    "WelcomeMessage": "value",
    ...
  },
  "disabledPlugins": ["PluginA", "PluginB"],
  "pluginConfigs": {
    "PluginName": {
      "configKey": "value",
      ...
    }
  },
  "hotkeys": [
    {
      "action": "HotkeyName",
      "value": "Hotkey sequence",
      "target": "field_id",
      "isPluginAction": false
    }
  ]
}
```

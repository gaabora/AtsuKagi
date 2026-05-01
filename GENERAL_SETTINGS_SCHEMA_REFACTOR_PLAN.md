# General Settings Schema Refactor Plan

## Objective

Refactor General settings so they are generated from structured schema metadata, matching the plugin-settings model.

Current behavior:
- General settings UI is mostly static and hardcoded in [includes/ui/settings.html](includes/ui/settings.html#L58)
- General serialization is hardcoded key-by-key in [includes/ui/classes/SettingsForm.js](includes/ui/classes/SettingsForm.js#L11)
- General AHK parsing is hardcoded with switch/case in [includes/AKGui.ahk](includes/AKGui.ahk#L363)

Target behavior:
- General fields are declared in one schema source
- AHK sends schema + values in state payload
- JS renders General fields dynamically from schema
- Save/apply path for General is schema-driven (typed), not key-specific code branches

## Scope

In scope:
- General settings section model, rendering, serialization, and apply logic
- AHK and JS bridge updates for General schema payload
- Backward-compatible migration path

Out of scope:
- Visual redesign
- Plugin schema or plugin page behavior changes
- Changes to persisted INI key names unless explicitly needed

## Success Criteria

1. No hardcoded General field list in JS serialization/apply paths.
2. No hardcoded General field rows in static HTML.
3. Adding a new General setting requires schema update only (no JS key-branch edits).
4. Existing General keys keep current persisted values and behavior.
5. Plugin pages remain unaffected.

## Current State Summary

### Hardcoded points to remove

1. Static General form markup in [includes/ui/settings.html](includes/ui/settings.html#L58)
2. Explicit General field reads in [includes/ui/classes/SettingsForm.js](includes/ui/classes/SettingsForm.js#L11)
3. Explicit General field writes in [includes/ui/classes/SettingsForm.js](includes/ui/classes/SettingsForm.js#L169)
4. Switch-based General config apply in [includes/AKGui.ahk](includes/AKGui.ahk#L363)

### Existing reusable dynamic patterns

1. Plugin page metadata assembly in [includes/AKApp.ahk](includes/AKApp.ahk#L189)
2. Dynamic plugin UI generation in [includes/ui/classes/SettingsForm.js](includes/ui/classes/SettingsForm.js#L254)
3. Typed value conversion for plugin settings in [includes/AKGui.ahk](includes/AKGui.ahk#L430)

## Proposed Architecture

## 1) General Schema Provider (AHK)

Add centralized General schema producer in AHK. Recommended host location:
- [includes/AKApp.ahk](includes/AKApp.ahk)

Use a descriptor pattern similar to existing `__DescribePlugin()` so metadata has one source of truth.

Recommended shape:
1. `__DescribeGeneralSettings()` returns one descriptor map
2. `GetGeneralSettingsPage()` derives page metadata from descriptor
3. `GetGeneralConfigSchema()` derives field schema from descriptor
4. `GetGeneralConfigValues()` injects current config values into schema fields

Why this pattern:
1. Matches the plugin architecture and avoids creating a second metadata style
2. Keeps defaults, labels, controls, and validation in one place
3. Prevents drift between UI rendering, save/apply logic, and docs

Schema field contract (aligned with plugin fields):
1. key
2. label
3. description
4. type (`string`, `integer`, `number`, `boolean`, `hotkey`, `color`, `path`, `select`)
5. control (`text`, `number`, `switch`, `hotkey`, `color`, `select`, `path`, `range`)
6. default
7. value
8. section
9. validation

## 2) AHK State Payload

Extend settings bootstrap payload in [includes/AKGui.ahk](includes/AKGui.ahk#L100):
1. Add `generalPage` metadata and schema-driven sections/fields
2. Keep existing `general` object during migration for compatibility

Bridge call remains:
- `window.SettingsPageBridge.applyState(state)`

## 3) JS Dynamic General Rendering

In [includes/ui/classes/SettingsForm.js](includes/ui/classes/SettingsForm.js):
1. Add `renderGeneralPage(page)`
2. Render section groups and field controls from schema
3. Reuse control templates/patterns from plugin rendering where practical

In [includes/ui/settings.html](includes/ui/settings.html#L58):
1. Replace hardcoded General rows with General container placeholder
2. Preserve section shell and title bar behavior

## 4) JS Schema-Driven General Serialization

In [includes/ui/classes/SettingsForm.js](includes/ui/classes/SettingsForm.js#L11):
1. Remove fixed key reads
2. Serialize all `.general-field[data-key][data-type]`
3. Convert checkbox/switch controls to booleans consistently

Output payload remains compatible:
1. `general` object (same keys)
2. encoded lines via `SettingsForm.encodeGeneralLines(...)`

## 5) AHK Schema-Driven Apply

In [includes/AKGui.ahk](includes/AKGui.ahk#L363):
1. Replace switch/case with generic schema-based assignment
2. Use type coercion rules from schema (`boolean`, `integer`, `number`, string fallback)
3. Keep unknown-key diagnostics, but keyed by schema lookup

## Migration Phases

## Phase 0: Safety Net

1. Add debug logs around incoming/outgoing General payload.
2. Keep existing hardcoded path untouched.
3. Add side-by-side snapshot comparison helper (optional debug mode).

Done when:
- Dev build can print General payload before and after save.

## Phase 1: Schema introduction only

1. Implement General schema provider in AHK.
2. Send `generalPage` in state payload.
3. Do not change UI rendering yet.

Done when:
- DevTools state export includes valid `generalPage` descriptor and values.

## Phase 2: Dynamic General render (dual mode)

1. Add dynamic renderer in JS.
2. Gate with feature flag (e.g. `generalPage.enableDynamicRender`).
3. Keep static HTML fallback until parity proven.

Done when:
- Dynamic and static render produce equivalent visible fields/values.

## Phase 3: Dynamic serialization/apply

1. Switch JS serialize/apply to schema-driven.
2. Switch AHK general apply to schema-driven type coercion.
3. Keep fallback parsing branch one release cycle.

Done when:
- Save/reopen roundtrip preserves all General values exactly.

## Phase 4: Remove hardcoded legacy

1. Remove static General rows from HTML.
2. Remove hardcoded JS key list reads/writes.
3. Remove AHK switch/case branch.

Done when:
- New General fields can be added by schema only.

## Phase 5: Cleanup + docs

1. Update architecture docs and README sections.
2. Add developer note for adding new General fields.
3. Remove temporary feature flag.

Done when:
- No migration-only code paths remain.

## Field Migration Matrix

Schema baseline for currently editable General keys:

| Key | Current Source | Type | Control | Default Source | Notes |
|---|---|---|---|---|---|
| WelcomeMessage | GENERAL | string | text | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L11) | simple text |
| DarkTheme | GENERAL | integer | select | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L19) | values: -1,0,1 |
| DebugLevel | GENERAL | integer | select | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L14) | keep existing levels |
| ToolTipTimeoutMs | GENERAL | integer | number | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L12) | min/max validation |
| WindowTransparencyValue | GENERAL | integer | range | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L10) | retain slider + label sync |
| WindowOnTopBorderColor | GENERAL | color | color | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L9) | retain color picker dialog |
| StartupSound | GENERAL | path | path | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L15) | retain Browse behavior |
| NotificationSound | GENERAL | path | path | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L16) | retain Browse behavior |
| ReloadAppHotkey | GENERAL | hotkey | hotkey | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L17) | retain recorder flow |
| SuspendAppHotkey | GENERAL | hotkey | hotkey | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L18) | retain recorder flow |
| SwapMouseXButtons | GENERAL | boolean | switch | [includes/defaultConfig.ahk](includes/defaultConfig.ahk#L20) | store as 0/1 in ini |

Optional second-wave General keys (currently not in UI):
- HotkeyInterval
- MaxHotkeysPerInterval
- KeyboardHookStealersList
- BlocklistGlobalWindowClasses
- ModifierHotkeysHint
- DisabledPlugins (should likely remain in Plugins page context)

## Type Coercion Rules

General apply/save should use explicit coercion:
1. boolean: `1|true` => true/1, else false/0
2. integer: parse to integer, fallback to raw string if invalid
3. number: parse float, fallback to raw string if invalid
4. hotkey/path/color/string/select: string passthrough

Persist format decision:
- Keep INI-compatible values (booleans written as 0/1 where expected)

## Compatibility Strategy

1. JS continues sending legacy-compatible encoded General lines.
2. AHK accepts schema-driven keys and ignores unknown keys with warning.
3. During migration, preserve both:
   - existing `state.general`
   - new `state.generalPage`

## Test Plan

Manual checks:
1. Open settings and verify General fields render with correct values.
2. Modify each field type and save.
3. Reopen settings and verify roundtrip.
4. Reload app and verify behavior-impacting values still take effect.

Regression checks:
1. Plugin pages still render and save unchanged.
2. Hotkeys table still updates.
3. Logs/problems sections unaffected.
4. Theme switching still updates settings window theme.

Suggested automated test follow-up:
1. Add unit tests for line encoding/decoding and type coercion.
2. Add schema contract test: every General schema key has default.

## Implementation Task List

1. Add General schema builder in AHK.
2. Extend AHK->JS payload with `generalPage`.
3. Add dynamic General renderer in JS.
4. Add generic General serializer from rendered fields.
5. Add AHK generic General apply using schema index.
6. Remove hardcoded General HTML and JS/ahk branches.
7. Validate with test checklist.

## Rollback Plan

If issues appear:
1. Keep feature flag to force static General rendering.
2. Keep AHK legacy switch-based parser for one cycle.
3. Log schema mismatches at debug level >= 3 for diagnosis.

## Ownership Notes

Recommended implementation order:
1. AHK schema + payload
2. JS renderer
3. JS serializer
4. AHK parser
5. cleanup

This order minimizes integration risk and keeps rollback simple.
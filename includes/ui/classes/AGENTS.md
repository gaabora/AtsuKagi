# Settings Classes

## Purpose

- Own focused frontend controllers, host bridges, form serialization, and dynamic settings renderers.

## Ownership

- Keep each class responsible for one settings concern.
- `AhkHostBridge.js` is the frontend boundary for AHK callbacks.
- Renderer classes own generated markup contracts consumed by `SettingsPage`.

## Local Contracts

- Preserve public methods called by `SettingsPage.js` and global bridge code.
- Host return values must be normalized before page code relies on them.
- Plugin list state includes `debugLevels` overrides and `globalDebugLevel`; `-1` in the selector means inherit the global level.

## Work Guidance

- Reuse existing DOM and binding helpers instead of adding parallel event systems.

## Verification

## Child DOX Index

- No child DOX files.

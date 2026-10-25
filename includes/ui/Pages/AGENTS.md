# Settings Pages

## Purpose

- Own page-level settings UI orchestration.

## Ownership

- `SettingsPage.js` coordinates navigation, controllers, rendering, and autosave behavior.

## Local Contracts

- Preserve compatibility with `SettingsDom`, renderer output, and `AhkHostBridge`.
- State application must not trigger unintended persistence callbacks.
- `SettingsPage` accepts an optional host bridge; its default is `AhkHostBridge`. Browser development passes a mock with the same methods.
- Plugin enable and debug-level controls must restore their prior values when an atomic host save fails.

## Work Guidance

- Keep lower-level rendering and serialization logic in `../classes/`.

## Verification

## Child DOX Index

- No child DOX files.

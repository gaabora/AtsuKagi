# Settings Pages

## Purpose

- Own page-level settings UI orchestration.

## Ownership

- `SettingsPage.js` coordinates navigation, controllers, rendering, and autosave behavior.

## Local Contracts

- Preserve compatibility with `SettingsDom`, renderer output, and `AhkHostBridge`.
- State application must not trigger unintended persistence callbacks.

## Work Guidance

- Keep lower-level rendering and serialization logic in `../classes/`.

## Verification

## Child DOX Index

- No child DOX files.

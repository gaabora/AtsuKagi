# Synthetic Workspaces Engine

## Purpose

- Own feature-specific portable model and service code for synthetic workspaces.

## Ownership

- `WorkspaceModel.ahk` owns stable workspace identity, directional slot mapping, active workspace state, and separated runtime window state containers.
- The top-level `plugins/SyntheticWorkspaces.ahk` file will own the plugin descriptor, public actions, and lifecycle when that stage starts.
- Windows window APIs belong in a later platform backend and must not enter portable model files.

## Local Contracts

- Keep the eight slot IDs exact: `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, and `nw`.
- Keep workspace IDs stable and separate from slot IDs.
- Keep observed, desired, and pending runtime window state in separate maps.
- Portable code must not call `WinGet*`, `WinMove`, `DllCall`, or other platform APIs.

## Work Guidance

- Add only behavior required by the current Synthetic Workspaces MVP stage.
- Use AutoHotkey v2 and public PascalCase/private `_camelCase` names.

## Verification

- `tests/SyntheticWorkspacesModelTests.ahk` checks the workspace and slot invariants.
- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- No child DOX files.

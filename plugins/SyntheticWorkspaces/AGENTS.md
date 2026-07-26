# Synthetic Workspaces Engine

## Purpose

- Own feature-specific portable model and service code for synthetic workspaces.

## Ownership

- `WorkspaceModel.ahk` owns stable workspace identity, directional slot mapping, active workspace state, and separated runtime window state containers.
- `WorkspaceService.ahk` owns the default in-memory model, direction-to-workspace action resolution, service lifecycle, and explicit missing-capability errors.
- The top-level `plugins/SyntheticWorkspaces.ahk` file owns the plugin descriptor, public actions, and app-exit lifecycle.
- Windows window APIs belong in a later platform backend and must not enter portable model files.

## Local Contracts

- Keep the eight slot IDs exact: `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, and `nw`.
- Keep workspace IDs stable and separate from slot IDs.
- Keep observed, desired, and pending runtime window state in separate maps.
- Public plugin actions must delegate to `SyntheticWorkspaceService`.
- Missing workspace or overview runtimes must fail clearly instead of reporting success.
- Portable code must not call `WinGet*`, `WinMove`, `DllCall`, or other platform APIs.

## Work Guidance

- Add only behavior required by the current Synthetic Workspaces MVP stage.
- Use AutoHotkey v2 and public PascalCase/private `_camelCase` names.

## Verification

- `tests/SyntheticWorkspacesModelTests.ahk` checks the workspace and slot invariants.
- `tests/SyntheticWorkspacesPluginTests.ahk` checks descriptor parity, slot resolution, delegation, lifecycle cleanup, and explicit missing capabilities.
- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- No child DOX files.

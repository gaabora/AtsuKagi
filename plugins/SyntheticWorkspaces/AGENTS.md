# Synthetic Workspaces Engine

## Purpose

- Own feature-specific portable model and service code for synthetic workspaces.
- Own child platform backends behind the portable service boundary.

## Ownership

- `WorkspaceModel.ahk` owns stable workspace identity, directional slot mapping, active workspace state, and separated runtime window state containers.
- `WorkspaceService.ahk` owns the default in-memory model, direction-to-workspace action resolution, service lifecycle, and explicit missing-capability errors.
- `RuntimeWindowCache.ahk` owns complete live window records, stable session runtime IDs, and HWND indexes.
- `WorkspaceRuntime.ahk` owns initial refresh, event-driven cache updates, focus history, light reconciliation repair, window assignment, and stale HWND removal.
- The top-level `plugins/SyntheticWorkspaces.ahk` file owns the plugin descriptor, public actions, and app-exit lifecycle.
- `Windows/` owns Windows snapshots, classification, native event hooks, reconciliation timing, AppUserModelID reads, and cached app icons.

## Local Contracts

- Keep the eight slot IDs exact: `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, and `nw`.
- Keep workspace IDs stable and separate from slot IDs.
- Keep observed, desired, and pending runtime window state in separate maps.
- Public plugin actions must delegate to `SyntheticWorkspaceService`.
- Missing workspace or overview runtimes must fail clearly instead of reporting success.
- Portable files must not call `WinGet*`, `WinMove`, `DllCall`, or other platform APIs.

## Work Guidance

- Add only behavior required by the current Synthetic Workspaces MVP stage.
- Use AutoHotkey v2 and public PascalCase/private `_camelCase` names.

## Verification

- `tests/SyntheticWorkspacesModelTests.ahk` checks the workspace and slot invariants.
- `tests/SyntheticWorkspacesPluginTests.ahk` checks descriptor parity, slot resolution, delegation, lifecycle cleanup, and explicit missing capabilities.
- `tests/SyntheticWorkspacesRuntimeTests.ahk` checks runtime records, cache repair, classification, assignment, and the read-only backend boundary.
- Do not run automated tests under the current repository-wide user preference.
- `tests/SyntheticWorkspacesEventTests.ahk` checks event-driven cache updates, focus history, light reconciliation, identity/icon source contracts, and cleanup with fake events.

## Child DOX Index

- [`Windows/AGENTS.md`](Windows/AGENTS.md): Windows-only snapshots, classification, native events, and reconciliation.

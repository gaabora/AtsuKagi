# Synthetic Workspaces Windows Backend

## Purpose

- Own Windows-only window discovery, observed snapshots, classification, native window events, reconciliation timing, placement, desktop covers, focus, special-window state, and unsupported-window offscreen handling for Synthetic Workspaces.

## Ownership

- `WindowBackend.ahk` reads top-level Windows metadata and assigns one canonical class with a diagnostic reason.
- `WindowEventService.ahk` owns WinEvent hooks and the low-rate reconciliation timer.
- `WorkspacePlacementBackend.ahk` applies prepared window state, z-order bands, covers, focus, verification, conditional rollback, and emergency restore.
- `OffscreenHelper.ahk` makes one bounded non-activating offscreen move attempt in a separate AutoHotkey process.

## Local Contracts

- Return `managed`, `owned-dialog`, `global`, `shell`, `ignored`, or `unsupported` with a non-empty reason.
- Restore `DetectHiddenWindows` after every enumeration attempt.
- Use non-blocking responsiveness checks and never wait on a target window.
- Read AppUserModelID from the window property store and report a clear reason when it is missing or unavailable.
- Cache one extracted icon per executable path and destroy owned icon handles on close.
- Do not read process command lines until an advanced identity rule enables that data.
- Keep `WindowBackend.ahk` and `WindowEventService.ahk` read-only; only `WorkspacePlacementBackend.ahk` and `OffscreenHelper.ahk` may mutate windows.
- Stop every timer, unhook every WinEvent hook, and free every native callback during cleanup.
- Keep reconciliation at 1500 ms and allow later switch transactions to pause it.
- Keep one non-activating process-owned cover per monitor and remove every cover when band verification is unsafe.
- Preserve original topmost and minimized state for suspend, disable, reload, exit, rollback, and emergency cleanup.
- Never move a non-responsive window from the main process; start the helper once when available, stop it after 500 ms, report an unavailable or rejected move, and do not remove covers only because its move was rejected.

## Work Guidance

- Keep Win32 and Windows-specific AHK calls inside this folder.

## Verification

- `tests/SyntheticWorkspacesRuntimeTests.ahk` checks classification with fake snapshots and checks that this backend has no mutating window calls.
- `tests/SyntheticWorkspacesEventTests.ahk` checks native event coverage and cleanup statically, and checks runtime behavior with fake events and snapshots.
- `tests/SyntheticWorkspacesSwitchTests.ahk` checks the placement contract statically and the portable transaction through a fake placement backend.
- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- No child DOX files.

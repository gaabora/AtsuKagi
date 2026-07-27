# Synthetic Workspaces Windows Backend

## Purpose

- Own Windows-only window discovery, observed snapshots, classification, native window events, and reconciliation timing for Synthetic Workspaces.

## Ownership

- `WindowBackend.ahk` reads top-level Windows metadata and assigns one canonical class with a diagnostic reason.
- `WindowEventService.ahk` owns WinEvent hooks and the low-rate reconciliation timer.
- Placement, focus changes, covers, and offscreen helpers belong to later MVP stages.

## Local Contracts

- Return `managed`, `owned-dialog`, `global`, `shell`, `ignored`, or `unsupported` with a non-empty reason.
- Restore `DetectHiddenWindows` after every enumeration attempt.
- Use non-blocking responsiveness checks and never wait on a target window.
- Read AppUserModelID from the window property store and report a clear reason when it is missing or unavailable.
- Cache one extracted icon per executable path and destroy owned icon handles on close.
- Do not read process command lines until an advanced identity rule enables that data.
- Keep event handling read-only: do not move, hide, minimize, activate, focus, or restack windows.
- Stop every timer, unhook every WinEvent hook, and free every native callback during cleanup.
- Keep reconciliation at 1500 ms and allow later switch transactions to pause it.

## Work Guidance

- Keep Win32 and Windows-specific AHK calls inside this folder.

## Verification

- `tests/SyntheticWorkspacesRuntimeTests.ahk` checks classification with fake snapshots and checks that this backend has no mutating window calls.
- `tests/SyntheticWorkspacesEventTests.ahk` checks native event coverage and cleanup statically, and checks runtime behavior with fake events and snapshots.
- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- No child DOX files.

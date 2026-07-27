# Synthetic Workspaces Windows Backend

## Purpose

- Own Windows-only window discovery, observed snapshots, and classification for Synthetic Workspaces.

## Ownership

- `WindowBackend.ahk` reads top-level Windows metadata and assigns one canonical class with a diagnostic reason.
- Window events, reconciliation timers, placement, focus, covers, and offscreen helpers belong to later MVP stages.

## Local Contracts

- Return `managed`, `owned-dialog`, `global`, `shell`, `ignored`, or `unsupported` with a non-empty reason.
- Restore `DetectHiddenWindows` after every enumeration attempt.
- Use non-blocking responsiveness checks and never wait on a target window.
- Keep this stage read-only: do not move, hide, minimize, activate, focus, or restack windows.
- Report unavailable AppUserModelID data explicitly until that capability is implemented.

## Work Guidance

- Keep Win32 and Windows-specific AHK calls inside this folder.

## Verification

- `tests/SyntheticWorkspacesRuntimeTests.ahk` checks classification with fake snapshots and checks that this backend has no mutating window calls.
- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- No child DOX files.

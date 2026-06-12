# Feature Plugins

## Purpose

- Own dynamically loaded feature classes that extend `AKPlugin` and expose user-callable actions.

## Ownership

- Each plugin owns its descriptor, configuration defaults, action implementation, and private helpers.
- Shared dispatch, metadata processing, blocklists, and settings integration belong in `includes/`.
- `dynamicPlugins.ahk` at the repository root is generated from this directory and is not hand-maintained as plugin source.

## Local Contracts

- Plugin filenames, class names, and descriptor `plugin.id` values must match.
- Public actions must be declared in `__DescribePlugin()` and keep signatures compatible with configured action strings.
- Window-mutating actions must resolve and validate target HWNDs and respect the applicable blocklist contract.
- `WindowResizeDialog.ahk` owns the numeric resize dialog and its focused directional-key controls; `WindowManager.ahk` must not duplicate that action or dialog state.
- The resize dialog key layout, move modifier, step modifier, default precision mode, and pixel step sizes are descriptor-backed plugin settings.
- Resize-dialog directional input must support held horizontal and vertical keys together for diagonal resize and move operations, with modifiers evaluated while the keys are held.
- Directional input applies one immediate step, then waits for the configured repeat delay before repeating at the configured polling interval.
- Use AutoHotkey v2 syntax and existing plugin naming conventions.

## Work Guidance

- Keep user actions small and delegate repeated mechanics to private helpers.
- Preserve hovered-window wrappers as thin calls into the corresponding HWND-aware action.
- Document new configuration keys and action parameters in the descriptor.

## Verification

- Review descriptor/action parity and configured call sites statically.
- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- No child DOX files.

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

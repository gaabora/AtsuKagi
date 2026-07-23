# Application Core

## Purpose

- Own application startup support, configuration defaults, plugin registration, action dispatch, GUI hosting, and Windows constants.

## Ownership

- `AKApp.ahk` owns application orchestration and public action/plugin registries.
- `AKPlugin.ahk` owns plugin metadata and the plugin-to-app bridge.
- `AKGui.ahk` owns the AHK side of the settings WebView.
- `defaultConfig.ahk` owns shipped configuration defaults.
- `ui/` owns the settings frontend.

## Local Contracts

- Keep AutoHotkey v2 syntax and the existing public PascalCase/private `_camelCase` convention.
- Changes to plugin descriptors, action dispatch, or settings payloads must remain compatible across `AKApp.ahk`, `AKPlugin.ahk`, and `ui/`.
- Plugin debug overrides are stored in `[PLUGIN_DEBUG]`; missing plugin entries inherit `[GENERAL].DebugLevel`, and loaded plugins apply level changes without reload.
- `AKBase.outputDebugLine` applies the instance debug threshold before writing to either `OutputDebug` or the settings log buffer.
- Central action dispatch logs each action start at debug level with its hotkey plus active and hovered window context.
- Central action dispatch catches runtime failures, logs full technical details, and shows a user-readable styled notification instead of allowing an AutoHotkey error window.
- `AKBase.ShowInfo` supports `info`, `success`, `warning`, and `error` notification styles through its fourth parameter.
- `AKBase.ShowInfo` uses live `[GENERAL]` notification appearance settings; a timeout of `-1` uses `NotificationDurationMs`.
- The General settings page owns global notification position, typography, padding, width, corner radius, and border controls.
- `AKApp.ToolTip` owns the shared custom tooltip GUI behavior while preserving the existing text, position, timeout, and forced-ID API.
- `SkipIfBlocklisted` passthrough must preserve held mouse-button input so blocked applications can keep native drag behavior.
- Windows constants should be named and centralized instead of repeated as unexplained literals when broadly reused.

## Work Guidance

- Keep application orchestration in the core and feature-specific behavior in `plugins/`.
- Preserve script-mode and compiled-build resource paths.

## Verification

## Child DOX Index

- [`ui/AGENTS.md`](ui/AGENTS.md): settings WebView frontend and bundled frontend dependencies.

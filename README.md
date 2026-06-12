# Haribol!

Haribol! is portable utility that combines window manager, virtual desktops, dynamic hotkeys manager, keyboard layout switching, touch gesture simulation, and small everyday workflow shortcuts on Windows.

It is built around a plugin system, but you do not need to think about plugins to start using it. Run the script, open Settings from the tray icon, and enable only the parts you want.

## Why Use It

- Move, resize, maximize, minimize, pin windows with keyboard and mouse shortcuts like in KDE but even more flexible.
- Switch virtual desktops faster and move windows between them.
- Convert mistyped text between keyboard layouts.
- Use mouse-driven gesture actions.
- Keep hotkeys and plugin enable/disable settings in one config file and one settings window.
- See startup diagnostics, logs, and config problems in the built-in UI.

## Quick Start

1. Install AutoHotkey v2.
2. Run [Haribol!.ahk](Haribol!.ahk).
3. Find the tray icon and open `Settings` from the tray menu.
4. Adjust plugins, hotkeys, sounds, and theme settings.
5. Reload the app from the tray menu or use the configured reload hotkey.

Notes:

- The repo already includes [VirtualDesktopAccessor.dll](VirtualDesktopAccessor.dll), so virtual desktop actions can work without an extra download.
- A compiled build can be produced with the workspace `build` task if you want an `.exe`.

## Configuration Basics

- [ACTION_CATALOG.md](ACTION_CATALOG.md): action reference.
- [PLUGIN_API.md](PLUGIN_API.md): plugin authoring guide.
- [BLOCKLIST_GUIDE.md](BLOCKLIST_GUIDE.md): how to exclude certain windows from actions.

## Plugin Overview

| Plugin | Purpose | Status |
|---|---|---|
| `WindowManager` | Minimize, maximize, fullscreen, on-top, transparency, window info | Stable |
| `WindowResizeDialog` | Numeric and keyboard-driven window resizing and positioning | Stable |
| `KDEMoverSizer` | Drag-based moving/resizing with snapping and axis lock | Stable |
| `VirtualDesktopManager` | Switch desktops, move windows between desktops, rename desktops | Stable |
| `TouchGesturesSimulator` | Mouse-driven touch gesture simulation | Stable |
| `TextLocaleManager` | Keyboard layout switching and text layout conversion | Stable |
| `TimerHandlers` | Future timer and scheduled task features | Experimental |
| `TextToSpeech` | Windows SAPI speech support placeholder | Experimental |
| `SwapButtonsHandler` | Future mouse button remapping | Experimental |
| `ShellMessageHook` | Low-level shell window event hooks | Experimental |
| `RDPWindowHandler` | RDP-specific window handling | Experimental |


## Example Hotkeys

These examples come from the current default config.

| Hotkey | Action | What it does |
|---|---|---|
| `Win+Left Click` | `EnterWindowMovingMode` | Move the window under the cursor |
| `Win+Right Click` | `IfThenElse(IsMouseOverWindowTitlebar, MinimizeHoveredWindow, EnterWindowResizingMode)` | Minimize from title bar, otherwise resize |
| `Win+Middle Click` | `IfThenElse(IsMouseOverWindowTitlebar, CloseHoveredWindow, ToggleHoveredWindowMaximized)` | Close or maximize hovered window |
| `Win+Enter` | `ToggleWindowMaximized` | Toggle maximize on the active window |
| `Ctrl+Win+Alt+Space` | `ToggleWindowTransparency` | Toggle transparency on the active window |
| `Win+WheelUp` | `IfThenElse(IsMouseOverWindowTitlebar, GoWithHoveredWindowToPrevDesktop, GoToPrevDesktop)` | Switch desktop, or move with hovered window |
| `CapsLock` | `SwitchKeyboardLayout()` | Switch current keyboard layout |
| `Ctrl+CapsLock` | `SwitchSelectedTextLayout(EN,RU)` | Convert selected text between EN and RU layouts |
| `RButton` | `SkipIfBlocklisted(NoRightClickGesture, EnterGestureMode(1, 4))` | Right-button gesture mode unless excluded by blocklist |
| `XButton2` | `EnterGestureMode(4, 4, ToggleTaskView)` | Four-finger gesture mode with Task View fallback |

See the full list in [includes/defaultConfig.ahk](includes\defaultConfig.ahk).

## Settings And Troubleshooting

Open `Settings` from the tray icon to manage:

- General app settings
- Theme values
- Enabled and disabled plugins
- Hotkeys
- Logs
- Problems detected during startup/config validation

If something does not work:

1. Open the `Problems` tab in Settings and fix invalid hotkeys or action names.
2. Open the `Logs` tab and check which plugins and actions were loaded.
3. Verify the target plugin is not listed in `GENERAL.DisabledPlugins`.
4. Check [BLOCKLIST_GUIDE.md](BLOCKLIST_GUIDE.md) if an action appears to do nothing in a specific app.
5. For virtual desktop actions, confirm [VirtualDesktopAccessor.dll](VirtualDesktopAccessor.dll) is present.

Useful built-in controls:

- Reload hotkey default: `Ctrl+Win+Alt+Backspace`
- Suspend hotkey default: `Ctrl+Win+Alt+Esc`
- Tray menu: `Settings`, `Reload`, `Disable`, `Exit`

## Advanced Docs

- [ACTION_CATALOG.md](ACTION_CATALOG.md)
- [PLUGIN_API.md](PLUGIN_API.md)
- [BLOCKLIST_GUIDE.md](BLOCKLIST_GUIDE.md)
- [ROADMAP.md](ROADMAP.md)

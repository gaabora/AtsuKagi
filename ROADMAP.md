# Window Manager and Shell Direction

## Current state

Haribol! is currently a Windows utility written in AutoHotkey v2. It extends the normal Windows shell instead of replacing it.

The current version already provides:

- Configurable global keyboard and mouse hotkeys.
- Window move, resize, minimize, maximize, close, fullscreen, frame, transparency, and always-on-top actions.
- KDE-style window move and resize with snapping and axis locking.
- Numeric window size and position controls.
- Windows virtual desktop switching, creation, naming, and moving windows between desktops.
- Mouse-driven touch gesture simulation.
- Keyboard layout switching and correction of text typed with the wrong layout.
- Plugins, per-window blocklists, settings UI, logs, and configuration checks.

This Windows/AHK version is the working base and a place to test behavior. A likely version 1 is a native cross-platform C++ application with feature parity and a larger window-policy system.

## Main goal

The long-term goal is a fast, programmable desktop shell and window manager for Windows, macOS, and Linux.

It should manage window geometry, focus, stacking, popups, hotkeys, layouts, and workspaces. It may also provide its own desktop layer, launcher, panels, notifications, and other shell UI.

It will not replace the OS display server or compositor. Windows DWM, macOS WindowServer, X11 will still draw and own application windows, but for Wayland we have to use our app as a compositor to be able to support global hotkeys and full windows control

Where possible, built-in shell parts such as the taskbar, Dock, desktop icons, and system shortcuts can be hidden, disabled, or replaced. Exact control is different on every platform.

## Synthetic workspaces

The planned workspace model does not need native Windows virtual desktops, macOS Spaces, or Linux workspaces. Each window can instead receive one or more workspace tags.

The first Windows and AutoHotkey MVP is defined in
[`SYNTHETIC_WORKSPACES_PLAN.md`](SYNTHETIC_WORKSPACES_PLAN.md).

The intended stack is:

```text
inactive workspace windows
desktop cover layer
active workspace windows
Haribol! shell UI
```

Switching a workspace would rebuild this order, restore its saved geometry and focus, and keep inactive windows below the desktop cover. Windows would not need to be minimized, hidden, or moved off-screen, but can be suspended/paused to save cpu (can be adjusted in Haribol! settings for each app behavior)

Minimizing normally does not suspend an application on Windows, macOS, or Linux. It may reduce drawing or composition work when the application cooperates, but CPU, memory, timers, and network work usually continue. Workspaces are therefore an organization and isolation feature, not a resource-saving feature.

Process suspension may be offered as an explicit per-application rule. It should not be the default because one process can own several windows and may hold audio, GPU, file, or network resources.

## Window state and policy

The application should keep a cached model of every managed window, including identity, owner, type, geometry, workspace, focus, visibility, minimized state, topmost state, and stack position.

The model must separate:

- Observed state reported by the OS.
- Desired state selected by Haribol! rules.
- Pending changes already requested by Haribol!.

Native events should provide immediate updates. A slower reconciliation scan should find missed events and repair differences. Constant high-frequency scanning of every property is unnecessary and can be expensive, especially on macOS.

Workspace and layout changes should be applied as transactions: calculate all changes, ignore events caused by that transaction, update stacking and geometry, restore focus, then verify the result.

## Popups and focus control

New windows and dialogs should be classified before they are allowed to interrupt the user. Useful signals include process identity, parent or owner window, window type, modal state, title, creation time, and recent user input.

Rules should be configurable per application. For example:

- Keep a normal window from an inactive app on its assigned workspace and mark that workspace as urgent.
- Switch to the app's workspace and focus an allowed dialog.
- Show an allowed dialog without focus.
- Deny focus, lower, notify about, or close a forbidden popup.
- Restore the previous approved window when an app steals focus.

Keyboard hooks and disabled system shortcuts reduce unwanted switching, but they are not enough. Applications can activate themselves, so foreground, creation, visibility, and stacking events must also be monitored.

## Native C++ design

The C++ version should be an event-driven core with small native backends, not a line-by-line port of PyWinCtl or the AHK code.

The portable core can own workspaces, rules, layouts, focus history, monitor state, transactions, configuration, and optional scripting. Native backends should only expose window discovery, geometry, stacking, focus, visibility, close, topmost, events, and platform capabilities.

Lua may be embedded later for reloadable rules and hotkeys while timing-sensitive work stays in C++.

Suggested order: reach current Windows feature parity first, add the synthetic workspace and policy engine, then add other platform backends without weakening the Windows behavior.

## Platform notes

| Platform | Main approach | Important limits |
|---|---|---|
| Windows | Win32 window APIs, WinEvent hooks, and a custom desktop cover | Strong control for normal windows; elevated apps, secure desktop prompts, topmost bands, and some fullscreen games need special handling. |
| macOS | Accessibility APIs, application activation, and Haribol!-owned overlay windows | Public APIs cannot freely place selected foreign application windows above and below one overlay. Strict synthetic workspaces may need a fallback or private APIs. Dock and menu bar replacement is also limited. |
| Linux/X11 | Become the window manager and use XCB/Xlib plus EWMH | Strong control when Haribol! is the real WM; otherwise it may conflict with the existing WM. |
| Linux/Wayland | Integrate with each compositor or provide a compositor | A normal client cannot universally inspect, move, stack, or focus other applications. KWin, GNOME, Sway, and Hyprland need separate integrations. |

Cross-platform should mean one shared behavior model with clearly reported capabilities, not pretending every OS supports the same low-level operations.

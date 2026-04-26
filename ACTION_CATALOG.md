# Action Catalog

This document lists all available actions by plugin. Actions are user-callable functions triggered by hotkeys or conditionally by other actions.

## GeneralHandlers
Built-in general-purpose actions available in all plugins.

- **IfThenElse(IfActionString, ThenActionString, ElseActionString)** - Evaluate condition (action string), then run ThenActionString if true, ElseActionString if false. Useful for branching logic.
- **SkipIfBlacklisted(BlacklistName, ActionString, FallbackAction='')** - Skip action if active window is in named blacklist; optionally run fallback instead of passthrough. Used to exclude certain windows from plugins.
- **RemapKeyTo(Hotkey)** - Simulate keyboard input. Same as deprecated RemapTo; kept for backward compatibility.
- **DoNothing()** - No-op action. Useful for disabling a hotkey without removing config.
- **ShowInfo(text, title='', timeout=2000)** - Display info popup with message, title, and optional timeout (ms).

## WindowManager
Manage windows: move, resize, minimize, toggle transparency (alpha), maximize, fullscreen. Detect mouse position over titlebar/borders for quick drag operations.

- **ShowWindowList()** - Display list of all open windows with their HWNDs.
- **ShowHoveredWindowInfo()** - Show info (title, HWND, class, process) of window under mouse cursor.
- **ShowWindowInfo(hwnd=0)** - Show info of specific window; default is active window.
- **ShowResizeWindowDialog(hwnd=0)** - Interactive dialog to resize window by entering width/height.
- **MinimizeWindow(hwnd=0)** - Minimize window; default is active window.
- **MinimizeHoveredWindow()** - Minimize window under mouse cursor.
- **CloseWindow(hwnd=0)** - Close window; default is active window.
- **CloseHoveredWindow()** - Close window under mouse cursor.
- **ToggleWindowMaximized(hwnd=0)** - Toggle maximized state of window.
- **ToggleHoveredWindowMaximized()** - Toggle maximized state of hovered window.
- **ToggleHoveredWindowOnTop(BorderColor=-1)** - Toggle "always on top" flag of hovered window; optionally draw colored border.
- **ToggleWindowOnTop(BorderColor=-1, hwnd=0)** - Toggle "always on top" flag of window.
- **ToggleWindowFullScreen(hwnd=0)** - Toggle fullscreen mode.
- **ToggleHoveredWindowFullScreen()** - Toggle fullscreen mode of hovered window.
- **ToggleWindowFrame(hwnd=0)** - Toggle window frame (titlebar/borders).
- **ToggleHoveredWindowFrame()** - Toggle frame of hovered window.
- **ToggleWindowTransparency(TransparencyValue=128, hwnd=0)** - Toggle transparency (alpha) with optional opacity level (0-255).
- **ToggleHoveredWindowTransparency(TransparencyValue=128)** - Toggle transparency of hovered window.
- **IncreaseWindowTransparency(ByValue=32, hwnd=0)** - Increase transparency (reduce opacity) by step (0-255).
- **IncreaseHoveredWindowTransparency(ByValue=32)** - Increase transparency of hovered window.
- **DecreaseWindowTransparency(ByValue=32, hwnd=0)** - Decrease transparency (increase opacity) by step.
- **DecreaseHoveredWindowTransparency(ByValue=32)** - Decrease transparency of hovered window.
- **SetWindowBorderColor(color=-1, hwnd=0)** - Set border color of window (hex color code).
- **ToggleTaskView()** - Toggle Windows Task View (virtual desktops overview).
- **IsMouseOverTaskbar()** - Check if mouse is over taskbar (condition for IfThenElse).
- **IsMouseOverWindowTitlebar()** - Check if mouse is over window title bar.
- **IsMouseOverWindowAnyBorder()** - Check if mouse is over any window border.
- **IsMouseOverWindowResizableBorder()** - Check if mouse is over resizable window border (for resize detection).

## VirtualDesktopManager
Switch between virtual desktops, move windows to desktops, create/remove desktops, rename desktops. Uses native Windows 10+ Virtual Desktop API via DLL.

- **GetDesktopName(desktopNumber)** - Get name of desktop by number.
- **SetDesktopName(desktopNumber, name)** - Set name/label of desktop.
- **CreateDesktop()** - Create new virtual desktop.
- **RemoveDesktop(RemoveDesktopNumber, FallbackDesktopNumber)** - Remove virtual desktop and switch removed window to fallback.
- **GetCurrentDesktopNumber()** - Get number of currently active desktop.
- **GetDesktopCount()** - Get total count of virtual desktops.
- **GetPrevDesktopNumber()** - Get number of previous desktop.
- **GetNextDesktopNumber()** - Get number of next desktop.
- **GoToDesktop(desktopNumber)** - Switch to specific desktop by number.
- **GoToRecentDesktop()** - Switch to most recently used desktop.
- **GoToPrevDesktop()** - Switch to previous desktop.
- **GoToNextDesktop()** - Switch to next desktop (loop to first at end).
- **MoveWindowToDesktop(desktopNumber, hwnd=0)** - Move window to specific desktop; default is active window.
- **MoveWindowToPrevDesktop(hwnd=0)** - Move window to previous desktop.
- **MoveWindowToNextDesktop(hwnd=0)** - Move window to next desktop.
- **MoveHoveredWindowToDesktop(desktopNumber)** - Move window under cursor to desktop.
- **MoveHoveredWindowToPrevDesktop()** - Move hovered window to previous desktop.
- **MoveHoveredWindowToNextDesktop()** - Move hovered window to next desktop.
- **GoWithWindowToDesktop(desktopNumber, hwnd=0)** - Move window to desktop AND switch to that desktop.
- **GoWithWindowToPrevDesktop()** - Move and switch to previous desktop.
- **GoWithWindowToNextDesktop()** - Move and switch to next desktop.
- **GoWithHoveredWindowToDesktop(desktopNumber)** - Move hovered window to desktop and switch.
- **GoWithHoveredWindowToPrevDesktop()** - Move hovered window and switch to previous desktop.
- **GoWithHoveredWindowToNextDesktop()** - Move hovered window and switch to next desktop.

## KDEMoverSizer
Enhanced window moving/resizing with drag from titlebar/borders. Visual frame guide overlay. Supports axis-locking and snap-to-grid.

- **EnterWindowMovingMode()** - Activate window moving mode (click and drag titlebar/anywhere on window). Hold Shift to lock axis, LWin for snap-to-grid.
- **EnterWindowResizingMode()** - Activate window resizing mode (click and drag borders to resize).

## TouchGesturesSimulator
Simulate touch gestures using mouse input. Multi-finger touch, swipe, pinch operations.

- **EnterGestureMode(fingers=1)** - Detect multi-finger touch gesture (1-10 fingers) using mouse position offsets.
- **SetPrecisionTouchpadRegistryConfig(key, value)** - Set Windows Precision Touchpad registry config (ThreeFingerSlideEnabled, FourFingerTapEnabled, etc.).

## TextLocaleManager
Detect current keyboard layout, switch layouts, convert mistyped text between EN/RU online. Useful for multi-language users who type in wrong layout.

- **SwapTextLayout(incorrectText, layoutA, layoutB)** - Convert text from one layout to another (e.g., "ghbdtn" EN→RU become "привет").
- **ShowCurrentKeyboardLayout()** - Display current keyboard layout tooltip at mouse position.
- **ShowUsersKeyboardLayouts()** - Display all installed keyboard layouts available on system.
- **GetCurrentKeyboardLayoutName()** - Get name of currently active keyboard layout.
- **SwitchKeyboardLayout(layoutNameOrId='')** - Switch to specific keyboard layout by name or language ID.
- **SwitchSelectedTextLayout(layoutA, layoutB)** - Convert selected text between two layouts and replace.
- **SwitchSelectedTextCase()** - Toggle case of selected text (UPPER ↔ lower).

## RDPWindowHandler
RDP-specific actions: minimize/restore RDP sessions, loop through RDP windows, switch to next RDP connection.

- **IsRDPClientWindowActive()** - Check if active window is RDP client.
- **MinimizeRestoreRDPClientWindows()** - Minimize or restore all RDP windows.
- **RestoreFullscreenRDPClientWindow()** - Restore RDP from fullscreen.
- **LoopRDPClientWindows()** - Cycle through all open RDP connections.
- **SwitchToNextRDPClientWindow()** - Switch focus to next RDP window.

**Status:** Untested. Use with caution or disable if unreliable.

## ShellMessageHook
Internal hook system for window creation/destruction/activation events. Plugins can register listeners via AddEventListener().

**Hooks:**
- **AddEventListener(eventName, callbackFn)** - Register callback for window event (WindowCreated, WindowActivated, WindowDestroyed). Used internally by plugins.

**Status:** Experimental, not fully tested.

## TextToSpeech
Text-to-speech placeholder. Currently stub implementation using Windows SAPI. Not implemented for hotkey actions.

**Status:** Experimental/disabled by default. Not recommended for use.

## TimerHandlers
Placeholder for timer-based actions and system event handling. Planned for future use.

**Status:** Experimental/disabled. Not yet fully implemented.

## SwapButtonsHandler
Placeholder for mouse button remapping. Intended to provide quick layout switching for mice with extra buttons.

**Status:** Incomplete/disabled. Not yet implemented.

---

## Quick Reference by Action Prefix

**Toggle*** (binary state changes):
- ToggleWindowMaximized, ToggleHoveredWindowMaximized
- ToggleWindowOnTop, ToggleHoveredWindowOnTop
- ToggleWindowFullScreen, ToggleHoveredWindowFullScreen
- ToggleWindowFrame, ToggleHoveredWindowFrame
- ToggleWindowTransparency, ToggleHoveredWindowTransparency
- ToggleTaskView

**Show*** (UI/info display):
- ShowWindowList, ShowHoveredWindowInfo, ShowWindowInfo, ShowResizeWindowDialog
- ShowCurrentKeyboardLayout, ShowUsersKeyboardLayouts

**Enter*** (mode transitions):
- EnterWindowMovingMode, EnterWindowResizingMode
- EnterGestureMode

**Switch*** / **GoTo*** (navigation/state target):
- SwitchKeyboardLayout, SwitchSelectedTextLayout, SwitchSelectedTextCase
- SwitchToNextRDPClientWindow
- GoToDesktop, GoToPrevDesktop, GoToNextDesktop, GoToRecentDesktop
- GoWithWindowToDesktop, GoWithWindowToPrevDesktop, GoWithWindowToNextDesktop

**Increase*** / **Decrease*** (bounded numeric adjustments):
- IncreaseWindowTransparency, IncreaseHoveredWindowTransparency
- DecreaseWindowTransparency, DecreaseHoveredWindowTransparency

**Set*** (explicit value setters):
- SetWindowBorderColor, SetDesktopName, SetPrecisionTouchpadRegistryConfig

**Is/Minimize/Move/Close** (miscellaneous):
- IsMouseOverTaskbar, IsMouseOverWindowTitlebar, IsMouseOverWindowAnyBorder, IsMouseOverWindowResizableBorder
- IsRDPClientWindowActive, IsInGesture
- MinimizeWindow, MinimizeHoveredWindow, MinimizeRestoreRDPClientWindows
- MoveWindowToDesktop, MoveWindowToPrevDesktop, MoveWindowToNextDesktop
- MoveHoveredWindowToDesktop, MoveHoveredWindowToPrevDesktop, MoveHoveredWindowToNextDesktop
- CloseWindow, CloseHoveredWindow

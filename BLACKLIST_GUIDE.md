# Window Blacklist System

## What is a Blacklist?

A **blacklist** is a list of window classes or titles that a plugin will intentionally exclude from its actions. It's a configuration-driven mechanism to protect specific applications from being affected by AtsuiKagi features.

**Simple analogy:** Like a firewall blocklist that says "don't apply this rule to these windows."

## Why Use Blacklists?

Some applications:
- Have custom window management you don't want to override (games, RDP, full-screen apps)
- Intercept hotkeys for their own use (IDEs, terminals)
- Behave unexpectedly when modified (transparency, moving, resizing)
- Need to preserve native behavior (keyboard layouts, text input)

Blacklists let you disable plugin actions for these apps without disabling the entire plugin.

## How to Configure

Blacklists are defined in your `config.ini` under the `[Blacklists]` section:

```ini
[Blacklists]
NoMoveResize=ahk_class Notepad|ahk_class WordPadClass|ahk_class PuTTY
NoTransparency=ahk_exe game.exe|ahk_class RDPClient
NoKeyboardSwitch=ahk_class "MSDEV.1"|ahk_class VirtualConsoleClass
```

**Format:**
- One blacklist per line: `BlacklistName=matcher1|matcher2|matcher3`
- Each matcher is a [WinTitle parameter](https://www.autohotkey.com/docs/v2.0/misc/WinTitle.htm): `ahk_class ClassName`, `ahk_exe ExeName.exe`, `ahk_pid 12345`, or window title text

**Example entries:**
```
NoMoveResize=ahk_class Notepad|ahk_class WordPadClass|ahk_exe notepad.exe
NoRightClickGesture=ahk_class ConsoleWindowClass
NoVirtualDesktopSwitch=ahk_class TscShellContainerClass  ; RDP window
```

## How Plugins Use Blacklists

### For Plugin Developers

In your plugin action, check if the target window is blacklisted:

```autohotkey
MyMoveAction(hwnd:=0) {
  if (hwnd = 0)
    WinGetActiveTitle(&hwnd)
  
  ; Skip if window is in "NoMoveResize" blacklist
  if (this.IsWindowBlacklisted(hwnd, "NoMoveResize"))
    return  ; Silently skip
  
  ; Proceed with moving the window
  WinMove(newX, newY, , , "ahk_id " hwnd)
}
```

### For Users (In Config)

Wrap actions with `SkipIfBlacklisted` to exclude blacklisted windows:

```ini
#j=SkipIfBlacklisted(NoMoveResize, MoveWindowToPrevDesktop())
#k=SkipIfBlacklisted(NoMoveResize, MoveWindowToNextDesktop())
^+Up=SkipIfBlacklisted(NoTransparency, IncreaseWindowTransparency(32))
#Tab=SkipIfBlacklisted(NoVirtualDesktopSwitch, GoToNextDesktop())
```

This reads as: **"Bind hotkey #J to MoveWindowToPrevDesktop, but skip this action if the window is in the NoMoveResize blacklist."**

## Blacklist Matching Rules

A window matches a blacklist if **any** of its properties match **any** entry in the blacklist.

**Examples:**

Config:
```ini
NoMoveResize=ahk_class Notepad|ahk_exe game.exe|Game Title
```

Matching:
- ✅ Window with class `Notepad` → matched
- ✅ Process `game.exe` with any class/title → matched
- ✅ Window with title "Game Title" (exact or substring) → matched
- ❌ `Explorer.exe` → not matched
- ❌ `Notepad` title but different class → depends on class match (if any)

## Common Blacklists

Here are blacklist patterns recommended for different plugins:

### WindowManager Plugin
```ini
NoMoveResize=ahk_class Notepad|ahk_class ConsoleWindowClass|ahk_class TscShellContainerClass
NoTransparency=ahk_exe vlc.exe|ahk_exe foobar2000.exe
```
(Don't move/resize terminals, RDP; don't make media players transparent)

### VirtualDesktopManager Plugin
```ini
NoVirtualDesktopSwitch=ahk_class TscShellContainerClass|ahk_class "MSDEV.1"|ahk_class AIMP3_RemoteWindow
```
(Don't switch desktops while in RDP, IDE fullscreen, or audio player)

### TextLocaleManager Plugin
```ini
NoKeyboardSwitch=ahk_class ConsoleWindowClass|ahk_class "PuTTY"|ahk_class MSVS_MainWindow
```
(Don't switch layouts in terminals or IDEs with custom input)

### TouchGesturesSimulator Plugin
```ini
NoGestureMode=ahk_exe game.exe|ahk_class UnityWndClass|ahk_class "Source 2"
```
(Don't simulate touches in games)

## Tips

1. **Start minimal.** Only blacklist windows that actually break. Overly broad blacklists make plugins less useful.

2. **Test carefully.** Add entries one by one and test each plugin action:
   ```
   WinActivate("app to exclude")
   ; Now test the action—it should skip silently
   ```

3. **Use class names when possible.** More reliable than window titles (titles can change).
   ```
   ahk_class ConsoleWindowClass  ← Good, stable
   Command Prompt              ← Bad, can change if user renames
   ```

4. **Check class name with debugging.** Hold Alt+F12 in the app and use the Window Spy tool that comes with AutoHotkey to see exact class/process names.

5. **One action, one blacklist.** If plugin has multiple related actions, create separate blacklists if they have different exclusion needs:
   ```
   NoMoveResize=...
   NoTransparency=...
   NoMinimize=...
   ```
   Then each action checks its own blacklist.

## Example Workflow

1. **Configure a hotkey:**
   ```ini
   #j=SkipIfBlacklisted(NoMoveResize, IncreaseWindowTransparency(32))
   ```

2. **Add blacklist matching apps you don't want affected:**
   ```ini
   [Blacklists]
   NoMoveResize=ahk_exe game.exe|ahk_class VLC
   ```

3. **Test:**
   - Activate a whitelisted app → press #J → window becomes transparent ✅
   - Activate game.exe → press #J → nothing happens (blacklisted) ✅

4. **Refine:** If some game still gets affected, add its class to blacklist and test again.

## Debugging Blacklists

If a blacklist isn't working:

1. **Verify syntax in config.ini:**
   - Check for typos in section header `[Blacklists]`
   - No leading/trailing spaces around `=` and `|`
   - Correct `ahk_class`/`ahk_exe` prefix

2. **Check window properties:**
   - Use AHK Window Spy (Alt+F12) to get exact class/process
   - Copy-paste exact strings to blacklist config

3. **Verify plugin is using correct blacklist name:**
   - Config has `NoMoveResize=...`
   - But action checks `IsWindowBlacklisted(hwnd, "WrongName")` ← typo!

4. **Reload config:**
   - Close and reopen settings UI
   - Or re-run script

5. **Enable debug logging:**
   - Open settings UI → Logs tab
   - Watch debug output for `IsWindowBlacklisted()` results

Example debug output:
```
IsWindowBlacklisted: nopad.exe NOT in NoMoveResize blacklist → allowed
IsWindowBlacklisted: game.exe in NoMoveResize blacklist → BLOCKED
```

## Advanced: Programmatic Blacklist Checking

From plugin code:

```autohotkey
; Check if current window is blacklisted
if (this.IsWindowBlacklisted(hwnd, "NoMoveResize")) {
  ; Gracefully handle blacklisted window
  return this.ShowInfo("This window is protected from moving", "Blacklisted")
}

; Check if in any specific blacklist
if (this.IsInBlacklist("NoVirtualDesktopSwitch", hwnd)) {
  ;Do something else
}
```

---

**See also:**
- `ACTION_CATALOG.md` for all available actions
- `PLUGIN_API.md` for plugin development
- `config.ini.example` for full configuration reference

# Window Blocklist System

## What is a Blocklist?

A **blocklist** is a list of window classes or titles that a plugin will intentionally exclude from its actions. It's a configuration-driven mechanism to protect specific applications from being affected by Haribol! features.

**Simple analogy:** Like a firewall blocklist that says "don't apply this rule to these windows."

## Why Use Blocklists?

Some applications:
- Have custom window management you don't want to override (games, RDP, full-screen apps)
- Intercept hotkeys for their own use (IDEs, terminals)
- Behave unexpectedly when modified (transparency, moving, resizing)
- Need to preserve native behavior (keyboard layouts, text input)

Blocklists let you disable plugin actions for these apps without disabling the entire plugin.

## How to Configure

Blocklists are defined in your `config.ini` under the `[Blocklists]` section:

```ini
[Blocklists]
NoMoveResize=ahk_class Notepad|ahk_class WordPadClass|ahk_class PuTTY
NoTransparency=ahk_exe game.exe|ahk_class RDPClient
NoKeyboardSwitch=ahk_class "MSDEV.1"|ahk_class VirtualConsoleClass
```

**Format:**
- One blocklist per line: `BlocklistName=matcher1|matcher2|matcher3`
- Each matcher is a [WinTitle parameter](https://www.autohotkey.com/docs/v2.0/misc/WinTitle.htm): `ahk_class ClassName`, `ahk_exe ExeName.exe`, `ahk_pid 12345`, or window title text

**Example entries:**
```
NoMoveResize=ahk_class Notepad|ahk_class WordPadClass|ahk_exe notepad.exe
NoRightClickGesture=ahk_class ConsoleWindowClass
NoVirtualDesktopSwitch=ahk_class TscShellContainerClass  ; RDP window
```

## How Plugins Use Blocklists

### For Plugin Developers

In your plugin action, check if the target window is blocklisted:

```autohotkey
MyMoveAction(hwnd:=0) {
  if (hwnd = 0)
    WinGetActiveTitle(&hwnd)
  
  ; Skip if window is in "NoMoveResize" blocklist
  if (this.IsWindowBlocklisted(hwnd, "NoMoveResize"))
    return  ; Silently skip
  
  ; Proceed with moving the window
  WinMove(newX, newY, , , "ahk_id " hwnd)
}
```

### For Users (In Config)

Wrap actions with `SkipIfBlocklisted` to exclude blocklisted windows:

```ini
#j=SkipIfBlocklisted(NoMoveResize, MoveWindowToPrevDesktop())
#k=SkipIfBlocklisted(NoMoveResize, MoveWindowToNextDesktop())
^+Up=SkipIfBlocklisted(NoTransparency, IncreaseWindowTransparency(32))
#Tab=SkipIfBlocklisted(NoVirtualDesktopSwitch, GoToNextDesktop())
```

This reads as: **"Bind hotkey #J to MoveWindowToPrevDesktop, but skip this action if the window is in the NoMoveResize blocklist."**

## Blocklist Matching Rules

A window matches a blocklist if **any** of its properties match **any** entry in the blocklist.

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

## Common Blocklists

Here are blocklist patterns recommended for different plugins:

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

1. **Start minimal.** Only blocklist windows that actually break. Overly broad blocklists make plugins less useful.

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

5. **One action, one blocklist.** If plugin has multiple related actions, create separate blocklists if they have different exclusion needs:
   ```
   NoMoveResize=...
   NoTransparency=...
   NoMinimize=...
   ```
   Then each action checks its own blocklist.

## Example Workflow

1. **Configure a hotkey:**
   ```ini
   #j=SkipIfBlocklisted(NoMoveResize, IncreaseWindowTransparency(32))
   ```

2. **Add blocklist matching apps you don't want affected:**
   ```ini
   [Blocklists]
   NoMoveResize=ahk_exe game.exe|ahk_class VLC
   ```

3. **Test:**
   - Activate a whitelisted app → press #J → window becomes transparent ✅
   - Activate game.exe → press #J → nothing happens (blocklisted) ✅

4. **Refine:** If some game still gets affected, add its class to blocklist and test again.

## Debugging Blocklists

If a blocklist isn't working:

1. **Verify syntax in config.ini:**
   - Check for typos in section header `[Blocklists]`
   - No leading/trailing spaces around `=` and `|`
   - Correct `ahk_class`/`ahk_exe` prefix

2. **Check window properties:**
   - Use AHK Window Spy (Alt+F12) to get exact class/process
   - Copy-paste exact strings to blocklist config

3. **Verify plugin is using correct blocklist name:**
   - Config has `NoMoveResize=...`
   - But action checks `IsWindowBlocklisted(hwnd, "WrongName")` ← typo!

4. **Reload config:**
   - Close and reopen settings UI
   - Or re-run script

5. **Enable debug logging:**
   - Open settings UI → Logs tab
   - Watch debug output for `IsWindowBlocklisted()` results

Example debug output:
```
IsWindowBlocklisted: nopad.exe NOT in NoMoveResize blocklist → allowed
IsWindowBlocklisted: game.exe in NoMoveResize blocklist → BLOCKED
```

## Advanced: Programmatic Blocklist Checking

From plugin code:

```autohotkey
; Check if current window is blocklisted
if (this.IsWindowBlocklisted(hwnd, "NoMoveResize")) {
  ; Gracefully handle blocklisted window
  return this.ShowInfo("This window is protected from moving", "Blocklisted")
}

; Check if in any specific blocklist
if (this.IsInBlocklist("NoVirtualDesktopSwitch", hwnd)) {
  ;Do something else
}
```

---

**See also:**
- `ACTION_CATALOG.md` for all available actions
- `PLUGIN_API.md` for plugin development
- `config.ini.example` for full configuration reference

# WinDrag Plugin Plan DRAFT INCOMPLETE, implemenation plan is unconfirmed and probably wrong!

**Status**: Planning phase  
**Based on**: KDEMoverSizer (proven, functional) + WinDrag v2 port (untested, new features)  
**Target**: Create unified, production-ready WinDrag plugin with best features from both

---

## 1. Feature Comparison Matrix

| Feature | KDEMoverSizer | WinDrag | New Plugin |
|---------|---------------|---------|-----------|
| **MOVE** | | | |
| Drag from anywhere on window | ✅ | ✅ | ✅ |
| Axis-locking (Shift) | ✅ | ❌ | ✅ (make key configurable) |
| Visual frame guide | ✅ | ❌ | ✅ |
| Real-time content preview | ✅ (option) | ✅ (default) | ✅ (configurable) |
| Quick-position grid | ✅ (LWin tap) | ❌ | ✅ |
| **RESIZE** | | | |
| Drag to resize | ✅ | ✅ | ✅ |
| 9-area resize detection | ❌ | ✅ | ✅ |
| 2-area resize (left/right) | ❌ | ❌ | ✅ |
| Axis-locking during resize | ✅ | ❌ | ✅ |
| **SNAP** | | | |
| Snap to edges | ✅ (basic) | ✅ (advanced) | ✅ (advanced) |
| Maximize on top edge | ❌ | ✅ | ✅ |
| Minimize on bottom edge | ❌ | ✅ | ✅ |
| Half-screen snap (L/R) | ❌ | ✅ | ✅ |
| Full-screen tiling option | ❌ | ✅ | ✅ |
| Configurable thresholds | ❌ | ✅ | ✅ |
| **WINDOW CONTROL** | | | |
| Close (middle-click) | ❌ | ✅ | ✅ (make key/mouse button configurable) |
| Minimize (middle-click alt) | ❌ | ✅ | ✅ (make key/mouse button configurable) |
| Always-on-top toggle | ❌ | ✅ | ✅ (make key/mouse button configurable) |
| Bring to front on drag | ✅ (option) | ✅ | ✅ (plugin config option) |
| **STATE MANAGEMENT** | | | |
| Save/restore window state | ✅ | ❌ | ✅ |
| Restore from maximized | ✅ | ✅ | ✅ |
| Maximize state tracking | ✅ | ✅ | ✅ |
| **SYSTEM** | | | |
| Blocklist support | ✅ | ❌ | ✅ |
| Multi-monitor aware | ✅ (basic) | ✅ (advanced) | ✅ (advanced) |
| Exclude system windows | ❌ | ✅ | ✅ |
| Escape to cancel | ✅ | ❌ | ✅ |
| Alternative modes (experimental) | ❌ | ✅ | ✅ (optional) |

---

## 2. Core Architecture

### 2.1 Class Structure

```ahk
class WinDrag extends AKPlugin {
  ; State management
  _isMoving := false
  _isResizing := false
  _windowState := {}
  
  ; Mouse hook handles
  _mouseHook := 0
  _keyboardHook := 0
  //FIXME: need to rethink the config and maybe other stuff, so main action is EnterWinDragMode() so it 
  ; Config options
  Config.MoveHotkey := "LWin"
  Config.CloseHotkey := "LWin & MButton"
  Config.ResizeHotkey := "LWin & RButton"
  Config.AlwaysOnTopHotkey := "LWin & A"
  
  ; Snap settings
  Config.EnableSnap := true
  Config.SnapThresholdEdge := 50
  Config.SnapMaximizeOnTop := true
  Config.SnapMinimizeOnBottom := true
  Config.SnapHalfScreen := true
  Config.SnapFullScreenTile := false
  
  ; Visual/UX
  Config.ShowContentDuringMove := true
  Config.ShowFrameGuide := true
  Config.ShowContentDuringResize := true
  Config.BringToFront := true
  
  ; Advanced
  Config.LockAxisHotkey := "Shift"
  Config.EnableEscapeCancel := true
}
```

### 2.2 Key Responsibilities

| Component | Purpose |
|-----------|---------|
| **MoveManager** | Handle window dragging with axis-locking & snapping |
| **ResizeManager** | Handle window resizing from multiple edges |
| **SnapEngine** | Detect screen edges & apply magnetic snapping |
| **FrameGuide** | Draw visual overlay guides during operations |
| **StateTracker** | Save/restore window position & maximized state |
| **HookManager** | Install/manage mouse & keyboard hooks |
| **ValidationFilter** | Blocklist & system window exclusion |

---

## 3. Configuration Options

### 3.1 Keybindings

```ini
[WinDrag]
; Movement
MoveHotkey=LWin & LButton
MoveHotkey_Alt=MWin & LButton

; Resizing
ResizeHotkey=LWin & RButton
ResizeHotkey_Alt=

; Window Control
CloseHotkey=LWin & MButton
MinimizeHotkey=
AlwaysOnTopHotkey=LWin & A

; Modifiers
LockAxisHotkey=Shift
QuickPositionHotkey=LWin

; Alternative modes (experimental)
EnableAltDragMode=false
EnableAltResizeMode=false
```

### 3.2 Snapping & Behavior

```ini
EnableSnap=true
SnapThresholdEdge=50
SnapThresholdCorner=50
SnapMaximizeOnTop=true
SnapMinimizeOnBottom=true
SnapHalfScreen=true
SnapFullScreenTile=false

ShowContentDuringMove=true
ShowFrameGuide=true
ShowContentDuringResize=true
BringToFront=true
EnableEscapeCancel=true
```

### 3.3 Exclusions

```ini
ExcludeCloseOnSystemUI=true
ExcludeResizeOnSystemUI=true
ExcludeMoveOnSystemUI=true
ExcludeByClass=Shell_TrayWnd,Shell_SecondaryTrayWnd,Windows.UI.Core.CoreWindow
ExcludeByExe=StartMenuExperienceHost.exe,SearchHost.exe
```

---

## 4. Feature Breakdown

### 4.1 Window Movement

**Entry Point**: `LWin & LButton` (or configured MoveHotkey)

**Flow**:
1. Detect window under mouse
2. Validate window (blocklist, system UI checks)
3. Save window state (position, size, maximized flag)
4. If maximized → restore and reposition under mouse
5. Enter move loop:
   - Track mouse movement delta
   - Apply axis-lock if Shift held
   - If ShowContentDuringMove: real-time WinMove
   - If not: draw frame guide overlay
   - Show geometry tooltip
   - Check for snap zones on mouse release
6. On release: apply snap if enabled
7. On Escape: restore original state

**Key Improvements over KDEMoverSizer**:
- Support for snapping to half-screen edges (WinDrag feature)
- Maximize/minimize snap actions (WinDrag feature)
- Exclude system windows (WinDrag feature)

**Key Improvements over WinDrag**:
- Axis-locking support
- Visual frame guide (option)
- Better maximized window restoration
- Escape to cancel support

### 4.2 Window Resizing

**Entry Point**: `LWin & RButton` (or configured ResizeHotkey)

**Flow**:
1. Detect window under mouse
2. Determine resize corner/edge based on mouse position within window:
   - 9-area mode: detect all 8 edges + center
   - 2-area mode: detect left vs right (top/bottom fixed)
3. Validate window
4. If maximized: restore first
5. Enter resize loop:
   - Calculate mouse delta
   - Apply axis-lock if Shift held
   - Update window dimensions:
     - Top-left area: move & resize
     - Top-center: resize height only
     - Top-right: resize width & height
     - Etc.
   - Apply snap constraints if enabled
   - Show frame guide or live preview
   - Show geometry tooltip
6. On release: finalize
7. On Escape: restore original size

**New Features**:
- 9-area vs 2-area detection modes
- Independent axis-locking
- Smart snap constraints during resize

### 4.3 Window Snapping

**Triggers**: On mouse release during move/resize

**Snap Actions**:
1. **Top Edge** (if SnapMaximizeOnTop):
   - Maximize window
   
2. **Bottom Edge** (if SnapMinimizeOnBottom):
   - Minimize window
   
3. **Left Edge** (if SnapHalfScreen):
   - Snap to left half OR use native Win+Left if available
   
4. **Right Edge** (if SnapHalfScreen):
   - Snap to right half OR use native Win+Right if available
   
5. **Corners** (optional):
   - Snap to corner with reduced size

**Threshold System**:
- `SnapThresholdEdge`: pixels from edge to trigger snap
- `SnapThresholdCorner`: separate corner detection
- Works with multi-monitor setups

### 4.4 Always-On-Top Toggle

**Entry Point**: `LWin & A` (or configured hotkey)

**Flow**:
1. Get active window
2. Validate window
3. Toggle WS_EX_TOPMOST style
4. Show notification (optional)

### 4.5 Window Close / Minimize

**Entry Point**: `LWin & MButton` (or configured hotkey)

**Flow**:
1. Detect window under mouse
2. Check if MinimizeInstead option enabled
3. Either WinMinimize() or WinClose()
4. Optional notification

---

## 5. Technical Implementation Details

### 5.1 Hook Strategy

**Mouse Hook** (DLL-based):
- Intercepts LButton, MButton, RButton events
- Tracks LWin + mouse combination
- Posts events to main event loop

**Keyboard Hook** (DLL-based):
- Tracks LWin press/release
- Tracks Shift press/release (for axis-lock)
- Tracks Escape (for cancel operation)

**Alternative**: Use AHK v2 native hotkeys where possible to reduce DLL dependency

### 5.2 State Tracking

```ahk
windowState := {
  hwnd: windowId,
  originalX: xPos,
  originalY: yPos,
  originalW: width,
  originalH: height,
  wasMaximized: 0/1,
  wasMinimized: 0/1,
  resizeMode: "corner" / "edge",
  startMouseX: xMouse,
  startMouseY: yMouse
}
```

### 5.3 Frame Guide (KDEMoverSizer Style)

- Create 4 GUI windows (left, top, right, bottom frames)
- Position frames around window bounds during move/resize
- Use screen-space coordinates
- Thin colored lines (default: white, 1-2px)
- Destroy on operation end

### 5.4 Geometry Tooltip

- Display format: `X: 123, Y: 456\n(1280 x 720)`
- Update in real-time
- Position: window center or mouse position
- Hide on release

### 5.5 System Window Exclusion

**Blocklist Checks**:
1. Check against app-level blocklist
2. Check window class: Shell_TrayWnd, Shell_SecondaryTrayWnd, Windows.UI.Core.CoreWindow
3. Check process name: StartMenuExperienceHost.exe, SearchHost.exe, etc.
4. Check extended window style:
   - WS_EX_TOOLWINDOW (0x80)
   - WS_EX_NOACTIVATE (0x08000000)
5. Check DWM cloaked state (UWP app previews)

---

## 6. Implementation Phases

### Phase 1: Core Movement (MVP)
- [ ] Drag to move windows
- [ ] Axis-lock with Shift
- [ ] Escape to cancel
- [ ] Window state save/restore
- [ ] Blocklist support
- [ ] System window exclusion

### Phase 2: Snapping
- [ ] Edge detection
- [ ] Maximize on top / minimize on bottom
- [ ] Half-screen snap (Win+Left/Right style)
- [ ] Configurable thresholds
- [ ] Multi-monitor support

### Phase 3: Resizing
- [ ] Drag to resize (2-area mode)
- [ ] Axis-lock during resize
- [ ] 9-area detection (optional)
- [ ] Snap constraints

### Phase 4: Polish
- [ ] Frame guide overlay
- [ ] Geometry tooltip
- [ ] Alternative drag/resize modes
- [ ] Always-on-top toggle
- [ ] Window close/minimize

### Phase 5: Testing & Refinement
- [ ] Blocklist edge cases
- [ ] Multi-monitor edge cases
- [ ] Maximized window edge cases
- [ ] Performance testing
- [ ] System stability validation

---

## 7. Known Risks & Considerations

### 7.1 From WinDrag Port Issues

**Risk**: WinDrag is untested AHK v1→v2 port
- **Mitigation**: Rewrite move/resize core from scratch
- **Test**: Validate against KDEMoverSizer behavior
- **Use**: WinDrag for snapping logic, not control flow

### 7.2 Hook Stability

**Risk**: Global mouse/keyboard hooks can cause system lag
- **Mitigation**: Minimize hook processing time
- **Use**: DllCall with Critical() for atomicity
- **Option**: Fall back to hotkey-based approach if hooks unstable

### 7.3 Multi-Monitor Complexity

**Risk**: Screen border detection across monitors
- **Mitigation**: Use MonitorGetCount() + MonitorGet() loops
- **Test**: Simulate all edge cases (different DPI, overlapping monitors, etc.)

### 7.4 UWP & Modern Windows UI

**Risk**: Some windows cannot be moved/resized (e.g., Settings, Store)
- **Mitigation**: Comprehensive exclusion list
- **Use**: DwmGetWindowAttribute for cloaked state detection
- **Test**: Check against system UI windows

### 7.5 Maximized Window Restoration

**Risk**: Restoring position may be off-center
- **WinDrag solution**: Reposition window at mouse location on restore
- **Implementation**: Save original click position, center restored window on it

---

## 8. Comparison: WinDrag vs KDEMoverSizer vs New Plugin

### WinDrag Strengths
✅ Advanced snapping (maximize/minimize/half-screen)  
✅ Always-on-top toggle  
✅ Close/minimize on middle-click  
✅ Configurable snap thresholds  
✅ System window exclusion  
✅ Full-screen tiling option  

### WinDrag Weaknesses
❌ No axis-locking  
❌ No visual frame guide  
❌ No escape-to-cancel  
❌ Untested port (potential bugs)  
❌ No blocklist support  

### KDEMoverSizer Strengths
✅ Proven & stable  
✅ Axis-locking (Shift)  
✅ Visual frame guide overlay  
✅ Quick-position grid (LWin tap)  
✅ Blocklist support  
✅ Window state preservation  

### KDEMoverSizer Weaknesses
❌ Complex codebase  
❌ Limited snapping (no maximize/minimize)  
❌ No window close/minimize  
❌ No always-on-top  

### New Plugin (Best of Both)
✅ Proven movement from KDEMoverSizer  
✅ Advanced snapping from WinDrag  
✅ Axis-locking + frame guide  
✅ Window state management  
✅ Blocklist + system window exclusion  
✅ Always-on-top + close/minimize  
✅ Cleaner codebase (rewrite from scratch)  
✅ Better maintainability  

---

## 9. Quick Start Implementation Template

```ahk
class WinDrag extends AKPlugin {
  
  _processPluginConfig() {
    ; Movement
    if (!this.Config.Has("MoveHotkey"))
      this.Config.MoveHotkey := "LWin & LButton"
    if (!this.Config.Has("LockAxisHotkey"))
      this.Config.LockAxisHotkey := "Shift"
    
    ; Resize
    if (!this.Config.Has("ResizeHotkey"))
      this.Config.ResizeHotkey := "LWin & RButton"
    
    ; Window control
    if (!this.Config.Has("CloseHotkey"))
      this.Config.CloseHotkey := "LWin & MButton"
    if (!this.Config.Has("AlwaysOnTopHotkey"))
      this.Config.AlwaysOnTopHotkey := "LWin & A"
    
    ; Snap settings
    if (!this.Config.Has("EnableSnap"))
      this.Config.EnableSnap := true
    if (!this.Config.Has("SnapThresholdEdge"))
      this.Config.SnapThresholdEdge := 50
    
    ; UX
    if (!this.Config.Has("ShowContentDuringMove"))
      this.Config.ShowContentDuringMove := true
    if (!this.Config.Has("BringToFront"))
      this.Config.BringToFront := true
  }
  
  __ActionsHelp() {
    return Map(
      "StartMoving", "StartMoving() - Begin moving window",
      "StartResizing", "StartResizing() - Begin resizing window",
      "ToggleAlwaysOnTop", "ToggleAlwaysOnTop() - Toggle always-on-top"
    )
  }
  
  StartMoving() {
    ; Implementation here
  }
  
  StartResizing() {
    ; Implementation here
  }
  
  ToggleAlwaysOnTop() {
    ; Implementation here
  }
}
```

---

## 10. Testing Checklist

- [ ] Move window from various positions
- [ ] Resize from each corner/edge
- [ ] Axis-lock works correctly
- [ ] Snap to all edges
- [ ] Multi-monitor snapping
- [ ] Maximize/minimize snap
- [ ] Escape cancellation
- [ ] Window state restoration
- [ ] System UI exclusion (taskbar, start menu, etc.)
- [ ] Always-on-top toggle
- [ ] Close/minimize middle-click
- [ ] Frame guide rendering
- [ ] Tooltip display
- [ ] Blocked windows bypass functionality
- [ ] Performance under repeated operations

---

## 11. Future Enhancements

- [ ] Gesture-based resizing (e.g., pinch-to-resize for future touch support)
- [ ] Window tiling presets (save/restore layouts)
- [ ] Keyboard shortcuts for common positions
- [ ] Animation during snapping (optional)
- [ ] Snap preview before release
- [ ] Virtual desktop awareness
- [ ] Per-monitor configuration
- [ ] Custom snap zones

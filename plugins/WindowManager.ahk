class WindowManager extends AKPlugin {
  _fullScreenWindowStates := Map()
  _fallbackBorders := Map()
  _fallbackBorderTimer := ""
  _fallbackBorderEventHandler := ""
  _fallbackBorderEventCallback := 0
  _fallbackBorderEventHook := 0
  _fallbackBorderThickness := 3

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "WindowManager",
        "title", "Window Manager",
        "description", "Manage windows: minimize, transparency, maximize, fullscreen, frames, and top-most behavior",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure window-management behavior and action-related settings",
        "icon", "icons10-window"
      ),
      "config", [
        Map(
          "key", "WindowTransparencyValue",
          "label", "Window Transparency",
          "description", "Transparency for on-top overlays",
          "type", "integer", "control", "range", "default", 120, "section", "General", "validation", Map("min", 10, "max", 250, "step", 10)
        ),
        Map(
          "key", "WindowOnTopBorderColor",
          "label", "On-Top Border Color",
          "description", "Border color for always-on-top window highlight",
          "type", "color", "control", "color", "default", "0xAACCFF", "section", "General"
        ),
        Map(
          "key", "WindowTitlebarAreaHeight",
          "label", "Titlebar area height",
          "description", "Height in pixels used to detect titlebar hover area",
          "type", "integer", "control", "range", "default", 32, "validation", Map("min", 0, "max", 128, "step", 2)
        )
      ],
      "actions", [
        Map("action", "ShowWindowList", "label", "Show window list", "description", "List current windows with class and state", "category", "Info"),
        Map("action", "ShowHoveredWindowInfo", "label", "Show hovered window info", "description", "Show diagnostics for the window under cursor", "category", "Info"),
        Map("action", "ShowWindowInfo", "label", "Show active window info", "description", "Show diagnostics for a specific or active window", "category", "Info", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "MinimizeWindow", "label", "Minimize window", "description", "Minimize a specific or active window", "category", "State", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "MinimizeHoveredWindow", "label", "Minimize hovered window", "description", "Minimize the window currently under cursor", "category", "State"),
        Map("action", "CloseWindow", "label", "Close window", "description", "Close a specific or active window", "category", "State", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "CloseHoveredWindow", "label", "Close hovered window", "description", "Close the window currently under cursor", "category", "State"),
        Map("action", "ToggleWindowMaximized", "label", "Toggle maximize", "description", "Toggle maximized state for a specific or active window", "category", "State", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "ToggleHoveredWindowMaximized", "label", "Toggle maximize (hovered)", "description", "Toggle maximized state for hovered window", "category", "State"),
        Map("action", "ToggleHoveredWindowOnTop", "label", "Toggle always on top (hovered)", "description", "Toggle top-most state for a hovered non-maximized, non-fullscreen window", "category", "On Top", "params", [Map("name", "BorderColor", "default", -1)]),
        Map("action", "ToggleWindowOnTop", "label", "Toggle always on top", "description", "Toggle top-most state for a non-maximized, non-fullscreen specific or active window", "category", "On Top", "params", [Map("name", "BorderColor", "default", -1), Map("name", "hwnd", "default", 0)]),
        Map("action", "ToggleWindowFullScreen", "label", "Toggle fullscreen", "description", "Toggle fullscreen mode for a specific or active window", "category", "State", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "ToggleHoveredWindowFullScreen", "label", "Toggle fullscreen (hovered)", "description", "Toggle fullscreen mode for hovered window", "category", "State"),
        Map("action", "ToggleWindowFrame", "label", "Toggle frame", "description", "Toggle window frame for a specific or active window", "category", "Frame", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "ToggleHoveredWindowFrame", "label", "Toggle frame (hovered)", "description", "Toggle window frame for hovered window", "category", "Frame"),
        Map("action", "ToggleWindowTransparency", "label", "Toggle transparency", "description", "Toggle transparency for a specific or active window", "category", "Transparency", "params", [Map("name", "TransparencyValue", "default", 128), Map("name", "hwnd", "default", 0)]),
        Map("action", "ToggleHoveredWindowTransparency", "label", "Toggle transparency (hovered)", "description", "Toggle transparency for hovered window", "category", "Transparency", "params", [Map("name", "TransparencyValue", "default", 128)]),
        Map("action", "IncreaseWindowTransparency", "label", "Increase transparency", "description", "Increase transparency level for a specific or active window", "category", "Transparency", "params", [Map("name", "ByValue", "default", 32), Map("name", "hwnd", "default", 0)]),
        Map("action", "IncreaseHoveredWindowTransparency", "label", "Increase transparency (hovered)", "description", "Increase transparency level for hovered window", "category", "Transparency", "params", [Map("name", "ByValue", "default", 32)]),
        Map("action", "DecreaseWindowTransparency", "label", "Decrease transparency", "description", "Decrease transparency level for a specific or active window", "category", "Transparency", "params", [Map("name", "ByValue", "default", 32), Map("name", "hwnd", "default", 0)]),
        Map("action", "DecreaseHoveredWindowTransparency", "label", "Decrease transparency (hovered)", "description", "Decrease transparency level for hovered window", "category", "Transparency", "params", [Map("name", "ByValue", "default", 32)]),
        Map("action", "SetWindowBorderColor", "label", "Set border color", "description", "Apply border color to a specific or active window", "category", "Frame", "params", [Map("name", "color", "default", -1), Map("name", "hwnd", "default", 0)]),
        Map("action", "ToggleTaskView", "label", "Toggle task view", "description", "Open or close Windows Task View", "category", "System"),
        Map("action", "IsMouseOverTaskbar", "label", "Is mouse over taskbar", "description", "Check whether cursor is over taskbar region", "category", "Detection"),
        Map("action", "IsMouseOverWindowTitlebar", "label", "Is mouse over titlebar", "description", "Check whether cursor is over a window titlebar region", "category", "Detection"),
        Map("action", "IsMouseOverWindowAnyBorder", "label", "Is mouse over any border", "description", "Check whether cursor is over any window border", "category", "Detection"),
        Map("action", "IsMouseOverWindowResizableBorder", "label", "Is mouse over resizable border", "description", "Check whether cursor is over a resizable border region", "category", "Detection")
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  ShowHoveredWindowInfo() { ;;;
    MouseGetPos(,, &hwnd)
    this.ShowWindowInfo(hwnd)
  }

  ShowWindowInfo(hwnd:=0) { ;;;
    if (hwnd=0)
      hwnd := WinGetID("A")
    vPName := WinGetProcessName("ahk_id " hwnd)
    vPPath := WinGetProcessPath("ahk_id " hwnd)
    vPID := WinGetPID("ahk_id " hwnd)
    this.ShowNotice("WindowClass: "  GetWindowClass(hwnd) "`nHoveredArea: " this._getHoveredAreaName() "`nPID" vPID "`nProcessName: " vPName, 'Window info')
  }

  ShowWindowList() { ;;;
    windowList := WinGetList()
    text := ""
    For hwnd in windowList {
      className := WinGetClass("ahk_id " hwnd)
      try {
        fileName := WinGetProcessName("ahk_id " hwnd)
        minMaxState := WinGetMinMax("ahk_id " hwnd)
      } catch Error as err {
        fileName := Format("{1}: {2} for hwnd {3}"
            , type(err), err.Message, hwnd)
        minMaxState := '?'
      }
      text .= fileName " class=" className ", minMax=" minMaxState "`n"
    }
    this.ShowNotice(text, 'Windows list', 0) 
  }

  MinimizeWindow(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    PostMessage(0x112, 0xF020,,, "ahk_id " hwnd) ; 0x112 = WM_SYSCOMMAND, 0xF020 = SC_MINIMIZE
    ; WinMinimize, ahk_id %hwnd%
    this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd))
  }

  MinimizeHoveredWindow() { ;;;
    MouseGetPos(,, &hwnd)
    this.MinimizeWindow(hwnd)  
  }
  
  CloseWindow(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd))
    WinClose("ahk_id " hwnd)
  }

  CloseHoveredWindow() { ;;;
    MouseGetPos(,, &hwnd)
    this.CloseWindow(hwnd)  
  }

  ToggleWindowMaximized(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    windowState := WinGetMinMax("ahk_id " hwnd)
    if (windowState = 1) {
      WinRestore("ahk_id " hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    } else {
      WinMaximize("ahk_id " hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    }
  }

  ToggleHoveredWindowMaximized() { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowMaximized(hwnd)  
  }

  ToggleHoveredWindowOnTop(BorderColor:=-1) { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowOnTop(BorderColor, hwnd)  
  }
  ToggleWindowOnTop(BorderColor:=-1, hwnd:=0) { ;;;
    HexColor := (BorderColor = -1) ? this.Config.WindowOnTopBorderColor : BorderColor

    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    windowStyle := WinGetExStyle("ahk_id " . hwnd)
    if (windowStyle & 0x8) { ; 0x8 is WS_EX_TOPMOST.
        WinSetAlwaysOnTop(False, "ahk_id " . hwnd)
        this.SetWindowBorderColor(,hwnd)
        this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
      } else {
        if (WinGetMinMax("ahk_id " hwnd) = 1 || this._isWindowFullscreen(hwnd)) {
          MouseGetPos(&tooltipX, &tooltipY)
          this.ToolTip("Always on top is unavailable for maximized or fullscreen windows", tooltipX + 16, tooltipY + 16, 2500)
          return
        }
        WinSetAlwaysOnTop(True, "ahk_id " . hwnd)
        this.SetWindowBorderColor(HexColor, hwnd)
        this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    }
  }

  ToggleWindowFullScreen(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    if (this._fullScreenWindowStates.Has(hwnd)) {
      originalState := this._fullScreenWindowStates[hwnd]
      WinRestore("ahk_id " hwnd)
      WinSetStyle(originalState.style, "ahk_id " hwnd)
      WinMove(originalState.x, originalState.y, originalState.w, originalState.h, "ahk_id " hwnd)
      if (originalState.minMax = 1)
        WinMaximize("ahk_id " hwnd)
      else if (originalState.minMax = -1)
        WinMinimize("ahk_id " hwnd)
      this._fullScreenWindowStates.Delete(hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
      return
    }

    minMaxState := WinGetMinMax("ahk_id " hwnd)
    originalStyle := WinGetStyle("ahk_id " hwnd)
    if (minMaxState != 0)
      WinRestore("ahk_id " hwnd)
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    this._fullScreenWindowStates[hwnd] := {
      style: originalStyle,
      minMax: minMaxState,
      x: x,
      y: y,
      w: w,
      h: h
    }

    this._setWindowStyleState(hwnd, WindowFlags.WS_CAPTION, false)
    this._setWindowStyleState(hwnd, WindowFlags.WS_SIZEBOX, false)
    WinMaximize("ahk_id " hwnd)
    this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
  }

  ToggleHoveredWindowFullScreen() { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowFullScreen(hwnd)  
  }


  ToggleWindowFrame(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    WinGetPos(&Xpos, &Ypos, &Width, &Height, "ahk_id " hwnd)

    if (this._hasWindowStyle(hwnd, WindowFlags.WS_CAPTION)) {
      this._setWindowStyleState(hwnd, WindowFlags.WS_CAPTION, false)
      ; this._setWindowStyleState(hwnd, WindowFlags.WS_SIZEBOX, false)
      
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    } else {
      this._setWindowStyleState(hwnd, WindowFlags.WS_CAPTION, true)
      ; this._setWindowStyleState(hwnd, WindowFlags.WS_SIZEBOX, true)
      
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    }
    WinMove(Xpos, Ypos, Width, Height, "ahk_id " hwnd)
  }

  ToggleHoveredWindowFrame() { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowFrame(hwnd)  
  }

  ToggleWindowTransparency(TransparencyValue:=-1, hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    if (TransparencyValue = -1)
      TransparencyValue := this.Config.WindowTransparencyValue

    Transparency := WinGetTransparent("ahk_id " . hwnd)
    if (Transparency = "") {
      WinSetTransparent(TransparencyValue, "ahk_id " . hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    } else {
      WinSetTransparent("OFF", "ahk_id " . hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    }
  }

  ToggleHoveredWindowTransparency(TransparencyValue:=-1) { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowTransparency(TransparencyValue, hwnd)  
  }

  IncreaseWindowTransparency(ByValue:=32, hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    ; DetectHiddenWindows(true)
    Transparency := WinGetTransparent("ahk_id " . hwnd)
    if (Transparency = "")
      Transparency := 255
    Transparency := Transparency + ByValue
    if (Transparency > 255 || Transparency < 0) 
      Transparency := 255
    this.ShowInfo(Transparency)
    WinSetTransparent(Transparency, "ahk_id " . hwnd)
  }

  IncreaseHoveredWindowTransparency(ByValue:=32) { ;;;
    MouseGetPos(,, &hwnd)
    this.IncreaseWindowTransparency(ByValue, hwnd)  
  }

  DecreaseWindowTransparency(ByValue:=32, hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    ; DetectHiddenWindows(true)
    Transparency := WinGetTransparent("ahk_id " . hwnd)
    if (Transparency = "")
      Transparency := 255
    Transparency := Transparency - ByValue
    if (Transparency > 255 || Transparency < ByValue) 
      Transparency := ByValue
    this.ShowInfo(Transparency)
    WinSetTransparent(Transparency, "ahk_id " . hwnd)
  }

  DecreaseHoveredWindowTransparency(ByValue:=32) { ;;;
    MouseGetPos(,, &hwnd)
    this.DecreaseWindowTransparency(ByValue, hwnd)  
  }

  SetWindowBorderColor(color:=-1, hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return false

    colorRef := WindowFlags.DWM_COLOR_DEFAULT
    if (color != -1) {
      R := (color & 0xFF0000) >> 16
      G := (color & 0xFF00) >> 8
      B := (color & 0xFF)
      colorRef := (B << 16) | (G << 8) | R
    }

    nativeResult := -1
    try nativeResult := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_BORDER_COLOR, "UInt*", colorRef, "UInt", Win32Sizes.DWORD)

    if (color = -1 || nativeResult = 0) {
      this._removeFallbackBorder(hwnd)
      return nativeResult = 0
    }

    this._setFallbackBorder(hwnd, color)
    return true
  }

  ; builtin in win10+ todo if ever need win 7 support
  ; FocuslessScroll(scrollStep:=120) { ; -120 for other direction
  ;   Critical
  ;   WM_MOUSEACTIVATE := 0x20A
  ;   MouseGetPos, xMou, yMou, WinID, Control1
  ;   MouseGetPos,,,, Control2, 2
  ;   MouseGetPos,,,, Control3, 3
  ;   ;TrayTip,, winid %WinID%   ctl1 _%Control1%_   ctl2 _%Control2%_   ctl3 _%Control3%_

  ;   wParam := scrollStep << 16
  ;   If(GetKeyState("Shift", "P"))
  ;       wParam := wParam | 0x4
  ;   If(GetKeyState("Ctrl", "P"))
  ;       wParam := wParam | 0x8

  ;   if (Control2 = "") {
  ;     PostMessage, WM_MOUSEACTIVATE, wParam, (yMou << 16) | (xMou &0xFFFF),, ahk_id %WinID%  ; SendMessage does not work for TotalCommander Lister
  ;   } else {
  ;     if (Control2 != Control3)
  ;       SendMessage, WM_MOUSEACTIVATE, wParam, (yMou << 16) | (xMou &0xFFFF),, ahk_id %Control3%
  ;     else
  ;       SendMessage, WM_MOUSEACTIVATE, wParam, (yMou << 16) | (xMou &0xFFFF),, ahk_id %Control2%
  ;   }
  ; }

  ToggleTaskView() { ;;;
    Run('shell:::{3080F90E-D7AD-11D9-BD98-0000947B0257}')
  }

  IsMouseOverTaskbar() { ;;;
    MouseGetPos(, , &hwnd)
    hoverTaskbar := WinExist("ahk_class Shell_TrayWnd ahk_id " hwnd)
    hoverSecondaryTaskbar := WinExist("ahk_class Shell_SecondaryTrayWnd ahk_id " hwnd)
    return hoverTaskbar || hoverSecondaryTaskbar
  }

  IsMouseOverWindowTitlebar() { ;;;
    ; treat top area as titlebar for windows without standard CAPTION
    CoordMode("Mouse", "Client")
    MouseGetPos(, &y)
    if (y < this.Config.WindowTitlebarAreaHeight) {
      return !this.IsMouseOverTaskbar()
    }
    return false
    ; areaCode := this._getHoveredWindowAreaCode()
    ; return (areaCode = 2 || areaCode = 3 || areaCode = 8 || areaCode = 9 || areaCode = 20 || areaCode = 21) && !this.IsMouseOverTaskbar()
  }

  IsMouseOverWindowAnyBorder() { ;;;
    areaCode := this._getHoveredWindowAreaCode()
    return (areaCode >= 10 && areaCode <= 18) && !this.IsMouseOverTaskbar()
  }

  IsMouseOverWindowResizableBorder() { ;;;
    areaCode := this._getHoveredWindowAreaCode()
    return (areaCode >= 10 && areaCode <= 17) && !this.IsMouseOverTaskbar()
  }

  _getHoveredAreaName() {
    if (this.IsMouseOverTaskbar())
      return "TASKBAR"
    areaCode := this._getHoveredWindowAreaCode()
    switch areaCode  {
      case -2:  ; HTERROR             (-2)      On the screen background or on a dividing line between windows (same as HTNOWHERE, except that the DefWindowProc function produces a system beep to indicate an error).
        return "ERROR"
      case -1:  ; HTTRANSPARENT       (-1)      In a window currently covered by another window in the same thread (the message will be sent to underlying windows in the same thread until one of them returns a code that is not HTTRANSPARENT).
        return "TRANSPARENT"
      case 0:    ; HTNOWHERE           0        On the screen background or on a dividing line between windows.
        return "NOWHERE"
      case 1:    ; HTCLIENT            1        In a client area.
        return "CLIENT"
      case 2:    ; HTCAPTION           2        In a title bar.
        return "CAPTION"
      case 3:    ; HTSYSMENU           3        In a window menu or in a Close button in a child window.
        return "SYSMENU"
      case 4:    ; HTGROWBOX or HTSIZE 4        In a size box (same as HTSIZE).
        return "GROWBOX"
      case 5:    ; HTMENU              5        In a menu (works for basic menus like notepad, not for menu **bars like in MS Word)
        return "MENU"
      case 6:    ; HTHSCROLL           6        In a horizontal scroll bar.
        return "HSCROLL"
      case 7:    ; HTVSCROLL           7        In the vertical scroll bar.
        return "VSCROLL"
      case 8:    ; HTMINBUTTON         8        In a Minimize button.
        return "MINBUTTON"
      case 9:    ; HTMAXBUTTON         9        In a Maximize button.
        return "MAXBUTTON"
      case 10:  ; HTLEFT              10      In the left border of a resizable window (the user can click the mouse to resize the window horizontally).
        return "LEFT"
      case 11:  ; HTRIGHT             11      In the right border of a resizable window (the user can click the mouse to resize the window horizontally).
        return "RIGHT"
      case 12:  ; HTTOP               12      In the upper-horizontal border of a window.
        return "TOP"
      case 13:  ; HTTOPLEFT           13      In the upper-left corner of a window border.
        return "TOPLEFT"
      case 14:  ; HTTOPRIGHT          14      In the upper-right corner of a window border.
        return "TOPRIGHT"
      case 15:  ; HTBOTTOM            15      In the lower-horizontal border of a resizable window (the user can click the mouse to resize the window vertically).
        return "BOTTOM"
      case 16:  ; HTBOTTOMLEFT        16      In the lower-left corner of a border of a resizable window (the user can click the mouse to resize the window diagonally).
        return "BOTTOMLEFT"
      case 17:  ; HTBOTTOMRIGHT       17      In the lower-right corner of a border of a resizable window (the user can click the mouse to resize the window diagonally).
        return "BOTTOMRIGHT"
      case 18:  ; HTBORDER            18      In the border of a window that does not have a sizing border.
        return "BORDER"
      case 20:  ; HTCLOSE             20      In a Close button.
        return "CLOSE"
      case 21:  ; HTHELP              21      In a Help button.
        return "HELP"
      default:
        return "UNKNOWN_" areaCode
    }
  }

  _getHoveredWindowAreaCode() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y, &hwnd)
    try {
      ErrorLevel := SendMessage(WindowFlags.WM_NCHITTEST, 0, (x & 0xFFFF) | (y & 0xFFFF) << 16, , "ahk_id " hwnd)
      return 1 * ErrorLevel
    } catch {
      return -2
    }
  }

  _getFunctionExecutedMessage(fnName, hwnd, state:="") {
    return this.beautifyActionName(fnName) " " (state="" ? "" : state " ") this._getWindowDescription(hwnd)
  }

  _getWindowDescription(hwnd) {
    windowClass := GetWindowClass(hwnd)
    vPName := WinGetProcessName("ahk_id " hwnd)
    return vPName " (" windowClass ")"
  }
  
  _checkHwnd(&hwnd, fnName) {
    if (hwnd=0)
      hwnd := WinGetID("A")
    if (this.IsWindowBlocklisted(hwnd, fnName)) {
      this.ShowInfo(this.beautifyActionName(fnName) " disabled for blocklisted " this._getWindowDescription(hwnd))
      return false
    }
    return true
  }

  _hasWindowStyle(hwnd, style) {
    windowStyle := WinGetStyle("ahk_id " hwnd)
    return !!(windowStyle & style)
  }

  _setWindowStyleState(hwnd, style, enable) {
    prefix := (enable) ? '+' : '-'
    WinSetStyle(Format("{2}{1:#x}", style, prefix), "ahk_id " hwnd)
  }

  _isWindowFullscreen(hwnd) {
    if (this._fullScreenWindowStates.Has(hwnd))
      return true

    frame := this._getVisibleWindowFrame(hwnd)
    if (!IsObject(frame))
      return false

    Loop MonitorGetCount() {
      MonitorGet(A_Index, &left, &top, &right, &bottom)
      if (Abs(frame.x - left) <= 2
          && Abs(frame.y - top) <= 2
          && Abs(frame.x + frame.w - right) <= 2
          && Abs(frame.y + frame.h - bottom) <= 2)
        return true
    }
    return false
  }

  _setFallbackBorder(hwnd, color) {
    this._removeFallbackBorder(hwnd)

    borderGui := Gui("-Caption +ToolWindow +E0x20 +E0x08000000 +Owner" hwnd)
    borderGui.BackColor := Format("{:06X}", color & 0xFFFFFF)
    borderGui.Show("Hide NoActivate")
    this._fallbackBorders[hwnd] := {
      gui: borderGui,
      frame: "",
      visible: false
    }

    this._updateFallbackBorder(hwnd, this._fallbackBorders[hwnd])
    this._startFallbackBorderTracking()
    if (!IsObject(this._fallbackBorderTimer))
      this._fallbackBorderTimer := ObjBindMethod(this, "_updateFallbackBorders")
    SetTimer(this._fallbackBorderTimer, this._fallbackBorderEventHook ? 250 : 50)
  }

  _removeFallbackBorder(hwnd) {
    if (!this._fallbackBorders.Has(hwnd))
      return

    state := this._fallbackBorders[hwnd]
    try state.gui.Destroy()
    this._fallbackBorders.Delete(hwnd)
    if (this._fallbackBorders.Count = 0) {
      if (IsObject(this._fallbackBorderTimer))
        SetTimer(this._fallbackBorderTimer, 0)
      this._stopFallbackBorderTracking()
    }
  }

  _startFallbackBorderTracking() {
    if (this._fallbackBorderEventHook)
      return

    this._fallbackBorderEventHandler := ObjBindMethod(this, "_onFallbackBorderWinEvent")
    this._fallbackBorderEventCallback := CallbackCreate(this._fallbackBorderEventHandler,, 7)
    this._fallbackBorderEventHook := DllCall("SetWinEventHook",
      "UInt", WinEventConstants.EVENT_OBJECT_LOCATIONCHANGE,
      "UInt", WinEventConstants.EVENT_OBJECT_LOCATIONCHANGE,
      "Ptr", 0,
      "Ptr", this._fallbackBorderEventCallback,
      "UInt", 0,
      "UInt", 0,
      "UInt", WinEventFlags.OUTOFCONTEXT
    )
    if (!this._fallbackBorderEventHook) {
      CallbackFree(this._fallbackBorderEventCallback)
      this._fallbackBorderEventCallback := 0
      this._fallbackBorderEventHandler := ""
    }
  }

  _stopFallbackBorderTracking() {
    if (this._fallbackBorderEventHook)
      DllCall("UnhookWinEvent", "Ptr", this._fallbackBorderEventHook)
    if (this._fallbackBorderEventCallback)
      CallbackFree(this._fallbackBorderEventCallback)
    this._fallbackBorderEventHook := 0
    this._fallbackBorderEventCallback := 0
    this._fallbackBorderEventHandler := ""
  }

  _onFallbackBorderWinEvent(hook, event, hwnd, idObject, idChild, eventThread, eventTime) {
    if (idObject != WinEventConstants.OBJID_WINDOW
        || idChild != WinEventConstants.CHILDID_SELF
        || !this._fallbackBorders.Has(hwnd))
      return
    try this._updateFallbackBorder(hwnd, this._fallbackBorders[hwnd])
  }

  _updateFallbackBorders() {
    staleHwnds := []
    for hwnd, state in this._fallbackBorders {
      if (!this._updateFallbackBorder(hwnd, state))
        staleHwnds.Push(hwnd)
    }
    for hwnd in staleHwnds
      this._removeFallbackBorder(hwnd)
  }

  _updateFallbackBorder(hwnd, state) {
    if (!DllCall("IsWindow", "Ptr", hwnd, "Int"))
      return false

    if (!this._isWindowVisibleForBorder(hwnd)) {
      try state.gui.Hide()
      state.visible := false
      return true
    }

    frame := this._getVisibleWindowFrame(hwnd)
    if (!IsObject(frame)) {
      try state.gui.Hide()
      state.visible := false
      return true
    }

    if (!IsObject(state.frame)
        || state.frame.x != frame.x || state.frame.y != frame.y
        || state.frame.w != frame.w || state.frame.h != frame.h
    ) {
      DllCall(
        "SetWindowPos",
        "Ptr", state.gui.Hwnd,
        "Ptr", 0,
        "Int", Round(frame.x),
        "Int", Round(frame.y),
        "Int", Round(frame.w),
        "Int", Round(frame.h),
        "UInt", WindowFlags.SWP_NOZORDER | WindowFlags.SWP_NOACTIVATE
      )
      this._setFallbackBorderRegion(state.gui.Hwnd, frame.w, frame.h)
      state.frame := frame
    }
    if (!state.visible) {
      state.gui.Show("NoActivate")
      state.visible := true
    }
    return true
  }

  _isWindowVisibleForBorder(hwnd) {
    try {
      if (!DllCall("IsWindowVisible", "Ptr", hwnd, "Int") || WinGetMinMax("ahk_id " hwnd) = -1)
        return false
    } catch {
      return false
    }

    cloaked := 0
    try {
      if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_CLOAKED, "UInt*", &cloaked, "UInt", Win32Sizes.DWORD) = 0 && cloaked)
        return false
    }
    return true
  }

  _getVisibleWindowFrame(hwnd) {
    rect := Buffer(16, 0)
    try {
      if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rect.Ptr, "UInt", rect.Size) = 0) {
        left := NumGet(rect, 0, "Int")
        top := NumGet(rect, 4, "Int")
        return {
          x: left,
          y: top,
          w: NumGet(rect, 8, "Int") - left,
          h: NumGet(rect, 12, "Int") - top
        }
      }
    }

    try {
      WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
      return {x: x, y: y, w: w, h: h}
    }
    return false
  }

  _setFallbackBorderRegion(guiHwnd, width, height) {
    width := Max(1, Round(width))
    height := Max(1, Round(height))
    thickness := Min(this._fallbackBorderThickness, Floor(Min(width, height) / 2))
    outerRegion := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr")

    if (thickness > 0 && width > thickness * 2 && height > thickness * 2) {
      innerRegion := DllCall("CreateRectRgn", "Int", thickness, "Int", thickness, "Int", width - thickness, "Int", height - thickness, "Ptr")
      DllCall("CombineRgn", "Ptr", outerRegion, "Ptr", outerRegion, "Ptr", innerRegion, "Int", 4)
      DllCall("DeleteObject", "Ptr", innerRegion)
    }

    if (!DllCall("SetWindowRgn", "Ptr", guiHwnd, "Ptr", outerRegion, "Int", true))
      DllCall("DeleteObject", "Ptr", outerRegion)
  }

  _setWindowCloaked(hwnd, cloaked) {
    if (!WinExist("ahk_id " hwnd))
      return

    cloakValue := cloaked ? 1 : 0
    try DllCall(
      "dwmapi\DwmSetWindowAttribute",
      "Ptr", hwnd,
      "UInt", WindowFlags.DWMWA_CLOAK,
      "Int*", cloakValue,
      "UInt", Win32Sizes.DWORD
    )
  }
}

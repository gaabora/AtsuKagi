class WindowManager extends AKPlugin {
  static WS_BORDER           := 0x800000   ; 	+/-Border. Creates a window that has a thin-line border.
  static WS_POPUP            := 0x80000000 ; 	Creates a pop-up window. This style cannot be used with the WS_CHILD style.
  static WS_CAPTION          := 0xC00000   ; 	+/-Caption. Creates a window that has a title bar. This style is a numerical combination of WS_BORDER and WS_DLGFRAME.
  static WS_CLIPSIBLINGS     := 0x4000000  ; 	Clips child windows relative to each other; that is, when a particular child window receives a WM_PAINT message, the WS_CLIPSIBLINGS style clips all other overlapping child windows out of the region of the child window to be updated. If WS_CLIPSIBLINGS is not specified and child windows overlap, it is possible, when drawing within the client area of a child window, to draw within the client area of a neighboring child window.
  static WS_DISABLED         := 0x8000000  ; 	+/-Disabled. Creates a window that is initially disabled.
  static WS_DLGFRAME         := 0x400000   ; 	Creates a window that has a border of a style typically used with dialog boxes.
  static WS_GROUP            := 0x20000    ; 	+/-Group. Indicates that this control is the first one in a group of controls. This style is automatically applied to manage the "only one at a time" behavior of radio buttons. In the rare case where two groups of radio buttons are added consecutively (with no other control types in between them), this style may be applied manually to the first control of the second radio group, which splits it off from the first.
  static WS_HSCROLL          := 0x100000   ; 	Creates a window that has a horizontal scroll bar.
  static WS_MAXIMIZE         := 0x1000000  ; 	Creates a window that is initially maximized.
  static WS_MAXIMIZEBOX      := 0x10000    ; 	+/-MaximizeBox. Creates a window that has a maximize button. Cannot be combined with the WS_EX_CONTEXTHELP style. The WS_SYSMENU style must also be specified.
  static WS_MINIMIZE         := 0x20000000 ; 	Creates a window that is initially minimized.
  static WS_MINIMIZEBOX      := 0x20000    ; 	+/-MinimizeBox. Creates a window that has a minimize button. Cannot be combined with the WS_EX_CONTEXTHELP style. The WS_SYSMENU style must also be specified.
  static WS_OVERLAPPED       := 0x0        ; 	Creates an overlapped window. An overlapped window has a title bar and a border. Same as the WS_TILED style.
  static WS_OVERLAPPEDWINDOW := 0xCF0000   ; 	Creates an overlapped window with the WS_OVERLAPPED, WS_CAPTION, WS_SYSMENU, WS_THICKFRAME, WS_MINIMIZEBOX, and WS_MAXIMIZEBOX styles. Same as the WS_TILEDWINDOW style.
  static WS_POPUPWINDOW      := 0x80880000 ; 	Creates a pop-up window with WS_BORDER, WS_POPUP, and WS_SYSMENU styles. The WS_CAPTION and WS_POPUPWINDOW styles must be combined to make the window menu visible.
  static WS_SIZEBOX          := 0x40000    ; 	+/-Resize. Creates a window that has a sizing border. Same as the WS_THICKFRAME style.
  static WS_SYSMENU          := 0x80000    ; 	+/-SysMenu. Creates a window that has a window menu on its title bar. The WS_CAPTION style must also be specified.
  static WS_TABSTOP          := 0x10000    ; 	+/-Tabstop. Specifies a control that can receive the keyboard focus when the user presses Tab. Pressing Tab changes the keyboard focus to the next control with the WS_TABSTOP style.
  static WS_THICKFRAME       := 0x40000    ; 	Creates a window that has a sizing border. Same as the WS_SIZEBOX style.
  static WS_VSCROLL          := 0x200000   ; 	Creates a window that has a vertical scroll bar.
  static WS_VISIBLE          := 0x10000000 ; 	Creates a window that is initially visible.
  static WS_CHILD            := 0x40000000 ; 	Creates a child window. A window with this style cannot have a menu bar. This style cannot be used with the WS_POPUP style.
  
  __ConfigHelp() {
    ; TODO
    return []
  }

  __UsageHelp() {
    return ""
  }

  __ActionsHelp() {
    texts := Map()
    texts["ShowWindowList"]                    := "ShowWindowList()"
    texts["ShowHoveredWindowInfo"]             := "ShowHoveredWindowInfo()"
    texts["ShowWindowInfo"]                    := "ShowWindowInfo()"
    texts["ShowResizeWindowDialog"]            := "ShowResizeWindowDialog(hwnd:=0)"
    texts["MinimizeWindow"]                    := "MinimizeWindow(hwnd:=0)"
    texts["MinimizeHoveredWindow"]             := "MinimizeHoveredWindow()"
    texts["CloseWindow"]                       := "CloseWindow(hwnd:=0)"
    texts["CloseHoveredWindow"]                := "CloseHoveredWindow()"
    texts["ToggleWindowMaximized"]             := "ToggleWindowMaximized(hwnd:=0)"
    texts["ToggleHoveredWindowMaximized"]      := "ToggleHoveredWindowMaximized()"
    texts["ToggleHoveredWindowOnTop"]          := "ToggleHoveredWindowOnTop(BorderColor:=-1)"
    texts["ToggleWindowOnTop"]                 := "ToggleWindowOnTop(BorderColor:=-1, hwnd:=0)"
    texts["ToggleWindowFullScreen"]            := "ToggleWindowFullScreen(hwnd:=0)"
    texts["ToggleHoveredWindowFullScreen"]     := "ToggleHoveredWindowFullScreen()"
    texts["ToggleWindowFrame"]                 := "ToggleWindowFrame(hwnd:=0)"
    texts["ToggleHoveredWindowFrame"]          := "ToggleHoveredWindowFrame()"
    texts["ToggleWindowTransparency"]          := "ToggleWindowTransparency(TransparencyValue:=128, hwnd:=0)"
    texts["ToggleHoveredWindowTransparency"]   := "ToggleHoveredWindowTransparency(TransparencyValue:=128)"
    texts["IncreaseWindowTransparency"]        := "IncreaseWindowTransparency(ByValue:=32, hwnd:=0)"
    texts["IncreaseHoveredWindowTransparency"] := "IncreaseHoveredWindowTransparency(ByValue:=32)"
    texts["DecreaseWindowTransparency"]        := "DecreaseWindowTransparency(ByValue:=32, hwnd:=0)"
    texts["DecreaseHoveredWindowTransparency"] := "DecreaseHoveredWindowTransparency(ByValue:=32)"
    texts["SetWindowBorderColor"]              := "SetWindowBorderColor(color:=-1, hwnd:=0)"

    texts["IsMouseOverTaskbar"]                := "IsMouseOverTaskbar()"
    texts["IsMouseOverWindowTitlebar"]         := "IsMouseOverWindowTitlebar()"
    texts["IsMouseOverWindowAnyBorder"]        := "IsMouseOverWindowAnyBorder()"
    texts["IsMouseOverWindowResizableBorder"]  := "IsMouseOverWindowResizableBorder()"
    
    return texts
  }

  ProcessBlacklistConfig() {
  }

  ProcessPluginConfig() {
    if (!this.Config.Has("WindowTitlebarAreaHeight"))
      this.Config.WindowTitlebarAreaHeight := 32
  }

  ShowHoveredWindowInfo() { ;;;
    MouseGetPos(,, &hwnd)
    this.ShowWindowInfo(hwnd)
  }

  ShowWindowInfo(hwnd:=0) { ;;;
    if (hwnd=0)
      hwnd := WinGetID("A")
    MouseGetPos(,, &hwnd)
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

  ShowResizeWindowDialog(hwnd:=0) { ;;;
    static SelectedWindowhwnd := 0
    static OldW := 0
    static OldH := 0
    static NewW := 0
    static NewH := 0
    static ResizeDialog := ''
    static OldMax := 0

    if (ResizeDialog) {
      ResizeDialog.Destroy()
      ResizeDialog := ''
      return
    }

    if (!this._checkHwnd(&hwnd, A_ThisFunc)) ; TODO ignore start menu
      return

    SelectedWindowhwnd := hwnd

    OldMax := WinGetMinMax("ahk_id " SelectedWindowhwnd)
    if (OldMax) {
      WinRestore("ahk_id " SelectedWindowhwnd)
    }

    WinGetPos(&OldX, &OldY, &OldW, &OldH, "ahk_id " SelectedWindowhwnd)
    
    ResizeDialog := Gui()
    ResizeDialog.Title := "Window size: " WinGetProcessName("ahk_id " SelectedWindowhwnd)
    ResizeDialog.Opt("+ToolWindow +AlwaysOnTop")
  
    ResizeDialog.Add("Edit", "w50 number right")

    ResizeDialog.Add("UpDown", "vNewW Range24-9999", OldW)
      .OnEvent("Change", Apply.Bind("Change"))
    
    ResizeDialog.Add("Edit", "ys w50 number right")

    ResizeDialog.Add("UpDown", "vNewH Range24-9999", OldH)
      .OnEvent("Change", Apply.Bind("Change"))

    ResizeDialog.Add("Button", "ys Default", "Apply")
      .OnEvent("Click", Apply.Bind("Change"))
    ResizeDialog.Add("Button", "ys", "OK")
      .OnEvent("Click", OK.Bind("Change"))
    ResizeDialog.Add("Button", "ys", "Revert")
      .OnEvent("Click", Revert.Bind("Change"))

    ResizeDialog.OnEvent('Escape', (*) => Revert())


    ResizeDialog.Show()

    Return

    OK(*) {
      Apply()
      ResizeDialog.Destroy()
      ResizeDialog := ''
    }
    Apply(*) {
      oSaved := ResizeDialog.Submit("0")
      NewW := oSaved.NewW
      NewH := oSaved.NewH
      WinMove(,,NewW, NewH, "ahk_id " SelectedWindowhwnd)
    }
    Revert(*) {
        if (OldMax) {
          WinMaximize("ahk_id " SelectedWindowhwnd)
        }
        WinMove(,,OldW, OldH, "ahk_id " SelectedWindowhwnd)
        ResizeDialog.Destroy()
        ResizeDialog := ''
    }
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

    maximized := WinGetMinMax("ahk_id " hwnd)
    if (maximized) {
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
    this.ToggleWindowOnTop(hwnd)  
  }
  ToggleWindowOnTop(BorderColor:=-1, hwnd:=0) { ;;;
    HexColor := (BorderColor = -1) ? 0x00FFFF : BorderColor

    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    windowStyle := WinGetExStyle("ahk_id " . hwnd)
    if (windowStyle & 0x8) { ; 0x8 is WS_EX_TOPMOST.
        WinSetAlwaysOnTop(False, "ahk_id " . hwnd)
        this.SetWindowBorderColor(,hwnd)
        this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
      } else {
        WinSetAlwaysOnTop(True, "ahk_id " . hwnd)
        this.SetWindowBorderColor(HexColor, hwnd)
        this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    }
  }

  ToggleWindowFullScreen(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    if (WinGetMinMax("ahk_id " hwnd)) {
      WinRestore("ahk_id " hwnd)
    }
    if (this._hasWindowStyle(hwnd, WindowManager.WS_CAPTION)) {
      this._setWindowStyleState(hwnd, WindowManager.WS_CAPTION, false)
      this._setWindowStyleState(hwnd, WindowManager.WS_SIZEBOX, false)
      WinMaximize("ahk_id " hwnd)

      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    } else {
      this._setWindowStyleState(hwnd, WindowManager.WS_CAPTION, true)
      this._setWindowStyleState(hwnd, WindowManager.WS_SIZEBOX, true)
      
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    }
  }

  ToggleHoveredWindowFullScreen() { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowFullScreen(hwnd)  
  }


  ToggleWindowFrame(hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    WinGetPos(&Xpos, &Ypos, &Width, &Height, "ahk_id " hwnd)

    if (this._hasWindowStyle(hwnd, WindowManager.WS_CAPTION)) {
      this._setWindowStyleState(hwnd, WindowManager.WS_CAPTION, false)
      ; this._setWindowStyleState(hwnd, WindowManager.WS_SIZEBOX, false)
      
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    } else {
      this._setWindowStyleState(hwnd, WindowManager.WS_CAPTION, true)
      ; this._setWindowStyleState(hwnd, WindowManager.WS_SIZEBOX, true)
      
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    }
    WinMove(Xpos, Ypos, Width, Height, "ahk_id " hwnd)
  }

  ToggleHoveredWindowFrame() { ;;;
    MouseGetPos(,, &hwnd)
    this.ToggleWindowFrame(hwnd)  
  }


  ToggleWindowTransparency(TransparencyValue:=128, hwnd:=0) { ;;;
    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    Transparency := WinGetTransparent("ahk_id " . hwnd)
    if (Transparency = "") {
      WinSetTransparent(TransparencyValue, "ahk_id " . hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    } else {
      WinSetTransparent("OFF", "ahk_id " . hwnd)
      this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    }
  }

  ToggleHoveredWindowTransparency(TransparencyValue:=128) { ;;;
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
    if (hwnd=0)
      hwnd := WinGetID("A")
    DWMWA_BORDER_COLOR := 34
    R := (color & 0xFF0000) >> 16
    G := (color & 0xFF00) >> 8
    B := (color & 0xFF)
    newColor := (B << 16) | (G << 8) | R
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", DWMWA_BORDER_COLOR, "int*", (color = -1) ? 0xFFFFFFFF : newColor, "int", 4)
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

  IsMouseOverTaskbar() { ;;;
    MouseGetPos(, , &hwnd)
    hoverTaskbar := WinExist("ahk_class Shell_TrayWnd ahk_id " hwnd)
    hoverSecondaryTaskbar := WinExist("ahk_class Shell_SecondaryTrayWnd ahk_id " hwnd)
    return hoverTaskbar || hoverSecondaryTaskbar
  }

  IsMouseOverWindowTitlebar() { ;;;
    areaCode := this._getHoveredWindowAreaCode()
    if (areaCode = 1) {
      CoordMode("Mouse", "Client")
      MouseGetPos(, &y)
      ; treat top area as titlebar for windows without standard CAPTION
      if (y < this.Config.WindowTitlebarAreaHeight)
        return true
    }
    return (areaCode = 2 || areaCode = 3 || areaCode = 8 || areaCode = 9 || areaCode = 20 || areaCode = 21) && !this.IsMouseOverTaskbar()
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
    WM_NCHITTEST := 0x84
    try {
      ErrorLevel := SendMessage(WM_NCHITTEST, 0, (x & 0xFFFF) | (y & 0xFFFF) << 16, , "ahk_id " hwnd)
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
    if (this.IsWindowBlacklisted(hwnd, fnName)) {
      this.ShowInfo(this.beautifyActionName(fnName) " disabled for blacklisted " this._getWindowDescription(hwnd))
      return false
    }
    return true
  }

  _hasWindowStyle(hwnd, style) {
    Style := WinGetStyle("ahk_id " hwnd)
    if (style & WindowManager.WS_CAPTION) {
      return true
    } else {
      return false
    }
  }

  _setWindowStyleState(hwnd, style, enable) {
    prefix := (enable) ? '+' : '-'
    WinSetStyle(Format("{2}{1:#x}", style, prefix), "ahk_id " hwnd)
  }
}

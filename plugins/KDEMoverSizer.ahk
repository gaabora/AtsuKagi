class KDEMoverSizer extends AKPlugin {
  _overlayGui := ""
  _overlayColor := "2080DD"
  _overlayOpacity := 80
  _infoTipGui := ""
  _infoTipTextCtrl := ""
  _lastInfoTipText := ""
  _infoTipVisible := false
  windowState := {}

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "KDEMoverSizer",
        "title", "KDE Mover-Sizer",
        "description", "Enhanced window moving/resizing with drag from any place on window instead of titlebar/borders.",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure drag-anywhere movement, resizing, snapping, and preview behavior.",
        "icon", "icons10-resize-four-directions"
      ),
      "config", [
        Map(
          "key", "LockAxisHotkey",
          "label", "Lock axis hotkey",
          "description", "Hold during move or resize to lock the dominant axis.",
          "type", "hotkey",
          "default", "Shift",
          "section", "Movement",
          "scope", "plugin"
        ),
        Map(
          "key", "QuickPositionHotkey",
          "label", "Quick position hotkey",
          "description", "Hold to snap the window into quick-position regions.",
          "type", "hotkey",
          "default", "LWin",
          "section", "Movement",
          "scope", "plugin"
        ),
        Map(
          "key", "EnableSnapping",
          "label", "Enable snapping",
          "description", "Snap dragged or resized windows to monitor edges.",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "SnappingDistance",
          "label", "Magnetic snap distance (px)",
          "description", "Pixel distance threshold for magnetic edge snapping during drag.",
          "type", "number",
          "default", 10,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "CompensateInvisibleBorders",
          "label", "Compensate invisible DWM borders",
          "description", "Use visible window bounds so edge snapping lands flush on screen edges.",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "ShowWindowContentOnMove",
          "label", "Show window content while moving",
          "description", "When disabled, show only a frame preview instead of moving the live window.",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
          "scope", "plugin"
        ),
        Map(
          "key", "ShowWindowContentOnResize",
          "label", "Show window content while resizing",
          "description", "When disabled, show only a frame preview instead of resizing the live window.",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
          "scope", "plugin"
        ),
        Map(
          "key", "ShowWindowContentOnQuickPosition",
          "label", "Show window content on quick position",
          "description", "When disabled, show only a frame preview when using quick position snap.",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
          "scope", "plugin"
        ),
        Map(
          "key", "UseSetWindowPos",
          "label", "Use SetWindowPos for dragging",
          "description", "Use the native SetWindowPos API during live move and resize updates.",
          "type", "boolean",
          "default", true,
          "section", "Performance",
          "scope", "plugin"
        ),
        Map(
          "key", "BringToFront",
          "label", "Bring window to front",
          "description", "Activate the target window when move or resize mode begins.",
          "type", "boolean",
          "default", false,
          "section", "Behavior",
          "scope", "plugin"
        )
      ],
      "actions", [
        Map(
          "action", "EnterWindowMovingMode",
          "label", "Move window",
          "description", "Move a window by dragging from anywhere on it.",
          "params", [],
          "category", "Window Movement",
          "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "SnappingDistance", "CompensateInvisibleBorders", "ShowWindowContentOnMove", "ShowWindowContentOnQuickPosition", "UseSetWindowPos", "BringToFront"]
        ),
        Map(
          "action", "EnterWindowResizingMode",
          "label", "Resize window",
          "description", "Resize a window by dragging from anywhere on it.",
          "params", [],
          "category", "Window Movement",
          "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "SnappingDistance", "CompensateInvisibleBorders", "ShowWindowContentOnResize", "ShowWindowContentOnQuickPosition", "UseSetWindowPos", "BringToFront"]
        )
      ],
      "hooks", []
    )
  }

  ; ── Legacy Methods (Phase 1-5: TODO: remove after Phase 5) ─────────────────────
  ; These are now derived from __DescribePlugin() by the base class
  _processBlocklistConfig() {
  }

  _processPluginConfig() {
    ; Apply descriptor defaults, then any additional processing if needed
    this.__ApplyDefaultConfig()
  }
  
  EnterWindowMovingMode() { ;;;
    SnappingDistance := Number(this.Config.SnappingDistance)
    
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    this.initEscapeHook()
    this.disableEscapeHook()

    MouseGetPos(&xMouSrc, &yMouSrc, &hwnd)
    hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
    MouseButton := hotkeyInfo.key

    if (!hwnd || this._isSystemWindow(hwnd))
      return

    if (this.IsWindowBlocklisted(hwnd, A_ThisFunc)) {
      SendEvent("{Blind}{" MouseButton " down}")
      KeyWait(MouseButton, "U")
      SendEvent("{Blind}{" MouseButton " up}")
      return
    }



    this.saveOriginalWindowState(hwnd)
    this.enableEscapeHook()

    if (!this.Config.ShowWindowContentOnMove)
      this._createOverlay()
    this._createInfoTip()

    if (this.Config.BringToFront)
      WinActivate("ahk_id " hwnd)
    
    IsMaximized := WinGetMinMax("ahk_id " hwnd)

    if (IsMaximized) {
      WinRestore("ahk_id " hwnd)
      this.saveOriginalWindowState(hwnd)
      this.windowState.max := 1
    }

    QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P") ; check that button was released once before window is QuickPositioned
    LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P") ; check that button was released once before movement is locked

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)

    wWinDst := wWinSrc
    hWinDst := hWinSrc

    leftInset := 0
    topInset := 0
    rightInset := 0
    bottomInset := 0
    this._getInvisibleBorderOffsets(hwnd, &leftInset, &topInset, &rightInset, &bottomInset)

    EscButtonState := "U"
    isQuickPositioning := false

    Loop {
      MouseButtonState := GetKeyState(MouseButton, "P") ? "D" : "U"
      if (MouseButtonState = "U")
        break

      EscButtonState := GetKeyState("Escape", "P") ? "D" : "U"
      if (EscButtonState = "D") {
        this.restoreOriginalWindowState(hwnd)
        break
      }

      if (!QuickPositionHotkey_wasUp)
        QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P")
      if (!LockAxisHotkey_wasUp)
        LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P")

      isQuickPositioning := false
      
      if (QuickPositionHotkey_wasUp && GetKeyState(this.Config.QuickPositionHotkey , "P")) {
        isQuickPositioning := true
        this.quickPositionWindowOnEdge(&xWinDst, &yWinDst, &wWinDst, &hWinDst)
      } else {

        MouseGetPos(&xMouLst, &yMouLst)
        xMouDif := xMouLst - xMouSrc
        yMouDif := yMouLst - yMouSrc
        
        if (LockAxisHotkey_wasUp && GetKeyState(this.Config.LockAxisHotkey , "P")) {
          if (Abs(xMouDif) - Abs(yMouDif) > 0)
            yMouDif := 0 ; lock Y
          else
            xMouDif := 0 ; lock X
        }

        ; Apply this offset to the window position.
        xWinDst := (xWinSrc + xMouDif)
        yWinDst := (yWinSrc + yMouDif)

        ; allow snapping on all monitors without releasing button
        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)

        if (this.Config.EnableSnapping) {
          visLeft := xWinDst + leftInset
          visTop := yWinDst + topInset
          visRight := xWinDst + wWinSrc - rightInset
          visBottom := yWinDst + hWinSrc - bottomInset

          if (visLeft < CurScrLeft + SnappingDistance) && (visLeft > CurScrLeft - SnappingDistance)
            xWinDst := CurScrLeft - leftInset

          if (visTop < CurScrTop + SnappingDistance) && (visTop > CurScrTop - SnappingDistance)
            yWinDst := CurScrTop - topInset

          if (visRight > CurScrRight - SnappingDistance) && (visRight < CurScrRight + SnappingDistance)
            xWinDst := CurScrRight - (wWinSrc - rightInset)

          if (visBottom > CurScrBottom - SnappingDistance) && (visBottom < CurScrBottom + SnappingDistance)
            yWinDst := CurScrBottom - (hWinSrc - bottomInset)
        }
      }

      showContent := isQuickPositioning ? this.Config.ShowWindowContentOnQuickPosition : this.Config.ShowWindowContentOnMove
      if (showContent) {
        if (isQuickPositioning)
          this._applyVisibleWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst, leftInset, topInset, rightInset, bottomInset)
        else
          this._applyWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst)
      }
      else
        this._showOverlay(xWinDst, yWinDst, wWinDst, hWinDst)

      this._updateInfoTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst/2, yWinDst + hWinDst/2)
    }

    showContent := isQuickPositioning ? this.Config.ShowWindowContentOnQuickPosition : this.Config.ShowWindowContentOnMove
    if (!showContent) {
      this._destroyOverlay()
      if (EscButtonState = "U")
        if (isQuickPositioning)
          this._applyVisibleWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst, leftInset, topInset, rightInset, bottomInset)
        else
          this._applyWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst)
    }

    this._destroyInfoTip()
    this.disableEscapeHook()
    return
  }

  EnterWindowResizingMode() { ;;;
    SnappingDistance := Number(this.Config.SnappingDistance)
    RestoreOnResize := 1
    Use9WindowAreasToResize := 0

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    this.initEscapeHook()
    this.disableEscapeHook()

    MouseGetPos(&xMouSrc, &yMouSrc, &hwnd)
    hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
    MouseButton := hotkeyInfo.key

    if (!hwnd || this._isSystemWindow(hwnd))
      return

    style := WinGetStyle("ahk_id " hwnd)
    if (!(style & WindowFlags.WS_SIZEBOX))
      return ; Only allow resizing windows that have a sizing border

    if (this.IsWindowBlocklisted(hwnd, A_ThisFunc)) {
      SendEvent("{Blind}{" MouseButton " down}")
      KeyWait(MouseButton, "U")
      SendEvent("{Blind}{" MouseButton " up}")
      return
    }

    this.saveOriginalWindowState(hwnd)
    this.enableEscapeHook()

    if (!this.Config.ShowWindowContentOnResize)
      this._createOverlay()
    this._createInfoTip()

    if (this.Config.BringToFront)
      WinActivate("ahk_id " hwnd)

    IsMaximized := WinGetMinMax("ahk_id " hwnd)
    if (IsMaximized) {
      if (RestoreOnResize) {
        WinRestore("ahk_id " hwnd)
        this.saveOriginalWindowState(hwnd)
        this.windowState.max := 1
      } else {
        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
        WinRestore("ahk_id " hwnd)
        this.saveOriginalWindowState(hwnd)
        this.windowState.max := 1
        WinMove(CurScrLeft, CurScrTop, CurScrRight - CurScrLeft, CurScrBottom - CurScrTop, "ahk_id " hwnd)
      }
    }

    QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P") ; check that button was released once before window is QuickPositioned
    LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P") ; check that button was released once before movement is locked

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)
    xWinDst := xWinSrc
    yWinDst := yWinSrc
    wWinDst := wWinSrc
    hWinDst := hWinSrc

    leftInset := 0
    topInset := 0
    rightInset := 0
    bottomInset := 0
    this._getInvisibleBorderOffsets(hwnd, &leftInset, &topInset, &rightInset, &bottomInset)

    if (Use9WindowAreasToResize) {
      ; WinLeft = [-1;0;1], WinUp = [-1;0;1]
      xMultiplier := 0
      yMultiplier   := 0
      if (xMouSrc < xWinSrc + wWinSrc / 3)
        xMultiplier := 1
      if (xMouSrc > xWinSrc + wWinSrc *2/3)
        xMultiplier := -1
      if (yMouSrc < yWinSrc + hWinSrc / 3)
        yMultiplier := 1
      if (yMouSrc > yWinSrc + hWinSrc *2/3)
        yMultiplier := -1
    } else {
      ; WinLeft = [-1;1], WinUp = [-1;1]
      xMultiplier := (xMouSrc < xWinSrc + wWinSrc / 2) ? 1 : -1
      yMultiplier := (yMouSrc < yWinSrc + hWinSrc / 2) ? 1 : -1
    }

    EscButtonState := "U"
    isQuickPositioning := false

    Loop{
      MouseButtonState := GetKeyState(MouseButton, "P") ? "D" : "U"
      if (MouseButtonState = "U") {
        break
      }

      EscButtonState := GetKeyState("Escape", "P") ? "D" : "U"
      if (EscButtonState = "D") {
        this.restoreOriginalWindowState(hwnd)
        break
      }

      if (!QuickPositionHotkey_wasUp)
        QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P")
      if (!LockAxisHotkey_wasUp)
        LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P")

      MouseGetPos(&xMouLst, &yMouLst)
      xMouDif := xMouLst - xMouSrc
      yMouDif := yMouLst - yMouSrc

      if (LockAxisHotkey_wasUp && GetKeyState(this.Config.LockAxisHotkey , "P")) {
        ; locking for default Resizing
        if (Abs(xMouDif) - Abs(yMouDif) > 0)
          yMouDif := 0 ; lock Y
        else
          xMouDif := 0 ; lock X
      }

      ; snap the window to the edge of the screen if closer than 10 pixels to border
      ; first, get current screen borders for snapping, do this within the loop to allow snapping on all monitors without releasing button

      ; allow snapping on all monitors without releasing button
      GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)

      if (!QuickPositionHotkey_wasUp)
        QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P")
      if (!LockAxisHotkey_wasUp)
        LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P")

      isQuickPositioning := false

      if (QuickPositionHotkey_wasUp && GetKeyState(this.Config.QuickPositionHotkey, "P")) {
        isQuickPositioning := true
        this.quickPositionWindowOnEdge(&xWinDst, &yWinDst, &wWinDst, &hWinDst)
      } else if (this.Config.EnableSnapping) {
        ; "normal" resizing
        xWinDst := (xWinSrc + (xMultiplier =1 ? 1 : 0) * xMouDif)
        yWinDst := (yWinSrc + (yMultiplier =1 ? 1 : 0) * yMouDif)
        wWinDst := (wWinSrc - xMultiplier * xMouDif)
        hWinDst := (hWinSrc - yMultiplier * yMouDif)

        visLeft := xWinDst + leftInset
        visTop := yWinDst + topInset
        visRight := xWinDst + wWinDst - rightInset
        visBottom := yWinDst + hWinDst - bottomInset

        if (visLeft < CurScrLeft + SnappingDistance) && (visLeft > CurScrLeft - SnappingDistance) && (xMultiplier > 0) {
          xWinDst := CurScrLeft - leftInset
          wWinDst := wWinSrc + xWinSrc - xWinDst
        }
        if (visTop < CurScrTop + SnappingDistance) && (visTop > CurScrTop - SnappingDistance) && (yMultiplier > 0) {
          yWinDst := CurScrTop - topInset
          hWinDst := hWinSrc + yWinSrc - yWinDst
        }
        if (visRight > CurScrRight - SnappingDistance) && (visRight < CurScrRight + SnappingDistance) && (xMultiplier < 0) {
          wWinDst := CurScrRight - xWinDst + rightInset
        }
        if (visBottom > CurScrBottom - SnappingDistance) && (visBottom < CurScrBottom + SnappingDistance) && (yMultiplier < 0) {
          hWinDst := CurScrBottom - yWinDst + bottomInset
        }
      } else {
        ; no snapping, just resizing
        xWinDst := (xWinSrc + (xMultiplier = 1 ? 1 : 0) * xMouDif)
        yWinDst := (yWinSrc + (yMultiplier = 1 ? 1 : 0) * yMouDif)
        wWinDst := (wWinSrc - xMultiplier * xMouDif)
        hWinDst := (hWinSrc - yMultiplier * yMouDif)
      }

      showContent := isQuickPositioning ? this.Config.ShowWindowContentOnQuickPosition : this.Config.ShowWindowContentOnResize
      if (showContent) {
        if (isQuickPositioning)
          this._applyVisibleWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst, leftInset, topInset, rightInset, bottomInset)
        else
          this._applyWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst)
      } else {
        this._showOverlay(xWinDst, yWinDst, wWinDst, hWinDst)
      }
      this._updateInfoTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst / 2, yWinDst + hWinDst / 2)
      ; Sleep, 1
    }

    showContent := isQuickPositioning ? this.Config.ShowWindowContentOnQuickPosition : this.Config.ShowWindowContentOnResize
    if (!showContent) {
      this._destroyOverlay()
      if (EscButtonState = "U")
        if (isQuickPositioning)
          this._applyVisibleWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst, leftInset, topInset, rightInset, bottomInset)
        else
          this._applyWindowRect(hwnd, xWinDst, yWinDst, wWinDst, hWinDst)
    }

    this._destroyInfoTip()
    this.disableEscapeHook()
    return
  }

  saveOriginalWindowState(hwnd) {
    max := WinGetMinMax("ahk_id " hwnd)
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    this.windowState := { max: max, x: x, y: y, w: w, h: h }
    OutputDebug("SAVE state: max: " max ", x: " x ", y: " y ", w: " w ", h: " h "`n")
  }
  
  restoreOriginalWindowState(hwnd) {
    max := this.windowState.max
    x := this.windowState.x
    y := this.windowState.y
    w := this.windowState.w
    h := this.windowState.h
    
    OutputDebug("LOAD state: max: " max ", x: " x ", y: " y ", w: " w ", h: " h "`n")
    IsMaximized := WinGetMinMax("ahk_id " hwnd)
    if (IsMaximized && ! this.windowState.max) {
      WinRestore("ahk_id " hwnd)
      WinMove(x, y, w, h, "ahk_id " hwnd)
    } else if (! IsMaximized && this.windowState.max) {
      WinMove(x, y, w, h, "ahk_id " hwnd)
      WinMaximize("ahk_id " hwnd)
    } else {
      WinMove(x, y, w, h, "ahk_id " hwnd)
    }
  }

  _applyWindowRect(hwnd, x, y, w, h) {
    if (this.Config.UseSetWindowPos) {
      try {
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", Round(x), "Int", Round(y), "Int", Round(w), "Int", Round(h), "UInt", WindowFlags.SWP_NOZORDER | WindowFlags.SWP_NOACTIVATE)
        return
      }
    }

    WinMove(x, y, w, h, "ahk_id " hwnd)
  }

  _applyVisibleWindowRect(hwnd, x, y, w, h, leftInset, topInset, rightInset, bottomInset) {
    this._applyWindowRect(
      hwnd,
      x - leftInset,
      y - topInset,
      w + leftInset + rightInset,
      h + topInset + bottomInset
    )
  }

  _getInvisibleBorderOffsets(hwnd, &leftInset, &topInset, &rightInset, &bottomInset) {
    leftInset := 0
    topInset := 0
    rightInset := 0
    bottomInset := 0

    if (!this.Config.CompensateInvisibleBorders)
      return false

    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
    rect := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rect.Ptr, "UInt", rect.Size) != 0)
      return false

    visX := NumGet(rect, 0, "Int")
    visY := NumGet(rect, 4, "Int")
    visR := NumGet(rect, 8, "Int")
    visB := NumGet(rect, 12, "Int")

    leftInset := Max(0, visX - winX)
    topInset := Max(0, visY - winY)
    rightInset := Max(0, (winX + winW) - visR)
    bottomInset := Max(0, (winY + winH) - visB)
    return true
  }

  _isSystemWindow(hwnd) {
    if (!hwnd)
      return true

    if (!DllCall("IsWindowVisible", "Ptr", hwnd))
      return true

    isWindowInvisible := 0
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_CLOAKED, "UInt*", &isWindowInvisible, "UInt", 4) = 0) {
      if (isWindowInvisible)
        return true
    }

    exStyle := WinGetExStyle("ahk_id " hwnd)
    if (exStyle & WindowFlags.WS_EX_TOOLWINDOW)
      return true
    if (exStyle & WindowFlags.WS_EX_LAYERED)
      return true

    className := ""
    try className := WinGetClass("ahk_id " hwnd)
    if (className = "Shell_TrayWnd" || className = "Shell_SecondaryTrayWnd" || className = "Windows.UI.Core.CoreWindow" || className = "Button" || className = "SysPager" || className = "WorkerW" || className = "Progman")
      return true

    processName := ""
    try processName := WinGetProcessName("ahk_id " hwnd)
    if (processName = "StartMenuExperienceHost.exe" || processName = "SearchHost.exe")
      return true

    return false
  }

  formatWindowGeometryInfo(x, y, w, h) {
    return "x: " . Round(x) . ", y: " . Round(y) . "`n(" . Round(w) . " x " . Round(h) . ")"
  }

  quickPositionWindowOnEdge(&xWin, &yWin, &wWin, &hWin) {
    ; Resize&Snapping Areas:
    ; Off   X,Y  W,H  QkSize X,Y    W,H  Off_l
    ;  0    0    1/4   =[1]  [0]     [1]   1
    ;  1/16 0    1/3   =[2]  [0]     [2]   2
    ;  2/16 0    0.382 =[3]  [0]     [3]   3
    ;  3/16 0    1/2   =[4]  [0]     [4]   4
    ;  4/16 0    0.618       [0]   1-[3]   5
    ;  5/16 0    2/3         [0]   1-[2]   6
    ;  6/16 0    3/4         [0]   1-[1]   7
    ;  7/16 0      1         [0]   1-[0]   8
    ;  8/16 0      1       1-W,H   1-[0]   8
    ;  9/16 1/4   3/4      1-W,H   1-[1]   7
    ; 10/16 1/3   2/3      1-W,H   1-[2]   6
    ; 11/16 0.382 0.618    1-W,H   1-[3]   5
    ; 12/16 1/2   1/2      1-W,H     [4]   4
    ; 13/16 0.618 0.382    1-W,H     [3]   3
    ; 14/16 2/3   1/3      1-W,H     [2]   2
    ; 15/16 3/4   1/4      1-W,H     [1]   1

    QuickSize0 := 0
    QuickSize1 := 1/4
    QuickSize2 := 1/3
    QuickSize3 := 0.382
    QuickSize4 := 1/2

    ; Center: (at 7/16 <= .. < 9/16)
    ; Off X+Y  X=Y, W=H
    ;  outer:       1
    ;  middle:      0.66
    ;  inner:       0.333

    ; Initialize with sensible defaults in case GetCurrentScreenBorders fails
    CurScrLeft := 0
    CurScrRight := A_ScreenWidth
    CurScrTop := 0
    CurScrBottom := A_ScreenHeight
    GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
    scrWidth  := CurScrRight - CurScrLeft
    scrHeight := CurScrBottom - CurScrTop
    MouseGetPos(&WinCenterX, &WinCenterY)

    WinCenterXl := WinCenterX - CurScrLeft
    WinCenterYl := WinCenterY - CurScrTop
    
    OffX := Floor((16 * WinCenterXl) / scrWidth)  ; floor divide to obtain OffX 0..15
    OffY := Floor((16 * WinCenterYl) / scrHeight) ; floor divide to obtain OffY 0..15
    
    OffX_l := OffX + 1
    OffY_l := OffY + 1
    if (OffX >= 8)
      OffX_l := 16 - OffX
    if (OffY >= 8)
      OffY_l := 16 - OffY

    M8mOffX_l := 8 - OffX_l
    M8mOffY_l := 8 - OffY_l
    
    if (Abs(WinCenterXl - scrWidth / 2) < scrWidth /16 * 0.33 && Abs(WinCenterYl - scrHeight / 2) < scrHeight / 16 * 0.33) { ; inner center
      xWin := CurScrLeft + 0.33 * scrWidth
      yWin := CurScrTop + 0.33 * scrHeight
      wWin := scrWidth * 0.33
      hWin := scrHeight * 0.33
    } else if (Abs(WinCenterXl - scrWidth / 2) < scrWidth /16 * 0.66 && Abs(WinCenterYl - scrHeight / 2) < scrHeight / 16 * 0.66) { ; middle center
      xWin := CurScrLeft + 0.25 * scrWidth
      yWin := CurScrTop + 0.25 * scrHeight
      wWin := scrWidth * 0.5
      hWin := scrHeight * 0.5
    } else if (Abs(WinCenterXl - scrWidth / 2) < scrWidth / 16 * 1 && Abs(WinCenterYl - scrHeight / 2) < scrHeight / 16 * 1) { ; outer center
      xWin := CurScrLeft + 0.382 * 0.382 * scrWidth
      yWin := CurScrTop + 0.382 * 0.382 * scrHeight
      wWin := scrWidth * (1 - 2 * 0.382 * 0.382)
      hWin := scrHeight * (1 - 2 * 0.382 * 0.382)
    } else { ; one of the outer squares
      if (OffX_l <= 4)
        wWin := scrWidth * QuickSize%OffX_l%
      else
        wWin := scrWidth * (1 - QuickSize%M8mOffX_l%)
          
      if (OffX < 8)
        xWin := CurScrLeft
      else
        xWin := CurScrLeft + scrWidth - wWin

      if (OffY_l <= 4)
        hWin := scrHeight * QuickSize%OffY_l%
      else
        hWin := scrHeight * (1 - QuickSize%M8mOffY_l%)
          
      if (OffY < 8)
        yWin := CurScrTop
      else
        yWin := CurScrTop + scrHeight - hWin
    }
  }

  _createOverlay() {
    this._destroyOverlay()
    this._overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    this._overlayGui.BackColor := this._overlayColor
    this._overlayGui.Show("Hide NoActivate")
    WinSetTransparent(this._overlayOpacity, "ahk_id " this._overlayGui.Hwnd)
    ; Rounded corners on Win11+ (DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this._overlayGui.Hwnd
        , "UInt", 33, "Int*", 2, "UInt", 4)
  }

  _showOverlay(x, y, w, h) {
    if (!IsObject(this._overlayGui))
      this._createOverlay()
    this._overlayGui.Show("x" Round(x) " y" Round(y) " w" Round(w) " h" Round(h) " NoActivate")
  }

  _destroyOverlay() {
    if (IsObject(this._overlayGui)) {
      try this._overlayGui.Destroy()
      this._overlayGui := ""
    }
  }

  _createInfoTip() {
    this._destroyInfoTip()
    this._infoTipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    this._infoTipGui.BackColor := "1A1A2E"
    this._infoTipGui.MarginX := 12
    this._infoTipGui.MarginY := 8
    this._infoTipGui.SetFont("s10 cE0E0E0", "Segoe UI")
    this._infoTipTextCtrl := this._infoTipGui.Add("Text", "vInfoText w160 R2 Center", "`n")
    this._infoTipGui.Show("AutoSize Hide NoActivate")
    WinSetTransparent(220, "ahk_id " this._infoTipGui.Hwnd)
    ; Rounded corners on Win11+
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this._infoTipGui.Hwnd
        , "UInt", 33, "Int*", 2, "UInt", 4)
    this._lastInfoTipText := ""
    this._infoTipVisible := false
  }

  _updateInfoTip(text, centerX, centerY) {
    if (!IsObject(this._infoTipGui) || !IsObject(this._infoTipTextCtrl))
      this._createInfoTip()

    infoTipGui := this._infoTipGui
    infoTipTextCtrl := this._infoTipTextCtrl
    if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd) {
      this._createInfoTip()
      infoTipGui := this._infoTipGui
      infoTipTextCtrl := this._infoTipTextCtrl
    }

    if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd)
      return

    if (this._lastInfoTipText != text) {
      try infoTipTextCtrl.Text := text
      catch {
        this._createInfoTip()
        infoTipGui := this._infoTipGui
        infoTipTextCtrl := this._infoTipTextCtrl
        if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl))
          return
        infoTipTextCtrl.Text := text
      }
      this._lastInfoTipText := text
    }
    try infoTipGui.GetPos(,, &tipW, &tipH)
    catch {
      this._createInfoTip()
      infoTipGui := this._infoTipGui
      infoTipTextCtrl := this._infoTipTextCtrl
      if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd)
        return
      tipW := 180
      tipH := 50
    }
    if (!tipW)
      tipW := 180
    if (!tipH)
      tipH := 50
    newX := Round(centerX - tipW / 2)
    newY := Round(centerY - tipH / 2)
    if (!this._infoTipVisible) {
      try infoTipGui.Show("x" newX " y" newY " NoActivate")
      catch {
        this._createInfoTip()
        infoTipGui := this._infoTipGui
        infoTipTextCtrl := this._infoTipTextCtrl
        if (!IsObject(infoTipGui) || !IsObject(infoTipTextCtrl) || !infoTipGui.Hwnd)
          return
        infoTipTextCtrl.Text := text
        infoTipGui.Show("x" newX " y" newY " NoActivate")
      }
      this._infoTipVisible := true
    } else {
      try DllCall("SetWindowPos", "Ptr", infoTipGui.Hwnd, "Ptr", 0
          , "Int", newX, "Int", newY, "Int", 0, "Int", 0
          , "UInt", WindowFlags.SWP_NOSIZE | WindowFlags.SWP_NOZORDER | WindowFlags.SWP_NOACTIVATE)
      catch {
        this._infoTipVisible := false
      }
    }
  }

  _destroyInfoTip() {
    if (IsObject(this._infoTipGui)) {
      try this._infoTipGui.Destroy()
    }
    this._infoTipGui := ""
    this._infoTipTextCtrl := ""
    this._lastInfoTipText := ""
    this._infoTipVisible := false
  }

  initEscapeHook() {
    doNothingFn := this.doNothing
    Hotkey("!Escape", doNothingFn)
    Hotkey("Escape", doNothingFn)
  }

  enableEscapeHook() {
    Hotkey("!Escape", "On")
    Hotkey("Escape", "On")
  }
  disableEscapeHook() {
    Hotkey("!Escape", "Off")
    Hotkey("Escape", "Off")
  }

  doNothing(*) {
    return
  }
}

class WindowFlags {
  ; SetWindowPos flags (SWP_*)
  static SWP_ASYNCWINDOWPOS := 0x4000 ; If the calling thread and the thread that owns the window are attached to different input queues, the system posts the request to the thread that owns the window. This prevents the calling thread from blocking its execution while other threads process the request.
  static SWP_DEFERERASE := 0x2000 ; Prevents generation of the WM_SYNCPAINT message.
  static SWP_DRAWFRAME := 0x0020 ; Draws a frame (defined in the window's class description) around the window.
  static SWP_FRAMECHANGED := 0x0020 ; Applies new frame styles set using the SetWindowLong function. Sends a WM_NCCALCSIZE message to the window, even if the window's size is not being changed. If this flag is not specified, WM_NCCALCSIZE is sent only when the window's size is being changed.
  static SWP_HIDEWINDOW := 0x0080 ; Hides the window.
  static SWP_NOACTIVATE := 0x0010 ; Does not activate the window. If this flag is not set, the window is activated and moved to the top of either the topmost or non-topmost group (depending on the setting of the hWndInsertAfter parameter).
  static SWP_NOCOPYBITS := 0x0100 ; Discards the entire contents of the client area. If this flag is not specified, the valid contents of the client area are saved and copied back into the client area after the window is sized or repositioned.
  static SWP_NOMOVE := 0x0002 ; Retains the current position (ignores X and Y parameters).
  static SWP_NOOWNERZORDER := 0x0200 ; Does not change the owner window's position in the Z order.
  static SWP_NOREDRAW := 0x0008 ; Does not redraw changes. If this flag is set, no repainting of any kind occurs. This applies to the client area, the nonclient area (including the title bar and scroll bars), and any part of the parent window uncovered as a result of the window being moved. When this flag is set, the application must explicitly invalidate or redraw any parts of the window and parent window that need redrawing.
  static SWP_NOREPOSITION := 0x0200 ; Same as the SWP_NOOWNERZORDER flag.
  static SWP_NOSENDCHANGING := 0x0400 ; Prevents the window from receiving the WM_WINDOWPOSCHANGING message.
  static SWP_NOSIZE := 0x0001 ; Retains the current size (ignores the cx and cy parameters).
  static SWP_NOZORDER := 0x0004 ; Retains the current Z order (ignores the hWndInsertAfter parameter).
  static SWP_SHOWWINDOW := 0x0040 ; Displays the window. 

  ; Window Styles (WS_*)
  static WS_SIZEBOX := 0x40000 ; Window has a sizing border

  ; Extended Window Styles (WS_EX_*)
  static WS_EX_TOOLWINDOW := 0x80
  static WS_EX_LAYERED := 0x08000000

  ; DWM Window Attributes
  static DWMWA_CLOAKED := 14
  static DWMWA_EXTENDED_FRAME_BOUNDS := 9
}
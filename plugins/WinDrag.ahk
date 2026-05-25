class WinDrag extends AKPlugin {
  _frameGui := {}
  _drawGridGUIOptions := "+Border"
  _drawGridColor := "White"
  windowState := {}

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "WinDrag",
        "title", "WinDrag",
        "description", "Enhanced window moving/resizing with snap-to-edge, axis-locking, and quick-position grid.",
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
          "label", "Enable magnetic snapping",
          "description", "Snap window edges to monitor edges during drag.",
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
          "key", "SnapOnRelease",
          "label", "Snap on release",
          "description", "When releasing window near screen edge: maximize/minimize/half-screen.",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "SnapThreshold",
          "label", "Release snap threshold (px)",
          "description", "Pixel distance from edge to trigger snap-on-release.",
          "type", "number",
          "default", 50,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "SnapMaximizeOnTop",
          "label", "Maximize on top edge",
          "description", "Maximize window when released near top screen edge.",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "SnapMinimizeOnBottom",
          "label", "Minimize on bottom edge",
          "description", "Minimize window when released near bottom screen edge.",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "SnapHalfScreen",
          "label", "Half-screen snap (L/R)",
          "description", "Snap to half-screen when released near left/right edge.",
          "type", "boolean",
          "default", true,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "SnapLeftRightTiles",
          "label", "Tile snap on full edge",
          "description", "Use full left/right monitor edge regions for half-screen snap.",
          "type", "boolean",
          "default", false,
          "section", "Snapping",
          "scope", "plugin"
        ),
        Map(
          "key", "ShowWindowContent",
          "label", "Show window content while dragging",
          "description", "When disabled, show only a frame preview instead of moving the live window.",
          "type", "boolean",
          "default", true,
          "section", "Visuals",
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
        ),
        Map(
          "key", "MinimizeInsteadOfClose",
          "label", "Minimize instead of close",
          "description", "CloseOrMinimizeHoveredWindow will minimize rather than close.",
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
          "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "SnappingDistance", "SnapOnRelease", "SnapThreshold", "SnapHalfScreen", "SnapLeftRightTiles", "ShowWindowContent", "BringToFront"]
        ),
        Map(
          "action", "EnterWindowResizingMode",
          "label", "Resize window",
          "description", "Resize a window by dragging from anywhere on it.",
          "params", [],
          "category", "Window Movement",
          "relatedConfig", ["LockAxisHotkey", "QuickPositionHotkey", "EnableSnapping", "SnappingDistance", "ShowWindowContent", "BringToFront"]
        ),
        Map(
          "action", "CloseOrMinimizeHoveredWindow",
          "label", "Close or minimize hovered window",
          "description", "Close (or minimize if configured) the window under cursor.",
          "params", [],
          "category", "Window Control",
          "relatedConfig", ["MinimizeInsteadOfClose"]
        ),
        Map(
          "action", "ToggleHoveredWindowAlwaysOnTop",
          "label", "Toggle always-on-top",
          "description", "Toggle always-on-top for the window under cursor.",
          "params", [],
          "category", "Window Control"
        )
      ],
      "hooks", []
    )
  }

  _processBlocklistConfig() {
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  EnterWindowMovingMode() { ;;;
    FrameDrawWidth := 1
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

    if (!this.Config.ShowWindowContent)
      this.drawRectFrame_Prepare()

    if (this.Config.BringToFront)
      WinActivate("ahk_id " hwnd)

    IsMaximized := WinGetMinMax("ahk_id " hwnd)
    if (IsMaximized = 1) {
      WinRestore("ahk_id " hwnd)
      WinGetPos(,, &wRestored, &hRestored, "ahk_id " hwnd)
      WinMove(xMouSrc - wRestored // 2, yMouSrc - hRestored // 2,,, "ahk_id " hwnd)
      this.saveOriginalWindowState(hwnd)
      this.windowState.max := 1
    }

    QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P")
    LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P")

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)

    xWinDst := xWinSrc
    yWinDst := yWinSrc
    wWinDst := wWinSrc
    hWinDst := hWinSrc

    EscButtonState := "U"
    toolTipId := this.ToolTip("...",,, 100)

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

      if (QuickPositionHotkey_wasUp && GetKeyState(this.Config.QuickPositionHotkey, "P")) {
        this.quickPositionWindowOnEdge(&xWinDst, &yWinDst, &wWinDst, &hWinDst)
      } else {
        MouseGetPos(&xMouLst, &yMouLst)
        xMouDif := xMouLst - xMouSrc
        yMouDif := yMouLst - yMouSrc

        if (LockAxisHotkey_wasUp && GetKeyState(this.Config.LockAxisHotkey, "P")) {
          if (Abs(xMouDif) - Abs(yMouDif) > 0)
            yMouDif := 0
          else
            xMouDif := 0
        }

        xWinDst := xWinSrc + xMouDif
        yWinDst := yWinSrc + yMouDif

        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)

        if (this.Config.EnableSnapping) {
          if (xWinDst < CurScrLeft + SnappingDistance) && (xWinDst > CurScrLeft - SnappingDistance)
            xWinDst := CurScrLeft

          if (yWinDst < CurScrTop + SnappingDistance) && (yWinDst > CurScrTop - SnappingDistance)
            yWinDst := CurScrTop

          if (xWinDst + wWinSrc > CurScrRight - SnappingDistance) && (xWinDst + wWinSrc < CurScrRight + SnappingDistance)
            xWinDst := CurScrRight - wWinSrc

          if (yWinDst + hWinSrc > CurScrBottom - SnappingDistance) && (yWinDst + hWinSrc < CurScrBottom + SnappingDistance)
            yWinDst := CurScrBottom - hWinSrc
        }
      }

      if (this.Config.ShowWindowContent)
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
      else
        this.drawRectFrame_Show(xWinDst, yWinDst, wWinDst, hWinDst, FrameDrawWidth)

      this.ToolTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst / 2, yWinDst + hWinDst / 2, 100, toolTipId)
    }

    MouseGetPos(&xRelease, &yRelease)
    snapApplied := 0
    if (EscButtonState = "U")
      snapApplied := this._snapWindowOnRelease(hwnd, xRelease, yRelease)

    if (!this.Config.ShowWindowContent) {
      this.drawRectFrame_Cancel()
      if (EscButtonState = "U" && !snapApplied)
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
    }

    this.disableEscapeHook()
    return
  }

  EnterWindowResizingMode() { ;;;
    FrameDrawWidth := 1
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

    if (this.IsWindowBlocklisted(hwnd, A_ThisFunc)) {
      SendEvent("{Blind}{" MouseButton " down}")
      KeyWait(MouseButton, "U")
      SendEvent("{Blind}{" MouseButton " up}")
      return
    }

    this.saveOriginalWindowState(hwnd)
    this.enableEscapeHook()

    if (!this.Config.ShowWindowContent)
      this.drawRectFrame_Prepare()

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

    QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P")
    LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P")
    
    ; QuickPosition_wasOn := 0
    ; locked := 0

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)
    xWinDst := xWinSrc
    yWinDst := yWinSrc
    wWinDst := wWinSrc
    hWinDst := hWinSrc

    if (Use9WindowAreasToResize) {
      xMultiplier := 0
      yMultiplier := 0
      if (xMouSrc < xWinSrc + wWinSrc / 3)
        xMultiplier := 1
      if (xMouSrc > xWinSrc + wWinSrc * 2 / 3)
        xMultiplier := -1
      if (yMouSrc < yWinSrc + hWinSrc / 3)
        yMultiplier := 1
      if (yMouSrc > yWinSrc + hWinSrc * 2 / 3)
        yMultiplier := -1
    } else {
      xMultiplier := (xMouSrc < xWinSrc + wWinSrc / 2) ? 1 : -1
      yMultiplier := (yMouSrc < yWinSrc + hWinSrc / 2) ? 1 : -1
    }

    EscButtonState := "U"
    toolTipId := this.ToolTip("...",,, 100)

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

      MouseGetPos(&xMouLst, &yMouLst)
      xMouDif := xMouLst - xMouSrc
      yMouDif := yMouLst - yMouSrc

      if (LockAxisHotkey_wasUp && GetKeyState(this.Config.LockAxisHotkey, "P")) {
        if (Abs(xMouDif) - Abs(yMouDif) > 0)
          yMouDif := 0
        else
          xMouDif := 0
      }

      ; if (LockAxisHotkey_wasUp && !GetKeyState(this.Config.LockAxisHotkey, "P") && locked != 0)
      ;   locked := 0

      GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)

      ; if (!QuickPositionHotkey_wasUp)
      ;   QuickPositionHotkey_wasUp := !GetKeyState(this.Config.QuickPositionHotkey, "P")
      ; if (!LockAxisHotkey_wasUp)
      ;   LockAxisHotkey_wasUp := !GetKeyState(this.Config.LockAxisHotkey, "P")
      if (QuickPositionHotkey_wasUp && GetKeyState(this.Config.QuickPositionHotkey, "P")) {
        ; if (!QuickPosition_wasOn) {
        ;   xMouLstQP := xMouLst
        ;   yMouLstQP := yMouLst
        ;   xWinDstQP := xWinDst
        ;   yWinDstQP := yWinDst
        ;   wWinDstQP := wWinDst
        ;   hWinDstQP := hWinDst
        ;   QuickPosition_wasOn := 1
        ; }
        this.quickPositionWindowOnEdge(&xWinDst, &yWinDst, &wWinDst, &hWinDst)
      } else if (this.Config.EnableSnapping) {
        xWinDst := (xWinSrc + (xMultiplier = 1 ? 1 : 0) * xMouDif)
        yWinDst := (yWinSrc + (yMultiplier = 1 ? 1 : 0) * yMouDif)
        wWinDst := (wWinSrc - xMultiplier * xMouDif)
        hWinDst := (hWinSrc - yMultiplier * yMouDif)

        if (xWinDst < CurScrLeft + SnappingDistance) && (xWinDst > CurScrLeft - SnappingDistance) && (xMultiplier > 0) {
          wWinDst := wWinSrc + xWinSrc - CurScrLeft
          xWinDst := CurScrLeft
        }
        if (yWinDst < CurScrTop + SnappingDistance) && (yWinDst > CurScrTop - SnappingDistance) && (yMultiplier > 0) {
          hWinDst := hWinSrc + yWinSrc - CurScrTop
          yWinDst := CurScrTop
        }
        if (xWinDst + wWinDst > CurScrRight - SnappingDistance) && (xWinDst + wWinDst < CurScrRight + SnappingDistance) && (xMultiplier < 0)
          wWinDst := -xWinSrc + CurScrRight
        if (yWinDst + hWinDst > CurScrBottom - SnappingDistance) && (yWinDst + hWinDst < CurScrBottom + SnappingDistance) && (yMultiplier < 0)
          hWinDst := -yWinSrc + CurScrBottom
      } else {
        xWinDst := (xWinSrc + (xMultiplier = 1 ? 1 : 0) * xMouDif)
        yWinDst := (yWinSrc + (yMultiplier = 1 ? 1 : 0) * yMouDif)
        wWinDst := (wWinSrc - xMultiplier * xMouDif)
        hWinDst := (hWinSrc - yMultiplier * yMouDif)
      }

      if (this.Config.ShowWindowContent)
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
      else
        this.drawRectFrame_Show(xWinDst, yWinDst, wWinDst, hWinDst, FrameDrawWidth)

      this.ToolTip(this.formatWindowGeometryInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst / 2, yWinDst + hWinDst / 2, 100, toolTipId)
    }

    if (!this.Config.ShowWindowContent) {
      this.drawRectFrame_Cancel()
      if (EscButtonState = "U")
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
    }

    this.disableEscapeHook()
    return
  }

  CloseOrMinimizeHoveredWindow() { ;;;
    CoordMode("Mouse", "Screen")
    MouseGetPos(,, &hwnd)
    if (!hwnd || this._isSystemWindow(hwnd))
      return
    if (this.IsWindowBlocklisted(hwnd, A_ThisFunc))
      return

    if (this.Config.MinimizeInsteadOfClose)
      WinMinimize("ahk_id " hwnd)
    else
      WinClose("ahk_id " hwnd)
  }

  ToggleHoveredWindowAlwaysOnTop() { ;;;
    CoordMode("Mouse", "Screen")
    MouseGetPos(,, &hwnd)
    if (!hwnd || this._isSystemWindow(hwnd))
      return
    if (this.IsWindowBlocklisted(hwnd, A_ThisFunc))
      return

    WinSetAlwaysOnTop(-1, "ahk_id " hwnd)
  }

  _snapWindowOnRelease(hwnd, curX, curY) {
    if (!this.Config.SnapOnRelease)
      return 0

    threshold := Number(this.Config.SnapThreshold)
    if (threshold < 0)
      threshold := 0

    if (!this._getMonitorWorkAreaAtPoint(curX, curY, &scrLeft, &scrRight, &scrTop, &scrBottom))
      return 0

    if (this.Config.SnapMaximizeOnTop && curY <= scrTop + threshold) {
      WinMaximize("ahk_id " hwnd)
      return 1
    }

    if (this.Config.SnapMinimizeOnBottom && curY >= scrBottom - threshold) {
      WinMinimize("ahk_id " hwnd)
      return 1
    }

    if (this.Config.SnapHalfScreen) {
      scrWidth := scrRight - scrLeft
      scrHeight := scrBottom - scrTop
      leftRightThreshold := threshold

      if (this.Config.SnapLeftRightTiles)
        leftRightThreshold := scrWidth // 2

      if (curX <= scrLeft + leftRightThreshold) {
        WinMove(scrLeft, scrTop, scrWidth // 2, scrHeight, "ahk_id " hwnd)
        return 1
      }

      if (curX >= scrRight - leftRightThreshold) {
        WinMove(scrLeft + scrWidth // 2, scrTop, scrWidth // 2, scrHeight, "ahk_id " hwnd)
        return 1
      }
    }

    return 0
  }

  _getMonitorWorkAreaAtPoint(x, y, &left, &right, &top, &bottom) {
    monCount := MonitorGetCount()
    Loop monCount {
      MonitorGetWorkArea(A_Index, &monLeft, &monTop, &monRight, &monBottom)
      if (x < monLeft || x > monRight || y < monTop || y > monBottom)
        continue

      left := monLeft
      right := monRight
      top := monTop
      bottom := monBottom
      return true
    }
    return false
  }

  _isSystemWindow(hwnd) {
    if (!hwnd)
      return true

    if (!DllCall("IsWindowVisible", "Ptr", hwnd))
      return true

    cloaked := 0
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "UInt*", &cloaked, "UInt", 4) = 0) {
      if (cloaked)
        return true
    }

    exStyle := WinGetExStyle("ahk_id " hwnd)
    if (exStyle & 0x80)
      return true
    if (exStyle & 0x08000000)
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
    if (IsMaximized && !this.windowState.max) {
      WinRestore("ahk_id " hwnd)
      WinMove(x, y, w, h, "ahk_id " hwnd)
    } else if (!IsMaximized && this.windowState.max) {
      WinMove(x, y, w, h, "ahk_id " hwnd)
      WinMaximize("ahk_id " hwnd)
    } else {
      WinMove(x, y, w, h, "ahk_id " hwnd)
    }
  }

  formatWindowGeometryInfo(x, y, w, h) {
    return "x: " . Round(x) . ", y: " . Round(y) . "`n(" . Round(w) . " x " . Round(h) . ")"
  }

  quickPositionWindowOnEdge(&xWin, &yWin, &wWin, &hWin) {
    QuickSize0 := 0
    QuickSize1 := 1/4
    QuickSize2 := 1/3
    QuickSize3 := 0.382
    QuickSize4 := 1/2

    GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
    scrWidth := CurScrRight - CurScrLeft
    scrHeight := CurScrBottom - CurScrTop
    MouseGetPos(&WinCenterX, &WinCenterY)

    WinCenterXl := WinCenterX - CurScrLeft
    WinCenterYl := WinCenterY - CurScrTop

    OffX := Floor((16 * WinCenterXl) / scrWidth)
    OffY := Floor((16 * WinCenterYl) / scrHeight)

    OffX_l := OffX + 1
    OffY_l := OffY + 1
    if (OffX >= 8)
      OffX_l := 16 - OffX
    if (OffY >= 8)
      OffY_l := 16 - OffY

    M8mOffX_l := 8 - OffX_l
    M8mOffY_l := 8 - OffY_l

    if (Abs(WinCenterXl - scrWidth / 2) < scrWidth / 16 * 0.33 && Abs(WinCenterYl - scrHeight / 2) < scrHeight / 16 * 0.33) {
      xWin := CurScrLeft + 0.33 * scrWidth
      yWin := CurScrTop + 0.33 * scrHeight
      wWin := scrWidth * 0.33
      hWin := scrHeight * 0.33
    } else if (Abs(WinCenterXl - scrWidth / 2) < scrWidth / 16 * 0.66 && Abs(WinCenterYl - scrHeight / 2) < scrHeight / 16 * 0.66) {
      xWin := CurScrLeft + 0.25 * scrWidth
      yWin := CurScrTop + 0.25 * scrHeight
      wWin := scrWidth * 0.5
      hWin := scrHeight * 0.5
    } else if (Abs(WinCenterXl - scrWidth / 2) < scrWidth / 16 * 1 && Abs(WinCenterYl - scrHeight / 2) < scrHeight / 16 * 1) {
      xWin := CurScrLeft + 0.382 * 0.382 * scrWidth
      yWin := CurScrTop + 0.382 * 0.382 * scrHeight
      wWin := scrWidth * (1 - 2 * 0.382 * 0.382)
      hWin := scrHeight * (1 - 2 * 0.382 * 0.382)
    } else {
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

  drawRectFrame_Prepare() {
    Loop 4 {
      this._frameGui[A_Index] := Gui()
      this._frameGui[A_Index].Opt("-Caption +ToolWindow +AlwaysOnTOp +OwnDialogs " this._drawGridGUIOptions)
      this._frameGui[A_Index].Color(this._drawGridColor)
    }
  }

  drawRectFrame_Show(xWin, yWin, wWin, hWin, FrameWidth) {
    this._frameGui[1].Show("x" xWin - 2 " y" yWin - 2 " w" FrameWidth + 1 " h" hWin " NoActivate")
    this._frameGui[2].Show("x" xWin - 2 " y" yWin - 2 " w" wWin " h" FrameWidth + 1 " NoActivate")
    this._frameGui[3].Show("x" xWin + wWin - 2 " y" yWin - 2 " w" FrameWidth + 1 " h" hWin " NoActivate")
    this._frameGui[4].Show("x" xWin - 2 " y" yWin + hWin - 2 " w" wWin " h" FrameWidth + 1 " NoActivate")
  }

  drawRectFrame_Cancel() {
    Loop 4
      this._frameGui[A_Index].Cancel()
  }

  initEscapeHook() {
    doNothingFn := this.doNothing.bind(this)
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

  doNothing() {
    return
  }
}

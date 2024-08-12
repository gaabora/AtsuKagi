class KDEMoverSizer extends AKPlugin {
  _frameGui := {}
  _drawGridGUIOptions := "+Border"
  _drawGridColor := "White"
  ProcessConfig() {
    if (!this.Config.Has("BlacklistedWindowSelectors"))
      this.Config.BlacklistedWindowSelectors := "MultitaskingViewFrame,ForegroundStaging,TaskSwitcherWnd,TaskSwitcherOverlayWnd,XamlExplorerHostIslandWindow"
  }

  __UsageHelp() {
    return "based on KDE Mover-Sizer v2.9 2014-09-10 http://corz.org/windows/software/accessories/KDE-resizing-moving-for-Windows.php"
  }

  __ActionsHelp() {
    texts := Map()
    texts["EnterWindowMovingMode"]   := "EnterWindowMovingMode(LockAxisHotkey:=Shift, QuickPositionHotkey:=LWin, EnableSnapping:=1, ShowWindowContent:=1, BringToFront:=0)"
    texts["EnterWindowResizingMode"] := "EnterWindowResizingMode(LockAxisHotkey:=Shift, QuickPositionHotkey:=LWin, EnableSnapping:=1, ShowWindowContent:=1, BringToFront:=0)"
    return texts
  }
  
  EnterWindowMovingMode(LockAxisHotkey:="Shift", QuickPositionHotkey:="LWin", EnableSnapping:=1, ShowWindowContent:=1, BringToFront:=0) { ;;;
    FrameDrawWidth := 1
    SnappingDistance := 10

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    this.initEscapeHook()
    this.disableEscapeHook()

    MouseGetPos(&xMouSrc, &yMouSrc, &hwnd)
    hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
    MouseButton := hotkeyInfo.key

    if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
      SendEvent("{Blind}{" MouseButton " down}")
      KeyWait(MouseButton, "U")
      SendEvent("{Blind}{" MouseButton " up}")
      return
    }



    this.saveOriginalWindowState(hwnd)
    this.enableEscapeHook()
    
    if (NOT ShowWindowContent)
      this.drawRectFrame_Prepare()

    

    if (BringToFront)
      WinActivate("ahk_id " hwnd)
    
    IsMaximized := WinGetMinMax("ahk_id " hwnd)

    if (IsMaximized) {
      WinRestore("ahk_id " hwnd)
      this.saveOriginalWindowState(hwnd)
      this.windowState.max := 1
    }

    QuickPositionHotkey_wasUp := NOT GetKeyState(QuickPositionHotkey, "P") ; check that button was released once before window is QuickPositioned
    LockAxisHotkey_wasUp := NOT GetKeyState(LockAxisHotkey, "P") ; check that button was released once before movement is locked

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)

    wWinDst := wWinSrc
    hWinDst := hWinSrc

    toolTipId := this.ToolTip("...",,, 100)

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

      if (NOT QuickPositionHotkey_wasUp)
        QuickPositionHotkey_wasUp := NOT GetKeyState(QuickPositionHotkey, "P")
      if (NOT LockAxisHotkey_wasUp)
        LockAxisHotkey_wasUp := NOT GetKeyState(LockAxisHotkey, "P")
      
      if (QuickPositionHotkey_wasUp AND GetKeyState(QuickPositionHotkey , "P")) {
        this.quickPositionWindowOnEdge(xWinDst, yWinDst, wWinDst, hWinDst)
      } else {

        MouseGetPos(&xMouLst, &yMouLst)
        xMouDif := xMouLst - xMouSrc
        yMouDif := yMouLst - yMouSrc
        
        if (LockAxisHotkey_wasUp AND GetKeyState(LockAxisHotkey , "P")) {
          if (abs(xMouDif) - abs(yMouDif) > 0)
            yMouDif := 0 ; lock Y
          else
            xMouDif := 0 ; lock X
        }

        ; Apply this offset to the window position.
        xWinDst := (xWinSrc + xMouDif) 
        yWinDst := (yWinSrc + yMouDif)

        ; allow snapping on all monitors without releasing button
        GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)

        if (EnableSnapping) {
          if (xWinDst < CurScrLeft + SnappingDistance) AND (xWinDst > CurScrLeft - SnappingDistance)
            xWinDst := CurScrLeft 

          if (yWinDst < CurScrTop + SnappingDistance) AND (yWinDst > CurScrTop - SnappingDistance)
            yWinDst := CurScrTop

          if (xWinDst + wWinSrc > CurScrRight - SnappingDistance) AND (xWinDst + wWinSrc < CurScrRight + SnappingDistance)
            xWinDst := CurScrRight - wWinSrc

          if (yWinDst + hWinSrc > CurScrBottom - SnappingDistance) AND (yWinDst + hWinSrc < CurScrBottom + SnappingDistance)
            yWinDst := CurScrBottom - hWinSrc
        }
      }

      if (ShowWindowContent)
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
      else
        this.drawRectFrame_Show(xWinDst, yWinDst, wWinDst, hWinDst, FrameDrawWidth)

      this.ToolTip(this.formatWindowGeomertyInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst/2, yWinDst + hWinDst/2, 100, toolTipId)
    }

    if (NOT ShowWindowContent) {
      this.drawRectFrame_Cancel()
      if (EscButtonState = "U")
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)  ; Move the window to the new position.
    }

    this.disableEscapeHook()
    return
  }

  EnterWindowResizingMode(LockAxisHotkey:="Shift", QuickPositionHotkey:="LWin", EnableSnapping:=1, ShowWindowContent:=1, BringToFront:=0) { ;;;
    FrameDrawWidth := 1
    SnappingDistance := 10
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

    if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
      SendEvent("{Blind}{" MouseButton " down}")
      KeyWait(MouseButton, "U")
      SendEvent("{Blind}{" MouseButton " up}")
      return
    }




    this.saveOriginalWindowState(hwnd)
    this.enableEscapeHook()

    if (NOT ShowWindowContent)
      this.drawRectFrame_Prepare()

    if (BringToFront)
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

    QuickPositionHotkey_wasUp := NOT GetKeyState(QuickPositionHotkey, "P") ; check that button was released once before window is QuickPositioned
    LockAxisHotkey_wasUp := NOT GetKeyState(LockAxisHotkey, "P") ; check that button was released once before movement is locked

    QuickPosition_wasOn    := 0
    locked := 0

    WinGetPos(&xWinSrc, &yWinSrc, &wWinSrc, &hWinSrc, "ahk_id " hwnd)
    xWinDst := xWinSrc
    yWinDst := yWinSrc
    wWinDst := wWinSrc
    hWinDst := hWinSrc

    if (Use9WindowAreasToResize) {
      ; WinLeft = [-1;0;1], WinUp = [-1;0;1]
      xMultiplier := 0
      yMultiplier   := 0
      If (xMouSrc < xWinSrc + wWinSrc / 3)
        xMultiplier := 1
      If (xMouSrc > xWinSrc + wWinSrc *2/3)
        xMultiplier := -1
      If (yMouSrc < yWinSrc + hWinSrc / 3)
        yMultiplier := 1
      If (yMouSrc > yWinSrc + hWinSrc *2/3)
        yMultiplier := -1
    } else {
      ; WinLeft = [-1;1], WinUp = [-1;1]
      xMultiplier := (xMouSrc < xWinSrc + wWinSrc / 2) ? 1 : -1
      yMultiplier := (yMouSrc < yWinSrc + hWinSrc / 2) ? 1 : -1
    }

    toolTipId := this.ToolTip("...",,, 100)

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

      if (NOT QuickPositionHotkey_wasUp)
        QuickPositionHotkey_wasUp := NOT GetKeyState(QuickPositionHotkey, "P")
      if (NOT LockAxisHotkey_wasUp)
        LockAxisHotkey_wasUp := NOT GetKeyState(LockAxisHotkey, "P")

      MouseGetPos(&xMouLst, &yMouLst)
      xMouDif := xMouLst - xMouSrc
      yMouDif := yMouLst - yMouSrc

      if (LockAxisHotkey_wasUp AND GetKeyState(LockAxisHotkey , "P")) {
        ; locking for default Resizing
        if (abs(xMouDif) - abs(yMouDif) > 0)
          yMouDif := 0 ; lock Y
        else
          xMouDif := 0 ; lock X
      }
      
      if (LockAxisHotkey_wasUp AND NOT GetKeyState(LockAxisHotkey , "P") AND locked != 0) {
        locked := 0
      }

      ; snap the window to the edge of the screen if closer than 10 pixels to border
      ; first, get current screen borders for snapping, do this within the loop to allow snapping on all monitors without releasing button

      ; allow snapping on all monitors without releasing button
      GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)

      if (NOT QuickPositionHotkey_wasUp)
        QuickPositionHotkey_wasUp := NOT GetKeyState(QuickPositionHotkey, "P")
      if (NOT LockAxisHotkey_wasUp)
        LockAxisHotkey_wasUp := NOT GetKeyState(LockAxisHotkey, "P")

      if (QuickPositionHotkey_wasUp AND GetKeyState(QuickPositionHotkey, "P")) {
        ; save mouse and window position to allow clean switch between magnetic resizing and QuickPositioning
        if (NOT QuickPosition_wasOn) {
          xMouLstQP := xMouLst
          yMouLstQP := yMouLst
          xWinDstQP := xWinDst
          yWinDstQP := yWinDst
          wWinDstQP := wWinDst
          hWinDstQP := hWinDst
          QuickPosition_wasOn := 1
        }
        this.quickPositionWindowOnEdge(xWinDst, yWinDst, wWinDst, hWinDst)
      } else if (EnableSnapping) {
        ; "normal" resizing
        xWinDst := (xWinSrc + (xMultiplier =1 ? 1 : 0) * xMouDif)
        yWinDst := (yWinSrc + (yMultiplier =1 ? 1 : 0) * yMouDif)
        wWinDst := (wWinSrc - xMultiplier * xMouDif)
        hWinDst := (hWinSrc - yMultiplier * yMouDif)

        if (xWinDst < CurScrLeft + SnappingDistance) AND (xWinDst > CurScrLeft - SnappingDistance) AND (xMultiplier > 0) {
          wWinDst := wWinSrc + xWinSrc - CurScrLeft
          xWinDst := CurScrLeft
        }
        if (yWinDst < CurScrTop + SnappingDistance) AND (yWinDst > CurScrTop - SnappingDistance) AND (yMultiplier > 0) {
          hWinDst := hWinSrc + yWinSrc - CurScrTop
          yWinDst := CurScrTop
        }
        if (xWinDst + wWinDst > CurScrRight - SnappingDistance) AND (xWinDst + wWinDst < CurScrRight + SnappingDistance)  AND (xMultiplier < 0) {
          wWinDst := - xWinSrc + CurScrRight
        }
        if (yWinDst + hWinDst > CurScrBottom - SnappingDistance) AND (yWinDst + hWinDst < CurScrBottom + SnappingDistance) AND (yMultiplier < 0) {
          hWinDst := - yWinSrc + CurScrBottom
        }
      } else {
        ; no snapping, just resizing
        xWinDst := (xWinSrc + (xMultiplier = 1 ? 1 : 0) * xMouDif)
        yWinDst := (yWinSrc + (yMultiplier = 1 ? 1 : 0) * yMouDif)
        wWinDst := (wWinSrc - xMultiplier * xMouDif)
        hWinDst := (hWinSrc - yMultiplier * yMouDif)
      }

      if (ShowWindowContent)
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
      else
        this.drawRectFrame_Show(xWinDst, yWinDst, wWinDst, hWinDst, FrameDrawWidth)

      this.ToolTip(this.formatWindowGeomertyInfo(xWinDst, yWinDst, wWinDst, hWinDst), xWinDst + wWinDst/2, yWinDst + hWinDst/2, 100, toolTipId)
      ; Sleep, 1
    }

    if (NOT ShowWindowContent) {
      this.drawRectFrame_Cancel()
      if (EscButtonState = "U")
        WinMove(xWinDst, yWinDst, wWinDst, hWinDst, "ahk_id " hwnd)
    }

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

  formatWindowGeomertyInfo(x, y, w, h) {
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

    GetCurrentScreenBorders(&CurScrLeft, &CurScrRight, &CurScrTop, &CurScrBottom)
    GetCurrentScreenBorders(CurScrLeft, CurScrRight, CurScrTop, CurScrBottom)
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
    
    if (abs(WinCenterXl - scrWidth / 2) < scrWidth /16*0.33 && abs(WinCenterYl - scrHeight / 2) < scrHeight / 16*0.33) { ; inner center
      xWin := CurScrLeft + 0.33 * scrWidth
      yWin := CurScrTop  + 0.33 * scrHeight
      wWin := scrWidth  * 0.33
      hWin := scrHeight * 0.33
    } else if (abs(WinCenterXl - scrWidth / 2) < scrWidth /16*0.66 && abs(WinCenterYl - scrHeight / 2) < scrHeight / 16*0.66) { ; middle center
      xWin := CurScrLeft + 0.25 * scrWidth
      yWin := CurScrTop  + 0.25 * scrHeight
      wWin := scrWidth  * 0.5
      hWin := scrHeight * 0.5
    } else if (abs(WinCenterXl - scrWidth / 2) < scrWidth / 16*1 && abs(WinCenterYl - scrHeight / 2) < scrHeight / 16*1) { ; outer center
      xWin := CurScrLeft + 0.382*0.382 * scrWidth
      yWin := CurScrTop  + 0.382*0.382 * scrHeight
      wWin := scrWidth  * (1 - 2*0.382*0.382)
      hWin := scrHeight * (1 - 2*0.382*0.382)
    } else { ; one of the outer squares
      if (OffX_l <= 4)
        wWin := scrWidth * QuickSize%OffX_l%
      else
        wWin := scrWidth * (1 - QuickSize%M8mOffX_l%)
          
      if (OffX < 8)
        xWin := CurScrLeft
      else
        xWin := CurScrLeft +  scrWidth - wWin

      if (OffY_l <= 4)
        hWin := scrHeight * QuickSize%OffY_l%
      else
        hWin := scrHeight * (1 - QuickSize%M8mOffY_l%)
          
      if (OffY < 8)
        yWin := CurScrTop
      else
        yWin := CurScrTop +  scrHeight - hWin
    }
  }

  drawRectFrame_Prepare() {
    global
    Loop 4 {
        this._frameGui[A_Index] := Gui()
        this._frameGui[A_Index].Opt("-Caption +ToolWindow +AlwaysOnTOp +OwnDialogs " this._drawGridGUIOptions)
        this._frameGui[A_Index].Color(this._drawGridColor)
    }
  }

  drawRectFrame_Show(KDE_WinX2, yWinDst, KDE_WinW2, KDE_WinH2, FrameWidth) {
    this._frameGui[1] := Gui()
    this._frameGui[1].Show("x" KDE_WinX2 - 2 " y" yWinDst - 2 " w" FrameWidth + 1 " h" KDE_WinH2 " NoActivate")
    this._frameGui[2] := Gui()
    this._frameGui[2].Show("x" KDE_WinX2 - 2 " y" yWinDst - 2 " w" KDE_WinW2 " h" FrameWidth + 1 " NoActivate")
    this._frameGui[3] := Gui()
    this._frameGui[3].Show("x" KDE_WinX2 + KDE_WinW2 - 2 " y" yWinDst - 2 " w" FrameWidth + 1 " h" KDE_WinH2 " NoActivate")
    this._frameGui[4] := Gui()
    this._frameGui[4].Show("x" KDE_WinX2 - 2 " y" yWinDst + KDE_WinH2 - 2 " w" KDE_WinW2 " h" FrameWidth + 1 " NoActivate")
  }

  drawRectFrame_Cancel() {
    Loop 4
      this._frameGui[A_Index].Cancel()
    ;DllCall("RedrawWindow", "Uint", curwin_id , "Uint", 0, "Uint", 0, "Uint", 0x81)    ; Workaround for WinSet, Redraw,, ahk_id %curwin_id% (didn't work for Gimp)
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
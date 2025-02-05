class RDPWindowHandler extends AKPlugin {
  __New() {
    
  }
  __UsageHelp() {
    return "based on RDP-Key v1.0 by Ken Wang https://github.com/gildorwang/RDP-Key/tree/master"
  }

  __ActionsHelp() {
    texts := Map()
    texts["IsRDPClientWindowActive"]          := "IsRDPClientWindowActive()"
    texts["MinimizeRestoreRDPClientWindows"]  := "MinimizeRestoreRDPClientWindows()"
    texts["RestoreFullscreenRDPClientWindow"] := "RestoreFullscreenRDPClientWindow()"
    texts["LoopRDPClientWindows"]             := "LoopRDPClientWindows()"
    texts["SwitchToNextRDPClientWindow"]      := "SwitchToNextRDPClientWindow()"
    return texts
  }


  
; RDPActive() {
;   static isActive;
;   if WinActive("ahk_class TscShellContainerClass") {
;       if(!Active) {
;           Active := true
;           SoundBeep 1500
;           Suspend off

;       }
;   } else {
;       if(Active) {
;           Active := false
;           SoundBeep 1000
;           Suspend on
;       }
;   }
; }

;   Pressed() {
;     SoundBeep 2000
;     Send {LCtrl down}{LAlt down}{Home}{LAlt up}{LCtrl up}
;     Sleep 500
;     ;Send {LCtrl down}{LWin down}{Left}{LWin up}{LCtrl up}
;     Return
;   }



  IsRDPClientWindowActive() { ;;;
    return (WinActive("ahk_class TscShellContainerClass"))
  }

  MinimizeRestoreRDPClientWindows() { ;;;
    ; TODO TEST!!!!
    RDCMWindowTitle := ""
    if(this.IsRDPClientWindowActive()) {
      ; Store the title of the topmost one
      RDCMWindowTitle := WinGetTitle("A")
      Loop{
          ; Need a short sleep here for focus to restore properly.
          Sleep(50)
          WinMinimize()
          this.getCenterPos(&centerX, &centerY)
          this.getWinAtPos(centerX, centerY, &title)
          WinActivate(title)
          ; Continue to minimize other RDP windows
      } Until (!this.IsRDPClientWindowActive())
      this.ShowInfo(RDCMWindowTitle, "Minimized")
    } else if (RDCMWindowTitle != "") {
        SetTitleMatchMode(3)
        WinActivate(RDCMWindowTitle)
        this.ShowInfo(RDCMWindowTitle, "Restored")
    }
  }

  RestoreFullscreenRDPClientWindow() { ;;;
        ; TODO TEST!!!!
    if(this.IsRDPClientWindowActive()) {
        Send("^!{CtrlBreak}")
    }
  }

  LoopRDPClientWindows() { ;;; TODO test, style
    if (OldTime = "") {
      OldTime := A_TickCount
      ;next: whether the next window should be activated; otherwise the first one
      next := false
    } else {
      next := (A_TickCount - OldTime) < 800
      OldTime := A_TickCount
    }
    if (next && OldIndex != "") {
      OldIndex := Mod(OldIndex, Wins) + 1
      ahkId := Wins%OldIndex%
      WinActivate("ahk_id " ahkId)
      winN_title := WinGetTitle("ahk_id " ahkId)
    } else {
      ; Go the normal way
      OldIndex := this.SwitchToNextRDPClientWindow()
    }
  }

  SwitchToNextRDPClientWindow() { ;;; TODO test, style
    local wins2_title, wins1_title
    oWins := WinGetList("ahk_class TscShellContainerClass",,,)
    aWins := Array()
    Wins := oWins.Length
    For v in oWins
    {   aWins.Push(v)
    }
    if (aWins.Length > 1) {
      WinActivate("ahk_id " aWins[2])
      wins2_title := WinGetTitle("ahk_id " aWins[2])
      return 2
    }
    else if (aWins.Length = 1) {
      WinActivate("ahk_id " aWins[1])
      wins1_title := WinGetTitle("ahk_id " aWins[1])
      return 1
    }
    else {
      this.ShowInfo("No more RDP windows", "RDP Key")
      return 0
    }
  }

  getCenterPos(&xScr:=0, &yScr:=0) {
    MonitorPrimary := MonitorGetPrimary()
    MonitorGetWorkArea(MonitorPrimary, &AreaLeft, &AreaTop, &AreaRight, &AreaBottom)
    xScr := (AreaRight - AreaLeft) / 2
    yScr := (AreaBottom - AreaTop) / 2
  }

  getWinAtPos(px, py, &title:="", &className:="", &xWin:=0, &yWin:=0, &wWin:=0, &hWin:=0) {
; REMOVED:     #NoEnv
    POINT := Buffer(8, 0) ; V1toV2: if 'POINT' is a UTF-16 string, use 'VarSetStrCapacity(&POINT, 8)'
    NumPut("int", px, POINT, 0), NumPut("int", py, POINT, 4)
    HWND := DllCall("WindowFromPoint", "Int64", NumGet(POINT, 0, "Int64"))
    HWND := DllCall("GetAncestor", "UInt", HWND, "UInt", GA_ROOT := 2)
    WinExist("ahk_id" . HWND)
    title := WinGetTitle()
    className := WinGetClass()
    WinGetPos(&xWin, &yWin, &wWin, &hWin)
  }
}
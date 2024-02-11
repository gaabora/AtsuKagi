class RDPWindowHandler extends AKPlugin {
  __New() {
    
  }
  __UsageHelp() {
    return "based on RDP-Key v1.0 by Ken Wang https://github.com/gildorwang/RDP-Key/tree/master"
  }

  __ActionsHelp() {
    texts := []
    texts["IsRDPClientWindowActive"] :=           "IsRDPClientWindowActive()"
    texts["MinimizeRestoreRDPClientWindows"] :=   "MinimizeRestoreRDPClientWindows()"
    texts["RestoreFullscreenRDPClientWindow"] :=  "RestoreFullscreenRDPClientWindow()"
    texts["LoopRDPClientWindows"] :=              "LoopRDPClientWindows()"
    texts["SwitchToNextRDPClientWindow"] :=       "SwitchToNextRDPClientWindow()"
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

    if(this.IsRDPClientWindowActive()) {
      ; Store the title of the topmost one
      WinGetActiveTitle, RDCMWindowTitle
      Loop {
          ; Need a short sleep here for focus to restore properly.
          Sleep 50
          WinMinimize
          this.getCenterPos(centerX, centerY)
          this.getWinAtPos(centerX, centerY, title)
          WinActivate % title
          ; Continue to minimize other RDP windows
      } Until (!this.IsRDPClientWindowActive())
      this.ShowInfo(RDCMWindowTitle, "Minimized")
    } else if (RDCMWindowTitle != "") {
        SetTitleMatchMode 3
        WinActivate %RDCMWindowTitle%
        this.ShowInfo(RDCMWindowTitle, "Restored")
    }
  }

  RestoreFullscreenRDPClientWindow() { ;;;
    if(this.IsRDPClientWindowActive()) {
        Send ^!{CtrlBreak}
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
    if (next && OldIndex <> "") {
      OldIndex := Mod(OldIndex, Wins) + 1
      ahkId := Wins%OldIndex%
      WinActivate ahk_id %ahkId%
      WinGetTitle, winN_title, ahk_id %ahkId%
    } else {
      ; Go the normal way
      OldIndex := this.SwitchToNextRDPClientWindow()
    }
  }

  SwitchToNextRDPClientWindow() { ;;; TODO test, style
    local wins2_title, wins1_title
    WinGet, Wins, List, ahk_class TscShellContainerClass
    if (Wins > 1) {
      WinActivate ahk_id %Wins2%
      WinGetTitle, wins2_title, ahk_id %Wins2%
      return 2
    }
    else if (Wins = 1) {
      WinActivate ahk_id %Wins1%
      WinGetTitle, wins1_title, ahk_id %Wins1%
      return 1
    }
    else {
      this.ShowInfo("No more RDP windows", "RDP Key")
      return 0
    }
  }

  getCenterPos(ByRef xScr:=0, ByRef yScr:=0) {
    SysGet, MonitorPrimary, MonitorPrimary
    SysGet, Area, MonitorWorkArea, MonitorPrimary
    xScr := (AreaRight - AreaLeft) / 2
    yScr := (AreaBottom - AreaTop) / 2
  }

  getWinAtPos(px, py, ByRef title:="", ByRef className:="", ByRef xWin:=0, ByRef yWin:=0, ByRef wWin:=0, ByRef hWin:=0) {
    #NoEnv
    VarSetCapacity(POINT, 8, 0)
    NumPut(px, POINT, 0, "int"), NumPut(py, POINT, 4, "int")
    HWND := DllCall("WindowFromPoint", "Int64", NumGet(POINT, 0, "Int64"))
    HWND := DllCall("GetAncestor", "UInt", HWND, "UInt", GA_ROOT := 2)
    WinExist("ahk_id" . HWND)
    WinGetTitle, title
    WinGetClass, className
    WinGetPos, xWin, yWin, wWin, hWin
  }
}
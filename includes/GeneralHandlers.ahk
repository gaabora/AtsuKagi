class GeneralHandlers extends AKPlugin {

  __ActionsHelp() {
    texts := Map()
    texts["IfThenElse"] := "IfThenElse(IfActionString, ThenActionString, ElseActionString)"
    texts["RemapTo"]    := "RemapTo(Hotkey)"
    texts["DoNothing"]  := "DoNothing()"
    texts["ShowInfo"]   := "ShowInfo(text, title:='', timeout:=2000)"
    return texts
  }
  
  RemapTo(Hotkey) { ;;;
    if (Hotkey = "")
      return

    InputString := RegExMatch(Hotkey, '^\s*\{') ? Hotkey : "{" Hotkey "}"
    SendInput(InputString)
  }

  DoNothing() { ;;;
    return
  }

  IfThenElse(IfActionString, ThenActionString, ElseActionString) { ;;;
    conditionResult := this.RunAction(IfActionString)
    this.outputDebugLine('IfThenElse(' IfActionString ' = ' conditionResult ', ' ThenActionString ', ' ElseActionString ')')
    if (conditionResult) {
      this.RunAction(ThenActionString)
    } else {
      this.RunAction(ElseActionString)
    }
    return
  }

  ShowInfo(text, title:="", timeout:=2000) {
    this.App.ShowInfo(text, title:="", timeout:=2000)
  }

  Run(cmdLine) { ;;;
    ; TODO
  }

  ; SetTimer, CheckIdle, 5000
  ; CheckIdle:
  ; ControlSend, , {Escape},  ahk_class TRegCheckDlg ; fuck rad studio license manager popups
  ; if (A_TimeIdlePhysical > 10000) {
  ;   If ((A_Hour>8) && (A_Hour<17)) {
  ;     Send {Shift}
  ;   }
  ;   ; WriteLog(" and ")
  ; }
}
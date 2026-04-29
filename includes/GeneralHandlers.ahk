class GeneralHandlers extends AKPlugin {

  __ConfigHelp() {
    return "No config keys. Built-in general-purpose actions available in all plugins."
  }

  __UsageHelp() {
    return "Core action utilities: conditional execution, blocklist checking, key remapping, info popups. Used as building blocks for other plugin actions."
  }

  __ActionsHelp() {
    texts := Map()
    texts["IfThenElse"] := "IfThenElse(IfActionString, ThenActionString, ElseActionString)"
    texts["SkipIfBlocklisted"] := "SkipIfBlocklisted(BlocklistName, ActionString, FallbackAction:='') - skip action if window is in named blocklist, optionally run fallback instead of passthrough"
    texts["RemapKeyTo"] := "RemapKeyTo(Hotkey)"
    texts["DoNothing"]  := "DoNothing()"
    texts["ShowInfo"]   := "ShowInfo(text, title:='', timeout:=2000)"
    return texts
  }
  
  RemapKeyTo(Hotkey) { ;;;
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

  ; Skip the action if the hovered window matches a named blocklist.
  ; If blocklisted: runs fallbackAction if provided, otherwise passes through the original key.
  ; Usage in config: SkipIfBlocklisted(NoRightClickGesture, EnterGestureMode(1, 4))
  ;                  SkipIfBlocklisted(NoCtrlCHotkey, SwitchSelectedTextCase(), DoNothing())
  SkipIfBlocklisted(blocklistName, actionString, fallbackAction:="") { ;;;
    MouseGetPos(,, &hwnd)
    if (this.App.IsInBlocklist(blocklistName, hwnd)) {
      this.outputDebugLine('SkipIfBlocklisted(' blocklistName '): BLOCKED for hwnd=' hwnd)
      if (fallbackAction != "") {
        this.RunAction(fallbackAction)
      } else {
        ; Pass through the original key
        try {
          hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
          SendInput("{Blind}{" hotkeyInfo.key "}")
        }
      }
      return
    }
    this.outputDebugLine('SkipIfBlocklisted(' blocklistName '): ALLOWED, running ' actionString)
    this.RunAction(actionString)
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
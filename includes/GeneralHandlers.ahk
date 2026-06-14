class GeneralHandlers extends AKPlugin {
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "GeneralHandlers",
        "title", "General Handlers",
        "description", "Core action utilities: conditional execution, blocklist checks, key remapping, and helper actions",
        "category", "Core"
      ),
      "config", [],
      "actions", [
        Map("action", "IfThenElse", "label", "If then else", "description", "Run ThenActionString when IfActionString is truthy; otherwise run ElseActionString", "params", [Map("name", "IfActionString"), Map("name", "ThenActionString"), Map("name", "ElseActionString")], "category", "Control Flow"),
        Map("action", "SkipIfBlocklisted", "label", "Skip if blocklisted", "description", "Skip action when hovered window matches named blocklist; optionally run fallback", "params", [Map("name", "blocklistName"), Map("name", "actionString"), Map("name", "fallbackAction", "default", "")], "category", "Control Flow"),
        Map("action", "RemapKeyTo", "label", "Remap key to", "description", "Send the provided key as input", "params", [Map("name", "Hotkey")], "category", "Input"),
        Map("action", "DoNothing", "label", "Do nothing", "description", "No-op action", "params", [], "category", "Utility"),
        Map("action", "ShowInfo", "label", "Show notification", "description", "Show a styled info, success, warning, or error notification", "params", [Map("name", "text"), Map("name", "title", "default", ""), Map("name", "timeout", "default", 2000), Map("name", "style", "default", "info")], "category", "Utility"),
        Map("action", "Run", "label", "Run command", "description", "Run a command line", "params", [Map("name", "cmdLine")], "category", "Utility")
      ]
    )
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
    this.outputDebugLine(AKApp.LOG_DEBUG, 'IfThenElse(' IfActionString ' = ' conditionResult ', ' ThenActionString ', ' ElseActionString ')')
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
      this.outputDebugLine(AKApp.LOG_DEBUG, 'SkipIfBlocklisted(' blocklistName '): BLOCKED for hwnd=' hwnd)
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
    this.outputDebugLine(AKApp.LOG_DEBUG, 'SkipIfBlocklisted(' blocklistName '): ALLOWED, running ' actionString)
    this.RunAction(actionString)
  }

  ShowInfo(text, title:="", timeout:=2000, style:="info") {
    this.App.ShowInfo(text, title, timeout, style)
  }

  Run(cmdLine) { ;;;
    this.outputDebugLine(AKApp.LOG_DEBUG, 'Run(' cmdLine ')')
    Run(cmdLine)
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

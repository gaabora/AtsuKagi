class GeneralHandlers extends AKPlugin {

  __ActionsHelp() {
    texts := Map()
    texts["IfThenElse"] := "IfThenElse(IfActionString, ThenActionString, ElseActionString)"
    texts["RemapTo"]    := "RemapTo(Hotkey)"
    texts["DoNothing"]  := "DoNothing()"
    return texts
  }
  
  RemapTo(Hotkey) { ;;;
      if (Hotkey = "")
        return

      SendInput(RegExMatch(Hotkey, '^\s*\{') ? Hotkey : "{" Hotkey "}")
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
}
#Requires AutoHotkey v2.0
#SingleInstance Force

class ManagedCapsLockPrototype {
  static WM_APP_ARM_DROPPED_UP := 0x8001
  static WM_APP_DISABLE := 0x8002
  static WM_APP_ENABLE := 0x8003
  static WM_APP_RESTART_BACKEND := 0x8004

  __New(smokeMode, logPath) {
    this.smokeMode := smokeMode
    this.logPath := logPath
    this.enabled := true
    this.cleanedUp := false
    this.restartPending := false
    this.sessionActive := false
    this.sessionMode := ""
    this.isActionLocked := false
    this.tapCancelled := false
    this.legacyBlocked := false
    this.directionGestureArmed := true
    this.heldDirectionMask := 0
    this.currentValidDirectionMask := 0
    this.pendingDirectionMask := 0
    this.inputObserver := 0
    this.inputObserverDownCallback := 0
    this.inputObserverUpCallback := 0
    this.hotkeyRegistrations := []
    this.messageRegistrations := []
    this.releaseGuards := Map()
    this.heldKeys := Map()
    this.repairCandidates := Map()
    this.droppedUpKeys := Map()
    this.ignoredPreheldSuffixes := Map()
    this.preheldLegacyKeys := Map()
    this.observedUnmanagedKeys := Map()
    this.pendingLogText := ""
    this.directionBits := Map("W", 1, "D", 2, "S", 4, "A", 8)
    this.validDirectionMasks := Map(1, "n", 2, "e", 4, "s", 8, "w", 3, "ne", 6, "se", 12, "sw", 9, "nw")
    this.keyKinds := Map("CapsLock", "caps", "W", "direction", "A", "direction", "S", "direction", "D", "direction", "Space", "space", "LAlt", "legacy-alt", "RAlt", "legacy-alt", "LCtrl", "legacy-ctrl", "RCtrl", "legacy-ctrl")
    this.keyByVirtualKey := Map(0x14, "CapsLock", 0x57, "W", 0x41, "A", 0x53, "S", 0x44, "D", 0x20, "Space", 0xA4, "LAlt", 0xA5, "RAlt", 0xA2, "LCtrl", 0xA3, "RCtrl")
    this.managedVirtualKeys := Map(0x14, true, 0x57, true, 0x41, true, 0x53, true, 0x44, true, 0x20, true, 0x10, true, 0x11, true, 0x12, true, 0x5B, true, 0x5C, true, 0xA0, true, 0xA1, true, 0xA2, true, 0xA3, true, 0xA4, true, 0xA5, true)
    this.stableTimerCallback := this._CommitStableDirection.Bind(this)
    this.repairTimerCallback := this._RepairPhysicalState.Bind(this)
    this.exitCallback := this._OnExit.Bind(this)
    this.logFlushCallback := this._FlushLogQueue.Bind(this)
    this.exitRequestedCallback := this._ExitRequested.Bind(this)
    this.manualDropUpCallback := this._ArmManualDroppedUp.Bind(this)
    this.manualDisableCallback := this._DisableManual.Bind(this)
    this.manualEnableCallback := this._EnableManual.Bind(this)
    this.manualRestartCallback := this._RestartManual.Bind(this)
    this.processId := DllCall("GetCurrentProcessId", "UInt")
    this._CreateStatusGui()
    this._RegisterMessages()
    this._RegisterHotkeys()
    SetTimer(this.repairTimerCallback, 25)
    OnExit(this.exitCallback)
    SetTimer(this.logFlushCallback, 250)
    this._Log("READY", "dynamic-callbacks")
  }

  _CreateStatusGui() {
    instructionLines := [
      "Manual physical-key check. Keep a normal text editor focused. Log updates do not activate this window.",
      "1. Tap CapsLock: expect one ACTION|tap.",
      "2. Hold W before CapsLock: W stays normal input and no workspace action appears.",
      "3. Hold CapsLock, then W for more than 100 ms: expect one ACTION|workspace:n. Keep W held: no second action.",
      "4. Keep CapsLock held, release W, then hold D for more than 100 ms: expect one ACTION|workspace:e.",
      "5. Hold CapsLock, press W, then add S before 100 ms: no action while invalid. Release S: expect one workspace:n.",
      "6. CapsLock+Q: Q reaches the editor and no ACTION|tap appears.",
      "7. CapsLock+Space: expect one ACTION|overview. Later Caps actions stay blocked until CapsLock is released.",
      "8. Test Alt then CapsLock, CapsLock then Alt, Ctrl then CapsLock, and CapsLock then Ctrl. Each legacy action appears once and locks the hold.",
      "9. Click Arm missed W-up, then press and release CapsLock+W quickly. Expect DROP_UP|W, then REPAIR|W. After CapsLock release, W must work normally.",
      "10. Change focus during a CapsLock hold, then release all keys. The next normal W must not stay blocked.",
      "11. Use Disable ownership, Enable ownership, and Restart backend. Normal keys must pass while disabled, and CapsLock+W must work again after restart.",
      "12. Close and reopen this prototype, then confirm WASD and Space work normally. Share the log below."
    ]
    instructionText := ""
    for instructionLine in instructionLines
      instructionText .= instructionLine "`n"
    this.statusGui := Gui("+ToolWindow +Resize", "SyntheticWorkspaces CapsLock feasibility prototype")
    this.statusGui.OnEvent("Close", this.exitRequestedCallback)
    this.statusGui.SetFont("s9", "Segoe UI")
    this.statusGui.Add("Text", "w900", instructionText)
    this.statusGui.SetFont("s14 Bold", "Segoe UI")
    this.statusGui.Add("Text", "xm", "LAST VALID DIRECTION")
    this.lastValidDirectionEdit := this.statusGui.Add("Edit", "x+12 yp-4 ReadOnly Center w140", "NONE")
    this.statusGui.SetFont("s9 Norm", "Segoe UI")
    this.statusGui.Add("Text", "xm w900", "Log file: " this.logPath)
    this.logStatusText := this.statusGui.Add("Text", "xm w900", "File log: waiting for data")
    this.statusEdit := this.statusGui.Add("Edit", "xm ReadOnly w900 r20 -Wrap")
    this.manualDisableButton := this.statusGui.Add("Button", "x+8 yp", "Disable ownership")
    this.manualDisableButton.OnEvent("Click", this.manualDisableCallback)
    this.manualEnableButton := this.statusGui.Add("Button", "x+8 yp", "Enable ownership")
    this.manualEnableButton.OnEvent("Click", this.manualEnableCallback)
    this.manualRestartButton := this.statusGui.Add("Button", "x+8 yp", "Restart backend")
    this.manualRestartButton.OnEvent("Click", this.manualRestartCallback)
    this.manualDropUpButton := this.statusGui.Add("Button", "xm", "Arm missed W-up")
    this.manualDropUpButton.OnEvent("Click", this.manualDropUpCallback)
    this.statusGuiHwnd := this.statusGui.Hwnd
    if (!this.smokeMode)
      this.statusGui.Show("NoActivate")
  }

  _RegisterMessages() {
    this._RegisterMessage(ManagedCapsLockPrototype.WM_APP_ARM_DROPPED_UP, this._ArmDroppedUpMessage.Bind(this))
    this._RegisterMessage(ManagedCapsLockPrototype.WM_APP_DISABLE, this._DisableMessage.Bind(this))
    this._RegisterMessage(ManagedCapsLockPrototype.WM_APP_ENABLE, this._EnableMessage.Bind(this))
    this._RegisterMessage(ManagedCapsLockPrototype.WM_APP_RESTART_BACKEND, this._RestartBackendMessage.Bind(this))
  }

  _RegisterMessage(messageNumber, callback) {
    OnMessage(messageNumber, callback)
    this.messageRegistrations.Push(Map("number", messageNumber, "callback", callback))
  }

  _RegisterHotkeys() {
    this._RegisterHotkey("*CapsLock", this._ManagedKeyDown.Bind(this, "CapsLock"), this._ShouldOwnCapsDown.Bind(this))
    this._RegisterHotkey("*CapsLock up", this._ManagedKeyUp.Bind(this, "CapsLock"), this._ShouldOwnKeyUp.Bind(this, "CapsLock"))
    for keyName in ["W", "A", "S", "D", "Space"] {
      this._RegisterHotkey("*" keyName, this._ManagedKeyDown.Bind(this, keyName), this._ShouldOwnSuffixDown.Bind(this, keyName))
      this._RegisterHotkey("*" keyName " up", this._ManagedKeyUp.Bind(this, keyName), this._ShouldOwnKeyUp.Bind(this, keyName))
    }
    for keyName in ["LAlt", "RAlt", "LCtrl", "RCtrl"] {
      this._RegisterHotkey("*" keyName, this._ManagedKeyDown.Bind(this, keyName), this._ShouldOwnLegacyDown.Bind(this, keyName))
      this._RegisterHotkey("*" keyName " up", this._ManagedKeyUp.Bind(this, keyName), this._ShouldOwnKeyUp.Bind(this, keyName))
    }
    this._Log("BACKEND", "registered")
  }

  _RegisterHotkey(hotkeyName, callback, predicate) {
    HotIf(predicate)
    Hotkey(hotkeyName, callback, "On I0")
    HotIf()
    this.hotkeyRegistrations.Push(Map("name", hotkeyName, "callback", callback, "predicate", predicate))
  }

  _UnregisterHotkeys() {
    for registration in this.hotkeyRegistrations {
      HotIf(registration["predicate"])
      try Hotkey(registration["name"], "Off")
      HotIf()
    }
    this.hotkeyRegistrations := []
    this._Log("BACKEND", "unregistered")
  }

  _ShouldOwnCapsDown(*) {
    return this.enabled || this.releaseGuards.Has("CapsLock")
  }

  _ShouldOwnSuffixDown(keyName, *) {
    if (this.releaseGuards.Has(keyName))
      return true
    if (!this.enabled || !this.sessionActive)
      return false
    return !this.ignoredPreheldSuffixes.Has(keyName)
  }

  _ShouldOwnLegacyDown(keyName, *) {
    if (this.releaseGuards.Has(keyName))
      return true
    if (!this.enabled || !this.sessionActive || this.isActionLocked || this.sessionMode != "" || this.legacyBlocked)
      return false
    return !this.preheldLegacyKeys.Has(keyName)
  }

  _ShouldOwnKeyUp(keyName, *) {
    return this.releaseGuards.Has(keyName)
  }

  _ManagedKeyDown(keyName, *) {
    if (this.heldKeys.Has(keyName)) {
      this._Log("REPEAT", keyName)
      return
    }
    this.heldKeys[keyName] := true
    this.releaseGuards[keyName] := true
    this._DeleteMapKey(this.repairCandidates, keyName)
    keyKind := this.keyKinds[keyName]
    switch keyKind {
      case "caps": this._StartCapsSession()
      case "direction": this._HandleDirectionDown(keyName)
      case "space": this._HandleSpaceDown()
      case "legacy-alt": this._HandleLegacyDown("alt")
      case "legacy-ctrl": this._HandleLegacyDown("ctrl")
    }
  }

  _ManagedKeyUp(keyName, *) {
    if (this.droppedUpKeys.Has(keyName)) {
      this._DeleteMapKey(this.droppedUpKeys, keyName)
      this._Log("DROP_UP", keyName)
      return
    }
    this._ReleaseManagedKey(keyName, false)
  }

  _ReleaseManagedKey(keyName, repaired) {
    if (!this.releaseGuards.Has(keyName))
      return
    keyKind := this.keyKinds[keyName]
    switch keyKind {
      case "caps": this._ReleaseCaps(repaired)
      case "direction": this._ReleaseDirection(keyName, repaired)
      default: this._ReleaseCommon(keyName)
    }
    this._TryCompletePendingRestart()
  }

  _ReleaseCommon(keyName) {
    this._DeleteMapKey(this.heldKeys, keyName)
    this._DeleteMapKey(this.releaseGuards, keyName)
    this._DeleteMapKey(this.repairCandidates, keyName)
  }

  _StartCapsSession() {
    if (!this.enabled || this.sessionActive)
      return
    this.sessionActive := true
    this.sessionMode := ""
    this.isActionLocked := false
    this.tapCancelled := false
    this.legacyBlocked := false
    this.directionGestureArmed := true
    this.heldDirectionMask := 0
    this.currentValidDirectionMask := 0
    this.pendingDirectionMask := 0
    this.ignoredPreheldSuffixes := Map()
    this.preheldLegacyKeys := Map()
    for keyName in ["W", "A", "S", "D", "Space"] {
      if (GetKeyState(keyName, "P"))
        this.ignoredPreheldSuffixes[keyName] := true
    }
    for keyName in ["LAlt", "RAlt", "LCtrl", "RCtrl"] {
      if (GetKeyState(keyName, "P"))
        this.preheldLegacyKeys[keyName] := true
    }
    altPreheld := this.preheldLegacyKeys.Has("LAlt") || this.preheldLegacyKeys.Has("RAlt")
    ctrlPreheld := this.preheldLegacyKeys.Has("LCtrl") || this.preheldLegacyKeys.Has("RCtrl")
    if (altPreheld && ctrlPreheld) {
      this.legacyBlocked := true
      this.tapCancelled := true
      this._Log("SESSION", "legacy-conflict")
    } else if (altPreheld) {
      this._AcceptLegacy("alt")
    } else if (ctrlPreheld) {
      this._AcceptLegacy("ctrl")
    }
    this._StartInputObserver()
    this._Log("SESSION", "started")
  }

  _ReleaseCaps(repaired) {
    this._ReleaseCommon("CapsLock")
    if (!this.sessionActive)
      return
    if (this.sessionMode = "" && !this.tapCancelled)
      this._DispatchAction("tap")
    this._CloseSession()
    if (repaired)
      this._Log("SESSION", "caps-repaired")
  }

  _CloseSession() {
    this._CancelStableTimer()
    this._StopInputObserver()
    this.sessionActive := false
    this.sessionMode := ""
    this.isActionLocked := false
    this.tapCancelled := false
    this.legacyBlocked := false
    this.directionGestureArmed := true
    this.heldDirectionMask := 0
    this.currentValidDirectionMask := 0
    this.pendingDirectionMask := 0
    this.ignoredPreheldSuffixes := Map()
    this.preheldLegacyKeys := Map()
    this._Log("SESSION", "closed")
  }

  _HandleDirectionDown(keyName) {
    if (!this.sessionActive || this.isActionLocked)
      return
    if (this.sessionMode = "") {
      this.sessionMode := "direction"
      this.tapCancelled := true
    }
    if (this.sessionMode != "direction")
      return
    this.heldDirectionMask := this.heldDirectionMask | this.directionBits[keyName]
    this._UpdateDirectionTimer()
  }

  _ReleaseDirection(keyName, repaired) {
    this._ReleaseCommon(keyName)
    if (!this.sessionActive || this.sessionMode != "direction")
      return
    this.heldDirectionMask := this.heldDirectionMask & ~this.directionBits[keyName]
    if (this.heldDirectionMask = 0) {
      this.directionGestureArmed := true
      this._CancelStableTimer()
      this.currentValidDirectionMask := 0
      this._Log("GESTURE", "rearmed")
    } else {
      this._UpdateDirectionTimer()
    }
    if (repaired)
      this._Log("DIRECTION", "release-repaired:" keyName)
  }

  _UpdateDirectionTimer() {
    directionMask := this.heldDirectionMask
    if (!this.validDirectionMasks.Has(directionMask)) {
      this.currentValidDirectionMask := 0
      this._CancelStableTimer()
      this._Log("MASK", "invalid:" directionMask)
      return
    }
    this.currentValidDirectionMask := directionMask
    if (!this.directionGestureArmed)
      return
    if (this.pendingDirectionMask = directionMask)
      return
    this._CancelStableTimer()
    this.pendingDirectionMask := directionMask
    SetTimer(this.stableTimerCallback, -100)
    this._Log("TIMER", "started:" directionMask)
  }

  _CommitStableDirection() {
    pendingDirectionMask := this.pendingDirectionMask
    this.pendingDirectionMask := 0
    if (!this.sessionActive || this.sessionMode != "direction" || !this.directionGestureArmed || pendingDirectionMask = 0 || this.currentValidDirectionMask != pendingDirectionMask)
      return
    if (!this._PhysicalDirectionMaskMatches(pendingDirectionMask)) {
      this._Log("TIMER", "physical-mismatch:" pendingDirectionMask)
      return
    }
    this.directionGestureArmed := false
    directionName := StrUpper(this.validDirectionMasks[pendingDirectionMask])
    if (IsObject(this.lastValidDirectionEdit))
      this.lastValidDirectionEdit.Value := directionName
    this._DispatchAction("workspace:" this.validDirectionMasks[pendingDirectionMask])
  }

  _PhysicalDirectionMaskMatches(expectedMask) {
    physicalMask := 0
    for keyName, directionBit in this.directionBits {
      if (this.releaseGuards.Has(keyName) && GetKeyState(keyName, "P"))
        physicalMask := physicalMask | directionBit
    }
    return physicalMask = expectedMask
  }

  _CancelStableTimer() {
    SetTimer(this.stableTimerCallback, 0)
    this.pendingDirectionMask := 0
  }

  _HandleSpaceDown() {
    if (!this.sessionActive)
      return
    this.tapCancelled := true
    if (this.isActionLocked)
      return
    if (this.sessionMode = "") {
      this.sessionMode := "space"
      this.isActionLocked := true
      this._DispatchAction("overview")
      return
    }
    if (this.sessionMode = "direction")
      this._Log("SPACE", "consumed-after-direction")
  }

  _HandleLegacyDown(legacyFamily) {
    if (!this.sessionActive || this.isActionLocked || this.sessionMode != "" || this.legacyBlocked)
      return
    otherFamilyDown := legacyFamily = "alt" ? this._IsCtrlPhysicallyDown() : this._IsAltPhysicallyDown()
    if (otherFamilyDown) {
      this.tapCancelled := true
      this.legacyBlocked := true
      return
    }
    this._AcceptLegacy(legacyFamily)
  }

  _AcceptLegacy(legacyFamily) {
    this.sessionMode := "legacy"
    this.isActionLocked := true
    this.tapCancelled := true
    this._DispatchAction("legacy:" legacyFamily)
  }

  _IsAltPhysicallyDown() {
    return GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P")
  }

  _IsCtrlPhysicallyDown() {
    return GetKeyState("LCtrl", "P") || GetKeyState("RCtrl", "P")
  }

  _StartInputObserver() {
    this._StopInputObserver()
    this.inputObserver := InputHook("V")
    this.inputObserver.KeyOpt("{All}", "N")
    this.inputObserverDownCallback := this._ObservedKeyDown.Bind(this)
    this.inputObserverUpCallback := this._ObservedKeyUp.Bind(this)
    this.inputObserver.OnKeyDown := this.inputObserverDownCallback
    this.inputObserver.OnKeyUp := this.inputObserverUpCallback
    this.inputObserver.Start()
  }

  _StopInputObserver() {
    if (IsObject(this.inputObserver))
      this.inputObserver.Stop()
    this.inputObserver := 0
    this.inputObserverDownCallback := 0
    this.inputObserverUpCallback := 0
    this.observedUnmanagedKeys := Map()
  }

  _ObservedKeyDown(inputHook, virtualKey, scanCode) {
    if (!this.sessionActive || this.managedVirtualKeys.Has(virtualKey))
      return
    if (this.observedUnmanagedKeys.Has(virtualKey))
      return
    this.observedUnmanagedKeys[virtualKey] := true
    this.tapCancelled := true
    this._Log("PASS", GetKeyName(Format("vk{:02X}sc{:03X}", virtualKey, scanCode)))
  }

  _ObservedKeyUp(inputHook, virtualKey, scanCode) {
    this._DeleteMapKey(this.observedUnmanagedKeys, virtualKey)
  }

  _RepairPhysicalState() {
    guardedKeys := []
    for keyName in this.releaseGuards
      guardedKeys.Push(keyName)
    for keyName in guardedKeys {
      if (GetKeyState(keyName, "P")) {
        this._DeleteMapKey(this.repairCandidates, keyName)
        continue
      }
      if (!this.repairCandidates.Has(keyName)) {
        this.repairCandidates[keyName] := A_TickCount
        continue
      }
      if (A_TickCount - this.repairCandidates[keyName] < 60)
        continue
      this._Log("REPAIR", keyName)
      this._ReleaseManagedKey(keyName, true)
    }
  }

  _DeleteMapKey(targetMap, keyName) {
    if (targetMap.Has(keyName))
      targetMap.Delete(keyName)
  }

  _DispatchAction(actionName) {
    this._Log("ACTION", actionName)
  }

  _ArmManualDroppedUp(*) {
    this.droppedUpKeys["W"] := true
    this._Log("COMMAND", "drop-up:W-armed")
  }

  _DisableManual(*) {
    this._DisableMessage(0, 0, 0, 0)
  }

  _EnableManual(*) {
    this._EnableMessage(0, 0, 0, 0)
  }

  _RestartManual(*) {
    this._RestartBackendMessage(0, 0, 0, 0)
  }

  _ArmDroppedUpMessage(virtualKey, lParam, messageNumber, windowHwnd) {
    if (this.keyByVirtualKey.Has(virtualKey)) {
      keyName := this.keyByVirtualKey[virtualKey]
      this.droppedUpKeys[keyName] := true
      this._Log("COMMAND", "drop-up:" keyName)
    }
    return 0
  }

  _DisableMessage(wParam, lParam, messageNumber, windowHwnd) {
    this.enabled := false
    if (this.sessionActive)
      this._CloseSession()
    this._Log("STATE", "disabled")
    return 0
  }

  _EnableMessage(wParam, lParam, messageNumber, windowHwnd) {
    this.enabled := true
    this._Log("STATE", "enabled")
    return 0
  }

  _RestartBackendMessage(wParam, lParam, messageNumber, windowHwnd) {
    this.enabled := false
    if (this.sessionActive)
      this._CloseSession()
    if (this.releaseGuards.Count > 0) {
      this.restartPending := true
      this._Log("BACKEND", "restart-pending")
    } else {
      this._CompleteBackendRestart()
    }
    return 0
  }

  _TryCompletePendingRestart() {
    if (this.restartPending && this.releaseGuards.Count = 0)
      this._CompleteBackendRestart()
  }

  _CompleteBackendRestart() {
    this.restartPending := false
    this._UnregisterHotkeys()
    this._RegisterHotkeys()
    this.enabled := true
    this._Log("BACKEND", "restarted")
  }

  _ExitRequested(*) {
    ExitApp()
  }

  _OnExit(exitReason, exitCode) {
    this.Cleanup()
  }

  Cleanup() {
    if (this.cleanedUp)
      return
    this.cleanedUp := true
    this.enabled := false
    this._CancelStableTimer()
    SetTimer(this.repairTimerCallback, 0)
    SetTimer(this.logFlushCallback, 0)
    this._StopInputObserver()
    this._UnregisterHotkeys()
    for registration in this.messageRegistrations
      OnMessage(registration["number"], registration["callback"], 0)
    this.messageRegistrations := []
    this.releaseGuards := Map()
    this.heldKeys := Map()
    this.repairCandidates := Map()
    this.droppedUpKeys := Map()
    this._Log("CLEANUP", "complete")
    this._FlushLogQueue()
  }

  _FlushLogQueue() {
    if (this.logPath = "" || this.pendingLogText = "")
      return
    logText := this.pendingLogText
    this.pendingLogText := ""
    try {
      FileAppend(logText, this.logPath, "UTF-8")
      if (IsObject(this.logStatusText))
        this.logStatusText.Text := "File log: OK"
    } catch Error as caughtError {
      this.pendingLogText := logText this.pendingLogText
      if (IsObject(this.logStatusText))
        this.logStatusText.Text := "File log busy, retrying: " caughtError.Message
    }
  }

  _Log(eventName, value) {
    logLine := A_TickCount "|" eventName "|" value "`n"
    if (this.logPath != "")
      this.pendingLogText .= logLine
    if (IsObject(this.statusEdit)) {
      this.statusEdit.Value .= logLine
      SendMessage(0x0115, 7, 0, this.statusEdit)
    }
  }
}

smokeMode := A_Args.Length >= 1 && A_Args[1] = "--smoke"
logPath := A_Args.Length >= 2 ? A_Args[2] : A_ScriptDir "\tmp\SyntheticWorkspacesCapsLockPrototypeManual.log"
try FileDelete(logPath)
prototype := ManagedCapsLockPrototype(smokeMode, logPath)
if (smokeMode) {
  smokeExitCallback := (*) => ExitApp()
  SetTimer(smokeExitCallback, -250)
}

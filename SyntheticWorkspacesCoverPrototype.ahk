#Requires AutoHotkey v2.0
#SingleInstance Off

class WindowsCoverBackendPrototype {
  static EVENT_SYSTEM_FOREGROUND := 0x0003
  static EVENT_OBJECT_REORDER := 0x8004
  static HWND_TOP := 0
  static HWND_TOPMOST := -1
  static HWND_NOTOPMOST := -2
  static SWP_NOSIZE := 0x0001
  static SWP_NOMOVE := 0x0002
  static SWP_NOACTIVATE := 0x0010
  static SWP_NOOWNERZORDER := 0x0200
  static WS_EX_TOPMOST := 0x00000008
  static WM_NULL := 0x0000
  static SMTO_ABORTIFHUNG := 0x0002

  __New(logCallback) {
    this.logCallback := logCallback
    this.covers := Map()
    this.eventCallback := 0
    this.winEventHandler := 0
    this.winEventCallback := 0
    this.winEventHooks := []
    this.forceNextStackFailure := false
    this.lastCoverCreateKeptForeground := false
    this.operationCounts := Map()
  }

  StartWinEvents(eventCallback) {
    this.StopWinEvents()
    this.eventCallback := eventCallback
    this.winEventHandler := ObjBindMethod(this, "_OnWinEvent")
    this.winEventCallback := CallbackCreate(this.winEventHandler,, 7)
    for eventNumber in [WindowsCoverBackendPrototype.EVENT_SYSTEM_FOREGROUND, WindowsCoverBackendPrototype.EVENT_OBJECT_REORDER] {
      hookHandle := DllCall("SetWinEventHook", "UInt", eventNumber, "UInt", eventNumber, "Ptr", 0, "Ptr", this.winEventCallback, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr")
      if (!hookHandle) {
        this.StopWinEvents()
        return false
      }
      this.winEventHooks.Push(hookHandle)
    }
    return true
  }

  StopWinEvents() {
    for hookHandle in this.winEventHooks
      DllCall("UnhookWinEvent", "Ptr", hookHandle)
    this.winEventHooks := []
    if (this.winEventCallback)
      CallbackFree(this.winEventCallback)
    this.winEventCallback := 0
    this.winEventHandler := 0
    this.eventCallback := 0
  }

  CreateCovers() {
    this.RemoveAllCovers()
    foregroundBefore := DllCall("GetForegroundWindow", "Ptr")
    monitorNumber := 1
    while (monitorNumber <= MonitorGetCount()) {
      MonitorGetWorkArea(monitorNumber, &workLeft, &workTop, &workRight, &workBottom)
      coverWidth := workRight - workLeft
      coverHeight := workBottom - workTop
      coverGui := Gui("+ToolWindow -Caption +E0x08000000", "SW Cover Monitor " monitorNumber)
      coverGui.BackColor := "1D2633"
      coverGui.SetFont("s26 Bold cFFFFFF", "Segoe UI")
      labelTop := Max(0, Floor(coverHeight / 2) - 35)
      coverGui.Add("Text", "x0 y" labelTop " w" coverWidth " Center BackgroundTrans", "INACTIVE WORKSPACE COVER`nMONITOR " monitorNumber)
      coverGui.Show("NA x" workLeft " y" workTop " w" coverWidth " h" coverHeight)
      WinSetTransparent(235, "ahk_id " coverGui.Hwnd)
      this.covers[monitorNumber] := Map("gui", coverGui, "hwnd", coverGui.Hwnd, "left", workLeft, "top", workTop, "width", coverWidth, "height", coverHeight)
      monitorNumber += 1
    }
    foregroundAfter := DllCall("GetForegroundWindow", "Ptr")
    this.lastCoverCreateKeptForeground := foregroundBefore = foregroundAfter && !this.IsCoverHwnd(foregroundAfter)
    this._Log("COVERS", "created:" this.covers.Count)
    return this.lastCoverCreateKeptForeground
  }

  RemoveCover(monitorNumber) {
    if (!this.covers.Has(monitorNumber))
      return
    coverRecord := this.covers[monitorNumber]
    try coverRecord["gui"].Destroy()
    this.covers.Delete(monitorNumber)
    this._Log("COVER", "removed-monitor:" monitorNumber)
  }

  RemoveAllCovers() {
    for monitorNumber, coverRecord in this.covers
      try coverRecord["gui"].Destroy()
    if (this.covers.Count > 0)
      this._Log("COVERS", "removed-all")
    this.covers := Map()
  }

  GetCoverHwnds() {
    coverHwnds := []
    for monitorNumber, coverRecord in this.covers
      coverHwnds.Push(coverRecord["hwnd"])
    return coverHwnds
  }

  IsCoverHwnd(windowHwnd) {
    for monitorNumber, coverRecord in this.covers {
      if (coverRecord["hwnd"] = windowHwnd)
        return true
    }
    return false
  }

  VerifyCoverGeometry() {
    if (this.covers.Count != MonitorGetCount())
      return false
    for monitorNumber, coverRecord in this.covers {
      if (!WinExist("ahk_id " coverRecord["hwnd"]) || !DllCall("IsWindowVisible", "Ptr", coverRecord["hwnd"]))
        return false
      WinGetPos(&actualLeft, &actualTop, &actualWidth, &actualHeight, "ahk_id " coverRecord["hwnd"])
      if (Abs(actualLeft - coverRecord["left"]) > 2 || Abs(actualTop - coverRecord["top"]) > 2 || Abs(actualWidth - coverRecord["width"]) > 2 || Abs(actualHeight - coverRecord["height"]) > 2)
        return false
    }
    return true
  }

  PlaceAtTop(windowHwnd) {
    return this._SetWindowPos(windowHwnd, WindowsCoverBackendPrototype.HWND_TOP)
  }

  PlaceBelow(windowHwnd, upperWindowHwnd) {
    return this._SetWindowPos(windowHwnd, upperWindowHwnd)
  }

  SetTopmost(windowHwnd, enabled) {
    insertAfter := enabled ? WindowsCoverBackendPrototype.HWND_TOPMOST : WindowsCoverBackendPrototype.HWND_NOTOPMOST
    return this._SetWindowPos(windowHwnd, insertAfter, false)
  }

  MinimizeWindow(windowHwnd) {
    this._RecordOperation(windowHwnd)
    DllCall("ShowWindow", "Ptr", windowHwnd, "Int", 6)
    return this.IsMinimized(windowHwnd)
  }

  RestoreWindow(windowHwnd, windowRect := 0) {
    this._RecordOperation(windowHwnd)
    DllCall("ShowWindow", "Ptr", windowHwnd, "Int", 9)
    if (IsObject(windowRect))
      DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", 0, "Int", windowRect["left"], "Int", windowRect["top"], "Int", windowRect["width"], "Int", windowRect["height"], "UInt", 0x0014)
    return !this.IsMinimized(windowHwnd)
  }

  IsTopmost(windowHwnd) {
    return (WinGetExStyle("ahk_id " windowHwnd) & WindowsCoverBackendPrototype.WS_EX_TOPMOST) != 0
  }

  IsMinimized(windowHwnd) {
    return DllCall("IsIconic", "Ptr", windowHwnd)
  }

  IsResponsive(windowHwnd, timeoutMs := 150) {
    messageResult := 0
    return DllCall("SendMessageTimeout", "Ptr", windowHwnd, "UInt", WindowsCoverBackendPrototype.WM_NULL, "Ptr", 0, "Ptr", 0, "UInt", WindowsCoverBackendPrototype.SMTO_ABORTIFHUNG, "UInt", timeoutMs, "Ptr*", &messageResult)
  }

  GetWindowRect(windowHwnd) {
    rectBuffer := Buffer(16, 0)
    if (!DllCall("GetWindowRect", "Ptr", windowHwnd, "Ptr", rectBuffer.Ptr))
      return 0
    return Map("left", NumGet(rectBuffer, 0, "Int"), "top", NumGet(rectBuffer, 4, "Int"), "width", NumGet(rectBuffer, 8, "Int") - NumGet(rectBuffer, 0, "Int"), "height", NumGet(rectBuffer, 12, "Int") - NumGet(rectBuffer, 4, "Int"))
  }

  GetOperationCount(windowHwnd) {
    return this.operationCounts.Has(windowHwnd) ? this.operationCounts[windowHwnd] : 0
  }

  _SetWindowPos(windowHwnd, insertAfterHwnd, allowForcedFailure := true) {
    if (allowForcedFailure && this.forceNextStackFailure) {
      this.forceNextStackFailure := false
      this._Log("STACK", "forced-failure")
      return false
    }
    this._RecordOperation(windowHwnd)
    flags := WindowsCoverBackendPrototype.SWP_NOMOVE | WindowsCoverBackendPrototype.SWP_NOSIZE | WindowsCoverBackendPrototype.SWP_NOACTIVATE | WindowsCoverBackendPrototype.SWP_NOOWNERZORDER
    return DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", insertAfterHwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
  }

  _RecordOperation(windowHwnd) {
    this.operationCounts[windowHwnd] := this.GetOperationCount(windowHwnd) + 1
  }

  _OnWinEvent(hookHandle, eventNumber, windowHwnd, objectId, childId, eventThread, eventTime) {
    if (IsObject(this.eventCallback))
      this.eventCallback.Call(eventNumber, windowHwnd, objectId, childId)
  }

  _Log(eventName, value) {
    if (IsObject(this.logCallback))
      this.logCallback.Call(eventName, value)
  }
}

class CoverFeasibilityPrototype {
  static WM_APP_HANG := 0x8001

  __New(smokeMode, logPath) {
    this.smokeMode := smokeMode
    this.logPath := logPath
    this.cleanedUp := false
    this.testWindowsReady := false
    this.currentWorkspace := "A"
    this.stackApplying := false
    this.ignoreEventsUntil := 0
    this.repairTestPending := false
    this.repairEventObserved := false
    this.repairApplied := false
    this.lastEvent := "none"
    this.reducedIsolation := false
    this.unsupportedFixturePid := 0
    this.unsupportedFixtureHwnd := 0
    this.unsupportedMonitorNumber := 0
    this.unsupportedRectBefore := 0
    this.unsupportedOperationsBefore := 0
    this.fixtureGuis := Map()
    this.windowHwnds := Map()
    this.pendingLogText := ""
    this.visibleLogText := ""
    this.resultOrder := ["covers", "repair", "specialInactive", "specialRestore", "unsupported", "failure", "cleanup"]
    this.results := Map()
    this._InitializeResults()
    this.logCallback := this._Log.Bind(this)
    this.winEventCallback := this._HandleWinEvent.Bind(this)
    this.repairCallback := this._RepairFromEvent.Bind(this)
    this.repairCheckCallback := this._CompleteRepairTest.Bind(this)
    this.unresponsiveCheckCallback := this._CompleteUnsupportedTest.Bind(this)
    this.reconcileCallback := this._ReconcileStack.Bind(this)
    this.logFlushCallback := this._FlushLogQueue.Bind(this)
    this.safetyRestoreCallback := this._SafetyRestore.Bind(this)
    this.emergencyCallback := this._EmergencyHotkey.Bind(this)
    this.exitCallback := this._OnExit.Bind(this)
    this.backend := WindowsCoverBackendPrototype(this.logCallback)
    this._CreatePanel()
    this.eventHookReady := this.backend.StartWinEvents(this.winEventCallback)
    Hotkey("^+F12", this.emergencyCallback)
    SetTimer(this.reconcileCallback, 1000)
    SetTimer(this.logFlushCallback, 250)
    OnExit(this.exitCallback)
    this._Log("READY", this.eventHookReady ? "win-events" : "win-event-hook-failed")
    this._RefreshStatus()
    if (!this.smokeMode)
      this.panelGui.Show("w960 NoActivate")
  }

  _InitializeResults() {
    this.results["covers"] := Map("label", "Covers and z-order bands", "state", "NOT RUN", "detail", "Create test windows")
    this.results["repair"] := Map("label", "WinEvent repair", "state", "NOT RUN", "detail", "Use Break z-order")
    this.results["specialInactive"] := Map("label", "Topmost/fullscreen inactive", "state", "NOT RUN", "detail", "Switch to B")
    this.results["specialRestore"] := Map("label", "Topmost/fullscreen restore", "state", "NOT RUN", "detail", "Switch back to A")
    this.results["unsupported"] := Map("label", "Unsupported safety fallback", "state", "NOT RUN", "detail", "Start unresponsive window")
    this.results["failure"] := Map("label", "Failed-stack recovery", "state", "NOT RUN", "detail", "Simulate stack failure")
    this.results["cleanup"] := Map("label", "Exit cleanup", "state", "MANUAL", "detail", "Close and reopen, then check the desktop")
  }

  _CreatePanel() {
    instructions := [
      "Manual TEST-4 cover feasibility prototype. It touches only the test windows that it creates.",
      "1. Create / Reset: expect one blue cover per monitor, Workspace A above it, Workspace B below it, and SHELL UI above normal active windows.",
      "2. Break z-order: Workspace B is activated on purpose. Expect a WinEvent and automatic repair.",
      "3. Switch to B: expect TOPMOST A to lose topmost and FULLSCREEN A to minimize.",
      "4. Switch to A: expect topmost and fullscreen state to return.",
      "5. Start unresponsive window: its monitor cover must be removed, Reduced isolation becomes YES, and the window is not moved or focused.",
      "6. Simulate stack failure: every cover must disappear and all test windows must stay reachable.",
      "7. Close and reopen: no cover or changed test-window state may remain.",
      "Emergency: press Ctrl+Shift+F12 at any time. Covers also auto-remove after 60 seconds."
    ]
    instructionText := ""
    for instructionLine in instructions
      instructionText .= instructionLine "`n"
    this.panelGui := Gui("+ToolWindow +AlwaysOnTop +Resize", "SyntheticWorkspaces cover feasibility prototype")
    this.panelGui.OnEvent("Close", (*) => ExitApp())
    this.panelGui.SetFont("s9", "Segoe UI")
    this.panelGui.Add("Text", "w930", instructionText)
    this.lastResultText := this.panelGui.Add("Text", "xm w930 c0066CC", "READY - create the test windows")
    this.resultEdit := this.panelGui.Add("Edit", "xm ReadOnly w930 r8 -Wrap")
    this.liveEdit := this.panelGui.Add("Edit", "xm ReadOnly w930 r8 -Wrap")
    createButton := this.panelGui.Add("Button", "xm w145", "Create / Reset")
    createButton.OnEvent("Click", this._CreateOrReset.Bind(this))
    applyAButton := this.panelGui.Add("Button", "x+8 yp w120", "Apply A")
    applyAButton.OnEvent("Click", this._ApplyWorkspaceA.Bind(this))
    breakButton := this.panelGui.Add("Button", "x+8 yp w135", "Break z-order")
    breakButton.OnEvent("Click", this._BreakAndRepair.Bind(this))
    switchBButton := this.panelGui.Add("Button", "x+8 yp w120", "Switch to B")
    switchBButton.OnEvent("Click", this._SwitchWorkspaceB.Bind(this))
    switchAButton := this.panelGui.Add("Button", "x+8 yp w120", "Switch to A")
    switchAButton.OnEvent("Click", this._SwitchWorkspaceA.Bind(this))
    unsupportedButton := this.panelGui.Add("Button", "xm w190", "Start unresponsive window")
    unsupportedButton.OnEvent("Click", this._StartUnsupportedTest.Bind(this))
    failureButton := this.panelGui.Add("Button", "x+8 yp w175", "Simulate stack failure")
    failureButton.OnEvent("Click", this._SimulateStackFailure.Bind(this))
    emergencyButton := this.panelGui.Add("Button", "x+8 yp w170", "Emergency Restore")
    emergencyButton.OnEvent("Click", this._EmergencyButton.Bind(this))
    this.panelGui.Add("Text", "xm w930", "Log file: " this.logPath)
    this.logStatusText := this.panelGui.Add("Text", "xm w930", "File log: waiting for data")
    this.logEdit := this.panelGui.Add("Edit", "xm ReadOnly w930 r10 -Wrap")
  }

  _CreateOrReset(*) {
    this._RemoveTestWindows()
    this._InitializeResults()
    this.currentWorkspace := "A"
    this.reducedIsolation := false
    MonitorGetWorkArea(MonitorGetPrimary(), &workLeft, &workTop, &workRight, &workBottom)
    panelWidth := 960
    panelLeft := Min(workRight - panelWidth, workLeft + 20)
    this.panelGui.Show("x" panelLeft " y" (workTop + 20) " w" panelWidth)
    this.fixtureGuis["normalA"] := this._CreateTestWindow("Workspace A - ACTIVE", "2F7D32", "WORKSPACE A`nACTIVE NORMAL WINDOW")
    this.fixtureGuis["normalB"] := this._CreateTestWindow("Workspace B - INACTIVE", "8A3B3B", "WORKSPACE B`nINACTIVE NORMAL WINDOW")
    this.fixtureGuis["topmostA"] := this._CreateTestWindow("Workspace A - TOPMOST", "6A3D9A", "WORKSPACE A`nSAVED TOPMOST WINDOW", "+AlwaysOnTop")
    this.fixtureGuis["fullscreenA"] := this._CreateTestWindow("Workspace A - FULLSCREEN", "1E5C73", "WORKSPACE A`nFULLSCREEN WINDOW", "-Caption +ToolWindow")
    this.fixtureGuis["shell"] := this._CreateTestWindow("Haribol shell UI sample", "B56A00", "HARIBOL SHELL UI`nMUST STAY ABOVE NORMAL ACTIVE WINDOWS", "+ToolWindow +E0x08000000")
    this.windowHwnds["normalA"] := this.fixtureGuis["normalA"].Hwnd
    this.windowHwnds["normalB"] := this.fixtureGuis["normalB"].Hwnd
    this.windowHwnds["topmostA"] := this.fixtureGuis["topmostA"].Hwnd
    this.windowHwnds["fullscreenA"] := this.fixtureGuis["fullscreenA"].Hwnd
    this.windowHwnds["shell"] := this.fixtureGuis["shell"].Hwnd
    this.fixtureGuis["normalA"].Show("NA x" (workLeft + 70) " y" (workTop + 220) " w360 h220")
    this.fixtureGuis["normalB"].Show("NA x" (workLeft + 470) " y" (workTop + 240) " w360 h220")
    this.fixtureGuis["topmostA"].Show("NA x" (workLeft + 150) " y" (workTop + 470) " w330 h170")
    this.fixtureGuis["shell"].Show("NA x" (workRight - 380) " y" (workTop + 100) " w340 h130")
    MonitorGet(MonitorGetPrimary(), &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
    this.fullscreenRect := Map("left", monitorLeft, "top", monitorTop, "width", monitorRight - monitorLeft, "height", monitorBottom - monitorTop)
    this.recoveryFullscreenRect := Map("left", workLeft + 420, "top", workTop + 470, "width", 380, "height", 220)
    this.fixtureGuis["fullscreenA"].Show("NA x" monitorLeft " y" monitorTop " w" (monitorRight - monitorLeft) " h" (monitorBottom - monitorTop))
    this.testWindowsReady := true
    this.backend.CreateCovers()
    this._ApplyWorkspace("A")
    coverResult := this._VerifyBands()
    this._SetResult("covers", coverResult["passed"], coverResult["detail"])
    this._ArmSafetyRestore()
    this._Log("TEST", "created-and-applied-A")
  }

  _CreateTestWindow(title, color, label, options := "") {
    testGui := Gui(options, title)
    testGui.BackColor := color
    testGui.SetFont("s18 Bold cFFFFFF", "Segoe UI")
    testGui.Add("Text", "Center w320 r4 BackgroundTrans", label)
    testGui.OnEvent("Close", (*) => testGui.Hide())
    return testGui
  }

  _ApplyWorkspaceA(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0)
      this.backend.CreateCovers()
    this._ApplyWorkspace("A")
    coverResult := this._VerifyBands()
    this._SetResult("covers", coverResult["passed"], coverResult["detail"])
    this._ArmSafetyRestore()
  }

  _SwitchWorkspaceB(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0)
      this.backend.CreateCovers()
    this._ApplyWorkspace("B")
    specialPassed := !this.backend.IsTopmost(this.windowHwnds["topmostA"]) && this.backend.IsMinimized(this.windowHwnds["fullscreenA"])
    this._SetResult("specialInactive", specialPassed, specialPassed ? "Topmost cleared and fullscreen minimized" : "Expected topmost OFF and fullscreen minimized")
    this._ArmSafetyRestore()
  }

  _SwitchWorkspaceA(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0)
      this.backend.CreateCovers()
    this._ApplyWorkspace("A")
    specialPassed := this.backend.IsTopmost(this.windowHwnds["topmostA"]) && !this.backend.IsMinimized(this.windowHwnds["fullscreenA"]) && this._FullscreenGeometryMatches()
    this._SetResult("specialRestore", specialPassed, specialPassed ? "Saved topmost and fullscreen state restored" : "Topmost or fullscreen state did not restore")
    this._ArmSafetyRestore()
  }

  _ApplyWorkspace(workspaceName) {
    this.currentWorkspace := workspaceName
    if (workspaceName = "A") {
      this.backend.RestoreWindow(this.windowHwnds["fullscreenA"], this.fullscreenRect)
      this.backend.SetTopmost(this.windowHwnds["topmostA"], true)
    } else {
      this.backend.SetTopmost(this.windowHwnds["topmostA"], false)
      this.backend.MinimizeWindow(this.windowHwnds["fullscreenA"])
    }
    if (!this._ApplyStack()) {
      this._RecoverAll("stack-apply-failed")
      return false
    }
    this._Log("WORKSPACE", "active:" workspaceName)
    this._RefreshStatus()
    return true
  }

  _ApplyStack() {
    if (!this.testWindowsReady)
      return false
    this.stackApplying := true
    stackSucceeded := true
    try {
      activeHwnds := this._GetActiveNormalHwnds()
      inactiveHwnds := this._GetInactiveHwnds()
      shellHwnd := this.windowHwnds["shell"]
      stackSucceeded := this.backend.SetTopmost(shellHwnd, false) && this.backend.PlaceAtTop(shellHwnd)
      upperHwnd := shellHwnd
      for activeHwnd in activeHwnds {
        if (stackSucceeded)
          stackSucceeded := this.backend.PlaceBelow(activeHwnd, upperHwnd)
        upperHwnd := activeHwnd
      }
      for coverHwnd in this.backend.GetCoverHwnds() {
        if (stackSucceeded)
          stackSucceeded := this.backend.PlaceBelow(coverHwnd, upperHwnd)
        upperHwnd := coverHwnd
      }
      for inactiveHwnd in inactiveHwnds {
        if (stackSucceeded)
          stackSucceeded := this.backend.PlaceBelow(inactiveHwnd, upperHwnd)
        upperHwnd := inactiveHwnd
      }
    } finally {
      this.stackApplying := false
      this.ignoreEventsUntil := A_TickCount + 250
    }
    return stackSucceeded
  }

  _GetActiveNormalHwnds() {
    if (this.currentWorkspace = "A")
      return [this.windowHwnds["fullscreenA"], this.windowHwnds["normalA"]]
    return [this.windowHwnds["normalB"]]
  }

  _GetInactiveHwnds() {
    if (this.currentWorkspace = "A")
      return [this.windowHwnds["normalB"]]
    return [this.windowHwnds["normalA"], this.windowHwnds["topmostA"], this.windowHwnds["fullscreenA"]]
  }

  _VerifyBands() {
    if (!this.testWindowsReady)
      return Map("passed", false, "detail", "Test windows do not exist")
    if (!this.backend.VerifyCoverGeometry() || !this.backend.lastCoverCreateKeptForeground)
      return Map("passed", false, "detail", "Cover count, geometry, visibility, or NoActivate check failed")
    zOrderRanks := this._ReadZOrderRanks()
    shellHwnd := this.windowHwnds["shell"]
    if (!zOrderRanks.Has(shellHwnd))
      return Map("passed", false, "detail", "Shell UI is missing from z-order")
    activeHwnds := this._GetActiveNormalHwnds()
    inactiveHwnds := this._GetInactiveHwnds()
    coverHwnds := this.backend.GetCoverHwnds()
    for activeHwnd in activeHwnds {
      if (!zOrderRanks.Has(activeHwnd) || zOrderRanks[shellHwnd] >= zOrderRanks[activeHwnd])
        return Map("passed", false, "detail", "Shell UI is not above every normal active window")
      for coverHwnd in coverHwnds {
        if (!zOrderRanks.Has(coverHwnd) || zOrderRanks[activeHwnd] >= zOrderRanks[coverHwnd])
          return Map("passed", false, "detail", "An active window is not above every cover")
      }
    }
    for coverHwnd in coverHwnds {
      for inactiveHwnd in inactiveHwnds {
        if (!zOrderRanks.Has(inactiveHwnd) || zOrderRanks[coverHwnd] >= zOrderRanks[inactiveHwnd])
          return Map("passed", false, "detail", "An inactive window is not below every cover")
      }
    }
    return Map("passed", true, "detail", this.backend.covers.Count " monitor cover(s), bands verified, covers did not activate")
  }

  _ReadZOrderRanks() {
    zOrderRanks := Map()
    windowList := WinGetList()
    for idx, windowHwnd in windowList
      zOrderRanks[windowHwnd] := idx
    return zOrderRanks
  }

  _BreakAndRepair(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0) {
      this.backend.CreateCovers()
      this._ApplyWorkspace(this.currentWorkspace)
    }
    brokenHwnd := this.currentWorkspace = "A" ? this.windowHwnds["normalB"] : this.windowHwnds["normalA"]
    this.repairTestPending := true
    this.repairEventObserved := false
    this.repairApplied := false
    this.ignoreEventsUntil := 0
    this.backend.PlaceAtTop(brokenHwnd)
    DllCall("SetForegroundWindow", "Ptr", brokenHwnd)
    this._Log("TEST", "z-order-broken:" brokenHwnd)
    SetTimer(this.repairCheckCallback, -800)
  }

  _HandleWinEvent(eventNumber, windowHwnd, objectId, childId) {
    if (this.cleanedUp || this.stackApplying || A_TickCount < this.ignoreEventsUntil || !this._IsTrackedWindow(windowHwnd))
      return
    eventName := eventNumber = WindowsCoverBackendPrototype.EVENT_SYSTEM_FOREGROUND ? "foreground" : "reorder"
    this.lastEvent := eventName ":" windowHwnd
    this._Log("WINEVENT", this.lastEvent)
    if (this.repairTestPending)
      this.repairEventObserved := true
    SetTimer(this.repairCallback, -80)
    this._RefreshStatus()
  }

  _RepairFromEvent() {
    if (!this.testWindowsReady || this.backend.covers.Count = 0)
      return
    verification := this._VerifyBands()
    if (!verification["passed"]) {
      this.repairApplied := this._ApplyStack()
      activeFocusHwnd := this.currentWorkspace = "A" ? this.windowHwnds["normalA"] : this.windowHwnds["normalB"]
      DllCall("SetForegroundWindow", "Ptr", activeFocusHwnd)
      this._Log("REPAIR", this.repairApplied ? "stack-restored" : "stack-failed")
    }
  }

  _CompleteRepairTest() {
    verification := this._VerifyBands()
    inactiveHwnd := this.currentWorkspace = "A" ? this.windowHwnds["normalB"] : this.windowHwnds["normalA"]
    inactiveStillForeground := DllCall("GetForegroundWindow", "Ptr") = inactiveHwnd
    repairPassed := this.repairEventObserved && this.repairApplied && verification["passed"] && !inactiveStillForeground
    detail := repairPassed ? "WinEvent observed and z-order/focus repaired" : "Event=" this._YesNo(this.repairEventObserved) ", repair=" this._YesNo(this.repairApplied) ", bands=" this._YesNo(verification["passed"])
    this.repairTestPending := false
    this._SetResult("repair", repairPassed, detail)
  }

  _StartUnsupportedTest(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0) {
      this.backend.CreateCovers()
      this._ApplyWorkspace(this.currentWorkspace)
    }
    this._CloseUnsupportedFixture()
    MonitorGetWorkArea(MonitorGetPrimary(), &workLeft, &workTop, &workRight, &workBottom)
    fixtureToken := A_TickCount
    fixtureTitle := "SW Unsupported " fixtureToken
    currentProcessId := DllCall("GetCurrentProcessId", "UInt")
    commandLine := '"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptFullPath '" --unresponsive-fixture "' fixtureToken '" "' currentProcessId '" "' (workLeft + 80) '" "' (workTop + 100) '"'
    try Run(commandLine, A_ScriptDir,, &fixturePid)
    catch Error as caughtError {
      this._SetResult("unsupported", false, "Could not start test window: " caughtError.Message)
      return
    }
    fixtureHwnd := WinWait(fixtureTitle,, 3)
    if (!fixtureHwnd) {
      this._SetResult("unsupported", false, "The unresponsive test window did not appear")
      try ProcessClose(fixturePid)
      return
    }
    this.unsupportedFixturePid := fixturePid
    this.unsupportedFixtureHwnd := fixtureHwnd
    this.unsupportedMonitorNumber := MonitorGetPrimary()
    this.unsupportedRectBefore := this.backend.GetWindowRect(fixtureHwnd)
    this.unsupportedOperationsBefore := this.backend.GetOperationCount(fixtureHwnd)
    PostMessage(CoverFeasibilityPrototype.WM_APP_HANG, 0, 0,, "ahk_id " fixtureHwnd)
    this.lastResultText.Text := "RUNNING - waiting for the test window to stop responding"
    this._Log("TEST", "unsupported-hang-started:" fixtureHwnd)
    SetTimer(this.unresponsiveCheckCallback, -500)
  }

  _CompleteUnsupportedTest() {
    if (!this.unsupportedFixtureHwnd || !WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
      this._SetResult("unsupported", false, "The test window closed too early")
      return
    }
    isResponsive := this.backend.IsResponsive(this.unsupportedFixtureHwnd)
    if (isResponsive) {
      this._SetResult("unsupported", false, "The test window still responds")
      return
    }
    operationsBeforeFallback := this.backend.GetOperationCount(this.unsupportedFixtureHwnd)
    this.backend.RemoveCover(this.unsupportedMonitorNumber)
    this.reducedIsolation := true
    this._ApplyStack()
    operationsAfterFallback := this.backend.GetOperationCount(this.unsupportedFixtureHwnd)
    rectAfter := this.backend.GetWindowRect(this.unsupportedFixtureHwnd)
    untouched := operationsBeforeFallback = this.unsupportedOperationsBefore && operationsAfterFallback = operationsBeforeFallback && this._RectsMatch(this.unsupportedRectBefore, rectAfter)
    coverRemoved := !this.backend.covers.Has(this.unsupportedMonitorNumber)
    unsupportedPassed := untouched && coverRemoved
    detail := unsupportedPassed ? "Unsupported window untouched; monitor cover removed; reduced isolation reported" : "The unsupported window changed or its monitor stayed covered"
    this._SetResult("unsupported", unsupportedPassed, detail)
    this._Log("UNSUPPORTED", unsupportedPassed ? "safe-fallback" : "fallback-failed")
  }

  _SimulateStackFailure(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0) {
      this.backend.CreateCovers()
      this._ApplyWorkspace(this.currentWorkspace)
    }
    this.backend.forceNextStackFailure := true
    stackSucceeded := this._ApplyStack()
    if (!stackSucceeded)
      this._RecoverAll("forced-stack-failure")
    recoveryPassed := !stackSucceeded && this.backend.covers.Count = 0 && this._AllManagedWindowsReachable()
    this._SetResult("failure", recoveryPassed, recoveryPassed ? "Failure detected; covers removed; test windows reachable" : "Safe recovery did not complete")
  }

  _RecoverAll(reason) {
    SetTimer(this.safetyRestoreCallback, 0)
    this.backend.RemoveAllCovers()
    if (this.testWindowsReady) {
      this.backend.SetTopmost(this.windowHwnds["topmostA"], true)
      this.backend.RestoreWindow(this.windowHwnds["fullscreenA"], this.recoveryFullscreenRect)
      for windowName in ["normalA", "normalB", "topmostA", "fullscreenA", "shell"] {
        windowHwnd := this.windowHwnds[windowName]
        DllCall("ShowWindow", "Ptr", windowHwnd, "Int", 5)
      }
    }
    this._Log("RECOVERY", reason)
    this.lastResultText.Text := "RECOVERED - " reason
    this._RefreshStatus()
  }

  _EmergencyButton(*) {
    this._RecoverAll("manual-button")
  }

  _EmergencyHotkey(*) {
    this._RecoverAll("Ctrl+Shift+F12")
  }

  _SafetyRestore() {
    if (this.backend.covers.Count > 0)
      this._RecoverAll("60-second-safety-timeout")
  }

  _ArmSafetyRestore() {
    SetTimer(this.safetyRestoreCallback, 0)
    SetTimer(this.safetyRestoreCallback, -60000)
  }

  _ReconcileStack() {
    if (this.cleanedUp || !this.testWindowsReady || this.stackApplying || this.repairTestPending || this.backend.covers.Count = 0)
      return
    verification := this._VerifyBands()
    if (!verification["passed"]) {
      repaired := this._ApplyStack()
      this._Log("RECONCILE", repaired ? "stack-restored" : "stack-failed")
      if (!repaired)
        this._RecoverAll("reconcile-failed")
    }
    this._RefreshStatus()
  }

  _FullscreenGeometryMatches() {
    actualRect := this.backend.GetWindowRect(this.windowHwnds["fullscreenA"])
    return this._RectsMatch(this.fullscreenRect, actualRect)
  }

  _RectsMatch(expectedRect, actualRect) {
    if (!IsObject(expectedRect) || !IsObject(actualRect))
      return false
    return Abs(expectedRect["left"] - actualRect["left"]) <= 2 && Abs(expectedRect["top"] - actualRect["top"]) <= 2 && Abs(expectedRect["width"] - actualRect["width"]) <= 2 && Abs(expectedRect["height"] - actualRect["height"]) <= 2
  }

  _AllManagedWindowsReachable() {
    for windowName in ["normalA", "normalB", "topmostA", "fullscreenA", "shell"] {
      windowHwnd := this.windowHwnds[windowName]
      if (!WinExist("ahk_id " windowHwnd) || !DllCall("IsWindowVisible", "Ptr", windowHwnd) || this.backend.IsMinimized(windowHwnd))
        return false
    }
    return true
  }

  _RequireTestWindows() {
    if (this.testWindowsReady)
      return true
    this.lastResultText.Text := "NOT READY - click Create / Reset first"
    return false
  }

  _IsTrackedWindow(windowHwnd) {
    if (!windowHwnd)
      return false
    for windowName, trackedHwnd in this.windowHwnds {
      if (trackedHwnd = windowHwnd)
        return true
    }
    return false
  }

  _SetResult(resultName, passed, detail) {
    this.results[resultName]["state"] := passed ? "PASS" : "FAIL"
    this.results[resultName]["detail"] := detail
    this.lastResultText.Text := (passed ? "PASS - " : "FAIL - ") detail
    this._Log("RESULT", resultName ":" this.results[resultName]["state"] ":" detail)
    this._RefreshStatus()
  }

  _RefreshStatus() {
    if (!IsObject(this.resultEdit))
      return
    resultText := "TEST RESULTS`r`n"
    for resultName in this.resultOrder {
      result := this.results[resultName]
      resultText .= result["label"] ": " result["state"] " - " result["detail"] "`r`n"
    }
    this.resultEdit.Value := resultText
    coverMonitors := ""
    for monitorNumber, coverRecord in this.backend.covers
      coverMonitors .= (coverMonitors = "" ? "" : ", ") monitorNumber
    if (coverMonitors = "")
      coverMonitors := "none"
    liveText := "LIVE STATE`r`n"
    liveText .= "Workspace: " this.currentWorkspace " | Covers: " this.backend.covers.Count "/" MonitorGetCount() " on monitor(s): " coverMonitors "`r`n"
    liveText .= "WinEvent hooks: " (this.eventHookReady ? "READY" : "FAILED") " | Last event: " this.lastEvent "`r`n"
    liveText .= "Reduced isolation: " this._YesNo(this.reducedIsolation) "`r`n"
    if (this.testWindowsReady) {
      liveText .= "TOPMOST A: " this._YesNo(this.backend.IsTopmost(this.windowHwnds["topmostA"])) " | FULLSCREEN A minimized: " this._YesNo(this.backend.IsMinimized(this.windowHwnds["fullscreenA"])) "`r`n"
      liveText .= "Tracked z-order ranks: " this._GetTrackedZOrderText() "`r`n"
    }
    liveText .= "Emergency: Ctrl+Shift+F12"
    this.liveEdit.Value := liveText
  }

  _GetTrackedZOrderText() {
    zOrderRanks := this._ReadZOrderRanks()
    rankText := ""
    for windowName in ["shell", "fullscreenA", "normalA", "normalB", "topmostA"] {
      windowHwnd := this.windowHwnds[windowName]
      rankValue := zOrderRanks.Has(windowHwnd) ? zOrderRanks[windowHwnd] : "missing"
      rankText .= (rankText = "" ? "" : ", ") windowName "=" rankValue
    }
    for monitorNumber, coverRecord in this.backend.covers {
      coverHwnd := coverRecord["hwnd"]
      rankValue := zOrderRanks.Has(coverHwnd) ? zOrderRanks[coverHwnd] : "missing"
      rankText .= ", cover" monitorNumber "=" rankValue
    }
    return rankText
  }

  _YesNo(value) {
    return value ? "YES" : "NO"
  }

  _RemoveTestWindows() {
    SetTimer(this.safetyRestoreCallback, 0)
    this.backend.RemoveAllCovers()
    this._CloseUnsupportedFixture()
    for windowName, fixtureGui in this.fixtureGuis
      try fixtureGui.Destroy()
    this.fixtureGuis := Map()
    this.windowHwnds := Map()
    this.testWindowsReady := false
  }

  _CloseUnsupportedFixture() {
    if (this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd))
      try PostMessage(0x0010, 0, 0,, "ahk_id " this.unsupportedFixtureHwnd)
    if (this.unsupportedFixturePid && ProcessExist(this.unsupportedFixturePid)) {
      Sleep(100)
      if (ProcessExist(this.unsupportedFixturePid))
        try ProcessClose(this.unsupportedFixturePid)
    }
    this.unsupportedFixturePid := 0
    this.unsupportedFixtureHwnd := 0
    this.unsupportedMonitorNumber := 0
    this.unsupportedRectBefore := 0
    this.unsupportedOperationsBefore := 0
  }

  _Log(eventName, value) {
    logLine := A_TickCount "|" eventName "|" value "`r`n"
    this.pendingLogText .= logLine
    this.visibleLogText .= logLine
    if (StrLen(this.visibleLogText) > 14000)
      this.visibleLogText := SubStr(this.visibleLogText, -12000)
    if (IsObject(this.logEdit)) {
      this.logEdit.Value := this.visibleLogText
      SendMessage(0x0115, 7, 0, this.logEdit)
    }
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

  _OnExit(exitReason, exitCode) {
    this.Cleanup()
  }

  Cleanup() {
    if (this.cleanedUp)
      return
    this.cleanedUp := true
    SetTimer(this.reconcileCallback, 0)
    SetTimer(this.repairCallback, 0)
    SetTimer(this.repairCheckCallback, 0)
    SetTimer(this.unresponsiveCheckCallback, 0)
    SetTimer(this.safetyRestoreCallback, 0)
    SetTimer(this.logFlushCallback, 0)
    try Hotkey("^+F12", "Off")
    this.backend.StopWinEvents()
    this._RecoverAll("exit-cleanup")
    this._RemoveTestWindows()
    this._Log("CLEANUP", "complete")
    this._FlushLogQueue()
  }
}

RunUnresponsiveFixture(fixtureToken, parentPid, windowLeft, windowTop) {
  global unsupportedFixtureGui
  global unsupportedHangCallback
  global unsupportedParentTimerCallback
  unsupportedFixtureGui := Gui("+Resize", "SW Unsupported " fixtureToken)
  unsupportedFixtureGui.BackColor := "5B2020"
  unsupportedFixtureGui.SetFont("s16 Bold cFFFFFF", "Segoe UI")
  unsupportedFixtureGui.Add("Text", "Center w380 r5 BackgroundTrans", "TEST WINDOW`nTHIS WINDOW WILL STOP RESPONDING FOR 8 SECONDS")
  unsupportedFixtureGui.OnEvent("Close", (*) => ExitApp())
  unsupportedHangCallback := (*) => DllCall("Sleep", "UInt", 8000)
  OnMessage(CoverFeasibilityPrototype.WM_APP_HANG, unsupportedHangCallback)
  unsupportedParentTimerCallback := (*) => ProcessExist(parentPid) ? 0 : ExitApp()
  SetTimer(unsupportedParentTimerCallback, 1000)
  unsupportedFixtureGui.Show("NA x" windowLeft " y" windowTop " w420 h220")
}

if (A_Args.Length >= 1 && A_Args[1] = "--unresponsive-fixture") {
  RunUnresponsiveFixture(A_Args[2], A_Args[3] + 0, A_Args[4] + 0, A_Args[5] + 0)
} else {
  smokeMode := A_Args.Length >= 1 && A_Args[1] = "--smoke"
  logPath := A_Args.Length >= 2 ? A_Args[2] : A_ScriptDir "\tmp\SyntheticWorkspacesCoverPrototypeManual.log"
  prototype := CoverFeasibilityPrototype(smokeMode, logPath)
  if (smokeMode) {
    smokeExitCallback := (*) => ExitApp()
    SetTimer(smokeExitCallback, -250)
  }
}

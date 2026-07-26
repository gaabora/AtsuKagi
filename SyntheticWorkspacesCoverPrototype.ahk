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
  static SWP_NOZORDER := 0x0004
  static SWP_NOACTIVATE := 0x0010
  static SWP_NOOWNERZORDER := 0x0200
  static SWP_NOSENDCHANGING := 0x0400
  static WS_EX_TOPMOST := 0x00000008
  static WM_MOUSEACTIVATE := 0x0021
  static MA_NOACTIVATEANDEAT := 4
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

  GetCoverHwnd(monitorNumber) {
    return this.covers.Has(monitorNumber) ? this.covers[monitorNumber]["hwnd"] : 0
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

  MoveOffscreenSynchronously(windowHwnd, offscreenLeft, offscreenTop) {
    if (!windowHwnd)
      return false
    this._RecordOperation(windowHwnd)
    flags := WindowsCoverBackendPrototype.SWP_NOSIZE | WindowsCoverBackendPrototype.SWP_NOZORDER | WindowsCoverBackendPrototype.SWP_NOACTIVATE | WindowsCoverBackendPrototype.SWP_NOOWNERZORDER | WindowsCoverBackendPrototype.SWP_NOSENDCHANGING
    return DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", 0, "Int", offscreenLeft, "Int", offscreenTop, "Int", 0, "Int", 0, "UInt", flags)
  }

  MoveToRect(windowHwnd, windowRect) {
    if (!windowHwnd || !IsObject(windowRect))
      return false
    this._RecordOperation(windowHwnd)
    flags := WindowsCoverBackendPrototype.SWP_NOZORDER | WindowsCoverBackendPrototype.SWP_NOACTIVATE | WindowsCoverBackendPrototype.SWP_NOOWNERZORDER
    return DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", 0, "Int", windowRect["left"], "Int", windowRect["top"], "Int", windowRect["width"], "Int", windowRect["height"], "UInt", flags)
  }

  GetOffscreenPosition() {
    virtualLeft := DllCall("GetSystemMetrics", "Int", 76)
    virtualTop := DllCall("GetSystemMetrics", "Int", 77)
    virtualWidth := DllCall("GetSystemMetrics", "Int", 78)
    return Map("left", virtualLeft + virtualWidth + 100, "top", virtualTop + 100)
  }

  IsRectOutsideVirtualDesktop(windowRect) {
    if (!IsObject(windowRect))
      return false
    virtualLeft := DllCall("GetSystemMetrics", "Int", 76)
    virtualTop := DllCall("GetSystemMetrics", "Int", 77)
    virtualRight := virtualLeft + DllCall("GetSystemMetrics", "Int", 78)
    virtualBottom := virtualTop + DllCall("GetSystemMetrics", "Int", 79)
    windowRight := windowRect["left"] + windowRect["width"]
    windowBottom := windowRect["top"] + windowRect["height"]
    return windowRight <= virtualLeft || windowRect["left"] >= virtualRight || windowBottom <= virtualTop || windowRect["top"] >= virtualBottom
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
    if (!windowHwnd || !DllCall("IsWindow", "Ptr", windowHwnd))
      return false
    try {
      return (WinGetExStyle("ahk_id " windowHwnd) & WindowsCoverBackendPrototype.WS_EX_TOPMOST) != 0
    } catch {
      return false
    }
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

  _SetWindowPos(windowHwnd, insertAfterHwnd, allowForcedFailure := true, suppressChanging := false) {
    if (allowForcedFailure && this.forceNextStackFailure) {
      this.forceNextStackFailure := false
      this._Log("STACK", "forced-failure")
      return false
    }
    this._RecordOperation(windowHwnd)
    flags := WindowsCoverBackendPrototype.SWP_NOMOVE | WindowsCoverBackendPrototype.SWP_NOSIZE | WindowsCoverBackendPrototype.SWP_NOACTIVATE | WindowsCoverBackendPrototype.SWP_NOOWNERZORDER
    if (suppressChanging)
      flags |= WindowsCoverBackendPrototype.SWP_NOSENDCHANGING
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
  static UNRESPONSIVE_DURATION_MS := 12000
  static MAX_RECONCILE_ATTEMPTS := 2
  static OFFSCREEN_HELPER_TIMEOUT_MS := 500

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
    this.repairScheduled := false
    this.repairStartedAt := 0
    this.lastRepairDurationMs := 0
    this.stepBeforeRepair := ""
    this.reconcileAttemptCount := 0
    this.lastEvent := "none"
    this.specialStatePrepared := false
    this.unsupportedFixturePid := 0
    this.unsupportedFixtureHwnd := 0
    this.unsupportedMonitorNumber := 0
    this.unsupportedRectBefore := 0
    this.unsupportedSavedTopmost := false
    this.unsupportedWorkspace := "A"
    this.unsupportedRecovered := false
    this.unsupportedTestRunning := false
    this.unsupportedVerified := false
    this.unsupportedHangUntil := 0
    this.unsupportedOffscreenTarget := 0
    this.unsupportedOffscreenHelperPid := 0
    this.unsupportedOffscreenPending := false
    this.unsupportedOffscreenForegroundBefore := 0
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
    this.unresponsiveCountdownCallback := this._UpdateUnsupportedCountdown.Bind(this)
    this.unsupportedOffscreenCheckCallback := this._CompleteUnsupportedOffscreen.Bind(this)
    this.reconcileCallback := this._ReconcileStack.Bind(this)
    this.logFlushCallback := this._FlushLogQueue.Bind(this)
    this.safetyRestoreCallback := this._SafetyRestore.Bind(this)
    this.emergencyCallback := this._EmergencyHotkey.Bind(this)
    this.mouseActivateCallback := this._HandleMouseActivate.Bind(this)
    this.exitCallback := this._OnExit.Bind(this)
    this.backend := WindowsCoverBackendPrototype(this.logCallback)
    this._CreatePanel()
    this.eventHookReady := this.backend.StartWinEvents(this.winEventCallback)
    OnMessage(WindowsCoverBackendPrototype.WM_MOUSEACTIVATE, this.mouseActivateCallback)
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
    this.results["unsupported"] := Map("label", "Unsupported offscreen fallback", "state", "NOT RUN", "detail", "Start unresponsive window")
    this.results["failure"] := Map("label", "Failed-stack recovery", "state", "NOT RUN", "detail", "Simulate stack failure")
    this.results["cleanup"] := Map("label", "Exit cleanup", "state", "MANUAL", "detail", "Close and reopen, then check the desktop")
  }

  _CreatePanel() {
    instructions := [
      "Manual TEST-4 cover feasibility prototype. It touches only the test windows that it creates.",
      "1. Create / Reset: expect one blue cover per monitor, Workspace A above it, Workspace B below it, and SHELL UI above normal active windows. Clicking a cover must do nothing and cause no blink.",
      "2. Break z-order: Workspace B is activated on purpose. A short flash is expected; repair must finish within one second.",
      "3. Show special A: TOPMOST A and FULLSCREEN A appear only for this test. Clicking fullscreen must not hide or blink the SHELL UI or main panel.",
      "4. Switch to B: expect TOPMOST A to lose topmost and FULLSCREEN A to minimize.",
      "5. Switch to A: expect topmost and fullscreen state to return.",
      "6. Start unresponsive window: a helper gets 500 ms to move the frozen TOPMOST fixture outside the virtual desktop without changing focus, size, or topmost. After response, the fixture returns to its old position in Workspace A.",
      "7. Simulate stack failure: every cover must disappear and all test windows must stay reachable.",
      "8. Close and reopen: no cover or changed test-window state may remain.",
      "Emergency: press Ctrl+Shift+F12 at any time. Covers also auto-remove after 60 seconds. Abort test removes all prototype windows."
    ]
    instructionText := ""
    for instructionLine in instructions
      instructionText .= instructionLine "`n"
    this.panelGui := Gui("+AlwaysOnTop +Resize", "SyntheticWorkspaces cover feasibility prototype")
    this.panelGui.OnEvent("Close", (*) => ExitApp())
    this.panelGui.SetFont("s9", "Segoe UI")
    this.panelGui.Add("Text", "w930", instructionText)
    this.panelGui.SetFont("s14 Bold", "Segoe UI")
    this.currentStepText := this.panelGui.Add("Text", "xm w930 c8A2BE2", "CURRENT STEP 1/8 - click Create / Reset")
    this.panelGui.SetFont("s9 Norm", "Segoe UI")
    this.lastResultText := this.panelGui.Add("Text", "xm w930 c0066CC", "READY - create the test windows")
    this.resultEdit := this.panelGui.Add("Edit", "xm ReadOnly w930 r8 -Wrap")
    this.liveEdit := this.panelGui.Add("Edit", "xm ReadOnly w930 r8 -Wrap")
    createButton := this.panelGui.Add("Button", "xm w145", "Create / Reset")
    createButton.OnEvent("Click", this._CreateOrReset.Bind(this))
    applyAButton := this.panelGui.Add("Button", "x+8 yp w120", "Apply A")
    applyAButton.OnEvent("Click", this._ApplyWorkspaceA.Bind(this))
    breakButton := this.panelGui.Add("Button", "x+8 yp w135", "Break z-order")
    breakButton.OnEvent("Click", this._BreakAndRepair.Bind(this))
    prepareSpecialButton := this.panelGui.Add("Button", "x+8 yp w145", "Show special A")
    prepareSpecialButton.OnEvent("Click", this._PrepareSpecialWorkspaceA.Bind(this))
    switchBButton := this.panelGui.Add("Button", "x+8 yp w110", "Switch to B")
    switchBButton.OnEvent("Click", this._SwitchWorkspaceB.Bind(this))
    switchAButton := this.panelGui.Add("Button", "x+8 yp w110", "Switch to A")
    switchAButton.OnEvent("Click", this._SwitchWorkspaceA.Bind(this))
    unsupportedButton := this.panelGui.Add("Button", "xm w190", "Start unresponsive window")
    unsupportedButton.OnEvent("Click", this._StartUnsupportedTest.Bind(this))
    failureButton := this.panelGui.Add("Button", "x+8 yp w175", "Simulate stack failure")
    failureButton.OnEvent("Click", this._SimulateStackFailure.Bind(this))
    emergencyButton := this.panelGui.Add("Button", "x+8 yp w140", "Remove covers")
    emergencyButton.OnEvent("Click", this._EmergencyButton.Bind(this))
    abortButton := this.panelGui.Add("Button", "x+8 yp w120", "Abort test")
    abortButton.OnEvent("Click", this._AbortTest.Bind(this))
    this.panelGui.Add("Text", "xm w930", "Log file: " this.logPath)
    this.logStatusText := this.panelGui.Add("Text", "xm w930", "File log: waiting for data")
    this.logEdit := this.panelGui.Add("Edit", "xm ReadOnly w930 r10 -Wrap")
  }

  _CreateOrReset(*) {
    this._RemoveTestWindows()
    this._InitializeResults()
    this.currentWorkspace := "A"
    this.specialStatePrepared := false
    this.reconcileAttemptCount := 0
    MonitorGetWorkArea(MonitorGetPrimary(), &workLeft, &workTop, &workRight, &workBottom)
    panelWidth := 960
    panelLeft := Min(workRight - panelWidth, workLeft + 20)
    this.panelGui.Show("x" panelLeft " y" (workTop + 20) " w" panelWidth)
    this.fixtureGuis["normalA"] := this._CreateTestWindow("normalA", "Workspace A - ACTIVE", "2F7D32", "WORKSPACE A`nACTIVE NORMAL WINDOW")
    this.fixtureGuis["normalB"] := this._CreateTestWindow("normalB", "Workspace B - INACTIVE", "8A3B3B", "WORKSPACE B`nINACTIVE NORMAL WINDOW")
    this.fixtureGuis["topmostA"] := this._CreateTestWindow("topmostA", "Workspace A - TOPMOST", "6A3D9A", "WORKSPACE A`nSAVED TOPMOST WINDOW", "+AlwaysOnTop")
    this.fixtureGuis["fullscreenA"] := this._CreateTestWindow("fullscreenA", "Workspace A - FULLSCREEN", "1E5C73", "WORKSPACE A`nFULLSCREEN WINDOW", "-Caption +ToolWindow")
    this.fixtureGuis["shell"] := this._CreateTestWindow("shell", "Haribol shell UI sample", "B56A00", "HARIBOL SHELL UI`nMUST STAY ABOVE NORMAL ACTIVE WINDOWS", "+ToolWindow +E0x08000000")
    this.windowHwnds["normalA"] := this.fixtureGuis["normalA"].Hwnd
    this.windowHwnds["normalB"] := this.fixtureGuis["normalB"].Hwnd
    this.windowHwnds["topmostA"] := this.fixtureGuis["topmostA"].Hwnd
    this.windowHwnds["fullscreenA"] := this.fixtureGuis["fullscreenA"].Hwnd
    this.windowHwnds["shell"] := this.fixtureGuis["shell"].Hwnd
    this.fixtureGuis["normalA"].Show("NA x" (workLeft + 70) " y" (workTop + 220) " w360 h220")
    this.fixtureGuis["normalB"].Show("NA x" (workLeft + 470) " y" (workTop + 240) " w360 h220")
    this.fixtureGuis["shell"].Show("NA x" (workRight - 380) " y" (workTop + 100) " w340 h130")
    MonitorGet(MonitorGetPrimary(), &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
    this.topmostRect := Map("left", Max(workLeft + 20, workRight - 380), "top", workTop + 470, "width", 330, "height", 170)
    this.fullscreenRect := Map("left", monitorLeft, "top", monitorTop, "width", monitorRight - monitorLeft, "height", monitorBottom - monitorTop)
    this.recoveryFullscreenRect := Map("left", workLeft + 420, "top", workTop + 470, "width", 380, "height", 220)
    this.testWindowsReady := true
    this.backend.CreateCovers()
    this._ApplyWorkspace("A")
    coverResult := this._VerifyBands()
    this._SetResult("covers", coverResult["passed"], coverResult["detail"])
    this._SetCurrentStep(coverResult["passed"] ? "CURRENT STEP 2/8 - click Break z-order" : "STEP 1 FAILED - click Create / Reset again")
    this._ArmSafetyRestore()
    this._Log("TEST", "created-and-applied-A")
  }

  _CreateTestWindow(windowName, title, color, label, options := "") {
    testGui := Gui(options, title)
    testGui.BackColor := color
    testGui.SetFont("s18 Bold cFFFFFF", "Segoe UI")
    testGui.Add("Text", "Center w320 r4 BackgroundTrans", label)
    testGui.OnEvent("Close", this._HandleTestWindowClose.Bind(this, windowName))
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
    this._SetCurrentStep(coverResult["passed"] ? "CURRENT STEP 2/8 - click Break z-order" : "STEP 1 FAILED - click Apply A again")
    this._ArmSafetyRestore()
  }

  _PrepareSpecialWorkspaceA(*) {
    if (!this._RequireTestWindows())
      return
    if (this.backend.covers.Count = 0)
      this.backend.CreateCovers()
    this.specialStatePrepared := true
    this.fixtureGuis["topmostA"].Show("NA x" this.topmostRect["left"] " y" this.topmostRect["top"] " w" this.topmostRect["width"] " h" this.topmostRect["height"])
    this.fixtureGuis["fullscreenA"].Show("NA x" this.fullscreenRect["left"] " y" this.fullscreenRect["top"] " w" this.fullscreenRect["width"] " h" this.fullscreenRect["height"])
    workspaceApplied := this._ApplyWorkspace("A")
    specialPassed := workspaceApplied && this.backend.IsTopmost(this.windowHwnds["topmostA"]) && !this.backend.IsMinimized(this.windowHwnds["fullscreenA"]) && this._FullscreenGeometryMatches() && this._PanelIsReachable()
    if (!specialPassed && this.backend.covers.Count > 0)
      this._RecoverAll("special-prepare-failed")
    this.lastResultText.Text := specialPassed ? "READY - special A windows are visible; the main panel must remain usable" : "FAIL - special A state did not apply; covers were removed"
    this._SetCurrentStep(specialPassed ? "CURRENT STEP 4/8 - click Switch to B" : "STEP 3 FAILED - click Create / Reset")
    this._ArmSafetyRestore()
    this._KeepPanelReachable()
    this._RefreshStatus()
  }

  _SwitchWorkspaceB(*) {
    if (!this._RequireTestWindows())
      return
    ; if (!this.specialStatePrepared) {
    ;   this.lastResultText.Text := "NOT READY - click Show special A first"
    ;   this._SetCurrentStep("CURRENT STEP 3/8 - click Show special A")
    ;   this._KeepPanelReachable()
    ;   return
    ; }
    if (this.backend.covers.Count = 0)
      this.backend.CreateCovers()
    this._ApplyWorkspace("B")
    specialPassed := !this.backend.IsTopmost(this.windowHwnds["topmostA"]) && this.backend.IsMinimized(this.windowHwnds["fullscreenA"])
    this._SetResult("specialInactive", specialPassed, specialPassed ? "Topmost cleared and fullscreen minimized" : "Expected topmost OFF and fullscreen minimized")
    this._SetCurrentStep(specialPassed ? "CURRENT STEP 5/8 - click Switch to A" : "STEP 4 FAILED - click Switch to B again")
    this._ArmSafetyRestore()
  }

  _SwitchWorkspaceA(*) {
    if (!this._RequireTestWindows())
      return
    ; if (!this.specialStatePrepared) {
    ;   this.lastResultText.Text := "NOT READY - click Show special A first"
    ;   this._SetCurrentStep("CURRENT STEP 3/8 - click Show special A")
    ;   this._KeepPanelReachable()
    ;   return
    ; }
    if (this.backend.covers.Count = 0)
      this.backend.CreateCovers()
    this._ApplyWorkspace("A")
    specialPassed := this.backend.IsTopmost(this.windowHwnds["topmostA"]) && !this.backend.IsMinimized(this.windowHwnds["fullscreenA"]) && this._FullscreenGeometryMatches()
    this._SetResult("specialRestore", specialPassed, specialPassed ? "Saved topmost and fullscreen state restored" : "Topmost or fullscreen state did not restore")
    this._SetCurrentStep(specialPassed ? "CURRENT STEP 6/8 - click Start unresponsive window" : "STEP 5 FAILED - click Switch to A again")
    this._ArmSafetyRestore()
  }

  _ApplyWorkspace(workspaceName) {
    this.currentWorkspace := workspaceName
    if (this.specialStatePrepared && workspaceName = "A") {
      this.backend.RestoreWindow(this.windowHwnds["fullscreenA"], this.fullscreenRect)
      this.backend.SetTopmost(this.windowHwnds["topmostA"], true)
    } else if (this.specialStatePrepared) {
      this.backend.SetTopmost(this.windowHwnds["topmostA"], false)
      this.backend.MinimizeWindow(this.windowHwnds["fullscreenA"])
    }
    if (this.unsupportedRecovered && this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd))
      this.backend.SetTopmost(this.unsupportedFixtureHwnd, workspaceName = this.unsupportedWorkspace && this.unsupportedSavedTopmost)
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
      stackSucceeded := this.backend.SetTopmost(shellHwnd, true)
      upperHwnd := 0
      for idx, activeHwnd in activeHwnds {
        if (stackSucceeded) {
          if (idx = 1)
            stackSucceeded := this.backend.PlaceAtTop(activeHwnd)
          else
            stackSucceeded := this.backend.PlaceBelow(activeHwnd, upperHwnd)
        }
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
      this.ignoreEventsUntil := A_TickCount + 500
      this._KeepPanelReachable()
    }
    return stackSucceeded
  }

  _GetActiveNormalHwnds() {
    if (this.currentWorkspace = "A") {
      activeHwnds := [this.windowHwnds["normalA"]]
      if (this.specialStatePrepared)
        activeHwnds.InsertAt(1, this.windowHwnds["fullscreenA"])
    } else
      activeHwnds := [this.windowHwnds["normalB"]]
    if (this.unsupportedRecovered && this.currentWorkspace = this.unsupportedWorkspace && !this.unsupportedSavedTopmost)
      activeHwnds.Push(this.unsupportedFixtureHwnd)
    return activeHwnds
  }

  _GetInactiveHwnds() {
    if (this.currentWorkspace = "A")
      inactiveHwnds := [this.windowHwnds["normalB"]]
    else if (this.specialStatePrepared)
      inactiveHwnds := [this.windowHwnds["normalA"], this.windowHwnds["topmostA"], this.windowHwnds["fullscreenA"]]
    else
      inactiveHwnds := [this.windowHwnds["normalA"]]
    if (this.unsupportedRecovered && this.currentWorkspace != this.unsupportedWorkspace)
      inactiveHwnds.Push(this.unsupportedFixtureHwnd)
    return inactiveHwnds
  }

  _IsInactiveWorkspaceHwnd(windowHwnd) {
    for inactiveHwnd in this._GetInactiveHwnds() {
      if (inactiveHwnd = windowHwnd)
        return true
    }
    return false
  }

  _VerifyBands() {
    if (!this.testWindowsReady)
      return Map("passed", false, "detail", "Test windows do not exist")
    if (!this._PanelIsReachable())
      return Map("passed", false, "detail", "Main panel is not reachable above the test windows")
    unavailableWindowName := this._GetUnavailableWindowName()
    if (unavailableWindowName != "")
      return Map("passed", false, "detail", "Test window is missing or hidden: " unavailableWindowName)
    if (!this.backend.VerifyCoverGeometry() || !this.backend.lastCoverCreateKeptForeground)
      return Map("passed", false, "detail", "Cover count, geometry, visibility, or NoActivate check failed")
    zOrderRanks := this._ReadZOrderRanks()
    shellHwnd := this.windowHwnds["shell"]
    if (!this.backend.IsTopmost(shellHwnd))
      return Map("passed", false, "detail", "Shell UI is not in its protected topmost band")
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
    if (this.unsupportedRecovered) {
      expectedTopmost := this.currentWorkspace = this.unsupportedWorkspace && this.unsupportedSavedTopmost
      if (this.backend.IsTopmost(this.unsupportedFixtureHwnd) != expectedTopmost)
        return Map("passed", false, "detail", "Recovered fixture topmost state does not match its workspace")
      if (expectedTopmost) {
        if (!zOrderRanks.Has(this.unsupportedFixtureHwnd) || zOrderRanks[shellHwnd] >= zOrderRanks[this.unsupportedFixtureHwnd])
          return Map("passed", false, "detail", "Shell UI is not above the recovered topmost fixture")
        for coverHwnd in coverHwnds {
          if (zOrderRanks[this.unsupportedFixtureHwnd] >= zOrderRanks[coverHwnd])
            return Map("passed", false, "detail", "Recovered topmost fixture is not above every cover")
        }
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

  _KeepPanelReachable() {
    if (IsObject(this.panelGui) && DllCall("IsWindowVisible", "Ptr", this.panelGui.Hwnd))
      this.backend.SetTopmost(this.panelGui.Hwnd, true)
  }

  _PanelIsReachable() {
    if (!IsObject(this.panelGui) || !DllCall("IsWindowVisible", "Ptr", this.panelGui.Hwnd) || !this.backend.IsTopmost(this.panelGui.Hwnd))
      return false
    zOrderRanks := this._ReadZOrderRanks()
    if (!zOrderRanks.Has(this.panelGui.Hwnd))
      return false
    shellHwnd := this.windowHwnds["shell"]
    if (zOrderRanks.Has(shellHwnd) && zOrderRanks[this.panelGui.Hwnd] >= zOrderRanks[shellHwnd])
      return false
    topmostHwnd := this.windowHwnds["topmostA"]
    if (this.specialStatePrepared && zOrderRanks.Has(topmostHwnd) && zOrderRanks[this.panelGui.Hwnd] >= zOrderRanks[topmostHwnd])
      return false
    if (this.unsupportedRecovered && this.unsupportedSavedTopmost && this.currentWorkspace = this.unsupportedWorkspace && zOrderRanks.Has(this.unsupportedFixtureHwnd) && zOrderRanks[this.panelGui.Hwnd] >= zOrderRanks[this.unsupportedFixtureHwnd])
      return false
    return true
  }

  _GetUnavailableWindowName() {
    if (!this.testWindowsReady)
      return ""
    for windowName in ["normalA", "normalB", "topmostA", "fullscreenA", "shell"] {
      if (!this.windowHwnds.Has(windowName) || !DllCall("IsWindow", "Ptr", this.windowHwnds[windowName]))
        return windowName
    }
    requiredVisibleNames := ["normalA", "normalB", "shell"]
    if ((this.unsupportedTestRunning || this.unsupportedRecovered) && (!this.unsupportedFixtureHwnd || !DllCall("IsWindow", "Ptr", this.unsupportedFixtureHwnd)))
      return "unsupported"
    if ((this.unsupportedTestRunning || this.unsupportedRecovered) && !DllCall("IsWindowVisible", "Ptr", this.unsupportedFixtureHwnd))
      return "unsupported"
    if (this.specialStatePrepared) {
      requiredVisibleNames.Push("topmostA")
      requiredVisibleNames.Push("fullscreenA")
    }
    for windowName in requiredVisibleNames {
      if (!DllCall("IsWindowVisible", "Ptr", this.windowHwnds[windowName]))
        return windowName
    }
    return ""
  }

  _HandleTestWindowClose(windowName, *) {
    if (this.cleanedUp || !this.testWindowsReady)
      return
    this._FailForTestWindow(windowName)
  }

  _FailForTestWindow(windowName) {
    if (!this.testWindowsReady)
      return
    detail := "Test window closed or disappeared: " windowName "; covers removed"
    this._Log("WINDOW", "unavailable:" windowName)
    this._RemoveTestWindows()
    this._SetResult("covers", false, detail)
    this._SetCurrentStep("TEST WINDOW CLOSED - click Create / Reset to start again")
    this._KeepPanelReachable()
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
    this.repairScheduled := false
    SetTimer(this.repairCallback, 0)
    this._SetCurrentStep("RUNNING STEP 2/8 - waiting for WinEvent repair")
    this.ignoreEventsUntil := 0
    this.backend.PlaceAtTop(brokenHwnd)
    DllCall("SetForegroundWindow", "Ptr", brokenHwnd)
    this._Log("TEST", "z-order-broken:" brokenHwnd)
    SetTimer(this.repairCheckCallback, -900)
  }

  _HandleMouseActivate(wParam, lParam, messageNumber, windowHwnd) {
    if (this.cleanedUp || !this.backend.IsCoverHwnd(windowHwnd))
      return
    this._Log("COVER_CLICK", "blocked:" windowHwnd)
    return WindowsCoverBackendPrototype.MA_NOACTIVATEANDEAT
  }

  _HandleWinEvent(eventNumber, windowHwnd, objectId, childId) {
    if (this.cleanedUp || this.stackApplying || this.backend.covers.Count = 0 || A_TickCount < this.ignoreEventsUntil || !this._IsTrackedWindow(windowHwnd))
      return
    eventName := eventNumber = WindowsCoverBackendPrototype.EVENT_SYSTEM_FOREGROUND ? "foreground" : "reorder"
    this.lastEvent := eventName ":" windowHwnd
    this._Log("WINEVENT", this.lastEvent)
    if (this.repairTestPending)
      this.repairEventObserved := true
    if (!this.repairScheduled) {
      this.repairScheduled := true
      this.repairStartedAt := A_TickCount
      this.stepBeforeRepair := this.currentStepText.Text
      this.currentStepText.Text := "REPAIRING - detected z-order change"
      SetTimer(this.repairCallback, -80)
    }
    this._RefreshStatus()
  }

  _RepairFromEvent() {
    this.repairScheduled := false
    if (!this.testWindowsReady || this.backend.covers.Count = 0)
      return
    unavailableWindowName := this._GetUnavailableWindowName()
    if (unavailableWindowName != "") {
      this._FailForTestWindow(unavailableWindowName)
      return
    }
    verification := this._VerifyBands()
    if (!verification["passed"]) {
      foregroundHwnd := DllCall("GetForegroundWindow", "Ptr")
      if (this._IsInactiveWorkspaceHwnd(foregroundHwnd)) {
        activeFocusHwnd := this._GetActiveNormalHwnds()[1]
        DllCall("SetForegroundWindow", "Ptr", activeFocusHwnd)
      }
      this.repairApplied := this._ApplyStack()
      this.lastRepairDurationMs := A_TickCount - this.repairStartedAt
      if (!this.testWindowsReady)
        return
      unavailableWindowName := this._GetUnavailableWindowName()
      if (unavailableWindowName != "") {
        this._FailForTestWindow(unavailableWindowName)
        return
      }
      verificationAfter := this._VerifyBands()
      repairSucceeded := this.repairApplied && verificationAfter["passed"]
      if (repairSucceeded)
        this.reconcileAttemptCount := 0
      else
        this.reconcileAttemptCount += 1
      this._Log("REPAIR", (repairSucceeded ? "stack-restored:" : "stack-failed:") this.lastRepairDurationMs "ms;attempt=" this.reconcileAttemptCount)
      if (!repairSucceeded && this.reconcileAttemptCount >= CoverFeasibilityPrototype.MAX_RECONCILE_ATTEMPTS) {
        this._StopForUnstableStack("event-repair-limit")
        return
      }
    }
    if (this.stepBeforeRepair != "")
      this.currentStepText.Text := this.stepBeforeRepair
    this.stepBeforeRepair := ""
  }

  _CompleteRepairTest() {
    verification := this._VerifyBands()
    inactiveHwnd := this.currentWorkspace = "A" ? this.windowHwnds["normalB"] : this.windowHwnds["normalA"]
    inactiveStillForeground := DllCall("GetForegroundWindow", "Ptr") = inactiveHwnd
    repairPassed := this.repairEventObserved && this.repairApplied && verification["passed"] && !inactiveStillForeground && this.lastRepairDurationMs > 0 && this.lastRepairDurationMs <= 1000
    detail := repairPassed ? "WinEvent observed; z-order/focus repaired in " this.lastRepairDurationMs " ms" : "Event=" this._YesNo(this.repairEventObserved) ", repair=" this._YesNo(this.repairApplied) ", bands=" this._YesNo(verification["passed"]) ", time=" this.lastRepairDurationMs " ms"
    this.repairTestPending := false
    this._SetResult("repair", repairPassed, detail)
    if (!repairPassed)
      this._RecoverAll("repair-test-failed")
    this._SetCurrentStep(repairPassed ? "CURRENT STEP 3/8 - click Show special A" : "STEP 2 FAILED - covers removed; click Apply A or Create / Reset")
  }

  _StopForUnstableStack(reason) {
    if (this.backend.covers.Count = 0)
      return
    detail := "Z-order did not stabilize after " CoverFeasibilityPrototype.MAX_RECONCILE_ATTEMPTS " attempts; covers removed"
    this._SetResult("repair", false, detail)
    this._RecoverAll(reason)
    this._SetCurrentStep("Z-ORDER FAILED - click Create / Reset to start again")
  }

  _StartUnsupportedTest(*) {
    if (!this._RequireTestWindows())
      return
    if (this.unsupportedTestRunning && this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
      this._UpdateUnsupportedCountdown(true)
      this._Log("UNSUPPORTED", "test-already-running")
      return
    }
    this._CloseUnsupportedFixture()
    if (this.backend.covers.Count = 0) {
      this.backend.CreateCovers()
      this._ApplyWorkspace(this.currentWorkspace)
    }
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
    this.unsupportedOffscreenTarget := this.backend.GetOffscreenPosition()
    this.unsupportedSavedTopmost := this.backend.IsTopmost(fixtureHwnd)
    this.unsupportedWorkspace := this.currentWorkspace
    this.unsupportedRecovered := false
    this.unsupportedTestRunning := true
    this.unsupportedVerified := false
    this.unsupportedHangUntil := A_TickCount + CoverFeasibilityPrototype.UNRESPONSIVE_DURATION_MS
    PostMessage(CoverFeasibilityPrototype.WM_APP_HANG, 0, 0,, "ahk_id " fixtureHwnd)
    this._UpdateUnsupportedCountdown(true)
    this.lastResultText.Text := "RUNNING - waiting for the test window to stop responding"
    this._Log("TEST", "unsupported-hang-started:" fixtureHwnd)
    SetTimer(this.unresponsiveCheckCallback, -500)
    SetTimer(this.unresponsiveCountdownCallback, 1000)
  }

  _CompleteUnsupportedTest() {
    if (!this.unsupportedFixtureHwnd || !WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
      this.unsupportedTestRunning := false
      SetTimer(this.unresponsiveCountdownCallback, 0)
      this._SetResult("unsupported", false, "The test window closed too early")
      this._SetCurrentStep("STEP 6 FAILED - start the unresponsive window again")
      return
    }
    isResponsive := this.backend.IsResponsive(this.unsupportedFixtureHwnd)
    if (isResponsive) {
      this.unsupportedTestRunning := false
      SetTimer(this.unresponsiveCountdownCallback, 0)
      this._SetResult("unsupported", false, "The test window still responds")
      this._SetCurrentStep("STEP 6 FAILED - start the unresponsive window again")
      return
    }
    this.unsupportedOffscreenForegroundBefore := DllCall("GetForegroundWindow", "Ptr")
    if (!this.backend.GetCoverHwnd(this.unsupportedMonitorNumber)) {
      this._SetResult("unsupported", false, "No monitor cover exists for the offscreen test")
      this._SetCurrentStep("OFFSCREEN FAILED - covers remain; waiting for the fixture to respond")
      return
    }
    commandLine := '"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptFullPath '" --offscreen-helper "' this.unsupportedFixtureHwnd '" "' this.unsupportedOffscreenTarget["left"] '" "' this.unsupportedOffscreenTarget["top"] '"'
    try Run(commandLine, A_ScriptDir, "Hide", &helperPid)
    catch Error as caughtError {
      this._SetResult("unsupported", false, "Could not start offscreen helper: " caughtError.Message)
      this._SetCurrentStep("OFFSCREEN FAILED - covers remain; waiting for the fixture to respond")
      this._Log("UNSUPPORTED", "offscreen-helper-start-failed")
      return
    }
    this.unsupportedOffscreenHelperPid := helperPid
    this.unsupportedOffscreenPending := true
    this.lastResultText.Text := "RUNNING - helper is trying to move the frozen window offscreen"
    this._Log("UNSUPPORTED", "offscreen-helper-started:" helperPid)
    SetTimer(this.unsupportedOffscreenCheckCallback, -CoverFeasibilityPrototype.OFFSCREEN_HELPER_TIMEOUT_MS)
  }

  _CompleteUnsupportedOffscreen() {
    this.unsupportedOffscreenPending := false
    helperTimedOut := this.unsupportedOffscreenHelperPid && ProcessExist(this.unsupportedOffscreenHelperPid)
    if (helperTimedOut) {
      try ProcessClose(this.unsupportedOffscreenHelperPid)
      try ProcessWaitClose(this.unsupportedOffscreenHelperPid, 0.2)
    }
    this.unsupportedOffscreenHelperPid := 0
    if (!this.unsupportedFixtureHwnd || !WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
      this._SetResult("unsupported", false, "The test window closed during the offscreen attempt")
      this._SetCurrentStep("STEP 6 FAILED - start the unresponsive window again")
      return
    }
    rectAfter := this.backend.GetWindowRect(this.unsupportedFixtureHwnd)
    foregroundAfter := DllCall("GetForegroundWindow", "Ptr")
    sizeKept := IsObject(this.unsupportedRectBefore) && IsObject(rectAfter) && rectAfter["width"] = this.unsupportedRectBefore["width"] && rectAfter["height"] = this.unsupportedRectBefore["height"] && !this.backend.IsMinimized(this.unsupportedFixtureHwnd)
    focusKept := this.unsupportedOffscreenForegroundBefore = foregroundAfter
    coversKept := this.backend.covers.Count = MonitorGetCount() && this.backend.VerifyCoverGeometry()
    movedOffscreen := this.backend.IsRectOutsideVirtualDesktop(rectAfter)
    topmostKept := this.backend.IsTopmost(this.unsupportedFixtureHwnd) = this.unsupportedSavedTopmost
    unsupportedPassed := this.unsupportedSavedTopmost && sizeKept && focusKept && coversKept && movedOffscreen && topmostKept
    this.unsupportedVerified := unsupportedPassed
    helperState := helperTimedOut ? "helper timed out and was stopped" : "helper exited within 500 ms"
    checkText := "offscreen=" this._YesNo(movedOffscreen) ", size=" this._YesNo(sizeKept) ", focus=" this._YesNo(focusKept) ", covers=" this._YesNo(coversKept) ", topmost=" this._YesNo(topmostKept)
    detail := (unsupportedPassed ? "Frozen topmost window moved outside the virtual desktop; " : "Offscreen move failed or changed window state; every cover stayed in place; ") helperState " | " checkText
    this._SetResult("unsupported", unsupportedPassed, detail)
    if (unsupportedPassed)
      this._UpdateUnsupportedCountdown(true)
    else
      this._SetCurrentStep("OFFSCREEN FAILED - covers remain; waiting for the fixture to respond")
    this._Log("UNSUPPORTED", (unsupportedPassed ? "moved-offscreen:" : "offscreen-failed-cover-kept:") helperState ":" checkText)
  }

  _UpdateUnsupportedCountdown(forceUpdate := false) {
    if (!this.unsupportedTestRunning)
      return
    currentStep := this.currentStepText.Text
    countdownOwnsStep := forceUpdate || InStr(currentStep, "UNRESPONSIVE") || InStr(currentStep, "WAITING FOR UNRESPONSIVE") || InStr(currentStep, "OFFSCREEN")
    remainingMs := this.unsupportedHangUntil - A_TickCount
    fixtureExists := this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd) && this.unsupportedFixturePid && ProcessExist(this.unsupportedFixturePid)
    if (!fixtureExists) {
      this._RestoreAfterUnsupportedFixture("fixture-closed")
      return
    }
    if (remainingMs <= 0) {
      if (this.backend.IsResponsive(this.unsupportedFixtureHwnd))
        this._RestoreAfterUnsupportedFixture("responsive")
      else if (countdownOwnsStep)
        this.currentStepText.Text := "STILL UNRESPONSIVE - covers stay; checking again"
      return
    }
    if (!countdownOwnsStep)
      return
    remainingSeconds := Ceil(remainingMs / 1000)
    stateText := this.unsupportedOffscreenPending ? "OFFSCREEN HELPER RUNNING" : this.unsupportedVerified ? "MOVED OFFSCREEN" : "OFFSCREEN FAILED; COVERS KEPT"
    this.currentStepText.Text := stateText " - " remainingSeconds " second(s) left; repeated Start is blocked"
  }

  _RestoreAfterUnsupportedFixture(recoveryReason) {
    fixtureExists := this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd) && this.unsupportedFixturePid && ProcessExist(this.unsupportedFixturePid)
    unsupportedPassed := this.unsupportedVerified
    SetTimer(this.unresponsiveCountdownCallback, 0)
    this.unsupportedTestRunning := false
    this.unsupportedHangUntil := 0
    if (!fixtureExists) {
      this.unsupportedRecovered := false
      this._SetResult("unsupported", false, "The test fixture closed before its saved state could return")
      this._SetCurrentStep("STEP 6 FAILED - click Start unresponsive window")
      return
    }
    this.unsupportedRecovered := true
    if (!this.testWindowsReady) {
      this.backend.MoveToRect(this.unsupportedFixtureHwnd, this.unsupportedRectBefore)
      return
    }
    workspaceApplied := this._ApplyWorkspace(this.currentWorkspace)
    geometryRestored := this.backend.MoveToRect(this.unsupportedFixtureHwnd, this.unsupportedRectBefore)
    coverResult := this._VerifyBands()
    restoredRect := this.backend.GetWindowRect(this.unsupportedFixtureHwnd)
    recoveryPassed := geometryRestored && this._RectsMatch(this.unsupportedRectBefore, restoredRect) && workspaceApplied && coverResult["passed"] && this.backend.covers.Count = MonitorGetCount()
    if (!recoveryPassed) {
      this._SetResult("unsupported", false, "The fixture responded, but its workspace or saved topmost state did not return safely")
      this._RecoverAll("unsupported-recovery-failed")
      this._SetCurrentStep("STEP 6 FAILED - covers removed; click Create / Reset")
      return
    }
    if (!unsupportedPassed) {
      this._SetResult("unsupported", false, "The fixture responded and returned to its old position, but the offscreen move failed; every cover remained")
      this._SetCurrentStep("STEP 6 FAILED - inspect the result details or click Start unresponsive window again")
      this._Log("UNSUPPORTED", "responsive-after-offscreen-failure")
      return
    }
    this._SetResult("unsupported", true, "Frozen topmost fixture moved offscreen; after response it returned to its old position in Workspace A")
    this._SetCurrentStep("CURRENT STEP 7/8 - click Simulate stack failure")
    this._ArmSafetyRestore()
    this._Log("UNSUPPORTED", "fixture-recovered-after-" recoveryReason)
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
    this._SetCurrentStep(recoveryPassed ? "CURRENT STEP 8/8 - close the prototype, check cleanup, then reopen" : "STEP 7 FAILED - click Simulate stack failure again")
  }

  _RecoverAll(reason) {
    SetTimer(this.safetyRestoreCallback, 0)
    SetTimer(this.repairCallback, 0)
    SetTimer(this.repairCheckCallback, 0)
    this.repairScheduled := false
    this.repairTestPending := false
    this.reconcileAttemptCount := 0
    this.backend.RemoveAllCovers()
    if (this.testWindowsReady) {
      this.backend.SetTopmost(this.windowHwnds["shell"], false)
      this.backend.SetTopmost(this.windowHwnds["topmostA"], false)
      for windowName in ["normalA", "normalB", "shell"] {
        windowHwnd := this.windowHwnds[windowName]
        DllCall("ShowWindow", "Ptr", windowHwnd, "Int", 5)
      }
      if (this.specialStatePrepared) {
        this.backend.RestoreWindow(this.windowHwnds["fullscreenA"], this.recoveryFullscreenRect)
        DllCall("ShowWindow", "Ptr", this.windowHwnds["topmostA"], "Int", 5)
        this.backend.SetTopmost(this.windowHwnds["topmostA"], false)
      } else {
        try this.fixtureGuis["topmostA"].Hide()
        try this.fixtureGuis["fullscreenA"].Hide()
      }
      if (this.unsupportedRecovered && this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
        this.backend.SetTopmost(this.unsupportedFixtureHwnd, this.unsupportedSavedTopmost)
        this.backend.MoveToRect(this.unsupportedFixtureHwnd, this.unsupportedRectBefore)
        DllCall("ShowWindow", "Ptr", this.unsupportedFixtureHwnd, "Int", 5)
      }
    }
    this._Log("RECOVERY", reason)
    this.lastResultText.Text := "RECOVERED - " reason
    this._KeepPanelReachable()
    this._RefreshStatus()
  }

  _EmergencyButton(*) {
    this._RecoverAll("manual-button")
    this._SetCurrentStep("COVERS REMOVED - click Create / Reset to start again")
  }

  _AbortTest(*) {
    this._RecoverAll("manual-abort")
    this._RemoveTestWindows()
    this.lastResultText.Text := "ABORTED - all prototype test windows and covers were removed"
    this._SetCurrentStep("TEST ABORTED - click Create / Reset to start again")
    this._KeepPanelReachable()
  }

  _EmergencyHotkey(*) {
    this._RecoverAll("Ctrl+Shift+F12")
    this._SetCurrentStep("COVERS REMOVED - click Create / Reset to start again")
  }

  _SafetyRestore() {
    if (this.backend.covers.Count > 0) {
      this._RecoverAll("60-second-safety-timeout")
      this._SetCurrentStep("SAFETY TIMEOUT - click Apply A or Create / Reset")
    }
  }

  _ArmSafetyRestore() {
    SetTimer(this.safetyRestoreCallback, 0)
    SetTimer(this.safetyRestoreCallback, -60000)
  }

  _ReconcileStack() {
    if (this.cleanedUp || !this.testWindowsReady || this.stackApplying || this.repairTestPending || this.backend.covers.Count = 0)
      return
    unavailableWindowName := this._GetUnavailableWindowName()
    if (unavailableWindowName != "") {
      this._FailForTestWindow(unavailableWindowName)
      return
    }
    verification := this._VerifyBands()
    if (verification["passed"]) {
      this.reconcileAttemptCount := 0
      this._RefreshStatus()
      return
    }
    this.reconcileAttemptCount += 1
    repaired := this._ApplyStack()
    if (!this.testWindowsReady)
      return
    unavailableWindowName := this._GetUnavailableWindowName()
    if (unavailableWindowName != "") {
      this._FailForTestWindow(unavailableWindowName)
      return
    }
    verificationAfter := this._VerifyBands()
    repairPassed := repaired && verificationAfter["passed"]
    this._Log("RECONCILE", (repairPassed ? "stack-restored" : "stack-failed") ":attempt=" this.reconcileAttemptCount)
    if (repairPassed)
      this.reconcileAttemptCount := 0
    else if (this.reconcileAttemptCount >= CoverFeasibilityPrototype.MAX_RECONCILE_ATTEMPTS)
      this._StopForUnstableStack("reconcile-limit")
    if (this.backend.covers.Count > 0)
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
    requiredVisibleNames := ["normalA", "normalB", "shell"]
    if (this.specialStatePrepared) {
      requiredVisibleNames.Push("topmostA")
      requiredVisibleNames.Push("fullscreenA")
    }
    for windowName in requiredVisibleNames {
      windowHwnd := this.windowHwnds[windowName]
      if (!DllCall("IsWindow", "Ptr", windowHwnd) || !DllCall("IsWindowVisible", "Ptr", windowHwnd) || this.backend.IsMinimized(windowHwnd))
        return false
    }
    if (this.unsupportedRecovered && (!this.unsupportedFixtureHwnd || !DllCall("IsWindow", "Ptr", this.unsupportedFixtureHwnd) || !DllCall("IsWindowVisible", "Ptr", this.unsupportedFixtureHwnd) || this.backend.IsMinimized(this.unsupportedFixtureHwnd)))
      return false
    return true
  }

  _RequireTestWindows() {
    if (this.testWindowsReady) {
      unavailableWindowName := this._GetUnavailableWindowName()
      if (unavailableWindowName = "")
        return true
      this._FailForTestWindow(unavailableWindowName)
      return false
    }
    this.lastResultText.Text := "NOT READY - click Create / Reset first"
    this._SetCurrentStep("CURRENT STEP 1/8 - click Create / Reset")
    return false
  }

  _IsTrackedWindow(windowHwnd) {
    if (!windowHwnd)
      return false
    for windowName, trackedHwnd in this.windowHwnds {
      if (trackedHwnd = windowHwnd)
        return true
    }
    if (this.unsupportedRecovered && this.unsupportedFixtureHwnd = windowHwnd)
      return true
    return false
  }

  _SetResult(resultName, passed, detail) {
    this.results[resultName]["state"] := passed ? "PASS" : "FAIL"
    this.results[resultName]["detail"] := detail
    this.lastResultText.Text := (passed ? "PASS - " : "FAIL - ") detail
    this._Log("RESULT", resultName ":" this.results[resultName]["state"] ":" detail)
    this._RefreshStatus()
  }

  _SetCurrentStep(stepText) {
    if (IsObject(this.currentStepText))
      this.currentStepText.Text := stepText
    this._Log("STEP", stepText)
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
    liveText .= "Last repair: " (this.lastRepairDurationMs > 0 ? this.lastRepairDurationMs " ms" : "none") " | Expected maximum: 1000 ms`r`n"
    if (this.testWindowsReady) {
      unavailableWindowName := this._GetUnavailableWindowName()
      if (unavailableWindowName != "")
        liveText .= "Test window unavailable: " unavailableWindowName " | safe cleanup pending`r`n"
      else {
        liveText .= "Special A prepared: " this._YesNo(this.specialStatePrepared) " | TOPMOST A: " this._YesNo(this.backend.IsTopmost(this.windowHwnds["topmostA"])) " | FULLSCREEN A minimized: " this._YesNo(this.backend.IsMinimized(this.windowHwnds["fullscreenA"])) "`r`n"
        liveText .= "Tracked z-order ranks: " this._GetTrackedZOrderText() "`r`n"
      }
      if (this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
        unsupportedState := this.unsupportedRecovered ? "RECOVERED" : this.unsupportedOffscreenPending ? "MOVING OFFSCREEN" : this.unsupportedVerified ? "OFFSCREEN" : this.unsupportedTestRunning ? "CHECKING" : "OPEN"
        liveText .= "Unsupported fixture: " unsupportedState " | Saved TOPMOST: " this._YesNo(this.unsupportedSavedTopmost) " | Assigned workspace: " this.unsupportedWorkspace "`r`n"
      }
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
    if (this.unsupportedFixtureHwnd && WinExist("ahk_id " this.unsupportedFixtureHwnd)) {
      rankValue := zOrderRanks.Has(this.unsupportedFixtureHwnd) ? zOrderRanks[this.unsupportedFixtureHwnd] : "missing"
      rankText .= ", unsupported=" rankValue
    }
    return rankText
  }

  _YesNo(value) {
    return value ? "YES" : "NO"
  }

  _RemoveTestWindows() {
    SetTimer(this.safetyRestoreCallback, 0)
    SetTimer(this.repairCallback, 0)
    SetTimer(this.repairCheckCallback, 0)
    this.repairScheduled := false
    this.repairTestPending := false
    this.reconcileAttemptCount := 0
    this.testWindowsReady := false
    this.backend.RemoveAllCovers()
    this._CloseUnsupportedFixture()
    for windowName, fixtureGui in this.fixtureGuis
      try fixtureGui.Destroy()
    this.fixtureGuis := Map()
    this.windowHwnds := Map()
    this.specialStatePrepared := false
  }

  _StopUnsupportedOffscreenHelper() {
    SetTimer(this.unsupportedOffscreenCheckCallback, 0)
    if (this.unsupportedOffscreenHelperPid && ProcessExist(this.unsupportedOffscreenHelperPid))
      try ProcessClose(this.unsupportedOffscreenHelperPid)
    this.unsupportedOffscreenHelperPid := 0
    this.unsupportedOffscreenPending := false
    this.unsupportedOffscreenForegroundBefore := 0
  }

  _CloseUnsupportedFixture() {
    SetTimer(this.unresponsiveCountdownCallback, 0)
    this._StopUnsupportedOffscreenHelper()
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
    this.unsupportedOffscreenTarget := 0
    this.unsupportedSavedTopmost := false
    this.unsupportedWorkspace := "A"
    this.unsupportedRecovered := false
    this.unsupportedTestRunning := false
    this.unsupportedVerified := false
    this.unsupportedHangUntil := 0
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
    SetTimer(this.unresponsiveCountdownCallback, 0)
    SetTimer(this.safetyRestoreCallback, 0)
    SetTimer(this.unsupportedOffscreenCheckCallback, 0)
    SetTimer(this.logFlushCallback, 0)
    try Hotkey("^+F12", "Off")
    try OnMessage(WindowsCoverBackendPrototype.WM_MOUSEACTIVATE, this.mouseActivateCallback, 0)
    this.backend.StopWinEvents()
    this._RecoverAll("exit-cleanup")
    this._RemoveTestWindows()
    this._Log("CLEANUP", "complete")
    this._FlushLogQueue()
  }
}

RunUnresponsiveFixture(fixtureToken, parentPid, windowLeft, windowTop) {
  global unsupportedFixtureGui
  global unsupportedFixtureStateText
  global unsupportedHangCallback
  global unsupportedParentTimerCallback
  unsupportedFixtureGui := Gui("+AlwaysOnTop +Resize", "SW Unsupported " fixtureToken)
  unsupportedFixtureGui.BackColor := "5B2020"
  unsupportedFixtureGui.SetFont("s16 Bold cFFFFFF", "Segoe UI")
  unsupportedFixtureStateText := unsupportedFixtureGui.Add("Text", "Center w380 r6 BackgroundTrans", "TOPMOST TEST WINDOW`nIT WILL FREEZE FOR 12 SECONDS`nTHE COVER MUST STAY")
  unsupportedFixtureGui.OnEvent("Close", (*) => ExitApp())
  unsupportedHangCallback := (*) => HangUnresponsiveFixture(fixtureToken)
  OnMessage(CoverFeasibilityPrototype.WM_APP_HANG, unsupportedHangCallback)
  unsupportedParentTimerCallback := (*) => ProcessExist(parentPid) ? 0 : ExitApp()
  SetTimer(unsupportedParentTimerCallback, 1000)
  unsupportedFixtureGui.Show("NA x" windowLeft " y" windowTop " w420 h220")
}

HangUnresponsiveFixture(fixtureToken) {
  global unsupportedFixtureGui
  global unsupportedFixtureStateText
  unsupportedFixtureGui.Title := "SW Unsupported " fixtureToken " - FROZEN"
  unsupportedFixtureStateText.Text := "FROZEN FOR 12 SECONDS`nTRY TO CLICK OR DRAG THIS WINDOW`nTHE MAIN PANEL SHOWS THE COUNTDOWN"
  DllCall("Sleep", "UInt", CoverFeasibilityPrototype.UNRESPONSIVE_DURATION_MS)
  unsupportedFixtureGui.Title := "SW Unsupported " fixtureToken " - RESPONDING AGAIN"
  unsupportedFixtureStateText.Text := "RESPONDING AGAIN`nSTAYS OPEN IN WORKSPACE A`nTOPMOST RETURNS ON A ONLY"
}

RunOffscreenHelper(windowHwnd, offscreenLeft, offscreenTop) {
  backend := WindowsCoverBackendPrototype(0)
  movedOffscreen := backend.MoveOffscreenSynchronously(windowHwnd, offscreenLeft, offscreenTop)
  ExitApp(movedOffscreen ? 0 : 2)
}

if (A_Args.Length >= 1 && A_Args[1] = "--unresponsive-fixture") {
  RunUnresponsiveFixture(A_Args[2], A_Args[3] + 0, A_Args[4] + 0, A_Args[5] + 0)
} else if (A_Args.Length >= 4 && A_Args[1] = "--offscreen-helper") {
  RunOffscreenHelper(A_Args[2] + 0, A_Args[3] + 0, A_Args[4] + 0)
} else {
  smokeMode := A_Args.Length >= 1 && A_Args[1] = "--smoke"
  logPath := A_Args.Length >= 2 ? A_Args[2] : A_ScriptDir "\tmp\SyntheticWorkspacesCoverPrototypeManual.log"
  prototype := CoverFeasibilityPrototype(smokeMode, logPath)
  if (smokeMode) {
    smokeExitCallback := (*) => ExitApp()
    SetTimer(smokeExitCallback, -250)
  }
}

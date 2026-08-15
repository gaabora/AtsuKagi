class WindowsSyntheticWorkspacePlacementBackend {
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
  static DWMWA_EXTENDED_FRAME_BOUNDS := 9
  static WM_MOUSEACTIVATE := 0x0021
  static MA_NOACTIVATEANDEAT := 4
  static OFFSCREEN_HELPER_TIMEOUT_MS := 500

  __New() {
    this._coversByMonitor := Map()
    this._temporaryTopmostByHwnd := Map()
    this._temporaryMinimizedByHwnd := Map()
    this._offscreenByHwnd := Map()
    this._mouseActivateCallback := this._onMouseActivate.Bind(this)
    this._messageCallbackRegistered := false
    this._isStarted := false
    SplitPath(A_LineFile,, &backendDirectory)
    this._helperScriptPath := backendDirectory "\OffscreenHelper.ahk"
  }

  Start() {
    if (this._isStarted)
      return false
    OnMessage(WindowsSyntheticWorkspacePlacementBackend.WM_MOUSEACTIVATE, this._mouseActivateCallback)
    this._messageCallbackRegistered := true
    this._isStarted := true
    return true
  }

  ApplyPlan(plan) {
    this._requirePlan(plan)
    if (!this._isStarted)
      throw Error("Synthetic workspace placement backend is not started")
    if (!this._ensureCovers() || !this._verifyCoverGeometry())
      return Map("success", false, "unsafeStack", true, "reason", "desktop covers could not be created or verified")
    this._restoreResponsiveOffscreen(plan["windows"])
    for windowPlan in plan["windows"] {
      if (!this._applyWindowPlan(windowPlan))
        return Map("success", false, "unsafeStack", true, "reason", "a window state operation failed")
    }
    for windowPlan in plan["windows"] {
      if (windowPlan.Get("moveOffscreen", false)) {
        windowPlan["offscreenAttemptAccepted"] := this._startOffscreenAttempt(windowPlan)
        if (!windowPlan["offscreenAttemptAccepted"])
          this._setUnsupportedDiagnostic(windowPlan["record"], "offscreen move was unavailable or rejected; covers remain in place")
        else
          this._setUnsupportedDiagnostic(windowPlan["record"], "offscreen helper attempt started; covers remain in place")
      }
    }
    if (!this._applyStack(plan))
      return Map("success", false, "unsafeStack", true, "reason", "z-order band placement failed")
    if (!this._applyFocus(plan))
      return Map("success", false, "unsafeStack", false, "reason", "destination focus failed")
    return Map("success", true, "unsafeStack", false, "reason", "")
  }

  VerifyPlan(plan) {
    this._requirePlan(plan)
    if (!this._verifyCoverGeometry() || !this._verifyWindowPlans(plan["windows"]) || !this._verifyStack(plan))
      return false
    foregroundHwnd := this.GetForegroundHwnd()
    focusHwnd := plan.Get("focusHwnd", 0)
    if (focusHwnd)
      return foregroundHwnd = focusHwnd
    for inactiveHwnd in plan.Get("inactiveHwnds", []) {
      if (foregroundHwnd = inactiveHwnd)
        return false
    }
    return true
  }

  RollbackPlan(plan) {
    this._requirePlan(plan)
    rollbackSucceeded := true
    for windowPlan in plan["windows"] {
      if (!this._rollbackWindowPlan(windowPlan))
        rollbackSucceeded := false
    }
    expectedFocusHwnd := plan.Get("focusHwnd", 0)
    priorFocusHwnd := plan.Get("priorFocusHwnd", 0)
    if (expectedFocusHwnd && this.GetForegroundHwnd() = expectedFocusHwnd && priorFocusHwnd && this._isWindow(priorFocusHwnd))
      rollbackSucceeded := this._focusWindow(priorFocusHwnd) && rollbackSucceeded
    this.RemoveAllCovers()
    return rollbackSucceeded
  }

  EmergencyRestore(records) {
    this.RemoveAllCovers()
    restoreSucceeded := true
    recordsByHwnd := Map()
    for record in records
      recordsByHwnd[record.Hwnd] := record
    for windowHwnd, originalTopmost in this._temporaryTopmostByHwnd {
      cleanupTopmost := recordsByHwnd.Has(windowHwnd) ? !!recordsByHwnd[windowHwnd].State.Desired.Get("topmost", originalTopmost) : originalTopmost
      if (this._isWindow(windowHwnd) && this._readTopmost(windowHwnd) != cleanupTopmost)
        restoreSucceeded := this._setTopmost(windowHwnd, cleanupTopmost) && restoreSucceeded
    }
    for windowHwnd, savedState in this._temporaryMinimizedByHwnd {
      if (!this._isWindow(windowHwnd))
        continue
      cleanupMinimized := recordsByHwnd.Has(windowHwnd) ? !!recordsByHwnd[windowHwnd].State.Desired.Get("minimized", savedState["minimized"]) : savedState["minimized"]
      cleanupGeometry := recordsByHwnd.Has(windowHwnd) ? recordsByHwnd[windowHwnd].State.Desired.Get("geometry", savedState["geometry"]) : savedState["geometry"]
      if (cleanupMinimized != this._isMinimized(windowHwnd))
        restoreSucceeded := this._setMinimized(windowHwnd, cleanupMinimized, cleanupGeometry) && restoreSucceeded
    }
    this._temporaryTopmostByHwnd := Map()
    this._temporaryMinimizedByHwnd := Map()
    this.RepairRecoveredUnsupported(records)
    this._stopAllOffscreenHelpers()
    return restoreSucceeded
  }

  RepairRecoveredUnsupported(records) {
    responsiveHwnds := Map()
    for record in records {
      if (record.Classification = "unsupported" && this._offscreenByHwnd.Has(record.Hwnd)) {
        offscreenState := this._offscreenByHwnd[record.Hwnd]
        diagnosticText := offscreenState.Get("helperPid", 0) ? "offscreen helper attempt is running; covers remain in place" : offscreenState.Get("moved", false) ? "window moved outside the virtual desktop while unsupported" : "offscreen move was unavailable or rejected; covers remain in place"
        this._setUnsupportedDiagnostic(record, diagnosticText)
      } else if (record.Responsive)
        responsiveHwnds[record.Hwnd] := true
    }
    offscreenHwnds := []
    for windowHwnd, offscreenState in this._offscreenByHwnd
      offscreenHwnds.Push(windowHwnd)
    for windowHwnd in offscreenHwnds {
      offscreenState := this._offscreenByHwnd[windowHwnd]
      if (!responsiveHwnds.Has(windowHwnd) || !this._isWindow(windowHwnd))
        continue
      if (offscreenState.Get("helperPid", 0))
        this._finishOffscreenAttempt(windowHwnd)
      if (this._moveOuterWindow(windowHwnd, offscreenState["geometry"]))
        this._offscreenByHwnd.Delete(windowHwnd)
    }
  }

  IsInternalWindow(windowHwnd) {
    for monitorNumber, coverRecord in this._coversByMonitor {
      if (coverRecord["hwnd"] = windowHwnd)
        return true
    }
    return false
  }

  GetForegroundHwnd() {
    return DllCall("GetForegroundWindow", "Ptr")
  }

  RemoveAllCovers() {
    for monitorNumber, coverRecord in this._coversByMonitor {
      try coverRecord["gui"].Destroy()
    }
    this._coversByMonitor := Map()
  }

  Close() {
    hadResources := this._isStarted || this._coversByMonitor.Count || this._temporaryTopmostByHwnd.Count || this._temporaryMinimizedByHwnd.Count || this._offscreenByHwnd.Count
    try this.EmergencyRestore([])
    this._offscreenByHwnd := Map()
    if (this._messageCallbackRegistered) {
      try OnMessage(WindowsSyntheticWorkspacePlacementBackend.WM_MOUSEACTIVATE, this._mouseActivateCallback, 0)
      this._messageCallbackRegistered := false
    }
    this._isStarted := false
    return !!hadResources
  }

  __Delete() {
    try this.Close()
  }

  _ensureCovers() {
    monitorCount := MonitorGetCount()
    if (this._coversByMonitor.Count = monitorCount && this._verifyCoverGeometry())
      return true
    this.RemoveAllCovers()
    try {
      monitorNumber := 1
      while (monitorNumber <= monitorCount) {
        MonitorGetWorkArea(monitorNumber, &workLeft, &workTop, &workRight, &workBottom)
        coverGui := Gui("+ToolWindow -Caption +E0x08000000", "Haribol synthetic workspace cover")
        coverGui.BackColor := "101820"
        coverGui.Show("NA x" workLeft " y" workTop " w" (workRight - workLeft) " h" (workBottom - workTop))
        this._coversByMonitor[monitorNumber] := Map("gui", coverGui, "hwnd", coverGui.Hwnd, "left", workLeft, "top", workTop, "width", workRight - workLeft, "height", workBottom - workTop)
        monitorNumber += 1
      }
    } catch {
      this.RemoveAllCovers()
      return false
    }
    return this._coversByMonitor.Count = monitorCount
  }

  _verifyCoverGeometry() {
    if (this._coversByMonitor.Count != MonitorGetCount())
      return false
    for monitorNumber, coverRecord in this._coversByMonitor {
      windowHwnd := coverRecord["hwnd"]
      if (!this._isWindow(windowHwnd) || !DllCall("IsWindowVisible", "Ptr", windowHwnd))
        return false
      try WinGetPos(&actualLeft, &actualTop, &actualWidth, &actualHeight, "ahk_id " windowHwnd)
      catch
        return false
      if (Abs(actualLeft - coverRecord["left"]) > 2 || Abs(actualTop - coverRecord["top"]) > 2 || Abs(actualWidth - coverRecord["width"]) > 2 || Abs(actualHeight - coverRecord["height"]) > 2)
        return false
    }
    return true
  }

  _applyWindowPlan(windowPlan) {
    windowHwnd := windowPlan["hwnd"]
    if (!this._isWindow(windowHwnd))
      return false
    targetState := windowPlan["target"]
    if (windowPlan.Get("applyGeometry", false) && !this._moveWindow(windowHwnd, targetState["geometry"]))
      return false
    if (windowPlan.Get("applyTopmost", false)) {
      if (!this._temporaryTopmostByHwnd.Has(windowHwnd))
        this._temporaryTopmostByHwnd[windowHwnd] := windowPlan["prior"]["topmost"]
      if (!this._setTopmost(windowHwnd, targetState["topmost"]))
        return false
    }
    if (windowPlan.Get("applyMinimized", false)) {
      if (!this._temporaryMinimizedByHwnd.Has(windowHwnd))
        this._temporaryMinimizedByHwnd[windowHwnd] := Map("minimized", windowPlan["prior"]["minimized"], "geometry", windowPlan["prior"]["geometry"])
      if (!this._setMinimized(windowHwnd, targetState["minimized"], targetState["geometry"]))
        return false
    }
    return true
  }

  _verifyWindowPlans(windowPlans) {
    for windowPlan in windowPlans {
      if (windowPlan["classification"] = "unsupported")
        continue
      windowHwnd := windowPlan["hwnd"]
      if (!this._isWindow(windowHwnd))
        return false
      targetState := windowPlan["target"]
      if (windowPlan.Get("applyTopmost", false) && this._readTopmost(windowHwnd) != targetState["topmost"])
        return false
      if (windowPlan.Get("applyMinimized", false) && this._isMinimized(windowHwnd) != targetState["minimized"])
        return false
      if (windowPlan.Get("applyGeometry", false) && !this._rectsMatch(this._readVisibleFrame(windowHwnd), targetState["geometry"]))
        return false
    }
    return true
  }

  _rollbackWindowPlan(windowPlan) {
    if (windowPlan["classification"] = "unsupported")
      return true
    windowHwnd := windowPlan["hwnd"]
    if (!this._isWindow(windowHwnd))
      return true
    priorState := windowPlan["prior"]
    targetState := windowPlan["target"]
    rollbackSucceeded := true
    if (windowPlan.Get("applyGeometry", false) && this._rectsMatch(this._readVisibleFrame(windowHwnd), targetState["geometry"]))
      rollbackSucceeded := this._moveWindow(windowHwnd, priorState["geometry"]) && rollbackSucceeded
    if (windowPlan.Get("applyTopmost", false) && this._readTopmost(windowHwnd) = targetState["topmost"]) {
      rollbackSucceeded := this._setTopmost(windowHwnd, priorState["topmost"]) && rollbackSucceeded
    }
    if (windowPlan.Get("applyMinimized", false) && this._isMinimized(windowHwnd) = targetState["minimized"]) {
      rollbackSucceeded := this._setMinimized(windowHwnd, priorState["minimized"], priorState["geometry"]) && rollbackSucceeded
    }
    return rollbackSucceeded
  }

  _applyStack(plan) {
    topDownHwnds := []
    this._appendVisibleHwnds(topDownHwnds, plan.Get("shellHwnds", []))
    this._appendGroups(topDownHwnds, plan.Get("activeGroups", []))
    for monitorNumber, coverRecord in this._coversByMonitor
      topDownHwnds.Push(coverRecord["hwnd"])
    this._appendGroups(topDownHwnds, plan.Get("inactiveGroups", []))
    upperHwnd := WindowsSyntheticWorkspacePlacementBackend.HWND_TOP
    for idx, windowHwnd in topDownHwnds {
      if (!this._setStackPosition(windowHwnd, idx = 1 ? WindowsSyntheticWorkspacePlacementBackend.HWND_TOP : upperHwnd))
        return false
      upperHwnd := windowHwnd
    }
    return true
  }

  _verifyStack(plan) {
    expectedTopDown := []
    this._appendVisibleHwnds(expectedTopDown, plan.Get("shellHwnds", []))
    this._appendGroups(expectedTopDown, plan.Get("activeGroups", []))
    for monitorNumber, coverRecord in this._coversByMonitor
      expectedTopDown.Push(coverRecord["hwnd"])
    this._appendGroups(expectedTopDown, plan.Get("inactiveGroups", []))
    ranksByHwnd := Map()
    stackRank := 1
    for windowHwnd in WinGetList() {
      ranksByHwnd[windowHwnd] := stackRank
      stackRank += 1
    }
    previousRank := 0
    for windowHwnd in expectedTopDown {
      if (!ranksByHwnd.Has(windowHwnd) || ranksByHwnd[windowHwnd] <= previousRank)
        return false
      previousRank := ranksByHwnd[windowHwnd]
    }
    return true
  }

  _appendGroups(targetHwnds, groups) {
    for groupHwnds in groups
      this._appendVisibleHwnds(targetHwnds, groupHwnds)
  }

  _appendVisibleHwnds(targetHwnds, sourceHwnds) {
    for windowHwnd in sourceHwnds {
      if (this._isWindow(windowHwnd) && DllCall("IsWindowVisible", "Ptr", windowHwnd) && !this._isMinimized(windowHwnd))
        targetHwnds.Push(windowHwnd)
    }
  }

  _applyFocus(plan) {
    focusHwnd := plan.Get("focusHwnd", 0)
    if (focusHwnd)
      return this._focusWindow(focusHwnd)
    for shellHwnd in plan.Get("shellHwnds", []) {
      if (this._isWindow(shellHwnd) && DllCall("IsWindowVisible", "Ptr", shellHwnd))
        return this._focusWindow(shellHwnd)
    }
    desktopHwnd := WinExist("ahk_class Progman")
    return desktopHwnd ? this._focusWindow(desktopHwnd) : true
  }

  _focusWindow(windowHwnd) {
    if (!this._isWindow(windowHwnd) || this._isMinimized(windowHwnd))
      return false
    try DllCall("AllowSetForegroundWindow", "Int", -1)
    DllCall("SetForegroundWindow", "Ptr", windowHwnd)
    return this.GetForegroundHwnd() = windowHwnd
  }

  _startOffscreenAttempt(windowPlan) {
    windowHwnd := windowPlan["hwnd"]
    if (this._offscreenByHwnd.Has(windowHwnd))
      return false
    offscreenState := Map("geometry", this._readWindowRect(windowHwnd), "helperPid", 0, "timer", 0, "moved", false, "record", windowPlan["record"])
    this._offscreenByHwnd[windowHwnd] := offscreenState
    if (A_IsCompiled || !FileExist(this._helperScriptPath))
      return false
    virtualLeft := DllCall("GetSystemMetrics", "Int", 76)
    virtualTop := DllCall("GetSystemMetrics", "Int", 77)
    virtualWidth := DllCall("GetSystemMetrics", "Int", 78)
    offscreenLeft := virtualLeft + virtualWidth + 100
    offscreenTop := virtualTop + 100
    commandLine := '"' A_AhkPath '" /ErrorStdOut "' this._helperScriptPath '" "' windowHwnd '" "' offscreenLeft '" "' offscreenTop '"'
    try Run(commandLine, A_ScriptDir, "Hide", &helperPid)
    catch
      return false
    timerCallback := this._finishOffscreenAttempt.Bind(this, windowHwnd)
    offscreenState["helperPid"] := helperPid
    offscreenState["timer"] := timerCallback
    SetTimer(timerCallback, -WindowsSyntheticWorkspacePlacementBackend.OFFSCREEN_HELPER_TIMEOUT_MS)
    return true
  }

  _finishOffscreenAttempt(windowHwnd) {
    if (!this._offscreenByHwnd.Has(windowHwnd))
      return
    offscreenState := this._offscreenByHwnd[windowHwnd]
    helperPid := offscreenState.Get("helperPid", 0)
    if (helperPid && ProcessExist(helperPid))
      try ProcessClose(helperPid)
    offscreenState["helperPid"] := 0
    offscreenState["timer"] := 0
    actualRect := this._readWindowRect(windowHwnd)
    offscreenState["moved"] := this._isRectOutsideVirtualDesktop(actualRect)
    diagnosticText := offscreenState["moved"] ? "window moved outside the virtual desktop while unsupported" : "offscreen move was rejected; covers remain in place and the window may stay above a cover"
    this._setUnsupportedDiagnostic(offscreenState["record"], diagnosticText)
  }

  _stopAllOffscreenHelpers() {
    for windowHwnd, offscreenState in this._offscreenByHwnd {
      timerCallback := offscreenState.Get("timer", 0)
      if (IsObject(timerCallback))
        try SetTimer(timerCallback, 0)
      helperPid := offscreenState.Get("helperPid", 0)
      if (helperPid && ProcessExist(helperPid))
        try ProcessClose(helperPid)
      offscreenState["helperPid"] := 0
      offscreenState["timer"] := 0
    }
  }

  _restoreResponsiveOffscreen(windowPlans) {
    records := []
    for windowPlan in windowPlans
      records.Push(windowPlan["record"])
    this.RepairRecoveredUnsupported(records)
  }

  _setTopmost(windowHwnd, enabled) {
    insertAfterHwnd := enabled ? WindowsSyntheticWorkspacePlacementBackend.HWND_TOPMOST : WindowsSyntheticWorkspacePlacementBackend.HWND_NOTOPMOST
    return this._setStackPosition(windowHwnd, insertAfterHwnd)
  }

  _setMinimized(windowHwnd, minimized, geometry) {
    if (minimized) {
      DllCall("ShowWindow", "Ptr", windowHwnd, "Int", 6)
      return this._isMinimized(windowHwnd)
    }
    DllCall("ShowWindow", "Ptr", windowHwnd, "Int", 9)
    if (IsObject(geometry) && geometry.Count)
      this._moveWindow(windowHwnd, geometry)
    return !this._isMinimized(windowHwnd)
  }

  _moveWindow(windowHwnd, geometry) {
    if (!(geometry is Map) || !geometry.Has("left") || !geometry.Has("top") || !geometry.Has("width") || !geometry.Has("height"))
      return false
    currentWindowRect := this._readWindowRect(windowHwnd)
    currentVisibleRect := this._readVisibleFrame(windowHwnd)
    if (!currentWindowRect.Count || !currentVisibleRect.Count)
      return false
    outerGeometry := Map(
      "left", geometry["left"] + currentWindowRect["left"] - currentVisibleRect["left"],
      "top", geometry["top"] + currentWindowRect["top"] - currentVisibleRect["top"],
      "width", geometry["width"] + currentWindowRect["width"] - currentVisibleRect["width"],
      "height", geometry["height"] + currentWindowRect["height"] - currentVisibleRect["height"]
    )
    return this._moveOuterWindow(windowHwnd, outerGeometry)
  }

  _moveOuterWindow(windowHwnd, geometry) {
    if (!(geometry is Map) || !geometry.Has("left") || !geometry.Has("top") || !geometry.Has("width") || !geometry.Has("height"))
      return false
    flags := WindowsSyntheticWorkspacePlacementBackend.SWP_NOZORDER | WindowsSyntheticWorkspacePlacementBackend.SWP_NOACTIVATE | WindowsSyntheticWorkspacePlacementBackend.SWP_NOOWNERZORDER
    return !!DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", 0, "Int", geometry["left"], "Int", geometry["top"], "Int", geometry["width"], "Int", geometry["height"], "UInt", flags)
  }

  _setStackPosition(windowHwnd, insertAfterHwnd) {
    flags := WindowsSyntheticWorkspacePlacementBackend.SWP_NOMOVE | WindowsSyntheticWorkspacePlacementBackend.SWP_NOSIZE | WindowsSyntheticWorkspacePlacementBackend.SWP_NOACTIVATE | WindowsSyntheticWorkspacePlacementBackend.SWP_NOOWNERZORDER
    return !!DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", insertAfterHwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
  }

  _readWindowRect(windowHwnd) {
    if (!this._isWindow(windowHwnd))
      return Map()
    rectBuffer := Buffer(16, 0)
    if (!DllCall("GetWindowRect", "Ptr", windowHwnd, "Ptr", rectBuffer.Ptr))
      return Map()
    left := NumGet(rectBuffer, 0, "Int")
    top := NumGet(rectBuffer, 4, "Int")
    return Map("left", left, "top", top, "width", NumGet(rectBuffer, 8, "Int") - left, "height", NumGet(rectBuffer, 12, "Int") - top)
  }

  _readVisibleFrame(windowHwnd) {
    if (!this._isWindow(windowHwnd))
      return Map()
    rectBuffer := Buffer(16, 0)
    try {
      if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspacePlacementBackend.DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rectBuffer.Ptr, "UInt", rectBuffer.Size, "Int") = 0) {
        left := NumGet(rectBuffer, 0, "Int")
        top := NumGet(rectBuffer, 4, "Int")
        return Map("left", left, "top", top, "width", NumGet(rectBuffer, 8, "Int") - left, "height", NumGet(rectBuffer, 12, "Int") - top)
      }
    }
    return this._readWindowRect(windowHwnd)
  }

  _readTopmost(windowHwnd) {
    if (!this._isWindow(windowHwnd))
      return false
    try return (WinGetExStyle("ahk_id " windowHwnd) & WindowsSyntheticWorkspacePlacementBackend.WS_EX_TOPMOST) != 0
    return false
  }

  _isMinimized(windowHwnd) {
    return !!DllCall("IsIconic", "Ptr", windowHwnd)
  }

  _isWindow(windowHwnd) {
    return windowHwnd && !!DllCall("IsWindow", "Ptr", windowHwnd)
  }

  _rectsMatch(firstRect, secondRect) {
    if (!(firstRect is Map) || !(secondRect is Map) || !firstRect.Count || !secondRect.Count)
      return false
    return Abs(firstRect["left"] - secondRect["left"]) <= 2 && Abs(firstRect["top"] - secondRect["top"]) <= 2 && Abs(firstRect["width"] - secondRect["width"]) <= 2 && Abs(firstRect["height"] - secondRect["height"]) <= 2
  }

  _isRectOutsideVirtualDesktop(windowRect) {
    if (!(windowRect is Map) || !windowRect.Count)
      return false
    virtualLeft := DllCall("GetSystemMetrics", "Int", 76)
    virtualTop := DllCall("GetSystemMetrics", "Int", 77)
    virtualRight := virtualLeft + DllCall("GetSystemMetrics", "Int", 78)
    virtualBottom := virtualTop + DllCall("GetSystemMetrics", "Int", 79)
    return windowRect["left"] + windowRect["width"] <= virtualLeft || windowRect["left"] >= virtualRight || windowRect["top"] + windowRect["height"] <= virtualTop || windowRect["top"] >= virtualBottom
  }

  _onMouseActivate(wParam, lParam, messageNumber, windowHwnd) {
    if (this.IsInternalWindow(windowHwnd))
      return WindowsSyntheticWorkspacePlacementBackend.MA_NOACTIVATEANDEAT
  }

  _setUnsupportedDiagnostic(record, diagnosticText) {
    if (!IsObject(record) || record.Classification != "unsupported" || InStr(record.ClassificationReason, diagnosticText))
      return
    record.SetClassification("unsupported", record.ClassificationReason " | " diagnosticText)
  }

  _requirePlan(plan) {
    if (!(plan is Map) || !(plan.Get("windows", 0) is Array))
      throw TypeError("Synthetic workspace placement plan is invalid")
  }
}

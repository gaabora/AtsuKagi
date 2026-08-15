#Include RuntimeWindowCache.ahk

class SyntheticWorkspaceRuntime {
  __New(workspaceModel, windowBackend, runtimeWindowCache:=0, windowEventService:=0, placementBackend:=0) {
    if (!(workspaceModel is SyntheticWorkspaceModel))
      throw TypeError("Workspace runtime requires a SyntheticWorkspaceModel")
    if (!IsObject(windowBackend) || !HasMethod(windowBackend, "ReadTopLevelWindowSnapshots"))
      throw TypeError("Workspace runtime requires a window snapshot backend")
    if (!IsObject(runtimeWindowCache))
      runtimeWindowCache := SyntheticWorkspaceRuntimeWindowCache()
    if (!(runtimeWindowCache is SyntheticWorkspaceRuntimeWindowCache))
      throw TypeError("Workspace runtime cache must be a SyntheticWorkspaceRuntimeWindowCache")
    if (IsObject(windowEventService) && (!HasMethod(windowEventService, "Start") || !HasMethod(windowEventService, "Stop")))
      throw TypeError("Workspace window event service requires Start and Stop methods")
    if (IsObject(windowEventService) && !HasMethod(windowBackend, "ReadWindowSnapshot"))
      throw TypeError("Event-driven workspace runtime requires single-window snapshots")
    if (IsObject(placementBackend) && (!HasMethod(placementBackend, "ApplyPlan") || !HasMethod(placementBackend, "VerifyPlan") || !HasMethod(placementBackend, "RollbackPlan") || !HasMethod(placementBackend, "EmergencyRestore")))
      throw TypeError("Workspace placement backend requires apply, verify, rollback, and emergency restore methods")
    this.Model := workspaceModel
    this.WindowBackend := windowBackend
    this.Cache := runtimeWindowCache
    this.WindowEventService := windowEventService
    this.PlacementBackend := placementBackend
    this._nativeEventCallback := this._handleNativeWindowEvent.Bind(this)
    this._reconciliationCallback := this.Reconcile.Bind(this)
    this._isRunning := false
    this._switchingEnabled := true
    this._suspended := false
    this._transactionGuard := false
    this._transactionStale := false
    this._nextTransactionNumber := 1
    this.LastSwitchError := ""
  }

  Start() {
    if (this._isRunning)
      return false
    this._isRunning := true
    try {
      if (IsObject(this.PlacementBackend) && HasMethod(this.PlacementBackend, "Start"))
        this.PlacementBackend.Start()
      this.Refresh()
      if (IsObject(this.WindowEventService))
        this.WindowEventService.Start(this._nativeEventCallback, this._reconciliationCallback)
      this._switchingEnabled := true
      this._suspended := false
      return true
    } catch Error as startError {
      this._isRunning := false
      if (IsObject(this.WindowEventService))
        try this.WindowEventService.Stop()
      try this._closePlacementBackend()
      this.Cache.Clear()
      try this._closeWindowBackend()
      throw startError
    }
  }

  Stop() {
    if (!this._isRunning)
      return false
    this._saveActiveObservedAsDesired()
    this._isRunning := false
    stopError := 0
    if (IsObject(this.WindowEventService)) {
      try this.WindowEventService.Stop()
      catch Error as eventStopError
        stopError := eventStopError
    }
    try this._closePlacementBackend()
    catch Error as placementCloseError {
      if (!IsObject(stopError))
        stopError := placementCloseError
    }
    try this._closeWindowBackend()
    catch Error as backendCloseError {
      if (!IsObject(stopError))
        stopError := backendCloseError
    }
    this.Cache.Clear()
    this._switchingEnabled := false
    this._suspended := false
    this._transactionGuard := false
    this._transactionStale := false
    if (IsObject(stopError))
      throw stopError
    return true
  }

  IsRunning() {
    return this._isRunning
  }

  Refresh() {
    if (!this._isRunning)
      throw Error("Synthetic workspace runtime is not running")
    snapshots := this.WindowBackend.ReadTopLevelWindowSnapshots()
    if (!(snapshots is Array))
      throw TypeError("Window backend must return an Array of snapshots")
    seenHwnds := Map()
    dialogSnapshots := []
    for snapshot in snapshots {
      this._validateSnapshot(snapshot)
      windowHwnd := snapshot["hwnd"]
      if (seenHwnds.Has(windowHwnd))
        throw ValueError("Window backend returned duplicate HWND", -1, windowHwnd)
      seenHwnds[windowHwnd] := true
      existingRecord := this.Cache.GetByHwnd(windowHwnd)
      workspaceId := this._resolveBaseWorkspaceId(snapshot["classification"], existingRecord)
      this.Cache.Upsert(snapshot, workspaceId)
      if (snapshot["classification"] = "owned-dialog")
        dialogSnapshots.Push(snapshot)
    }
    for snapshot in dialogSnapshots
      this._assignOwnedDialog(snapshot)
    for cachedHwnd in this.Cache.GetHwnds() {
      if (!seenHwnds.Has(cachedHwnd))
        this.Cache.RemoveByHwnd(cachedHwnd)
    }
    this._repairRecoveredUnsupported()
    return this.Cache.Count()
  }

  Reconcile() {
    if (!this._isRunning)
      throw Error("Synthetic workspace runtime is not running")
    if (!HasMethod(this.WindowBackend, "ReadReconciliationWindowSnapshots"))
      return this.Refresh()
    summaries := this.WindowBackend.ReadReconciliationWindowSnapshots()
    if (!(summaries is Array))
      throw TypeError("Window backend must return an Array of reconciliation snapshots")
    seenHwnds := Map()
    for summary in summaries {
      if (!(summary is Map) || !summary.Get("hwnd", 0))
        throw ValueError("Reconciliation snapshot must contain a valid HWND")
      windowHwnd := summary["hwnd"]
      if (seenHwnds.Has(windowHwnd))
        throw ValueError("Window backend returned duplicate reconciliation HWND", -1, windowHwnd)
      seenHwnds[windowHwnd] := true
      existingRecord := this.Cache.GetByHwnd(windowHwnd)
      if (!IsObject(existingRecord) || this._reconciliationSnapshotChanged(existingRecord, summary))
        this._refreshWindow(windowHwnd)
      else
        existingRecord.UpdateObservedStackIndex(summary.Get("stackIndex", existingRecord.State.Observed.Get("stackIndex", 0)))
    }
    for cachedHwnd in this.Cache.GetHwnds() {
      if (!seenHwnds.Has(cachedHwnd))
        this.Cache.RemoveByHwnd(cachedHwnd)
    }
    this._repairRecoveredUnsupported()
    return this.Cache.Count()
  }

  SetReconciliationPaused(paused) {
    if (!IsObject(this.WindowEventService) || !HasMethod(this.WindowEventService, "SetReconciliationPaused"))
      return false
    this.WindowEventService.SetReconciliationPaused(paused)
    return true
  }

  SwitchWorkspace(workspaceId) {
    this._requireSwitchingAvailable()
    this.Model.GetWorkspace(workspaceId)
    return this._runSwitchTransaction(workspaceId, Map())
  }

  MoveWindowToWorkspace(workspaceId, windowHwnd:=0) {
    this._requireSwitchingAvailable()
    this.Model.GetWorkspace(workspaceId)
    assignmentRollback := this._assignOwnerGroupToWorkspace(this._resolveActionRecord(windowHwnd), workspaceId)
    return this._runSwitchTransaction(this.Model.GetActiveWorkspaceId(), assignmentRollback)
  }

  MoveWindowAndSwitchWorkspace(workspaceId, windowHwnd:=0) {
    this._requireSwitchingAvailable()
    this.Model.GetWorkspace(workspaceId)
    assignmentRollback := this._assignOwnerGroupToWorkspace(this._resolveActionRecord(windowHwnd), workspaceId)
    return this._runSwitchTransaction(workspaceId, assignmentRollback)
  }

  RestoreAllWindows() {
    if (!this._isRunning)
      throw Error("Synthetic workspace runtime is not running")
    if (!IsObject(this.PlacementBackend))
      throw Error("Synthetic Workspaces capability unavailable: workspace placement")
    this._transactionStale := true
    if (!this._transactionGuard)
      try this.Refresh()
    this._saveActiveObservedAsDesired()
    this._clearAllPending()
    restoreSucceeded := this.PlacementBackend.EmergencyRestore(this.Cache.GetAll())
    this._switchingEnabled := false
    return restoreSucceeded
  }

  PrepareForSuspend() {
    if (!this._isRunning || this._suspended)
      return false
    restoreSucceeded := this.RestoreAllWindows()
    this._suspended := true
    if (!restoreSucceeded)
      throw Error("Synthetic workspace suspend cleanup failed")
    return true
  }

  ResumeAfterSuspend() {
    if (!this._isRunning || !this._suspended)
      return false
    try {
      this.Refresh()
      this._switchingEnabled := true
      this._suspended := false
      return true
    } catch Error as resumeError {
      this._switchingEnabled := false
      throw resumeError
    }
  }

  IsSwitchingEnabled() {
    return this._isRunning && this._switchingEnabled && !this._suspended
  }

  _runSwitchTransaction(destinationWorkspaceId, assignmentRollback) {
    if (this._transactionGuard)
      throw Error("A synthetic workspace switch is already active")
    this.LastSwitchError := ""
    sourceWorkspaceId := this.Model.GetActiveWorkspaceId()
    plan := 0
    rollbackSnapshot := 0
    candidateFocusHistories := 0
    committed := false
    unsafeStack := false
    rollbackSucceeded := true
    lastFailureReason := "workspace switch verification failed"
    this.SetReconciliationPaused(true)
    try {
      this.Refresh()
      priorFocusHwnd := this._getForegroundHwnd()
      rollbackSnapshot := this._captureRuntimeSnapshot()
      candidateFocusHistories := this._buildCandidateFocusHistories(sourceWorkspaceId, priorFocusHwnd)
      transactionId := "switch-" this._nextTransactionNumber
      this._nextTransactionNumber += 1
      plan := this._buildSwitchPlan(transactionId, sourceWorkspaceId, destinationWorkspaceId, rollbackSnapshot, candidateFocusHistories, priorFocusHwnd)
      this._transactionGuard := true
      attemptNumber := 1
      while (attemptNumber <= 2) {
        if (!this._switchingEnabled)
          throw Error("Synthetic workspace switching was disabled during the transaction")
        if (attemptNumber = 2) {
          this.Refresh()
          plan := this._buildSwitchPlan(transactionId, sourceWorkspaceId, destinationWorkspaceId, rollbackSnapshot, candidateFocusHistories, priorFocusHwnd)
        }
        this._transactionStale := false
        this._markPlanPending(plan)
        applyResult := 0
        try applyResult := this.PlacementBackend.ApplyPlan(plan)
        catch Error as applyError {
          lastFailureReason := applyError.Message
          applyResult := Map("success", false, "unsafeStack", true, "reason", applyError.Message)
        }
        applySucceeded := IsObject(applyResult) ? !!applyResult.Get("success", false) : !!applyResult
        if (IsObject(applyResult)) {
          unsafeStack := unsafeStack || !!applyResult.Get("unsafeStack", false)
          if (applyResult.Get("reason", "") != "")
            lastFailureReason := applyResult["reason"]
        }
        verified := false
        if (applySucceeded && !this._transactionStale) {
          try verified := !!this.PlacementBackend.VerifyPlan(plan)
          catch Error as verifyError
            lastFailureReason := verifyError.Message
        } else if (this._transactionStale)
          lastFailureReason := "window state changed during workspace switch"
        if (applySucceeded && verified && !this._transactionStale) {
          this._commitSwitchPlan(plan)
          committed := true
          return true
        }
        this._clearPlanPending(plan)
        attemptNumber += 1
      }
      throw Error("Synthetic workspace switch failed: " lastFailureReason)
    } catch Error as transactionError {
      if (IsObject(plan)) {
        try rollbackSucceeded := !!this.PlacementBackend.RollbackPlan(plan)
        catch
          rollbackSucceeded := false
      }
      if (IsObject(rollbackSnapshot))
        this._restoreRuntimeSnapshot(rollbackSnapshot)
      if (unsafeStack || !rollbackSucceeded) {
        try this.PlacementBackend.EmergencyRestore(this.Cache.GetAll())
        this._switchingEnabled := false
      }
      throw transactionError
    } finally {
      if (!committed)
        this._restoreAssignments(assignmentRollback)
      this._clearAllPending()
      this._transactionGuard := false
      this._transactionStale := false
      this.SetReconciliationPaused(false)
    }
  }

  _buildSwitchPlan(transactionId, sourceWorkspaceId, destinationWorkspaceId, rollbackSnapshot, candidateFocusHistories, priorFocusHwnd) {
    windowPlans := []
    for record in this.Cache.GetAll() {
      if (this._isInternalWindow(record.Hwnd))
        continue
      windowPlans.Push(this._buildWindowPlan(record, sourceWorkspaceId, destinationWorkspaceId, rollbackSnapshot))
    }
    bandPlan := this._buildBandPlan(windowPlans)
    focusHwnd := this._selectDestinationFocus(destinationWorkspaceId, candidateFocusHistories[destinationWorkspaceId], windowPlans)
    plan := Map(
      "transactionId", transactionId,
      "sourceWorkspaceId", sourceWorkspaceId,
      "destinationWorkspaceId", destinationWorkspaceId,
      "priorFocusHwnd", priorFocusHwnd,
      "focusHwnd", focusHwnd,
      "focusHistories", candidateFocusHistories,
      "windows", windowPlans,
      "activeGroups", bandPlan["activeGroups"],
      "inactiveGroups", bandPlan["inactiveGroups"],
      "specialTopmostGroups", bandPlan["specialTopmostGroups"],
      "shellHwnds", bandPlan["shellHwnds"],
      "inactiveHwnds", bandPlan["inactiveHwnds"],
      "pendingEntries", []
    )
    this._preparePendingEntries(plan)
    return plan
  }

  _buildWindowPlan(record, sourceWorkspaceId, destinationWorkspaceId, rollbackSnapshot) {
    currentState := this._cloneValue(record.State.Observed)
    if (rollbackSnapshot.Has(record.RuntimeRecordId))
      priorState := this._cloneValue(rollbackSnapshot[record.RuntimeRecordId]["observed"])
    else
      priorState := this._cloneValue(currentState)
    candidateDesired := this._cloneValue(record.State.Desired)
    candidateDesired["workspaceId"] := record.WorkspaceId
    if (!candidateDesired.Has("geometry") || !(candidateDesired["geometry"] is Map) || !candidateDesired["geometry"].Count)
      candidateDesired["geometry"] := this._cloneValue(currentState.Get("geometry", Map()))
    if (!candidateDesired.Has("topmost"))
      candidateDesired["topmost"] := !!currentState.Get("topmost", false)
    if (!candidateDesired.Has("fullscreen"))
      candidateDesired["fullscreen"] := !!currentState.Get("fullscreen", false)
    if (!candidateDesired.Has("minimized"))
      candidateDesired["minimized"] := !!currentState.Get("minimized", false)
    if (record.WorkspaceId = sourceWorkspaceId && this._isManageableRecord(record)) {
      candidateDesired["geometry"] := this._cloneValue(currentState.Get("geometry", Map()))
      candidateDesired["topmost"] := !!currentState.Get("topmost", false)
      candidateDesired["fullscreen"] := !!currentState.Get("fullscreen", false)
      candidateDesired["minimized"] := !!currentState.Get("minimized", false)
    }
    isGlobal := record.Classification = "global"
    isActive := isGlobal || (record.WorkspaceId != "" && record.WorkspaceId = destinationWorkspaceId)
    targetState := this._cloneValue(currentState)
    targetState["geometry"] := this._cloneValue(candidateDesired["geometry"])
    targetState["topmost"] := this._isManageableRecord(record) ? !!candidateDesired["topmost"] && isActive : !!currentState.Get("topmost", false)
    targetState["minimized"] := !!currentState.Get("minimized", false)
    if (this._isManageableRecord(record) && !!candidateDesired["fullscreen"])
      targetState["minimized"] := isActive ? !!candidateDesired["minimized"] : true
    role := this._getWindowRole(record, isActive)
    applyGeometry := this._isManageableRecord(record) && isActive && !targetState["minimized"] && !this._valuesEqual(currentState.Get("geometry", Map()), targetState["geometry"])
    applyTopmost := this._isManageableRecord(record) && !!currentState.Get("topmost", false) != targetState["topmost"]
    applyMinimized := this._isManageableRecord(record) && !!candidateDesired["fullscreen"] && !!currentState.Get("minimized", false) != targetState["minimized"]
    moveOffscreen := record.Classification = "unsupported" && record.WorkspaceId != "" && record.WorkspaceId != destinationWorkspaceId && !!currentState.Get("visible", false)
    return Map(
      "record", record,
      "runtimeRecordId", record.RuntimeRecordId,
      "hwnd", record.Hwnd,
      "rootOwnerHwnd", record.RootOwnerHwnd ? record.RootOwnerHwnd : record.Hwnd,
      "classification", record.Classification,
      "workspaceId", record.WorkspaceId,
      "role", role,
      "prior", priorState,
      "current", currentState,
      "target", targetState,
      "candidateDesired", candidateDesired,
      "applyGeometry", applyGeometry,
      "applyTopmost", applyTopmost,
      "applyMinimized", applyMinimized,
      "moveOffscreen", moveOffscreen
    )
  }

  _buildBandPlan(windowPlans) {
    groupsByRoot := Map()
    shellPlans := []
    inactiveHwnds := []
    for windowPlan in windowPlans {
      if (windowPlan["role"] = "shell") {
        this._insertWindowPlanByStack(shellPlans, windowPlan)
        continue
      }
      if (windowPlan["role"] != "active" && windowPlan["role"] != "inactive")
        continue
      if (windowPlan["role"] = "inactive")
        inactiveHwnds.Push(windowPlan["hwnd"])
      if (windowPlan["target"]["minimized"])
        continue
      rootOwnerHwnd := windowPlan["rootOwnerHwnd"]
      if (!groupsByRoot.Has(rootOwnerHwnd))
        groupsByRoot[rootOwnerHwnd] := []
      this._insertWindowPlanByStack(groupsByRoot[rootOwnerHwnd], windowPlan)
    }
    activeGroups := []
    inactiveGroups := []
    specialTopmostGroups := []
    for rootOwnerHwnd, groupPlans in groupsByRoot {
      groupHwnds := []
      groupIsTopmost := false
      for windowPlan in groupPlans {
        groupHwnds.Push(windowPlan["hwnd"])
        groupIsTopmost := groupIsTopmost || !!windowPlan["target"]["topmost"]
      }
      if (groupIsTopmost)
        this._insertGroupByStack(specialTopmostGroups, groupHwnds, groupPlans[1]["current"].Get("stackIndex", 0))
      else if (groupPlans[1]["role"] = "active")
        this._insertGroupByStack(activeGroups, groupHwnds, groupPlans[1]["current"].Get("stackIndex", 0))
      else
        this._insertGroupByStack(inactiveGroups, groupHwnds, groupPlans[1]["current"].Get("stackIndex", 0))
    }
    shellHwnds := []
    for shellPlan in shellPlans
      shellHwnds.Push(shellPlan["hwnd"])
    return Map("activeGroups", this._unwrapGroups(activeGroups), "inactiveGroups", this._unwrapGroups(inactiveGroups), "specialTopmostGroups", this._unwrapGroups(specialTopmostGroups), "shellHwnds", shellHwnds, "inactiveHwnds", inactiveHwnds)
  }

  _preparePendingEntries(plan) {
    for windowPlan in plan["windows"] {
      if (windowPlan["applyGeometry"])
        this._addPendingEntry(plan, windowPlan, "geometry", windowPlan["prior"].Get("geometry", Map()), windowPlan["target"]["geometry"])
      if (windowPlan["applyTopmost"])
        this._addPendingEntry(plan, windowPlan, "topmost", windowPlan["prior"].Get("topmost", false), windowPlan["target"]["topmost"])
      if (windowPlan["applyMinimized"])
        this._addPendingEntry(plan, windowPlan, "minimized", windowPlan["prior"].Get("minimized", false), windowPlan["target"]["minimized"])
      if (windowPlan["role"] = "active" || windowPlan["role"] = "inactive")
        this._addPendingEntry(plan, windowPlan, "stack", windowPlan["prior"].Get("stackIndex", 0), windowPlan["role"])
      if (windowPlan["moveOffscreen"])
        this._addPendingEntry(plan, windowPlan, "offscreen", windowPlan["prior"].Get("geometry", Map()), "outside-virtual-desktop")
      if (windowPlan["hwnd"] = plan["focusHwnd"])
        this._addPendingEntry(plan, windowPlan, "focus", false, true)
    }
  }

  _addPendingEntry(plan, windowPlan, propertyName, priorValue, expectedValue) {
    plan["pendingEntries"].Push(Map("transactionId", plan["transactionId"], "runtimeRecordId", windowPlan["runtimeRecordId"], "property", propertyName, "prior", this._cloneValue(priorValue), "expected", this._cloneValue(expectedValue), "record", windowPlan["record"]))
  }

  _markPlanPending(plan) {
    for pendingEntry in plan["pendingEntries"]
      pendingEntry["record"].State.Pending[pendingEntry["property"]] := pendingEntry
  }

  _clearPlanPending(plan) {
    for pendingEntry in plan["pendingEntries"] {
      record := pendingEntry["record"]
      propertyName := pendingEntry["property"]
      if (record.State.Pending.Has(propertyName) && record.State.Pending[propertyName].Get("transactionId", "") = plan["transactionId"])
        record.State.Pending.Delete(propertyName)
    }
  }

  _clearAllPending() {
    for record in this.Cache.GetAll()
      record.State.Pending := Map()
  }

  _commitSwitchPlan(plan) {
    for windowPlan in plan["windows"] {
      record := this.Cache.GetByRuntimeId(windowPlan["runtimeRecordId"])
      if (IsObject(record))
        record.State.Desired := this._cloneValue(windowPlan["candidateDesired"])
    }
    for workspaceId, focusHistory in plan["focusHistories"]
      this.Model.GetWorkspace(workspaceId).FocusHistory := this._cloneValue(focusHistory)
    this.Model.CommitActiveWorkspace(plan["destinationWorkspaceId"])
    if (HasMethod(this.Model, "PublishRevision"))
      this.Model.PublishRevision()
  }

  _captureRuntimeSnapshot() {
    snapshotByRuntimeId := Map()
    for record in this.Cache.GetAll()
      snapshotByRuntimeId[record.RuntimeRecordId] := Map("observed", this._cloneValue(record.State.Observed), "desired", this._cloneValue(record.State.Desired), "workspaceId", record.WorkspaceId)
    return snapshotByRuntimeId
  }

  _restoreRuntimeSnapshot(snapshotByRuntimeId) {
    for runtimeRecordId, savedRecord in snapshotByRuntimeId {
      record := this.Cache.GetByRuntimeId(runtimeRecordId)
      if (!IsObject(record))
        continue
      record.State.Desired := this._cloneValue(savedRecord["desired"])
    }
  }

  _buildCandidateFocusHistories(sourceWorkspaceId, foregroundHwnd) {
    histories := Map()
    for workspaceId in this.Model.GetWorkspaceIds()
      histories[workspaceId] := this._cloneValue(this.Model.GetWorkspace(workspaceId).FocusHistory)
    foregroundRecord := foregroundHwnd ? this.Cache.GetByHwnd(foregroundHwnd) : 0
    if (IsObject(foregroundRecord) && foregroundRecord.WorkspaceId = sourceWorkspaceId && this._isManageableRecord(foregroundRecord))
      this._moveRuntimeIdToHistoryFront(histories[sourceWorkspaceId], foregroundRecord.RuntimeRecordId)
    return histories
  }

  _selectDestinationFocus(destinationWorkspaceId, focusHistory, windowPlans) {
    plansByRuntimeId := Map()
    focusCandidates := []
    for windowPlan in windowPlans {
      plansByRuntimeId[windowPlan["runtimeRecordId"]] := windowPlan
      if (windowPlan["role"] = "active" && !windowPlan["target"]["minimized"] && !!windowPlan["current"].Get("visible", false))
        this._insertWindowPlanByStack(focusCandidates, windowPlan)
    }
    for runtimeRecordId in focusHistory {
      if (!plansByRuntimeId.Has(runtimeRecordId))
        continue
      windowPlan := plansByRuntimeId[runtimeRecordId]
      if (windowPlan["workspaceId"] = destinationWorkspaceId && windowPlan["role"] = "active" && !windowPlan["target"]["minimized"] && !!windowPlan["current"].Get("visible", false))
        return windowPlan["hwnd"]
    }
    return focusCandidates.Length ? focusCandidates[1]["hwnd"] : 0
  }

  _moveRuntimeIdToHistoryFront(focusHistory, runtimeRecordId) {
    for historyIndex, existingRuntimeId in focusHistory {
      if (existingRuntimeId = runtimeRecordId) {
        focusHistory.RemoveAt(historyIndex)
        break
      }
    }
    focusHistory.InsertAt(1, runtimeRecordId)
  }

  _assignOwnerGroupToWorkspace(record, workspaceId) {
    rootOwnerHwnd := record.RootOwnerHwnd ? record.RootOwnerHwnd : record.Hwnd
    assignmentRollback := Map()
    for groupRecord in this.Cache.GetAll() {
      groupRootHwnd := groupRecord.RootOwnerHwnd ? groupRecord.RootOwnerHwnd : groupRecord.Hwnd
      if (groupRootHwnd != rootOwnerHwnd || !this._isWorkspaceAssignableRecord(groupRecord))
        continue
      assignmentRollback[groupRecord.RuntimeRecordId] := groupRecord.WorkspaceId
      groupRecord.AssignWorkspace(workspaceId)
    }
    return assignmentRollback
  }

  _restoreAssignments(assignmentRollback) {
    if (!(assignmentRollback is Map))
      return
    for runtimeRecordId, workspaceId in assignmentRollback {
      record := this.Cache.GetByRuntimeId(runtimeRecordId)
      if (IsObject(record))
        record.AssignWorkspace(workspaceId)
    }
  }

  _saveActiveObservedAsDesired() {
    activeWorkspaceId := this.Model.GetActiveWorkspaceId()
    for record in this.Cache.GetAll() {
      if (record.WorkspaceId != activeWorkspaceId || !this._isManageableRecord(record))
        continue
      observedState := record.State.Observed
      record.State.Desired["geometry"] := this._cloneValue(observedState.Get("geometry", Map()))
      record.State.Desired["topmost"] := !!observedState.Get("topmost", false)
      record.State.Desired["fullscreen"] := !!observedState.Get("fullscreen", false)
      record.State.Desired["minimized"] := !!observedState.Get("minimized", false)
    }
  }

  _resolveActionRecord(windowHwnd) {
    if (!windowHwnd)
      windowHwnd := this._getForegroundHwnd()
    record := this.Cache.GetByHwnd(windowHwnd)
    if (!IsObject(record))
      throw Error("The selected window is not in the synthetic workspace cache")
    if (!this._isWorkspaceAssignableRecord(record))
      throw Error("The selected window cannot be assigned to a synthetic workspace")
    rootOwnerHwnd := record.RootOwnerHwnd ? record.RootOwnerHwnd : record.Hwnd
    rootRecord := this.Cache.GetByHwnd(rootOwnerHwnd)
    return IsObject(rootRecord) && this._isWorkspaceAssignableRecord(rootRecord) ? rootRecord : record
  }

  _getWindowRole(record, isActive) {
    if (record.Classification = "shell")
      return record.IsHaribolShell ? "shell" : "ignored"
    if (record.Classification = "unsupported")
      return "unsupported"
    if (this._isManageableRecord(record))
      return isActive ? "active" : "inactive"
    return "ignored"
  }

  _isManageableRecord(record) {
    return record.Classification = "managed" || record.Classification = "owned-dialog" || record.Classification = "global"
  }

  _isWorkspaceAssignableRecord(record) {
    return record.Classification = "managed" || record.Classification = "owned-dialog" || record.Classification = "unsupported"
  }

  _insertWindowPlanByStack(windowPlans, windowPlan) {
    insertIndex := windowPlans.Length + 1
    candidateStackIndex := windowPlan["current"].Get("stackIndex", 0)
    for idx, existingPlan in windowPlans {
      if (candidateStackIndex < existingPlan["current"].Get("stackIndex", 0)) {
        insertIndex := idx
        break
      }
    }
    windowPlans.InsertAt(insertIndex, windowPlan)
  }

  _insertGroupByStack(groups, groupHwnds, stackIndex) {
    groupEntry := Map("hwnds", groupHwnds, "stackIndex", stackIndex)
    insertIndex := groups.Length + 1
    for idx, existingGroup in groups {
      if (stackIndex < existingGroup["stackIndex"]) {
        insertIndex := idx
        break
      }
    }
    groups.InsertAt(insertIndex, groupEntry)
  }

  _unwrapGroups(groupEntries) {
    groups := []
    for groupEntry in groupEntries
      groups.Push(groupEntry["hwnds"])
    return groups
  }

  _getForegroundHwnd() {
    if (!IsObject(this.PlacementBackend) || !HasMethod(this.PlacementBackend, "GetForegroundHwnd"))
      return 0
    return this.PlacementBackend.GetForegroundHwnd()
  }

  _isInternalWindow(windowHwnd) {
    return IsObject(this.PlacementBackend) && HasMethod(this.PlacementBackend, "IsInternalWindow") && this.PlacementBackend.IsInternalWindow(windowHwnd)
  }

  _requireSwitchingAvailable() {
    if (!this._isRunning)
      throw Error("Synthetic workspace runtime is not running")
    if (!this._switchingEnabled || this._suspended)
      throw Error("Synthetic workspace switching is disabled until the runtime resumes")
    if (!IsObject(this.PlacementBackend))
      throw Error("Synthetic Workspaces capability unavailable: workspace placement")
  }

  _cloneValue(value) {
    if (value is Map) {
      clonedMap := Map()
      for propertyName, propertyValue in value
        clonedMap[propertyName] := this._cloneValue(propertyValue)
      return clonedMap
    }
    if (value is Array) {
      clonedArray := []
      for item in value
        clonedArray.Push(this._cloneValue(item))
      return clonedArray
    }
    return value
  }

  _valuesEqual(firstValue, secondValue) {
    if (firstValue is Map) {
      if (!(secondValue is Map) || firstValue.Count != secondValue.Count)
        return false
      for propertyName, propertyValue in firstValue {
        if (!secondValue.Has(propertyName) || !this._valuesEqual(propertyValue, secondValue[propertyName]))
          return false
      }
      return true
    }
    if (firstValue is Array) {
      if (!(secondValue is Array) || firstValue.Length != secondValue.Length)
        return false
      for idx, item in firstValue {
        if (!this._valuesEqual(item, secondValue[idx]))
          return false
      }
      return true
    }
    return firstValue = secondValue
  }

  _resolveBaseWorkspaceId(classification, existingRecord) {
    if (classification = "managed" || classification = "unsupported") {
      if (IsObject(existingRecord) && existingRecord.WorkspaceId != "")
        return existingRecord.WorkspaceId
      return this.Model.GetActiveWorkspaceId()
    }
    if (classification = "owned-dialog" && IsObject(existingRecord))
      return existingRecord.WorkspaceId
    return ""
  }

  _assignOwnedDialog(snapshot) {
    dialogRecord := this.Cache.GetByHwnd(snapshot["hwnd"])
    rootOwnerHwnd := snapshot.Get("rootOwnerHwnd", 0)
    rootOwnerRecord := rootOwnerHwnd ? this.Cache.GetByHwnd(rootOwnerHwnd) : 0
    if (IsObject(rootOwnerRecord)) {
      dialogRecord.AssignWorkspace(rootOwnerRecord.WorkspaceId)
      return
    }
    fallbackWorkspaceId := dialogRecord.WorkspaceId != "" ? dialogRecord.WorkspaceId : this.Model.GetActiveWorkspaceId()
    dialogRecord.AssignWorkspace(fallbackWorkspaceId)
    dialogRecord.SetClassification("unsupported", "owned dialog root owner is unavailable")
  }

  _handleNativeWindowEvent(eventData) {
    if (!this._isRunning)
      return false
    if (!(eventData is Map))
      throw TypeError("Native window event must be a Map")
    eventType := eventData.Get("type", "")
    windowHwnd := eventData.Get("hwnd", 0)
    if (!windowHwnd)
      return false
    if (this._transactionGuard)
      return this._handleTransactionWindowEvent(eventType, windowHwnd)
    if (eventType = "destroy")
      return this.Cache.RemoveByHwnd(windowHwnd)
    if (eventType != "create" && eventType != "activate" && eventType != "title" && eventType != "state" && eventType != "geometry" && eventType != "stack")
      return false
    record := this._refreshWindow(windowHwnd)
    if (!IsObject(record))
      return false
    if (eventType = "create")
      this._repairOwnedDialogsForRoot(windowHwnd)
    if (eventType = "activate") {
      this._recordFocus(record, eventData.Get("eventTime", 0))
      if (IsObject(this.PlacementBackend) && this.IsSwitchingEnabled() && this._isWorkspaceAssignableRecord(record) && record.WorkspaceId != "" && record.WorkspaceId != this.Model.GetActiveWorkspaceId()) {
        try this.SwitchWorkspace(record.WorkspaceId)
        catch Error as activationSwitchError
          this.LastSwitchError := activationSwitchError.Message
      }
    }
    return true
  }

  _handleTransactionWindowEvent(eventType, windowHwnd) {
    if (eventType = "destroy") {
      this._transactionStale := true
      return this.Cache.RemoveByHwnd(windowHwnd)
    }
    if (eventType != "create" && eventType != "activate" && eventType != "title" && eventType != "state" && eventType != "geometry" && eventType != "stack")
      return false
    record := this._refreshWindow(windowHwnd)
    if (!IsObject(record)) {
      this._transactionStale := true
      return false
    }
    if (eventType = "create" || (eventType != "title" && !this._pendingEventMatches(record, eventType)))
      this._transactionStale := true
    return true
  }

  _pendingEventMatches(record, eventType) {
    pendingState := record.State.Pending
    observedState := record.State.Observed
    if (eventType = "stack")
      return pendingState.Has("stack")
    if (eventType = "activate")
      return pendingState.Has("focus") && this._getForegroundHwnd() = record.Hwnd
    if (eventType = "geometry") {
      if (pendingState.Has("geometry") && this._valuesEqual(observedState.Get("geometry", Map()), pendingState["geometry"]["expected"]))
        return true
      return pendingState.Has("offscreen")
    }
    if (eventType = "state") {
      for propertyName in ["topmost", "minimized"] {
        if (pendingState.Has(propertyName) && observedState.Get(propertyName, false) = pendingState[propertyName]["expected"])
          return true
      }
    }
    return false
  }

  _refreshWindow(windowHwnd) {
    snapshot := this.WindowBackend.ReadWindowSnapshot(windowHwnd)
    if (!(snapshot is Map)) {
      this.Cache.RemoveByHwnd(windowHwnd)
      return 0
    }
    this._validateSnapshot(snapshot)
    existingRecord := this.Cache.GetByHwnd(windowHwnd)
    workspaceId := this._resolveBaseWorkspaceId(snapshot["classification"], existingRecord)
    record := this.Cache.Upsert(snapshot, workspaceId)
    if (snapshot["classification"] = "owned-dialog")
      this._assignOwnedDialog(snapshot)
    return record
  }

  _repairOwnedDialogsForRoot(rootOwnerHwnd) {
    for record in this.Cache.GetAll() {
      if (record.Hwnd = rootOwnerHwnd || record.RootOwnerHwnd != rootOwnerHwnd)
        continue
      if (record.Classification = "unsupported" && record.ClassificationReason = "owned dialog root owner is unavailable")
        this._refreshWindow(record.Hwnd)
    }
  }

  _recordFocus(record, eventTime) {
    if (record.WorkspaceId = "")
      return
    record.LastFocusTime := eventTime ? eventTime : A_TickCount
    workspace := this.Model.GetWorkspace(record.WorkspaceId)
    for historyIndex, runtimeRecordId in workspace.FocusHistory {
      if (runtimeRecordId = record.RuntimeRecordId) {
        workspace.FocusHistory.RemoveAt(historyIndex)
        break
      }
    }
    workspace.FocusHistory.InsertAt(1, record.RuntimeRecordId)
  }

  _reconciliationSnapshotChanged(record, summary) {
    titleChanged := record.Title != summary.Get("title", record.Title)
    ownerChanged := record.OwnerHwnd != summary.Get("ownerHwnd", record.OwnerHwnd) || record.RootOwnerHwnd != summary.Get("rootOwnerHwnd", record.RootOwnerHwnd)
    responsivenessChanged := record.Responsive != !!summary.Get("responsive", record.Responsive)
    if (titleChanged || ownerChanged || responsivenessChanged)
      return true
    observedState := record.State.Observed
    stateProperties := ["visible", "minimized", "maximized", "topmost", "cloaked"]
    for propertyName in stateProperties {
      if (observedState.Get(propertyName, false) != !!summary.Get(propertyName, observedState.Get(propertyName, false)))
        return true
    }
    if (!this._mapsEqual(observedState.Get("geometry", 0), summary.Get("geometry", 0)))
      return true
    return false
  }

  _mapsEqual(firstMap, secondMap) {
    if (!(firstMap is Map) || !(secondMap is Map) || firstMap.Count != secondMap.Count)
      return false
    for propertyName, propertyValue in firstMap {
      if (!secondMap.Has(propertyName) || secondMap[propertyName] != propertyValue)
        return false
    }
    return true
  }

  _closeWindowBackend() {
    if (HasMethod(this.WindowBackend, "Close"))
      this.WindowBackend.Close()
  }

  _closePlacementBackend() {
    if (!IsObject(this.PlacementBackend))
      return
    if (HasMethod(this.PlacementBackend, "EmergencyRestore"))
      this.PlacementBackend.EmergencyRestore(this.Cache.GetAll())
    if (HasMethod(this.PlacementBackend, "Close"))
      this.PlacementBackend.Close()
  }

  _repairRecoveredUnsupported() {
    if (IsObject(this.PlacementBackend) && HasMethod(this.PlacementBackend, "RepairRecoveredUnsupported"))
      this.PlacementBackend.RepairRecoveredUnsupported(this.Cache.GetAll())
  }

  _validateSnapshot(snapshot) {
    if (!(snapshot is Map))
      throw TypeError("Window backend snapshot must be a Map")
    if (!snapshot.Get("hwnd", 0))
      throw ValueError("Window backend snapshot must contain a valid HWND")
    if (!snapshot.Has("classification") || !snapshot.Has("classificationReason"))
      throw ValueError("Window backend snapshot must contain classification and diagnostic reason")
  }
}

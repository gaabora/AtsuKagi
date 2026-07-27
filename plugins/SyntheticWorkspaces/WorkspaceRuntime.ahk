#Include RuntimeWindowCache.ahk

class SyntheticWorkspaceRuntime {
  __New(workspaceModel, windowBackend, runtimeWindowCache:=0, windowEventService:=0) {
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
    this.Model := workspaceModel
    this.WindowBackend := windowBackend
    this.Cache := runtimeWindowCache
    this.WindowEventService := windowEventService
    this._nativeEventCallback := this._handleNativeWindowEvent.Bind(this)
    this._reconciliationCallback := this.Reconcile.Bind(this)
    this._isRunning := false
  }

  Start() {
    if (this._isRunning)
      return false
    this._isRunning := true
    try {
      this.Refresh()
      if (IsObject(this.WindowEventService))
        this.WindowEventService.Start(this._nativeEventCallback, this._reconciliationCallback)
      return true
    } catch Error as startError {
      this._isRunning := false
      if (IsObject(this.WindowEventService))
        try this.WindowEventService.Stop()
      this.Cache.Clear()
      try this._closeWindowBackend()
      throw startError
    }
  }

  Stop() {
    if (!this._isRunning)
      return false
    this._isRunning := false
    stopError := 0
    if (IsObject(this.WindowEventService)) {
      try this.WindowEventService.Stop()
      catch Error as eventStopError
        stopError := eventStopError
    }
    try this._closeWindowBackend()
    catch Error as backendCloseError {
      if (!IsObject(stopError))
        stopError := backendCloseError
    }
    this.Cache.Clear()
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
    return this.Cache.Count()
  }

  SetReconciliationPaused(paused) {
    if (!IsObject(this.WindowEventService) || !HasMethod(this.WindowEventService, "SetReconciliationPaused"))
      return false
    this.WindowEventService.SetReconciliationPaused(paused)
    return true
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
    if (eventType = "destroy")
      return this.Cache.RemoveByHwnd(windowHwnd)
    if (eventType != "create" && eventType != "activate" && eventType != "title" && eventType != "state" && eventType != "geometry" && eventType != "stack")
      return false
    record := this._refreshWindow(windowHwnd)
    if (!IsObject(record))
      return false
    if (eventType = "create")
      this._repairOwnedDialogsForRoot(windowHwnd)
    if (eventType = "activate")
      this._recordFocus(record, eventData.Get("eventTime", 0))
    return true
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

  _validateSnapshot(snapshot) {
    if (!(snapshot is Map))
      throw TypeError("Window backend snapshot must be a Map")
    if (!snapshot.Get("hwnd", 0))
      throw ValueError("Window backend snapshot must contain a valid HWND")
    if (!snapshot.Has("classification") || !snapshot.Has("classificationReason"))
      throw ValueError("Window backend snapshot must contain classification and diagnostic reason")
  }
}

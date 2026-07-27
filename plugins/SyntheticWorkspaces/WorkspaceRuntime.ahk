#Include RuntimeWindowCache.ahk

class SyntheticWorkspaceRuntime {
  __New(workspaceModel, windowBackend, runtimeWindowCache:=0) {
    if (!(workspaceModel is SyntheticWorkspaceModel))
      throw TypeError("Workspace runtime requires a SyntheticWorkspaceModel")
    if (!IsObject(windowBackend) || !HasMethod(windowBackend, "ReadTopLevelWindowSnapshots"))
      throw TypeError("Workspace runtime requires a window snapshot backend")
    if (!IsObject(runtimeWindowCache))
      runtimeWindowCache := SyntheticWorkspaceRuntimeWindowCache()
    if (!(runtimeWindowCache is SyntheticWorkspaceRuntimeWindowCache))
      throw TypeError("Workspace runtime cache must be a SyntheticWorkspaceRuntimeWindowCache")
    this.Model := workspaceModel
    this.WindowBackend := windowBackend
    this.Cache := runtimeWindowCache
    this._isRunning := false
  }

  Start() {
    if (this._isRunning)
      return false
    this._isRunning := true
    try {
      this.Refresh()
      return true
    } catch Error as startError {
      this._isRunning := false
      this.Cache.Clear()
      throw startError
    }
  }

  Stop() {
    if (!this._isRunning)
      return false
    this._isRunning := false
    this.Cache.Clear()
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

  _validateSnapshot(snapshot) {
    if (!(snapshot is Map))
      throw TypeError("Window backend snapshot must be a Map")
    if (!snapshot.Get("hwnd", 0))
      throw ValueError("Window backend snapshot must contain a valid HWND")
    if (!snapshot.Has("classification") || !snapshot.Has("classificationReason"))
      throw ValueError("Window backend snapshot must contain classification and diagnostic reason")
  }
}

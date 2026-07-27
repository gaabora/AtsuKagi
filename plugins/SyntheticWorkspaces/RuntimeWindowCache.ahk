#Include WorkspaceModel.ahk

class SyntheticWorkspaceRuntimeWindowRecord {
  __New(runtimeRecordId, snapshot, workspaceId:="") {
    if (Type(runtimeRecordId) != "String" || Trim(runtimeRecordId) = "")
      throw ValueError("Runtime record ID must be a non-empty string", -1, runtimeRecordId)
    this._runtimeRecordId := runtimeRecordId
    this.State := SyntheticWorkspaceRuntimeWindowState()
    this.WorkspaceId := ""
    this.LastFocusTime := 0
    this.MatchedProfileId := ""
    this.UpdateSnapshot(snapshot)
    this.AssignWorkspace(workspaceId)
  }

  RuntimeRecordId {
    get => this._runtimeRecordId
  }

  UpdateSnapshot(snapshot) {
    if (!(snapshot is Map))
      throw TypeError("Runtime window snapshot must be a Map")
    windowHwnd := snapshot.Get("hwnd", 0)
    if (!windowHwnd)
      throw ValueError("Runtime window snapshot must contain a valid HWND", -1, windowHwnd)
    if (this.HasOwnProp("Hwnd") && this.Hwnd != windowHwnd)
      throw ValueError("Runtime window record HWND cannot change", -1, windowHwnd)
    this.Hwnd := windowHwnd
    this.Pid := snapshot.Get("pid", 0)
    this.ExecutablePath := snapshot.Get("executablePath", "")
    this.ExecutableName := snapshot.Get("executableName", "")
    this.WindowClass := snapshot.Get("windowClass", "")
    this.AppUserModelId := snapshot.Get("appUserModelId", "")
    this.AppUserModelIdAvailable := !!snapshot.Get("appUserModelIdAvailable", false)
    this.AppUserModelIdReason := snapshot.Get("appUserModelIdReason", "")
    this.Title := snapshot.Get("title", "")
    this.NormalizedTitle := snapshot.Has("normalizedTitle") ? snapshot["normalizedTitle"] : this._normalizeTitle(this.Title)
    this.OwnerHwnd := snapshot.Get("ownerHwnd", 0)
    this.RootOwnerHwnd := snapshot.Get("rootOwnerHwnd", this.Hwnd)
    this.PopupHwnd := snapshot.Get("popupHwnd", 0)
    this.Classification := snapshot.Get("classification", "")
    this.ClassificationReason := snapshot.Get("classificationReason", "")
    this._validateClassification(this.Classification, this.ClassificationReason)
    observedState := Map(
      "geometry", this._cloneMap(snapshot.Get("geometry", 0)),
      "monitor", this._cloneMap(snapshot.Get("monitor", 0)),
      "visible", !!snapshot.Get("visible", false),
      "minimized", !!snapshot.Get("minimized", false),
      "maximized", !!snapshot.Get("maximized", false),
      "fullscreen", !!snapshot.Get("fullscreen", false),
      "topmost", !!snapshot.Get("topmost", false),
      "cloaked", !!snapshot.Get("cloaked", false),
      "stackIndex", snapshot.Get("stackIndex", 0)
    )
    this.State.Observed := observedState
    this.DisplayTitle := snapshot.Get("displayTitle", this.Title)
    this.Icon := snapshot.Get("icon", 0)
    this.BaseColor := snapshot.Get("baseColor", "")
    this.ColorPreset := snapshot.Get("colorPreset", "")
  }

  AssignWorkspace(workspaceId) {
    if (Type(workspaceId) != "String")
      throw TypeError("Runtime workspace ID must be a string")
    this.WorkspaceId := workspaceId
    this.State.Desired["workspaceId"] := workspaceId
  }

  SetClassification(classification, reason) {
    this._validateClassification(classification, reason)
    this.Classification := classification
    this.ClassificationReason := reason
  }

  _validateClassification(classification, reason) {
    validClasses := Map("managed", true, "owned-dialog", true, "global", true, "shell", true, "ignored", true, "unsupported", true)
    if (!validClasses.Has(classification))
      throw ValueError("Unknown runtime window classification", -1, classification)
    if (Type(reason) != "String" || Trim(reason) = "")
      throw ValueError("Runtime window classification requires a diagnostic reason", -1, reason)
  }

  _normalizeTitle(title) {
    return Trim(RegExReplace("" title, "\s+", " "))
  }

  _cloneMap(sourceMap) {
    if (!(sourceMap is Map))
      return Map()
    clonedMap := Map()
    for propertyName, propertyValue in sourceMap
      clonedMap[propertyName] := propertyValue
    return clonedMap
  }
}

class SyntheticWorkspaceRuntimeWindowCache {
  __New() {
    this._recordsByHwnd := Map()
    this._recordsByRuntimeId := Map()
    this._nextRuntimeNumber := 1
  }

  Upsert(snapshot, workspaceId:="") {
    if (!(snapshot is Map))
      throw TypeError("Runtime window snapshot must be a Map")
    windowHwnd := snapshot.Get("hwnd", 0)
    if (!windowHwnd)
      throw ValueError("Runtime window snapshot must contain a valid HWND", -1, windowHwnd)
    if (this._recordsByHwnd.Has(windowHwnd)) {
      record := this._recordsByHwnd[windowHwnd]
      record.UpdateSnapshot(snapshot)
      record.AssignWorkspace(workspaceId)
      return record
    }
    runtimeRecordId := "runtime-" this._nextRuntimeNumber
    this._nextRuntimeNumber += 1
    record := SyntheticWorkspaceRuntimeWindowRecord(runtimeRecordId, snapshot, workspaceId)
    this._recordsByHwnd[windowHwnd] := record
    this._recordsByRuntimeId[runtimeRecordId] := record
    return record
  }

  RemoveByHwnd(windowHwnd) {
    if (!this._recordsByHwnd.Has(windowHwnd))
      return false
    record := this._recordsByHwnd[windowHwnd]
    this._recordsByHwnd.Delete(windowHwnd)
    this._recordsByRuntimeId.Delete(record.RuntimeRecordId)
    return true
  }

  HasHwnd(windowHwnd) {
    return this._recordsByHwnd.Has(windowHwnd)
  }

  GetByHwnd(windowHwnd) {
    return this._recordsByHwnd.Has(windowHwnd) ? this._recordsByHwnd[windowHwnd] : 0
  }

  GetByRuntimeId(runtimeRecordId) {
    return this._recordsByRuntimeId.Has(runtimeRecordId) ? this._recordsByRuntimeId[runtimeRecordId] : 0
  }

  GetAll() {
    records := []
    for runtimeRecordId, record in this._recordsByRuntimeId
      records.Push(record)
    return records
  }

  GetByClassification(classification) {
    records := []
    for runtimeRecordId, record in this._recordsByRuntimeId {
      if (record.Classification = classification)
        records.Push(record)
    }
    return records
  }

  GetHwnds() {
    windowHwnds := []
    for windowHwnd, record in this._recordsByHwnd
      windowHwnds.Push(windowHwnd)
    return windowHwnds
  }

  Count() {
    return this._recordsByHwnd.Count
  }

  Clear() {
    this._recordsByHwnd := Map()
    this._recordsByRuntimeId := Map()
  }
}

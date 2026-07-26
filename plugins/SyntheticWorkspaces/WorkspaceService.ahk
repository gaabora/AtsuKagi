#Include WorkspaceModel.ahk

class SyntheticWorkspaceService {
  __New(workspaceModel:=0, workspaceRuntime:=0, overviewRuntime:=0) {
    if (!IsObject(workspaceModel)) {
      if (workspaceModel != 0)
        throw TypeError("Workspace model must be a SyntheticWorkspaceModel")
      workspaceModel := SyntheticWorkspaceService.CreateDefaultModel()
    }
    if (!(workspaceModel is SyntheticWorkspaceModel))
      throw TypeError("Workspace model must be a SyntheticWorkspaceModel")
    this.Model := workspaceModel
    this._workspaceRuntime := workspaceRuntime
    this._overviewRuntime := overviewRuntime
    this._isRunning := false
  }

  static CreateDefaultModel() {
    workspaces := []
    slotMap := Map()
    workspaceNumber := 1
    for slotId in SyntheticWorkspaceModel.GetSlotIds() {
      workspaceId := "workspace-" workspaceNumber
      workspaces.Push(SyntheticWorkspaceRecord(workspaceId))
      slotMap[slotId] := workspaceId
      workspaceNumber += 1
    }
    return SyntheticWorkspaceModel(workspaces, slotMap, slotMap["n"])
  }

  Start() {
    if (this._isRunning)
      return false
    workspaceStarted := false
    try {
      if (IsObject(this._workspaceRuntime)) {
        this._callCapability(this._workspaceRuntime, "Start", "workspace runtime lifecycle")
        workspaceStarted := true
      }
      if (IsObject(this._overviewRuntime))
        this._callCapability(this._overviewRuntime, "Start", "overview runtime lifecycle")
      this._isRunning := true
      return true
    } catch Error as startError {
      if (workspaceStarted)
        try this._callCapability(this._workspaceRuntime, "Stop", "workspace runtime lifecycle")
      throw startError
    }
  }

  Stop() {
    if (!this._isRunning)
      return false
    this._isRunning := false
    stopError := 0
    if (IsObject(this._overviewRuntime)) {
      try this._callCapability(this._overviewRuntime, "Stop", "overview runtime lifecycle")
      catch Error as overviewStopError
        stopError := overviewStopError
    }
    if (IsObject(this._workspaceRuntime)) {
      try this._callCapability(this._workspaceRuntime, "Stop", "workspace runtime lifecycle")
      catch Error as workspaceStopError {
        if (!IsObject(stopError))
          stopError := workspaceStopError
      }
    }
    if (IsObject(stopError))
      throw stopError
    return true
  }

  IsRunning() {
    return this._isRunning
  }

  SwitchSyntheticWorkspace(slotId) {
    this._requireRunning()
    workspaceId := this.Model.GetWorkspaceIdForSlot(slotId)
    return this._callCapability(this._workspaceRuntime, "SwitchWorkspace", "workspace switching", workspaceId)
  }

  MoveWindowToSyntheticWorkspace(slotId, hwnd:=0) {
    this._requireRunning()
    workspaceId := this.Model.GetWorkspaceIdForSlot(slotId)
    return this._callCapability(this._workspaceRuntime, "MoveWindowToWorkspace", "moving a window to a workspace", workspaceId, hwnd)
  }

  MoveWindowAndSwitchSyntheticWorkspace(slotId, hwnd:=0) {
    this._requireRunning()
    workspaceId := this.Model.GetWorkspaceIdForSlot(slotId)
    return this._callCapability(this._workspaceRuntime, "MoveWindowAndSwitchWorkspace", "moving a window and switching workspace", workspaceId, hwnd)
  }

  ShowSyntheticWorkspaceOverview() {
    this._requireRunning()
    return this._callCapability(this._overviewRuntime, "Show", "showing the workspace overview")
  }

  HideSyntheticWorkspaceOverview() {
    this._requireRunning()
    return this._callCapability(this._overviewRuntime, "Hide", "hiding the workspace overview")
  }

  ToggleSyntheticWorkspaceOverview() {
    this._requireRunning()
    return this._callCapability(this._overviewRuntime, "Toggle", "toggling the workspace overview")
  }

  DisableSyntheticWorkspaces() {
    this._requireRunning()
    return this.Stop()
  }

  RestoreAllSyntheticWorkspaceWindows() {
    this._requireRunning()
    return this._callCapability(this._workspaceRuntime, "RestoreAllWindows", "restoring synthetic workspace windows")
  }

  _requireRunning() {
    if (!this._isRunning)
      throw Error("Synthetic Workspaces service is not running")
  }

  _callCapability(target, methodName, capabilityName, params*) {
    if (!IsObject(target) || !HasMethod(target, methodName))
      throw Error("Synthetic Workspaces capability unavailable: " capabilityName)
    return target.%methodName%(params*)
  }
}

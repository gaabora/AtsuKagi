#Include SyntheticWorkspaces\WorkspaceService.ahk

class SyntheticWorkspaces extends AKPlugin {
  __New(app, service:=0) {
    super.__New(app)
    if (IsObject(service))
      this._service := service
    else if (service = 0)
      this._service := SyntheticWorkspaceService()
    else
      throw TypeError("Synthetic Workspaces service must be an object")
    this._exitFn := 0
    this._exitRegistered := false
  }

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "SyntheticWorkspaces",
        "title", "Synthetic Workspaces",
        "description", "Manage eight directional workspaces without changing Windows virtual desktops",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure synthetic workspace behavior",
        "icon", "icons10-grid-2"
      ),
      "config", [],
      "actions", [
        Map("action", "SwitchSyntheticWorkspace", "label", "Switch synthetic workspace", "description", "Switch to the workspace currently mapped to a direction slot", "params", ["slot"], "category", "Workspace Navigation"),
        Map("action", "MoveWindowToSyntheticWorkspace", "label", "Move window to synthetic workspace", "description", "Move a specific or active window to the workspace mapped to a direction slot", "params", [Map("name", "slot"), Map("name", "hwnd", "default", 0)], "category", "Window Management"),
        Map("action", "MoveWindowAndSwitchSyntheticWorkspace", "label", "Move window and switch synthetic workspace", "description", "Move a specific or active window to a direction slot and switch to its workspace", "params", [Map("name", "slot"), Map("name", "hwnd", "default", 0)], "category", "Window Management"),
        Map("action", "ShowSyntheticWorkspaceOverview", "label", "Show synthetic workspace overview", "description", "Open the synthetic workspace overview", "params", [], "category", "Workspace Overview"),
        Map("action", "HideSyntheticWorkspaceOverview", "label", "Hide synthetic workspace overview", "description", "Close the synthetic workspace overview", "params", [], "category", "Workspace Overview"),
        Map("action", "ToggleSyntheticWorkspaceOverview", "label", "Toggle synthetic workspace overview", "description", "Open or close the synthetic workspace overview", "params", [], "category", "Workspace Overview"),
        Map("action", "DisableSyntheticWorkspaces", "label", "Disable synthetic workspaces", "description", "Stop synthetic workspace services and restore safe window access", "params", [], "category", "Recovery"),
        Map("action", "RestoreAllSyntheticWorkspaceWindows", "label", "Restore all synthetic workspace windows", "description", "Make every window managed by synthetic workspaces reachable", "params", [], "category", "Recovery")
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  _init() {
    if (!this._exitRegistered) {
      this._exitFn := this._onExit.Bind(this)
      OnExit(this._exitFn)
      this._exitRegistered := true
    }
    try return this._service.Start()
    catch Error as startError {
      this._unregisterExitCallback()
      throw startError
    }
  }

  SwitchSyntheticWorkspace(slot) {
    return this._service.SwitchSyntheticWorkspace(slot)
  }

  MoveWindowToSyntheticWorkspace(slot, hwnd:=0) {
    return this._service.MoveWindowToSyntheticWorkspace(slot, hwnd)
  }

  MoveWindowAndSwitchSyntheticWorkspace(slot, hwnd:=0) {
    return this._service.MoveWindowAndSwitchSyntheticWorkspace(slot, hwnd)
  }

  ShowSyntheticWorkspaceOverview() {
    return this._service.ShowSyntheticWorkspaceOverview()
  }

  HideSyntheticWorkspaceOverview() {
    return this._service.HideSyntheticWorkspaceOverview()
  }

  ToggleSyntheticWorkspaceOverview() {
    return this._service.ToggleSyntheticWorkspaceOverview()
  }

  DisableSyntheticWorkspaces() {
    result := this._service.DisableSyntheticWorkspaces()
    this._unregisterExitCallback()
    return result
  }

  RestoreAllSyntheticWorkspaceWindows() {
    return this._service.RestoreAllSyntheticWorkspaceWindows()
  }

  _shutdown() {
    this._unregisterExitCallback()
    return this._service.Stop()
  }

  _unregisterExitCallback() {
    if (!this._exitRegistered)
      return
    OnExit(this._exitFn, 0)
    this._exitRegistered := false
  }

  _onExit(*) {
    try this._shutdown()
    return 0
  }
}

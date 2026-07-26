class SyntheticWorkspaceRecord {
  __New(workspaceId) {
    this._validateWorkspaceId(workspaceId)
    this._id := workspaceId
    this.CustomName := ""
    this.CustomColor := ""
    this.LayoutsByMonitor := Map()
    this.FocusHistory := []
  }

  Id {
    get => this._id
  }

  _validateWorkspaceId(workspaceId) {
    if (Type(workspaceId) != "String" || Trim(workspaceId) = "")
      throw ValueError("Workspace ID must be a non-empty string", -1, workspaceId)
  }
}

class SyntheticWorkspaceRuntimeWindowState {
  __New(observed := 0, desired := 0, pending := 0) {
    this.Observed := this._cloneStateMap(observed, "observed")
    this.Desired := this._cloneStateMap(desired, "desired")
    this.Pending := this._cloneStateMap(pending, "pending")
  }

  _cloneStateMap(state, stateName) {
    if (!IsObject(state))
      return Map()
    if (!(state is Map))
      throw TypeError("Runtime " stateName " state must be a Map")
    clonedState := Map()
    for propertyName, propertyValue in state
      clonedState[propertyName] := propertyValue
    return clonedState
  }
}

class SyntheticWorkspaceModel {
  __New(workspaces, slotMap, activeWorkspaceId) {
    this._workspacesById := Map()
    this._slotMap := Map()
    this._validateAndCopyWorkspaces(workspaces)
    this._validateAndCopySlotMap(slotMap)
    this._requireKnownWorkspace(activeWorkspaceId)
    this._activeWorkspaceId := activeWorkspaceId
  }

  static GetSlotIds() {
    return ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
  }

  GetWorkspaceCount() {
    return this._workspacesById.Count
  }

  GetWorkspaceIds() {
    workspaceIds := []
    for workspaceId, workspaceRecord in this._workspacesById
      workspaceIds.Push(workspaceId)
    return workspaceIds
  }

  GetWorkspace(workspaceId) {
    this._requireKnownWorkspace(workspaceId)
    return this._workspacesById[workspaceId]
  }

  GetWorkspaceIdForSlot(slotId) {
    this._requireKnownSlot(slotId)
    return this._slotMap[slotId]
  }

  GetWorkspaceForSlot(slotId) {
    return this.GetWorkspace(this.GetWorkspaceIdForSlot(slotId))
  }

  GetSlotForWorkspace(workspaceId) {
    this._requireKnownWorkspace(workspaceId)
    for slotId in SyntheticWorkspaceModel.GetSlotIds() {
      if (this._slotMap[slotId] == workspaceId)
        return slotId
    }
    throw Error("Workspace is missing from the slot map: " workspaceId)
  }

  GetSlotMapSnapshot() {
    snapshot := Map()
    for slotId in SyntheticWorkspaceModel.GetSlotIds()
      snapshot[slotId] := this._slotMap[slotId]
    return snapshot
  }

  GetActiveWorkspaceId() {
    return this._activeWorkspaceId
  }

  CommitActiveWorkspace(workspaceId) {
    this._requireKnownWorkspace(workspaceId)
    this._activeWorkspaceId := workspaceId
  }

  SwapSlots(firstSlotId, secondSlotId) {
    this._requireKnownSlot(firstSlotId)
    this._requireKnownSlot(secondSlotId)
    if (firstSlotId == secondSlotId)
      return
    firstWorkspaceId := this._slotMap[firstSlotId]
    this._slotMap[firstSlotId] := this._slotMap[secondSlotId]
    this._slotMap[secondSlotId] := firstWorkspaceId
  }

  _validateAndCopyWorkspaces(workspaces) {
    if (!(workspaces is Array))
      throw TypeError("Workspaces must be an Array")
    if (workspaces.Length != SyntheticWorkspaceModel.GetSlotIds().Length)
      throw ValueError("Exactly eight workspace records are required", -1, workspaces.Length)
    for workspaceRecord in workspaces {
      if (!(workspaceRecord is SyntheticWorkspaceRecord))
        throw TypeError("Every workspace must be a SyntheticWorkspaceRecord")
      workspaceId := workspaceRecord.Id
      if (this._workspacesById.Has(workspaceId))
        throw ValueError("Workspace IDs must be unique", -1, workspaceId)
      this._workspacesById[workspaceId] := workspaceRecord
    }
  }

  _validateAndCopySlotMap(slotMap) {
    if (!(slotMap is Map))
      throw TypeError("Slot map must be a Map")
    requiredSlotIds := SyntheticWorkspaceModel.GetSlotIds()
    if (slotMap.Count != requiredSlotIds.Length)
      throw ValueError("Slot map must contain exactly eight slots", -1, slotMap.Count)
    mappedWorkspaceIds := Map()
    for providedSlotId, workspaceId in slotMap {
      this._requireKnownSlot(providedSlotId)
      this._requireKnownWorkspace(workspaceId)
      if (mappedWorkspaceIds.Has(workspaceId))
        throw ValueError("Each workspace must appear in the slot map exactly once", -1, workspaceId)
      mappedWorkspaceIds[workspaceId] := true
      this._slotMap[providedSlotId] := workspaceId
    }
    for requiredSlotId in requiredSlotIds {
      if (!this._slotMap.Has(requiredSlotId))
        throw ValueError("Slot map is missing required slot", -1, requiredSlotId)
    }
  }

  _requireKnownSlot(slotId) {
    if (!this._isKnownSlot(slotId))
      throw ValueError("Unknown synthetic workspace slot", -1, slotId)
  }

  _isKnownSlot(slotId) {
    if (Type(slotId) != "String")
      return false
    for knownSlotId in SyntheticWorkspaceModel.GetSlotIds() {
      if (slotId == knownSlotId)
        return true
    }
    return false
  }

  _requireKnownWorkspace(workspaceId) {
    if (Type(workspaceId) != "String" || !this._workspacesById.Has(workspaceId))
      throw ValueError("Unknown synthetic workspace ID", -1, workspaceId)
  }
}

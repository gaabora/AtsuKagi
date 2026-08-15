#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk
#Include ..\plugins\SyntheticWorkspaces\WorkspaceRuntime.ahk

if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(SyntheticWorkspacesSwitchTests)
else
   Yunit.Use(YunitWindow).Test(SyntheticWorkspacesSwitchTests)

CreateSyntheticWorkspaceSwitchModel() {
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

CreateSyntheticWorkspaceSwitchSnapshot(windowHwnd, overrides:=0) {
   snapshot := Map(
      "hwnd", windowHwnd,
      "pid", windowHwnd + 1000,
      "isHaribolShell", false,
      "executablePath", "C:\Fake\App.exe",
      "executableName", "App.exe",
      "windowClass", "FakeWindow",
      "title", "Window " windowHwnd,
      "normalizedTitle", "Window " windowHwnd,
      "appUserModelId", "",
      "appUserModelIdAvailable", false,
      "appUserModelIdReason", "not set",
      "ownerHwnd", 0,
      "rootOwnerHwnd", windowHwnd,
      "popupHwnd", 0,
      "geometry", Map("left", windowHwnd, "top", 50, "width", 800, "height", 600),
      "monitor", Map("handle", 1),
      "visible", true,
      "minimized", false,
      "maximized", false,
      "fullscreen", false,
      "topmost", false,
      "cloaked", false,
      "responsive", true,
      "stackIndex", windowHwnd,
      "snapshotFailed", false,
      "metadataReadable", true,
      "classification", "managed",
      "classificationReason", "normal controllable top-level window",
      "displayTitle", "Window " windowHwnd,
      "icon", 0,
      "baseColor", "",
      "colorPreset", ""
   )
   if (overrides is Map) {
      for propertyName, propertyValue in overrides
         snapshot[propertyName] := propertyValue
   }
   return snapshot
}

CloneSyntheticWorkspaceSwitchValue(value) {
   if (value is Map) {
      clonedMap := Map()
      for propertyName, propertyValue in value
         clonedMap[propertyName] := CloneSyntheticWorkspaceSwitchValue(propertyValue)
      return clonedMap
   }
   if (value is Array) {
      clonedArray := []
      for item in value
         clonedArray.Push(CloneSyntheticWorkspaceSwitchValue(item))
      return clonedArray
   }
   return value
}

SyntheticWorkspaceSwitchValuesEqual(firstValue, secondValue) {
   if (firstValue is Map) {
      if (!(secondValue is Map) || firstValue.Count != secondValue.Count)
         return false
      for propertyName, propertyValue in firstValue {
         if (!secondValue.Has(propertyName) || !SyntheticWorkspaceSwitchValuesEqual(propertyValue, secondValue[propertyName]))
            return false
      }
      return true
   }
   return firstValue = secondValue
}

SyntheticWorkspaceSwitchGroupContains(groups, firstHwnd, secondHwnd) {
   for groupHwnds in groups {
      firstFound := false
      secondFound := false
      for windowHwnd in groupHwnds {
         firstFound := firstFound || windowHwnd = firstHwnd
         secondFound := secondFound || windowHwnd = secondHwnd
      }
      if (firstFound && secondFound)
         return true
   }
   return false
}

class SyntheticWorkspaceSwitchSnapshotBackendTestDouble {
   __New(snapshots) {
      this.SnapshotsByHwnd := Map()
      for snapshot in snapshots
         this.SetSnapshot(snapshot)
      this.FullReadCount := 0
      this.SingleReadCount := 0
      this.CloseCount := 0
   }

   SetSnapshot(snapshot) {
      this.SnapshotsByHwnd[snapshot["hwnd"]] := snapshot
   }

   ReadTopLevelWindowSnapshots() {
      this.FullReadCount += 1
      snapshots := []
      for windowHwnd, snapshot in this.SnapshotsByHwnd
         snapshots.Push(snapshot)
      return snapshots
   }

   ReadWindowSnapshot(windowHwnd) {
      this.SingleReadCount += 1
      return this.SnapshotsByHwnd.Has(windowHwnd) ? this.SnapshotsByHwnd[windowHwnd] : 0
   }

   Close() {
      this.CloseCount += 1
   }
}

class SyntheticWorkspacePlacementBackendTestDouble {
   __New() {
      this.StartCount := 0
      this.ApplyCount := 0
      this.VerifyCount := 0
      this.RollbackCount := 0
      this.EmergencyCount := 0
      this.CloseCount := 0
      this.ForegroundHwnd := 0
      this.PendingSeen := false
      this.VerifyResults := []
      this.LastPlan := 0
      this.OnApply := 0
      this.ExternalChangeOnApplyCount := 0
      this.ExternalChangeHwnd := 0
      this.ExternalChangeProperty := ""
      this.ExternalChangeValue := 0
      this.SkippedExternalRollback := false
   }

   Start() {
      this.StartCount += 1
      return true
   }

   ApplyPlan(plan) {
      this.ApplyCount += 1
      this.LastPlan := plan
      this.PendingSeen := plan["pendingEntries"].Length > 0
      for pendingEntry in plan["pendingEntries"] {
         if (!pendingEntry["record"].State.Pending.Has(pendingEntry["property"]))
            this.PendingSeen := false
      }
      for windowPlan in plan["windows"] {
         record := windowPlan["record"]
         for propertyName in ["geometry", "topmost", "minimized"] {
            applyFlag := "apply" StrTitle(propertyName)
            if (windowPlan.Get(applyFlag, false))
               record.State.Observed[propertyName] := CloneSyntheticWorkspaceSwitchValue(windowPlan["target"][propertyName])
         }
      }
      this.ForegroundHwnd := plan["focusHwnd"]
      if (this.ExternalChangeOnApplyCount = this.ApplyCount) {
         for windowPlan in plan["windows"] {
            if (windowPlan["hwnd"] = this.ExternalChangeHwnd)
               windowPlan["record"].State.Observed[this.ExternalChangeProperty] := CloneSyntheticWorkspaceSwitchValue(this.ExternalChangeValue)
         }
      }
      if (IsObject(this.OnApply))
         this.OnApply.Call(plan, this)
      return Map("success", true, "unsafeStack", false, "reason", "")
   }

   VerifyPlan(plan) {
      this.VerifyCount += 1
      return this.VerifyResults.Length ? this.VerifyResults.RemoveAt(1) : true
   }

   RollbackPlan(plan) {
      this.RollbackCount += 1
      for windowPlan in plan["windows"] {
         record := windowPlan["record"]
         for propertyName in ["geometry", "topmost", "minimized"] {
            applyFlag := "apply" StrTitle(propertyName)
            if (!windowPlan.Get(applyFlag, false))
               continue
            if (SyntheticWorkspaceSwitchValuesEqual(record.State.Observed[propertyName], windowPlan["target"][propertyName]))
               record.State.Observed[propertyName] := CloneSyntheticWorkspaceSwitchValue(windowPlan["prior"][propertyName])
            else
               this.SkippedExternalRollback := true
         }
      }
      return true
   }

   EmergencyRestore(records) {
      this.EmergencyCount += 1
      return true
   }

   RepairRecoveredUnsupported(records) {
   }

   IsInternalWindow(windowHwnd) {
      return false
   }

   GetForegroundHwnd() {
      return this.ForegroundHwnd
   }

   Close() {
      this.CloseCount += 1
      return true
   }
}

class SyntheticWorkspacesSwitchTests {
   T01_SuccessCommitsOnlyAfterApplyAndVerify() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      sourceWorkspaceId := model.GetActiveWorkspaceId()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(101), CreateSyntheticWorkspaceSwitchSnapshot(102)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      placementBackend.ForegroundHwnd := 101
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      runtime.Cache.GetByHwnd(102).AssignWorkspace(destinationWorkspaceId)
      runtime.SwitchWorkspace(destinationWorkspaceId)
      Yunit.assert(model.GetActiveWorkspaceId() = destinationWorkspaceId && model.GetRevision() = 1, "verified switch should commit the destination and one revision")
      Yunit.assert(placementBackend.ApplyCount = 1 && placementBackend.VerifyCount = 1 && placementBackend.PendingSeen, "switch should apply and verify once with pending state visible during apply")
      Yunit.assert(runtime.Cache.GetByHwnd(101).State.Pending.Count = 0 && runtime.Cache.GetByHwnd(102).State.Pending.Count = 0, "successful switch should clear pending state")
      Yunit.assert(sourceWorkspaceId != destinationWorkspaceId && placementBackend.LastPlan["focusHwnd"] = 102, "destination fallback should receive focus")
      runtime.Stop()
   }

   T02_FailedVerificationKeepsCommittedWorkspaceAndRollsBack() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      sourceWorkspaceId := model.GetActiveWorkspaceId()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(201), CreateSyntheticWorkspaceSwitchSnapshot(202)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      placementBackend.VerifyResults := [false, false]
      placementBackend.ForegroundHwnd := 201
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      runtime.Cache.GetByHwnd(202).AssignWorkspace(destinationWorkspaceId)
      switchError := 0
      try runtime.SwitchWorkspace(destinationWorkspaceId)
      catch Error as caughtError
         switchError := caughtError
      Yunit.assert(IsObject(switchError) && model.GetActiveWorkspaceId() = sourceWorkspaceId && model.GetRevision() = 0, "failed verification must keep the prior committed workspace")
      Yunit.assert(placementBackend.ApplyCount = 2 && placementBackend.RollbackCount = 1, "failed switch should use one repair pass and one rollback")
      runtime.Stop()
   }

   T03_UnexpectedCreateEventCausesOneReplan() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(301), CreateSyntheticWorkspaceSwitchSnapshot(302)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      runtime.Cache.GetByHwnd(302).AssignWorkspace(destinationWorkspaceId)
      placementBackend.OnApply := (plan, backend) => SyntheticWorkspaceSwitchEmitUnexpectedCreate(runtime, snapshotBackend, placementBackend)
      runtime.SwitchWorkspace(destinationWorkspaceId)
      Yunit.assert(placementBackend.ApplyCount = 2 && runtime.Cache.HasHwnd(303), "one unexpected create event should make the transaction refresh and replan once")
      Yunit.assert(model.GetActiveWorkspaceId() = destinationWorkspaceId, "repaired transaction should commit only after its second verification")
      runtime.Stop()
   }

   T04_RollbackDoesNotOverwriteNewerExternalGeometry() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(401), CreateSyntheticWorkspaceSwitchSnapshot(402)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      placementBackend.VerifyResults := [false, false]
      placementBackend.ExternalChangeOnApplyCount := 2
      placementBackend.ExternalChangeHwnd := 402
      placementBackend.ExternalChangeProperty := "geometry"
      placementBackend.ExternalChangeValue := Map("left", 999, "top", 77, "width", 640, "height", 480)
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      destinationRecord := runtime.Cache.GetByHwnd(402)
      destinationRecord.AssignWorkspace(destinationWorkspaceId)
      destinationRecord.State.Desired["geometry"] := Map("left", 500, "top", 60, "width", 700, "height", 500)
      try runtime.SwitchWorkspace(destinationWorkspaceId)
      Yunit.assert(placementBackend.SkippedExternalRollback && destinationRecord.State.Observed["geometry"]["left"] = 999, "rollback should skip a property that no longer matches the transaction target")
      runtime.Stop()
   }

   T05_OwnerAndDialogStayInOneStackGroup() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      dialogOverrides := Map("ownerHwnd", 501, "rootOwnerHwnd", 501, "classification", "owned-dialog", "classificationReason", "window follows its root owner", "stackIndex", 1)
      rootOverrides := Map("stackIndex", 2)
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(501, rootOverrides), CreateSyntheticWorkspaceSwitchSnapshot(502, dialogOverrides)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      runtime.Cache.GetByHwnd(501).AssignWorkspace(destinationWorkspaceId)
      runtime.Cache.GetByHwnd(502).AssignWorkspace(destinationWorkspaceId)
      runtime.SwitchWorkspace(destinationWorkspaceId)
      Yunit.assert(SyntheticWorkspaceSwitchGroupContains(placementBackend.LastPlan["activeGroups"], 501, 502), "root owner and its dialog should be one active stacking group")
      runtime.Stop()
   }

   T06_SessionFocusHistoryRestoresLastValidWindow() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(601), CreateSyntheticWorkspaceSwitchSnapshot(602), CreateSyntheticWorkspaceSwitchSnapshot(603)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      placementBackend.ForegroundHwnd := 601
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      secondRecord := runtime.Cache.GetByHwnd(602)
      thirdRecord := runtime.Cache.GetByHwnd(603)
      secondRecord.AssignWorkspace(destinationWorkspaceId)
      thirdRecord.AssignWorkspace(destinationWorkspaceId)
      model.GetWorkspace(destinationWorkspaceId).FocusHistory := [thirdRecord.RuntimeRecordId, secondRecord.RuntimeRecordId]
      runtime.SwitchWorkspace(destinationWorkspaceId)
      Yunit.assert(placementBackend.LastPlan["focusHwnd"] = 603, "session runtime focus history should select its newest valid destination window")
      runtime.Stop()
   }

   T07_MissingFocusEntryUsesSafeStackFallback() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      firstDestinationOverrides := Map("stackIndex", 2)
      secondDestinationOverrides := Map("stackIndex", 3)
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(701), CreateSyntheticWorkspaceSwitchSnapshot(702, firstDestinationOverrides), CreateSyntheticWorkspaceSwitchSnapshot(703, secondDestinationOverrides)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      runtime.Cache.GetByHwnd(702).AssignWorkspace(destinationWorkspaceId)
      runtime.Cache.GetByHwnd(703).AssignWorkspace(destinationWorkspaceId)
      model.GetWorkspace(destinationWorkspaceId).FocusHistory := ["missing-runtime-id"]
      runtime.SwitchWorkspace(destinationWorkspaceId)
      Yunit.assert(placementBackend.LastPlan["focusHwnd"] = 702, "missing focus history should use the first safe destination window by observed stack")
      runtime.Stop()
   }

   T08_MoveActionsKeepOwnerGroupAndUseTheSameTransaction() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      sourceWorkspaceId := model.GetActiveWorkspaceId()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      dialogOverrides := Map("ownerHwnd", 801, "rootOwnerHwnd", 801, "classification", "owned-dialog", "classificationReason", "window follows its root owner")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(801), CreateSyntheticWorkspaceSwitchSnapshot(802, dialogOverrides)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      runtime.MoveWindowToWorkspace(destinationWorkspaceId, 802)
      Yunit.assert(model.GetActiveWorkspaceId() = sourceWorkspaceId && runtime.Cache.GetByHwnd(801).WorkspaceId = destinationWorkspaceId && runtime.Cache.GetByHwnd(802).WorkspaceId = destinationWorkspaceId, "move should assign the complete owner group without switching")
      runtime.MoveWindowAndSwitchWorkspace(destinationWorkspaceId, 801)
      Yunit.assert(model.GetActiveWorkspaceId() = destinationWorkspaceId && placementBackend.ApplyCount = 2, "move-and-switch should use the guarded transaction and commit the destination")
      runtime.Stop()
   }

   T09_SuspendEmergencyAndResumeUseSafeCleanup() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(901)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      Yunit.assert(runtime.PrepareForSuspend() && !runtime.IsSwitchingEnabled() && placementBackend.EmergencyCount = 1, "suspend should restore windows before switching is disabled")
      Yunit.assert(runtime.ResumeAfterSuspend() && runtime.IsSwitchingEnabled() && snapshotBackend.FullReadCount >= 2, "resume should rebuild the cache before switching is enabled")
      Yunit.assert(runtime.RestoreAllWindows() && !runtime.IsSwitchingEnabled() && placementBackend.EmergencyCount = 2, "emergency restore should stay available and disable further switching")
      runtime.Stop()
      Yunit.assert(placementBackend.CloseCount = 1 && snapshotBackend.CloseCount = 1, "stop should clean both placement and snapshot backends")
   }

   T10_SourceKeepsPortableBoundaryHelperCleanupAndTrayPath() {
      global Yunit
      runtimeSource := ReadRepoFile("plugins\SyntheticWorkspaces\WorkspaceRuntime.ahk")
      placementSource := ReadRepoFile("plugins\SyntheticWorkspaces\Windows\WorkspacePlacementBackend.ahk")
      helperSource := ReadRepoFile("plugins\SyntheticWorkspaces\Windows\OffscreenHelper.ahk")
      pluginSource := ReadRepoFile("plugins\SyntheticWorkspaces.ahk")
      serviceSource := ReadRepoFile("plugins\SyntheticWorkspaces\WorkspaceService.ahk")
      appSource := ReadRepoFile("includes\AKApp.ahk")
      Yunit.assert(!RegExMatch(runtimeSource, "i)\b(?:WinGet\w*|WinMove|DllCall)\b"), "portable switch runtime should not call Windows APIs")
      AssertSourceContainsAll(placementSource, ["Gui(\"+ToolWindow -Caption +E0x08000000\"", "SetWindowPos", "RollbackPlan(plan)", "RemoveAllCovers()", "OFFSCREEN_HELPER_TIMEOUT_MS := 500", "ProcessClose(helperPid)"], "Windows placement and cleanup contract")
      AssertSourceContainsAll(helperSource, ["#SingleInstance Off", "SWP_NOSENDCHANGING", "SetWindowPos"], "bounded offscreen helper contract")
      AssertSourceContainsAll(pluginSource, ["\"trayLabel\", \"Restore synthetic workspace windows\"", "BeforeAppSuspend()", "AfterAppResume()"], "plugin emergency lifecycle contract")
      AssertSourceContainsAll(serviceSource, ["PrepareForSuspend()", "ResumeAfterSuspend()", "RestoreAllSyntheticWorkspaceWindows()"], "service recovery delegation contract")
      AssertSourceContainsAll(appSource, ["_runPluginLifecycleHook(\"BeforeAppSuspend\")", "_runPluginLifecycleHook(\"AfterAppResume\")", "_trayActionByLabel"], "unsuspended generic tray and suspend hook contract")
   }

   T11_ActivatingAnInactiveWindowSwitchesToItsWorkspace() {
      global Yunit
      model := CreateSyntheticWorkspaceSwitchModel()
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      snapshotBackend := SyntheticWorkspaceSwitchSnapshotBackendTestDouble([CreateSyntheticWorkspaceSwitchSnapshot(1101), CreateSyntheticWorkspaceSwitchSnapshot(1102)])
      placementBackend := SyntheticWorkspacePlacementBackendTestDouble()
      placementBackend.ForegroundHwnd := 1102
      runtime := SyntheticWorkspaceRuntime(model, snapshotBackend, 0, 0, placementBackend)
      runtime.Start()
      destinationRecord := runtime.Cache.GetByHwnd(1102)
      destinationRecord.AssignWorkspace(destinationWorkspaceId)
      runtime._handleNativeWindowEvent(Map("type", "activate", "hwnd", 1102, "eventTime", 10))
      Yunit.assert(model.GetActiveWorkspaceId() = destinationWorkspaceId && placementBackend.LastPlan["focusHwnd"] = 1102, "activating an inactive managed window should switch through the guarded transaction and keep that window focused")
      runtime.Stop()
   }
}

SyntheticWorkspaceSwitchEmitUnexpectedCreate(runtime, snapshotBackend, placementBackend) {
   placementBackend.OnApply := 0
   snapshotBackend.SetSnapshot(CreateSyntheticWorkspaceSwitchSnapshot(303))
   runtime._handleNativeWindowEvent(Map("type", "create", "hwnd", 303, "eventTime", 1))
}

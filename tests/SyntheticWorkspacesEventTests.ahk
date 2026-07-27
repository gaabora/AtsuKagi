#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk
#Include ..\plugins\SyntheticWorkspaces\WorkspaceRuntime.ahk
#Include ..\plugins\SyntheticWorkspaces\Windows\WindowEventService.ahk

if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(SyntheticWorkspacesEventTests)
else
   Yunit.Use(YunitWindow).Test(SyntheticWorkspacesEventTests)

CreateSyntheticWorkspaceEventModel() {
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

CreateSyntheticWorkspaceEventSnapshot(windowHwnd, overrides:=0) {
   snapshot := Map(
      "hwnd", windowHwnd,
      "pid", 2000 + windowHwnd,
      "executablePath", "C:\Apps\EventTest.exe",
      "executableName", "EventTest.exe",
      "windowClass", "EventTestWindow",
      "title", "Event Window",
      "normalizedTitle", "Event Window",
      "appUserModelId", "",
      "appUserModelIdAvailable", false,
      "appUserModelIdReason", "not set",
      "ownerHwnd", 0,
      "rootOwnerHwnd", windowHwnd,
      "popupHwnd", 0,
      "geometry", Map("left", 10, "top", 20, "width", 800, "height", 600),
      "monitor", Map("handle", 1, "left", 0, "top", 0, "right", 1920, "bottom", 1080),
      "visible", true,
      "minimized", false,
      "maximized", false,
      "fullscreen", false,
      "topmost", false,
      "cloaked", false,
      "responsive", true,
      "stackIndex", 1,
      "snapshotFailed", false,
      "metadataReadable", true,
      "classification", "managed",
      "classificationReason", "normal controllable top-level window",
      "displayTitle", "Event Window",
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

CreateSyntheticWorkspaceReconciliationSnapshot(snapshot) {
   return Map(
      "hwnd", snapshot["hwnd"],
      "title", snapshot["title"],
      "ownerHwnd", snapshot["ownerHwnd"],
      "rootOwnerHwnd", snapshot["rootOwnerHwnd"],
      "geometry", snapshot["geometry"],
      "visible", snapshot["visible"],
      "minimized", snapshot["minimized"],
      "maximized", snapshot["maximized"],
      "topmost", snapshot["topmost"],
      "cloaked", snapshot["cloaked"],
      "responsive", snapshot["responsive"],
      "stackIndex", snapshot["stackIndex"]
   )
}

class SyntheticWorkspaceEventBackendTestDouble {
   __New(snapshots) {
      this.SnapshotsByHwnd := Map()
      this.SnapshotOrder := []
      this.SingleReadCount := 0
      this.ReconciliationReadCount := 0
      this.CloseCount := 0
      for snapshot in snapshots
         this.SetSnapshot(snapshot)
   }

   SetSnapshot(snapshot) {
      windowHwnd := snapshot["hwnd"]
      if (!this.SnapshotsByHwnd.Has(windowHwnd))
         this.SnapshotOrder.Push(windowHwnd)
      this.SnapshotsByHwnd[windowHwnd] := snapshot
   }

   RemoveSnapshot(windowHwnd) {
      this.SnapshotsByHwnd.Delete(windowHwnd)
   }

   ReadTopLevelWindowSnapshots() {
      snapshots := []
      for windowHwnd in this.SnapshotOrder {
         if (this.SnapshotsByHwnd.Has(windowHwnd))
            snapshots.Push(this.SnapshotsByHwnd[windowHwnd])
      }
      return snapshots
   }

   ReadWindowSnapshot(windowHwnd) {
      this.SingleReadCount += 1
      return this.SnapshotsByHwnd.Has(windowHwnd) ? this.SnapshotsByHwnd[windowHwnd] : 0
   }

   ReadReconciliationWindowSnapshots() {
      this.ReconciliationReadCount += 1
      snapshots := []
      for windowHwnd in this.SnapshotOrder {
         if (this.SnapshotsByHwnd.Has(windowHwnd))
            snapshots.Push(CreateSyntheticWorkspaceReconciliationSnapshot(this.SnapshotsByHwnd[windowHwnd]))
      }
      return snapshots
   }

   Close() {
      this.CloseCount += 1
   }
}

class SyntheticWorkspaceEventServiceTestDouble {
   __New(failStart:=false) {
      this.FailStart := failStart
      this.StartCount := 0
      this.StopCount := 0
      this.ReconciliationPaused := false
      this._eventCallback := 0
      this._reconciliationCallback := 0
      this._isRunning := false
   }

   Start(eventCallback, reconciliationCallback) {
      this.StartCount += 1
      this._eventCallback := eventCallback
      this._reconciliationCallback := reconciliationCallback
      this._isRunning := true
      if (this.FailStart)
         throw Error("fake event service start failed")
      return true
   }

   Stop() {
      this.StopCount += 1
      wasRunning := this._isRunning
      this._isRunning := false
      this._eventCallback := 0
      this._reconciliationCallback := 0
      return wasRunning
   }

   Emit(eventType, windowHwnd, eventTime:=0) {
      if (!this._isRunning)
         return false
      return this._eventCallback.Call(Map("type", eventType, "hwnd", windowHwnd, "eventTime", eventTime))
   }

   TriggerReconciliation() {
      if (!this._isRunning || this.ReconciliationPaused)
         return false
      this._reconciliationCallback.Call()
      return true
   }

   SetReconciliationPaused(paused) {
      this.ReconciliationPaused := !!paused
   }
}

class SyntheticWorkspacesEventTests {
   T01_CreateEventReadsOnlyTheNewWindow() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(101))
      eventService.Emit("create", 101)
      Yunit.assert(runtime.Cache.HasHwnd(101) && runtime.Cache.GetByHwnd(101).WorkspaceId = runtime.Model.GetActiveWorkspaceId(), "create event should add one managed window to the active workspace")
      Yunit.assert(backend.SingleReadCount = 1 && backend.ReconciliationReadCount = 0, "create event should read only its HWND without a reconciliation scan")
      runtime.Stop()
   }

   T02_TitleStateAndGeometryEventsRefreshObservedState() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([CreateSyntheticWorkspaceEventSnapshot(201)])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(201, Map("title", "Renamed", "normalizedTitle", "Renamed")))
      eventService.Emit("title", 201)
      Yunit.assert(runtime.Cache.GetByHwnd(201).Title = "Renamed", "title event should refresh cached title")
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(201, Map("title", "Renamed", "normalizedTitle", "Renamed", "minimized", true)))
      eventService.Emit("state", 201)
      Yunit.assert(runtime.Cache.GetByHwnd(201).State.Observed["minimized"], "state event should refresh minimized state")
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(201, Map("title", "Renamed", "normalizedTitle", "Renamed", "minimized", true, "geometry", Map("left", 90, "top", 80, "width", 700, "height", 500))))
      eventService.Emit("geometry", 201)
      Yunit.assert(runtime.Cache.GetByHwnd(201).State.Observed["geometry"]["left"] = 90 && backend.SingleReadCount = 3, "geometry event should refresh geometry through one HWND read")
      runtime.Stop()
   }

   T03_DestroyEventRemovesBothCacheIndexes() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([CreateSyntheticWorkspaceEventSnapshot(301)])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      runtimeRecordId := runtime.Cache.GetByHwnd(301).RuntimeRecordId
      backend.RemoveSnapshot(301)
      eventService.Emit("destroy", 301)
      Yunit.assert(!runtime.Cache.HasHwnd(301) && runtime.Cache.GetByRuntimeId(runtimeRecordId) = 0, "destroy event should remove HWND and runtime ID indexes")
      runtime.Stop()
   }

   T04_ActivateEventMaintainsUniqueFocusHistory() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([CreateSyntheticWorkspaceEventSnapshot(401), CreateSyntheticWorkspaceEventSnapshot(402)])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      firstRuntimeId := runtime.Cache.GetByHwnd(401).RuntimeRecordId
      secondRuntimeId := runtime.Cache.GetByHwnd(402).RuntimeRecordId
      eventService.Emit("activate", 401, 10)
      eventService.Emit("activate", 402, 20)
      eventService.Emit("activate", 401, 30)
      focusHistory := runtime.Model.GetWorkspace(runtime.Model.GetActiveWorkspaceId()).FocusHistory
      Yunit.assert(focusHistory.Length = 2 && focusHistory[1] = firstRuntimeId && focusHistory[2] = secondRuntimeId, "focus history should be newest first without duplicate runtime IDs")
      Yunit.assert(runtime.Cache.GetByHwnd(401).LastFocusTime = 30, "activate event should keep its native event time")
      runtime.Stop()
   }

   T05_RootCreateRepairsAnEarlierOrphanDialogEvent() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      dialogOverrides := Map("ownerHwnd", 501, "rootOwnerHwnd", 501, "classification", "owned-dialog", "classificationReason", "window follows its root owner")
      dialogSnapshot := CreateSyntheticWorkspaceEventSnapshot(502, dialogOverrides)
      backend.SetSnapshot(dialogSnapshot)
      eventService.Emit("create", 502)
      Yunit.assert(runtime.Cache.GetByHwnd(502).Classification = "unsupported", "dialog should stay reachable while its root event is missing")
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(501))
      eventService.Emit("create", 501)
      dialogRecord := runtime.Cache.GetByHwnd(502)
      rootRecord := runtime.Cache.GetByHwnd(501)
      Yunit.assert(dialogRecord.Classification = "owned-dialog" && dialogRecord.WorkspaceId = rootRecord.WorkspaceId, "later root create should repair the dialog and its workspace")
      runtime.Stop()
   }

   T06_LightReconciliationRepairsMissedEvents() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([CreateSyntheticWorkspaceEventSnapshot(601)])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(601, Map("stackIndex", 9)))
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(602))
      eventService.TriggerReconciliation()
      Yunit.assert(runtime.Cache.HasHwnd(602) && backend.SingleReadCount = 1, "reconciliation should fully read only a missed new window")
      Yunit.assert(runtime.Cache.GetByHwnd(601).State.Observed["stackIndex"] = 9, "reconciliation should repair stack index from its light snapshot")
      backend.SetSnapshot(CreateSyntheticWorkspaceEventSnapshot(601, Map("title", "Missed title", "normalizedTitle", "Missed title", "stackIndex", 9)))
      backend.RemoveSnapshot(602)
      eventService.TriggerReconciliation()
      Yunit.assert(runtime.Cache.GetByHwnd(601).Title = "Missed title" && !runtime.Cache.HasHwnd(602), "reconciliation should repair a missed property event and destroy event")
      Yunit.assert(backend.SingleReadCount = 2 && backend.ReconciliationReadCount = 2, "unchanged windows should not receive full snapshots during reconciliation")
      runtime.Stop()
   }

   T07_StopCleansEventServiceBackendAndCache() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([CreateSyntheticWorkspaceEventSnapshot(701)])
      eventService := SyntheticWorkspaceEventServiceTestDouble()
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      runtime.Start()
      Yunit.assert(runtime.SetReconciliationPaused(true) && eventService.ReconciliationPaused, "runtime should expose a reconciliation pause for later switch transactions")
      runtime.Stop()
      Yunit.assert(eventService.StopCount = 1 && backend.CloseCount = 1 && runtime.Cache.Count() = 0, "stop should clean listeners, backend resources, and cache")
      Yunit.assert(!eventService.Emit("create", 702), "stopped event service should not deliver later callbacks")
   }

   T08_FailedEventStartUsesTheSameCleanupPath() {
      global Yunit
      backend := SyntheticWorkspaceEventBackendTestDouble([CreateSyntheticWorkspaceEventSnapshot(801)])
      eventService := SyntheticWorkspaceEventServiceTestDouble(true)
      runtime := SyntheticWorkspaceRuntime(CreateSyntheticWorkspaceEventModel(), backend, 0, eventService)
      startError := 0
      try runtime.Start()
      catch Error as caughtError
         startError := caughtError
      Yunit.assert(IsObject(startError) && !runtime.IsRunning() && runtime.Cache.Count() = 0, "failed event start should leave the runtime stopped and empty")
      Yunit.assert(eventService.StopCount = 1 && backend.CloseCount = 1, "failed event start should clean partial listener and icon resources")
   }

   T09_NativeSourceHasBoundedPollingIdentityIconsAndCleanup() {
      global Yunit
      eventSource := ReadRepoFile("plugins\SyntheticWorkspaces\Windows\WindowEventService.ahk")
      backendSource := ReadRepoFile("plugins\SyntheticWorkspaces\Windows\WindowBackend.ahk")
      AssertSourceContainsAll(eventSource, ["SetWinEventHook", "UnhookWinEvent", "CallbackFree", "SetTimer(this._reconciliationTimer, 0)", "reconciliationIntervalMs:=1500"], "native event service cleanup contract")
      AssertSourceContainsAll(eventSource, ["EVENT_OBJECT_CREATE", "EVENT_OBJECT_DESTROY", "EVENT_SYSTEM_FOREGROUND", "EVENT_OBJECT_NAMECHANGE", "EVENT_OBJECT_STATECHANGE", "EVENT_OBJECT_LOCATIONCHANGE"], "native event coverage")
      AssertSourceContainsAll(backendSource, ["ReadWindowSnapshot(windowHwnd)", "ReadReconciliationWindowSnapshots()", "SHGetPropertyStoreForWindow", "ExtractIconExW", "DestroyIcon"], "Windows snapshot identity and icon contract")
      Yunit.assert(!RegExMatch(backendSource, "i)Win32_Process|CommandLine"), "disabled advanced identity must not read command lines")
   }
}

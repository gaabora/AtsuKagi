#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk
#Include ..\plugins\SyntheticWorkspaces\WorkspaceRuntime.ahk
#Include ..\plugins\SyntheticWorkspaces\Windows\WindowBackend.ahk

if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(SyntheticWorkspacesRuntimeTests)
else
   Yunit.Use(YunitWindow).Test(SyntheticWorkspacesRuntimeTests)

CreateSyntheticWorkspaceRuntimeModel() {
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

CreateSyntheticWorkspaceRuntimeSnapshot(windowHwnd, overrides:=0) {
   snapshot := Map(
      "hwnd", windowHwnd,
      "pid", 1000 + windowHwnd,
      "executablePath", "C:\Apps\Test.exe",
      "executableName", "Test.exe",
      "windowClass", "TestWindow",
      "title", " Test  Window ",
      "appUserModelId", "",
      "appUserModelIdAvailable", false,
      "appUserModelIdReason", "unavailable",
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
      "elevated", false,
      "protected", false,
      "toolWindow", false,
      "blocklisted", false,
      "blocklistCheckFailed", false,
      "globalWindow", false,
      "globalRuleCheckFailed", false,
      "classification", "managed",
      "classificationReason", "normal controllable top-level window",
      "displayTitle", "Test Window",
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

class SyntheticWorkspaceSnapshotBackendTestDouble {
   __New(snapshots) {
      this.Snapshots := snapshots
   }

   ReadTopLevelWindowSnapshots() {
      return this.Snapshots
   }
}

class SyntheticWorkspacesRuntimeTests {
   T01_RuntimeRecordKeepsCompleteSeparatedState() {
      global Yunit
      cache := SyntheticWorkspaceRuntimeWindowCache()
      snapshot := CreateSyntheticWorkspaceRuntimeSnapshot(101)
      record := cache.Upsert(snapshot, "workspace-1")
      record.State.Desired["geometry"] := "desired"
      record.State.Pending["geometry"] := "pending"
      snapshot["geometry"]["left"] := 999
      Yunit.assert(record.RuntimeRecordId = "runtime-1" && record.Hwnd = 101 && record.Pid = 1101, "record should keep stable runtime identity and process data")
      Yunit.assert(record.ExecutablePath = "C:\Apps\Test.exe" && record.WindowClass = "TestWindow" && record.NormalizedTitle = "Test Window", "record should keep app metadata and normalized title")
      Yunit.assert(record.State.Observed["geometry"]["left"] = 10, "record should clone observed geometry")
      updatedSnapshot := CreateSyntheticWorkspaceRuntimeSnapshot(101, Map("title", "Updated", "geometry", Map("left", 30, "top", 40, "width", 900, "height", 700)))
      cache.Upsert(updatedSnapshot, "workspace-1")
      Yunit.assert(record.Title = "Updated" && record.State.Observed["geometry"]["left"] = 30, "snapshot update should replace observed data")
      Yunit.assert(record.State.Desired["geometry"] = "desired" && record.State.Pending["geometry"] = "pending", "snapshot update must not change desired or pending data")
   }

   T02_CacheUpdatesRemovesAndNeverReusesRuntimeIds() {
      global Yunit
      cache := SyntheticWorkspaceRuntimeWindowCache()
      firstRecord := cache.Upsert(CreateSyntheticWorkspaceRuntimeSnapshot(201), "workspace-1")
      updatedRecord := cache.Upsert(CreateSyntheticWorkspaceRuntimeSnapshot(201, Map("title", "Updated")), "workspace-2")
      secondRecord := cache.Upsert(CreateSyntheticWorkspaceRuntimeSnapshot(202), "workspace-1")
      Yunit.assert(updatedRecord == firstRecord && firstRecord.RuntimeRecordId = "runtime-1" && firstRecord.WorkspaceId = "workspace-2", "same HWND should update one runtime record")
      cache.RemoveByHwnd(201)
      thirdRecord := cache.Upsert(CreateSyntheticWorkspaceRuntimeSnapshot(203), "workspace-1")
      Yunit.assert(!cache.HasHwnd(201) && cache.GetByRuntimeId(firstRecord.RuntimeRecordId) = 0, "removed HWND should leave both cache indexes")
      Yunit.assert(secondRecord.RuntimeRecordId = "runtime-2" && thirdRecord.RuntimeRecordId = "runtime-3", "runtime IDs should not be reused during the session")
   }

   T03_BackendClassifiesEveryCanonicalClassWithReason() {
      global Yunit
      backend := WindowsSyntheticWorkspaceWindowBackend(0, 0, 900)
      classificationCases := [
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(301, Map("pid", 900)), "expected", "shell"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(302, Map("windowClass", "Shell_TrayWnd")), "expected", "shell"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(303, Map("visible", false)), "expected", "ignored"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(304, Map("cloaked", true)), "expected", "ignored"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(305, Map("toolWindow", true)), "expected", "ignored"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(306, Map("elevated", true)), "expected", "unsupported"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(307, Map("protected", true)), "expected", "unsupported"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(308, Map("responsive", false)), "expected", "unsupported"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(309, Map("blocklisted", true)), "expected", "unsupported"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(310, Map("ownerHwnd", 300, "rootOwnerHwnd", 300)), "expected", "owned-dialog"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(311, Map("globalWindow", true)), "expected", "global"),
         Map("snapshot", CreateSyntheticWorkspaceRuntimeSnapshot(312), "expected", "managed")
      ]
      for classificationCase in classificationCases {
         result := backend.ClassifySnapshot(classificationCase["snapshot"])
         Yunit.assert(result["class"] = classificationCase["expected"], "snapshot should receive expected classification " classificationCase["expected"])
         Yunit.assert(Trim(result["reason"]) != "", "every classification should include a diagnostic reason")
      }
   }

   T04_RuntimeAssignsNormalUnsupportedAndOwnedWindows() {
      global Yunit
      model := CreateSyntheticWorkspaceRuntimeModel()
      activeWorkspaceId := model.GetActiveWorkspaceId()
      snapshots := [
         CreateSyntheticWorkspaceRuntimeSnapshot(402, Map("ownerHwnd", 401, "rootOwnerHwnd", 401, "classification", "owned-dialog", "classificationReason", "window follows its root owner")),
         CreateSyntheticWorkspaceRuntimeSnapshot(401),
         CreateSyntheticWorkspaceRuntimeSnapshot(403, Map("visible", false, "classification", "ignored", "classificationReason", "window is hidden")),
         CreateSyntheticWorkspaceRuntimeSnapshot(404, Map("responsive", false, "classification", "unsupported", "classificationReason", "window is not responding")),
         CreateSyntheticWorkspaceRuntimeSnapshot(406, Map("ownerHwnd", 405, "rootOwnerHwnd", 405, "classification", "owned-dialog", "classificationReason", "window follows its root owner")),
         CreateSyntheticWorkspaceRuntimeSnapshot(405, Map("globalWindow", true, "classification", "global", "classificationReason", "window matches an explicit global rule"))
      ]
      runtime := SyntheticWorkspaceRuntime(model, SyntheticWorkspaceSnapshotBackendTestDouble(snapshots))
      runtime.Start()
      Yunit.assert(runtime.Cache.GetByHwnd(401).WorkspaceId = activeWorkspaceId, "new normal window should join the active workspace")
      Yunit.assert(runtime.Cache.GetByHwnd(402).WorkspaceId = activeWorkspaceId, "owned dialog should follow its root owner's workspace")
      Yunit.assert(runtime.Cache.GetByHwnd(403).WorkspaceId = "", "ignored window should not join a workspace")
      Yunit.assert(runtime.Cache.GetByHwnd(404).WorkspaceId = activeWorkspaceId && runtime.Cache.GetByHwnd(404).ClassificationReason = "window is not responding", "unsupported window should keep assignment and diagnostic reason")
      Yunit.assert(runtime.Cache.GetByHwnd(405).WorkspaceId = "" && runtime.Cache.GetByHwnd(406).Classification = "owned-dialog" && runtime.Cache.GetByHwnd(406).WorkspaceId = "", "dialog should follow a global root without gaining a workspace")
      runtime.Stop()
   }

   T05_RefreshPreservesAssignmentAndRepairsMissedCreateDestroy() {
      global Yunit
      model := CreateSyntheticWorkspaceRuntimeModel()
      backend := SyntheticWorkspaceSnapshotBackendTestDouble([CreateSyntheticWorkspaceRuntimeSnapshot(501), CreateSyntheticWorkspaceRuntimeSnapshot(502)])
      runtime := SyntheticWorkspaceRuntime(model, backend)
      runtime.Start()
      existingRecord := runtime.Cache.GetByHwnd(501)
      existingRuntimeId := existingRecord.RuntimeRecordId
      destinationWorkspaceId := model.GetWorkspaceIdForSlot("e")
      existingRecord.AssignWorkspace(destinationWorkspaceId)
      backend.Snapshots := [CreateSyntheticWorkspaceRuntimeSnapshot(501, Map("title", "Changed")), CreateSyntheticWorkspaceRuntimeSnapshot(503)]
      runtime.Refresh()
      Yunit.assert(runtime.Cache.Count() = 2 && !runtime.Cache.HasHwnd(502) && runtime.Cache.HasHwnd(503), "refresh should add new and remove missing HWNDs")
      Yunit.assert(runtime.Cache.GetByHwnd(501).RuntimeRecordId = existingRuntimeId && runtime.Cache.GetByHwnd(501).WorkspaceId = destinationWorkspaceId, "refresh should preserve runtime ID and existing workspace assignment")
      Yunit.assert(runtime.Cache.GetByHwnd(501).Title = "Changed", "refresh should update observed metadata")
      runtime.Stop()
   }

   T06_OrphanDialogBecomesUnsupportedWithVisibleReason() {
      global Yunit
      model := CreateSyntheticWorkspaceRuntimeModel()
      snapshot := CreateSyntheticWorkspaceRuntimeSnapshot(601, Map("ownerHwnd", 699, "rootOwnerHwnd", 699, "classification", "owned-dialog", "classificationReason", "window follows its root owner"))
      runtime := SyntheticWorkspaceRuntime(model, SyntheticWorkspaceSnapshotBackendTestDouble([snapshot]))
      runtime.Start()
      record := runtime.Cache.GetByHwnd(601)
      Yunit.assert(record.Classification = "unsupported" && record.ClassificationReason = "owned dialog root owner is unavailable", "orphan dialog should become unsupported with an exact reason")
      Yunit.assert(record.WorkspaceId = model.GetActiveWorkspaceId(), "orphan dialog should keep a reachable session assignment")
      runtime.Stop()
   }

   T07_InvalidRefreshRollsBackRuntimeStartState() {
      global Yunit
      model := CreateSyntheticWorkspaceRuntimeModel()
      duplicateSnapshot := CreateSyntheticWorkspaceRuntimeSnapshot(701)
      runtime := SyntheticWorkspaceRuntime(model, SyntheticWorkspaceSnapshotBackendTestDouble([duplicateSnapshot, duplicateSnapshot]))
      startError := 0
      try runtime.Start()
      catch Error as caughtError
         startError := caughtError
      Yunit.assert(IsObject(startError) && !runtime.IsRunning() && runtime.Cache.Count() = 0, "invalid initial snapshot set should leave runtime stopped with an empty cache")
   }

   T08_PortableRuntimeIsNativeFreeAndWindowsBackendIsReadOnly() {
      global Yunit
      portableSource := ReadRepoFile("plugins\SyntheticWorkspaces\RuntimeWindowCache.ahk") ReadRepoFile("plugins\SyntheticWorkspaces\WorkspaceRuntime.ahk")
      nativePortableCallFound := RegExMatch(portableSource, "i)\b(?:WinGet\w*|WinMove|DllCall|GetKeyState|A_ThisHotkey)\b")
      windowsBackendSource := ReadRepoFile("plugins\SyntheticWorkspaces\Windows\WindowBackend.ahk")
      mutatingBackendCallFound := RegExMatch(windowsBackendSource, "i)\b(?:WinMove|WinHide|WinMinimize|WinActivate|SetWindowPos|SetWinEventHook|SetTimer|SendMessage|PostMessage)\b")
      Yunit.assert(!nativePortableCallFound, "portable runtime and cache should contain no native window or input calls")
      Yunit.assert(!mutatingBackendCallFound, "STATE-4 Windows backend should remain read-only")
   }
}

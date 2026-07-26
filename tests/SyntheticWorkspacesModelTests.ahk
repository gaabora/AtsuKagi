#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include ..\plugins\SyntheticWorkspaces\WorkspaceModel.ahk

if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(SyntheticWorkspacesModelTests)
else
   Yunit.Use(YunitWindow).Test(SyntheticWorkspacesModelTests)

CreateSyntheticWorkspaceModelFixture() {
   workspaces := []
   slotMap := Map()
   for slotId in SyntheticWorkspaceModel.GetSlotIds() {
      workspaceId := "workspace-" slotId
      workspaceRecord := SyntheticWorkspaceRecord(workspaceId)
      workspaces.Push(workspaceRecord)
      slotMap[slotId] := workspaceId
   }
   return {workspaces: workspaces, slotMap: slotMap, activeWorkspaceId: "workspace-n"}
}

AssertSyntheticWorkspaceModelRejected(workspaces, slotMap, activeWorkspaceId, message) {
   global Yunit
   rejected := false
   try SyntheticWorkspaceModel(workspaces, slotMap, activeWorkspaceId)
   catch {
      rejected := true
   }
   Yunit.assert(rejected, message)
}

class SyntheticWorkspacesModelTests {
   T01_ValidModelResolvesEverySlot() {
      global Yunit
      fixture := CreateSyntheticWorkspaceModelFixture()
      model := SyntheticWorkspaceModel(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId)
      Yunit.assert(model.GetWorkspaceCount() = 8, "model should contain eight workspaces")
      Yunit.assert(model.GetActiveWorkspaceId() = "workspace-n", "model should keep one global active workspace")
      for slotId in SyntheticWorkspaceModel.GetSlotIds()
         Yunit.assert(model.GetWorkspaceIdForSlot(slotId) = "workspace-" slotId, "slot should resolve its mapped workspace")
   }

   T02_ModelRejectsWrongWorkspaceCount() {
      fixture := CreateSyntheticWorkspaceModelFixture()
      fixture.workspaces.Pop()
      AssertSyntheticWorkspaceModelRejected(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId, "model should reject fewer than eight workspaces")
   }

   T03_ModelRejectsMissingOrUnknownSlot() {
      fixture := CreateSyntheticWorkspaceModelFixture()
      fixture.slotMap.Delete("nw")
      fixture.slotMap["north-west"] := "workspace-nw"
      AssertSyntheticWorkspaceModelRejected(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId, "model should require the exact eight slot IDs")
   }

   T04_ModelRejectsDuplicateWorkspaceMapping() {
      fixture := CreateSyntheticWorkspaceModelFixture()
      fixture.slotMap["ne"] := fixture.slotMap["n"]
      AssertSyntheticWorkspaceModelRejected(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId, "model should reject a workspace mapped to two slots")
   }

   T05_ModelRejectsUnknownWorkspaceMappingAndActiveId() {
      fixture := CreateSyntheticWorkspaceModelFixture()
      fixture.slotMap["n"] := "workspace-missing"
      AssertSyntheticWorkspaceModelRejected(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId, "slot map should reject unknown workspace IDs")
      fixture := CreateSyntheticWorkspaceModelFixture()
      AssertSyntheticWorkspaceModelRejected(fixture.workspaces, fixture.slotMap, "workspace-missing", "active workspace should be one of the stable records")
   }

   T06_SwapMovesCompleteWorkspaceIdentity() {
      global Yunit
      fixture := CreateSyntheticWorkspaceModelFixture()
      model := SyntheticWorkspaceModel(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId)
      northWorkspace := model.GetWorkspaceForSlot("n")
      eastWorkspace := model.GetWorkspaceForSlot("e")
      northWorkspace.CustomName := "Writing"
      northWorkspace.CustomColor := "112233"
      model.SwapSlots("n", "e")
      Yunit.assert(model.GetWorkspaceForSlot("e") == northWorkspace, "swap should move the complete north workspace record")
      Yunit.assert(model.GetWorkspaceForSlot("n") == eastWorkspace, "swap should move the complete east workspace record")
      Yunit.assert(northWorkspace.Id = "workspace-n" && northWorkspace.CustomName = "Writing" && northWorkspace.CustomColor = "112233", "swap should not change workspace identity or custom values")
      idChangeRejected := false
      try northWorkspace.Id := "workspace-mutated"
      catch {
         idChangeRejected := true
      }
      Yunit.assert(idChangeRejected, "workspace ID should be read-only")
   }

   T07_ActiveWorkspaceCommitRequiresKnownStableId() {
      global Yunit
      fixture := CreateSyntheticWorkspaceModelFixture()
      model := SyntheticWorkspaceModel(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId)
      model.CommitActiveWorkspace("workspace-sw")
      Yunit.assert(model.GetActiveWorkspaceId() = "workspace-sw", "known workspace should become globally active")
      rejected := false
      try model.CommitActiveWorkspace("workspace-missing")
      catch {
         rejected := true
      }
      Yunit.assert(rejected && model.GetActiveWorkspaceId() = "workspace-sw", "unknown workspace should not change committed active state")
   }

   T08_SlotMapSnapshotCannotBreakModel() {
      global Yunit
      fixture := CreateSyntheticWorkspaceModelFixture()
      model := SyntheticWorkspaceModel(fixture.workspaces, fixture.slotMap, fixture.activeWorkspaceId)
      fixture.slotMap["n"] := "workspace-broken"
      Yunit.assert(model.GetWorkspaceIdForSlot("n") = "workspace-n", "mutating the source slot map should not break the model")
      snapshot := model.GetSlotMapSnapshot()
      snapshot["n"] := "workspace-broken"
      Yunit.assert(model.GetWorkspaceIdForSlot("n") = "workspace-n", "mutating a snapshot should not break the model")
      Yunit.assert(model.GetSlotForWorkspace("workspace-n") = "n", "reverse slot lookup should remain valid")
   }

   T09_RuntimeWindowStateKeepsThreeSeparateMaps() {
      global Yunit
      sourceState := Map("geometry", "original")
      runtimeState := SyntheticWorkspaceRuntimeWindowState(sourceState, sourceState, sourceState)
      runtimeState.Observed["geometry"] := "observed"
      runtimeState.Desired["geometry"] := "desired"
      runtimeState.Pending["geometry"] := "pending"
      Yunit.assert(sourceState["geometry"] = "original", "runtime state should clone input maps")
      Yunit.assert(runtimeState.Observed["geometry"] = "observed", "observed state should stay separate")
      Yunit.assert(runtimeState.Desired["geometry"] = "desired", "desired state should stay separate")
      Yunit.assert(runtimeState.Pending["geometry"] = "pending", "pending state should stay separate")
   }
}

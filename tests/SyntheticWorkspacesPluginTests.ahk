#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk

class AKPlugin {
   __New(app) {
      this.App := app
      this.Config := Map()
   }
}

#Include ..\plugins\SyntheticWorkspaces.ahk

if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(SyntheticWorkspacesPluginTests)
else
   Yunit.Use(YunitWindow).Test(SyntheticWorkspacesPluginTests)

class SyntheticWorkspaceRuntimeTestDouble {
   __New() {
      this.StartCount := 0
      this.StopCount := 0
      this.RestoreCount := 0
      this.LastAction := ""
      this.LastWorkspaceId := ""
      this.LastHwnd := 0
   }

   Start() {
      this.StartCount += 1
      return true
   }

   Stop() {
      this.StopCount += 1
      return true
   }

   SwitchWorkspace(workspaceId) {
      this.LastAction := "switch"
      this.LastWorkspaceId := workspaceId
      return workspaceId
   }

   MoveWindowToWorkspace(workspaceId, hwnd) {
      this.LastAction := "move"
      this.LastWorkspaceId := workspaceId
      this.LastHwnd := hwnd
      return workspaceId
   }

   MoveWindowAndSwitchWorkspace(workspaceId, hwnd) {
      this.LastAction := "move-and-switch"
      this.LastWorkspaceId := workspaceId
      this.LastHwnd := hwnd
      return workspaceId
   }

   RestoreAllWindows() {
      this.LastAction := "restore"
      this.RestoreCount += 1
      return true
   }
}

class SyntheticWorkspaceOverviewTestDouble {
   __New() {
      this.StartCount := 0
      this.StopCount := 0
      this.LastAction := ""
   }

   Start() {
      this.StartCount += 1
      return true
   }

   Stop() {
      this.StopCount += 1
      return true
   }

   Show() {
      this.LastAction := "show"
      return "show"
   }

   Hide() {
      this.LastAction := "hide"
      return "hide"
   }

   Toggle() {
      this.LastAction := "toggle"
      return "toggle"
   }
}

class SyntheticWorkspaceFailingOverviewTestDouble extends SyntheticWorkspaceOverviewTestDouble {
   Stop() {
      this.StopCount += 1
      throw Error("overview stop failed")
   }
}

class SyntheticWorkspacesPluginTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("SyntheticWorkspaces", [
         "SwitchSyntheticWorkspace",
         "MoveWindowToSyntheticWorkspace",
         "MoveWindowAndSwitchSyntheticWorkspace",
         "ShowSyntheticWorkspaceOverview",
         "HideSyntheticWorkspaceOverview",
         "ToggleSyntheticWorkspaceOverview",
         "DisableSyntheticWorkspaces",
         "RestoreAllSyntheticWorkspaceWindows"
      ], [])
   }

   T02_DefaultServiceModelContainsEightMappedWorkspaces() {
      global Yunit
      service := SyntheticWorkspaceService()
      Yunit.assert(service.Model.GetWorkspaceCount() = 8, "default service model should contain eight workspaces")
      for slotId in SyntheticWorkspaceModel.GetSlotIds()
         Yunit.assert(service.Model.GetWorkspaceIdForSlot(slotId) != "", "every default direction slot should resolve a workspace")
   }

   T03_DirectionUsesCurrentSlotMapping() {
      global Yunit
      model := SyntheticWorkspaceService.CreateDefaultModel()
      eastWorkspaceId := model.GetWorkspaceIdForSlot("e")
      model.SwapSlots("n", "e")
      workspaceRuntime := SyntheticWorkspaceRuntimeTestDouble()
      service := SyntheticWorkspaceService(model, workspaceRuntime)
      service.Start()
      result := service.SwitchSyntheticWorkspace("n")
      service.Stop()
      Yunit.assert(result = eastWorkspaceId && workspaceRuntime.LastWorkspaceId = eastWorkspaceId, "direction action should use the workspace currently mapped to the slot")
   }

   T04_WindowActionsDelegateStableWorkspaceAndHwnd() {
      global Yunit
      workspaceRuntime := SyntheticWorkspaceRuntimeTestDouble()
      service := SyntheticWorkspaceService(0, workspaceRuntime)
      service.Start()
      expectedWorkspaceId := service.Model.GetWorkspaceIdForSlot("sw")
      service.MoveWindowToSyntheticWorkspace("sw", 1234)
      Yunit.assert(workspaceRuntime.LastAction = "move" && workspaceRuntime.LastWorkspaceId = expectedWorkspaceId && workspaceRuntime.LastHwnd = 1234, "move action should pass the resolved workspace and HWND")
      service.MoveWindowAndSwitchSyntheticWorkspace("sw", 5678)
      Yunit.assert(workspaceRuntime.LastAction = "move-and-switch" && workspaceRuntime.LastWorkspaceId = expectedWorkspaceId && workspaceRuntime.LastHwnd = 5678, "move-and-switch action should pass the resolved workspace and HWND")
      service.RestoreAllSyntheticWorkspaceWindows()
      Yunit.assert(workspaceRuntime.RestoreCount = 1, "restore action should delegate once")
      service.Stop()
   }

   T05_OverviewActionsDelegateOnce() {
      global Yunit
      overviewRuntime := SyntheticWorkspaceOverviewTestDouble()
      service := SyntheticWorkspaceService(0, 0, overviewRuntime)
      service.Start()
      Yunit.assert(service.ShowSyntheticWorkspaceOverview() = "show" && overviewRuntime.LastAction = "show", "show overview should delegate")
      Yunit.assert(service.HideSyntheticWorkspaceOverview() = "hide" && overviewRuntime.LastAction = "hide", "hide overview should delegate")
      Yunit.assert(service.ToggleSyntheticWorkspaceOverview() = "toggle" && overviewRuntime.LastAction = "toggle", "toggle overview should delegate")
      service.Stop()
   }

   T06_MissingCapabilityFailsClearly() {
      global Yunit
      service := SyntheticWorkspaceService()
      service.Start()
      unavailableError := 0
      try service.SwitchSyntheticWorkspace("n")
      catch Error as caughtError
         unavailableError := caughtError
      service.Stop()
      Yunit.assert(IsObject(unavailableError) && InStr(unavailableError.Message, "capability unavailable") && InStr(unavailableError.Message, "workspace switching"), "missing runtime should report the unavailable capability")
   }

   T07_LifecycleIsIdempotentAndStopsBothRuntimes() {
      global Yunit
      workspaceRuntime := SyntheticWorkspaceRuntimeTestDouble()
      overviewRuntime := SyntheticWorkspaceOverviewTestDouble()
      service := SyntheticWorkspaceService(0, workspaceRuntime, overviewRuntime)
      Yunit.assert(service.Start() && !service.Start(), "service start should be idempotent")
      Yunit.assert(service.Stop() && !service.Stop(), "service stop should be idempotent")
      Yunit.assert(workspaceRuntime.StartCount = 1 && workspaceRuntime.StopCount = 1, "workspace runtime should start and stop once")
      Yunit.assert(overviewRuntime.StartCount = 1 && overviewRuntime.StopCount = 1, "overview runtime should start and stop once")
   }

   T08_StopContinuesAfterOneRuntimeFails() {
      global Yunit
      workspaceRuntime := SyntheticWorkspaceRuntimeTestDouble()
      overviewRuntime := SyntheticWorkspaceFailingOverviewTestDouble()
      service := SyntheticWorkspaceService(0, workspaceRuntime, overviewRuntime)
      service.Start()
      stopError := 0
      try service.Stop()
      catch Error as caughtError
         stopError := caughtError
      Yunit.assert(IsObject(stopError) && !service.IsRunning(), "failed cleanup should be reported after marking the service stopped")
      Yunit.assert(overviewRuntime.StopCount = 1 && workspaceRuntime.StopCount = 1, "one cleanup failure should not skip the other runtime")
   }

   T09_PluginStartsDelegatesAndStopsItsService() {
      global Yunit
      workspaceRuntime := SyntheticWorkspaceRuntimeTestDouble()
      service := SyntheticWorkspaceService(0, workspaceRuntime)
      plugin := SyntheticWorkspaces(Map(), service)
      plugin._init()
      expectedWorkspaceId := service.Model.GetWorkspaceIdForSlot("nw")
      result := plugin.SwitchSyntheticWorkspace("nw")
      plugin._shutdown()
      plugin._shutdown()
      Yunit.assert(result = expectedWorkspaceId && workspaceRuntime.LastWorkspaceId = expectedWorkspaceId, "plugin action should delegate to its service")
      Yunit.assert(workspaceRuntime.StartCount = 1 && workspaceRuntime.StopCount = 1, "plugin lifecycle should start and stop its service once")
   }

   T10_PortableServiceHasNoNativeWindowCalls() {
      global Yunit
      serviceSource := ReadRepoFile("plugins\SyntheticWorkspaces\WorkspaceService.ahk")
      forbiddenCallFound := RegExMatch(serviceSource, "i)\b(?:WinGet\w*|WinMove|DllCall|GetKeyState|A_ThisHotkey)\b")
      Yunit.assert(!forbiddenCallFound, "portable service should not contain native window or input calls")
   }
}

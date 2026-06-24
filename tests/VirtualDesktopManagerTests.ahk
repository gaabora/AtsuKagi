#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(VirtualDesktopManagerTests)
else
   Yunit.Use(YunitWindow).Test(VirtualDesktopManagerTests)


class VirtualDesktopManagerTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("VirtualDesktopManager", [
         "GetDesktopName",
         "SetDesktopName",
         "CreateDesktop",
         "RemoveDesktop",
         "GetCurrentDesktopNumber",
         "GetDesktopCount",
         "GetPrevDesktopNumber",
         "GetNextDesktopNumber",
         "GoToDesktop",
         "GoToRecentDesktop",
         "GoToPrevDesktop",
         "GoToNextDesktop",
         "MoveWindowToDesktop",
         "MoveWindowToPrevDesktop",
         "MoveWindowToNextDesktop",
         "MoveHoveredWindowToDesktop",
         "MoveHoveredWindowToPrevDesktop",
         "MoveHoveredWindowToNextDesktop",
         "GoWithWindowToDesktop",
         "GoWithWindowToPrevDesktop",
         "GoWithWindowToNextDesktop",
         "GoWithHoveredWindowToDesktop",
         "GoWithHoveredWindowToPrevDesktop",
         "GoWithHoveredWindowToNextDesktop"
      ], [
         "LoopFirstAndLast"
      ])
   }
}

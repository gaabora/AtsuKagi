#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(RDPWindowHandlerTests)
else
   Yunit.Use(YunitWindow).Test(RDPWindowHandlerTests)


class RDPWindowHandlerTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("RDPWindowHandler", [
         "IsRDPClientWindowActive",
         "MinimizeRestoreRDPClientWindows",
         "RestoreFullscreenRDPClientWindow",
         "LoopRDPClientWindows",
         "SwitchToNextRDPClientWindow"
      ], [])
   }
}

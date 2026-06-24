#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(SwapButtonsHandlerTests)
else
   Yunit.Use(YunitWindow).Test(SwapButtonsHandlerTests)


class SwapButtonsHandlerTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("SwapButtonsHandler", [], [])
   }
}

#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(WindowResizeDialogTests)
else
   Yunit.Use(YunitWindow).Test(WindowResizeDialogTests)


class WindowResizeDialogTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("WindowResizeDialog", [
         "ShowResizeWindowDialog"
      ], [
         "KeyLayout",
         "MoveModifier",
         "StepModifier",
         "UsePreciseModeByDefault",
         "PreciseStepSize",
         "NormalStepSize",
         "RepeatDelayMs",
         "PollingIntervalMs"
      ])
   }
}

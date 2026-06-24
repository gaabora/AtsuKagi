#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(WindowStashTests)
else
   Yunit.Use(YunitWindow).Test(WindowStashTests)


class WindowStashTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("WindowStash", [
         "StashWindowLeft",
         "StashWindowRight",
         "StashWindowTop",
         "StashWindowBottom",
         "UnstashWindow",
         "UnstashHoveredWindow",
         "RestoreAllStashedWindows"
      ], [
         "HoverTolerance",
         "PollInterval",
         "ShiftFocusWhenStashed",
         "RestorePositionOnUnstash",
         "WindowEdgeOffset",
         "AnimateTransitions",
         "AnimationDuration",
         "RestoreSettleDelay",
         "ShowWindowContent",
         "OverlayColor",
         "OverlayOpacity",
         "HandleColor",
         "HandleGripColor",
         "HandleOpacity",
         "HandleThickness",
         "HandleLength",
         "HandleDragDistance",
         "LockHandleDragAxis"
      ])
   }
}

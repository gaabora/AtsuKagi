#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(WindowManagerTests)
else
   Yunit.Use(YunitWindow).Test(WindowManagerTests)


class WindowManagerTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("WindowManager", [
         "ShowWindowList",
         "ShowHoveredWindowInfo",
         "ShowWindowInfo",
         "MinimizeWindow",
         "MinimizeHoveredWindow",
         "CloseWindow",
         "CloseHoveredWindow",
         "ToggleWindowMaximized",
         "ToggleHoveredWindowMaximized",
         "ToggleHoveredWindowOnTop",
         "ToggleWindowOnTop",
         "ToggleWindowFullScreen",
         "ToggleHoveredWindowFullScreen",
         "ToggleWindowFrame",
         "ToggleHoveredWindowFrame",
         "ToggleWindowTransparency",
         "ToggleHoveredWindowTransparency",
         "IncreaseWindowTransparency",
         "IncreaseHoveredWindowTransparency",
         "DecreaseWindowTransparency",
         "DecreaseHoveredWindowTransparency",
         "SetWindowBorderColor",
         "ToggleTaskView",
         "IsMouseOverTaskbar",
         "IsMouseOverWindowTitlebar",
         "IsMouseOverWindowAnyBorder",
         "IsMouseOverWindowResizableBorder"
      ], [
         "WindowTransparencyValue",
         "WindowOnTopBorderColor",
         "WindowTitlebarAreaHeight"
      ])
   }
}

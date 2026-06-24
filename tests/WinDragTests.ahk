#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(WinDragTests)
else
   Yunit.Use(YunitWindow).Test(WinDragTests)


class WinDragTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("WinDrag", [
         "EnterWindowMovingMode",
         "EnterWindowResizingMode",
         "EnterWindowQuickPositioningMode"
      ], [
         "QuickPositionHotkey",
         "EnableSnapping",
         "SnappingDistance",
         "CompensateInvisibleBorders",
         "SnapOnRelease",
         "SnapEdgeThreshold",
         "SnapHalfScreen",
         "SnapMaximizeOnTop",
         "SnapMinimizeOnBottom",
         "SnapLeftRightTiles",
         "SnapQuarterCorners",
         "SnapToWindows",
         "SnapToWindowsDistance",
         "ResizeAxisThreshold",
         "StickyResizeModifier",
         "ShowWindowContentOnMove",
         "ShowWindowContentOnResize",
         "ShowWindowContentOnQuickPosition",
         "BringToFront",
         "ShowGeometryTooltip",
         "OverlayColor",
         "OverlayOpacity",
         "UseSetWindowPos"
      ])
   }
}

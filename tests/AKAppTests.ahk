#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(AKAppTests)
else
   Yunit.Use(YunitWindow).Test(AKAppTests)


class AKAppTests {
   T01_GeneralSettingsDescriptorContract() {
      source := ReadRepoFile("includes\AKApp.ahk")
      AssertSourceMatches(source, "m)^class\s+AKApp\s+extends\s+AKBase\b", "AKApp class must extend AKBase")
      AssertSourceContains(source, "__DescribeGeneralSettings()", "AKApp must expose the general settings descriptor")
      AssertSourceContains(source, '"id", "general"', "General settings page id must remain stable")
      AssertSourceContainsAll(source, [
         '"key", "WelcomeMessage"',
         '"key", "DarkTheme"',
         '"key", "UIScalingPercent"',
         '"key", "DebugLevel"',
         '"key", "ToolTipTimeoutMs"',
         '"key", "StartupSound"',
         '"key", "NotificationSound"',
         '"key", "NotificationPosition"',
         '"key", "NotificationDurationMs"',
         '"key", "NotificationFontFace"',
         '"key", "NotificationTitleFontSize"',
         '"key", "NotificationMessageFontSize"',
         '"key", "NotificationPaddingX"',
         '"key", "NotificationPaddingY"',
         '"key", "NotificationMaxWidth"',
         '"key", "NotificationCornerRadius"',
         '"key", "NotificationShowBorder"',
         '"key", "ReloadAppHotkey"',
         '"key", "SuspendAppHotkey"',
         '"key", "SwapMouseXButtons"'
      ], "General settings descriptor field")
   }
}

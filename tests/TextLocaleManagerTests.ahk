#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(TextLocaleManagerTests)
else
   Yunit.Use(YunitWindow).Test(TextLocaleManagerTests)


class TextLocaleManagerTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("TextLocaleManager", [
         "ShowCurrentKeyboardLayout",
         "ShowUsersKeyboardLayouts",
         "GetCurrentKeyboardLayoutName",
         "SwitchKeyboardLayout",
         "SwapTextLayout",
         "SwitchSelectedTextLayout",
         "SwitchSelectedTextCase"
      ], [])
   }
}

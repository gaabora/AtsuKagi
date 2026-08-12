#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(AutomationsTests)
else
   Yunit.Use(YunitWindow).Test(AutomationsTests)


class AutomationsTests {
   T01_PluginDescriptorContract() {
      AssertPluginSourceContract("Automations", ["RunAutomation", "TestAutomationAction", "EnableAutomation", "DisableAutomation", "ToggleAutomation"], ["SchedulerEnabled", "PollingIntervalMs", "CatchUpMaximumHours", "BatterySampleIntervalMs", "BatteryHistoryRetentionDays"])
   }
}

#Requires AutoHotKey v2.0
#Include Yunit\Yunit.ahk
#Include Yunit\Window.ahk
#Include Yunit\Stdout.ahk
#Include DescriptorTestHelpers.ahk


if (A_Args.Length && A_Args[1] = "--cli")
   Yunit.Use(YunitStdOut).Test(GeneralHandlersTests)
else
   Yunit.Use(YunitWindow).Test(GeneralHandlersTests)


class GeneralHandlersTests {
   T01_PluginDescriptorContract() {
      source := ReadRepoFile("includes\GeneralHandlers.ahk")
      AssertSourceMatches(source, "m)^class\s+GeneralHandlers\s+extends\s+AKPlugin\b", "GeneralHandlers class must extend AKPlugin")
      AssertSourceContains(source, "__DescribePlugin()", "GeneralHandlers must describe itself")
      AssertSourceContains(source, '"id", "GeneralHandlers"', "GeneralHandlers descriptor id must match class")
      for actionName in [
         "IfThenElse",
         "SkipIfBlocklisted",
         "RemapKeyTo",
         "DoNothing",
         "ShowInfo",
         "Run"
      ] {
         AssertSourceContains(source, '"action", "' actionName '"', "GeneralHandlers descriptor must declare action " actionName)
         AssertSourceMatches(source, "m)^\s*" actionName "\([^`r`n{]*\)\s*\{", "GeneralHandlers must implement action " actionName)
      }
   }
}

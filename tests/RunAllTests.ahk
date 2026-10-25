#Requires AutoHotKey v2.0

testFiles := [
   "IniFileTests.ahk",
   "AKAppTests.ahk",
   "GeneralHandlersTests.ahk",
   "RDPWindowHandlerTests.ahk",
   "ShellMessageHookTests.ahk",
   "SwapButtonsHandlerTests.ahk",
   "TextLocaleManagerTests.ahk",
   "SyntheticWorkspacesModelTests.ahk",
   "SyntheticWorkspacesPluginTests.ahk",
   "SyntheticWorkspacesRuntimeTests.ahk",
   "SyntheticWorkspacesEventTests.ahk",
   "SyntheticWorkspacesSwitchTests.ahk",
   "TextToSpeechTests.ahk",
   "AutomationsTests.ahk",
   "TouchGesturesSimulatorTests.ahk",
   "VirtualDesktopManagerTests.ahk",
   "WindowManagerTests.ahk",
   "WindowResizeDialogTests.ahk",
   "WindowStashTests.ahk",
   "WinDragTests.ahk"
]

quote := Chr(34)
ahkRuntime := A_AhkPath
shell := ComObject("WScript.Shell")
failedSuites := 0
outputToStdout := !(A_Args.Length && A_Args[1] = "--debug-output") && HasStdout()

for testFile in testFiles {
   testPath := A_ScriptDir "\" testFile
   WriteOutput("`n== " testFile " ==`n")

   command := quote ahkRuntime quote " /ErrorStdOut " quote testPath quote " --cli"
   exec := shell.Exec(command)
   output := exec.StdOut.ReadAll()
   errorOutput := exec.StdErr.ReadAll()

   if (output != "")
      WriteOutput(output)
   if (errorOutput != "")
      WriteOutput(errorOutput)

   if (exec.ExitCode != 0 || InStr(output, "FAIL:") || errorOutput != "") {
      failedSuites += 1
      WriteOutput("SUITE FAIL: " testFile "`n")
   } else {
      WriteOutput("SUITE PASS: " testFile "`n")
   }
}

if (failedSuites) {
   WriteOutput("`nFAILED SUITES: " failedSuites "`n")
   ExitApp(1)
}

WriteOutput("`nALL TEST SUITES PASSED`n")
ExitApp(0)

HasStdout() {
   return DllCall("GetFileType", "Ptr", DllCall("GetStdHandle", "Int", -11, "Ptr"), "UInt") != 0
}

WriteOutput(text) {
   global outputToStdout
   if (outputToStdout) {
      FileAppend(text, "*")
      return
   }
   OutputDebug(RTrim(text, "`r`n") "`n")
}

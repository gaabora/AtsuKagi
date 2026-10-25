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

for testFile in testFiles {
   testPath := A_ScriptDir "\" testFile
   Run(quote ahkRuntime quote " " quote testPath quote)
}

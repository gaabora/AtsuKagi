SetPropIfNotExist(configSection, propName, propValue) {
  if (!configSection.Has(propName))
    configSection.%propName% := propValue
}

ProcessGereralConfigSection(configSection) {
  SetPropIfNotExist(configSection, "HotkeyInterval"               , 1000)
  SetPropIfNotExist(configSection, "MaxHotkeysPerInterval"        , 1000)
  SetPropIfNotExist(configSection, "KeyboardHookStealersList"     , "TscShellContainerClass")
  SetPropIfNotExist(configSection, "BlacklistGlobalWindowClasses" , "WorkerW Progman Shell_TrayWnd Shell_SecondaryTrayWnd TscShellContainerClass")
  SetPropIfNotExist(configSection, "WindowOnTopBorderColor"       , "0xAACCFF")
  SetPropIfNotExist(configSection, "WindowTransparencyValue"      , 128)
  SetPropIfNotExist(configSection, "WelcomeMessage"               , "Enjoy")
  SetPropIfNotExist(configSection, "ToolTipTimeoutMs"             , 1000)
  SetPropIfNotExist(configSection, "StartupSound"                 , "Assets/mixkit-light-button-2580.wav")
  SetPropIfNotExist(configSection, "NotificationSound"            , "Assets/mixkit-light-button-2580.wav")
  SetPropIfNotExist(configSection, "ReloadAppHotkey"              , "^#!Backspace")
  SetPropIfNotExist(configSection, "SuspendAppHotkey"             , "^#!Esc")
  SetPropIfNotExist(configSection, "DarkTheme"                    , 1)
  SetPropIfNotExist(configSection, "SwapMouseXButtons"            , 0)
  SetPropIfNotExist(configSection, "ModifierHotkeysHint"          , "Alt=!, Ctrl=^, Shift=+, LWin=#, AltGr=<^>!")
  SetPropIfNotExist(configSection, "DisabledPlugins"              , "ShellMessageHook,RDPWindowHandler")
}

ProcessThemeConfigSection(configSection) {
  SetPropIfNotExist(configSection, "DarkThemeBackgroundColor"  , 0xFF2E2E2E)
  SetPropIfNotExist(configSection, "DarkThemeBorderColor"      , 0xFF545456)
  SetPropIfNotExist(configSection, "DarkThemeTextColor"        , 0xFFFFFFFF)
  SetPropIfNotExist(configSection, "LightThemeBackgroundColor" , 0xFFFFFFFF)
  SetPropIfNotExist(configSection, "LightThemeBorderColor"     , 0xFFB4B4B4)
  SetPropIfNotExist(configSection, "LightThemeTextColor"       , 0xFF000000)
  SetPropIfNotExist(configSection, "BorderWidth"               , 1)
  SetPropIfNotExist(configSection, "BorderRadius"              , 5)
  SetPropIfNotExist(configSection, "FontFace"                  , "Tahoma")
  SetPropIfNotExist(configSection, "FontSize"                  , 12)
  SetPropIfNotExist(configSection, "FontStyle"                 , "") ; (Regular Bold Italic BoldItalic Underline Strikeout)
  SetPropIfNotExist(configSection, "Margin"                    , 5)
}

; getDefaultAppBlackListsConfig() {
;   config := Map()
;   ; config[""] := "FocusStealers"
;   config["NeverResize"]    := ""
;   config["NeverMove"]  := ""
;   config[""]    := "GoWithHoveredWindowToPrevDesktop"
;   return config
; }

GetDefaultHotkeysConfig() {
  config := Map()
  config["#Esc"]         := 'Run("scrnsave.scr /s")'
  config["RButton"]      := "EnterGestureMode(1, 4)"
  config["XButton2"]     := "EnterGestureMode(4, 4, ToggleTaskView)"

  config["#!i"]          := "ShowHoveredWindowInfo"
  config["#!l"]          := "ShowWindowList"

  config["#LButton"]     := "EnterWindowMovingMode"
  config["#RButton"]     := "IfThenElse(IsMouseOverWindowTitlebar, MinimizeHoveredWindow, EnterWindowResizingMode)"
  config["#MButton"]     := "IfThenElse(IsMouseOverWindowTitlebar, CloseHoveredWindow, ToggleHoveredWindowMaximized)"
  config["#!MButton"]    := "ToggleHoveredWindowFullScreen"
  config["#F11"]         := "ToggleWindowFullScreen"
  config["+^#!F11"]      := "ToggleWindowFrame"
  config["#Enter"]       := "ToggleWindowMaximized"
  config["#!Enter"]      := "ShowResizeWindowDialog"
  config["#!SPACE"]      := "ToggleWindowOnTop"
  config["^#!SPACE"]     := "ToggleWindowTransparency"
  config["^#!WheelDown"] := "DecreaseHoveredWindowTransparency"
  config["^#!WheelUp"]   := "IncreaseHoveredWindowTransparency"
  
  config["#WheelDown"]   := "IfThenElse(IsMouseOverWindowTitlebar, GoWithHoveredWindowToNextDesktop, GoToNextDesktop)"
  config["#WheelUp"]     := "IfThenElse(IsMouseOverWindowTitlebar, GoWithHoveredWindowToPrevDesktop, GoToPrevDesktop)"
  config["+#WheelDown"]  := "GoWithHoveredWindowToPrevDesktop"
  config["+#WheelUp"]    := "GoWithHoveredWindowToNextDesktop"
  config["^+#Left"]      := "GoWithWindowToPrevDesktop"
  config["^+#Right"]     := "GoWithWindowToNextDesktop"
  config["^#Tab"]        := "GoToRecentDesktop"
  config["#F1"]          := "GoToDesktop(1)"
  config["#F2"]          := "GoToDesktop(2)"
  config["#F3"]          := "GoToDesktop(3)"
  config["#F4"]          := "GoToDesktop(4)"
  config["#F5"]          := "GoToDesktop(5)"
  config["#F6"]          := "GoToDesktop(6)"
  config["#F7"]          := "GoToDesktop(7)"
  config["#F8"]          := "GoToDesktop(8)"
  config["+#F1"]         := "MoveWindowToDesktop(1)"
  config["+#F2"]         := "MoveWindowToDesktop(2)"
  config["+#F3"]         := "MoveWindowToDesktop(3)"
  config["+#F4"]         := "MoveWindowToDesktop(4)"
  config["+#F5"]         := "MoveWindowToDesktop(5)"
  config["+#F6"]         := "MoveWindowToDesktop(6)"
  config["+#F7"]         := "MoveWindowToDesktop(7)"
  config["+#F8"]         := "MoveWindowToDesktop(8)"

  config["+!^LWin"]      := "RemapTo({Blind} {vkE8})"
  config[">!M"]          := "RemapTo(0)"
  config[">!J"]          := "RemapTo(1)"
  config[">!K"]          := "RemapTo(2)"
  config[">!L"]          := "RemapTo(3)"
  config[">!U"]          := "RemapTo(4)"
  config[">!I"]          := "RemapTo(5)"
  config[">!O"]          := "RemapTo(6)"
  config[">!7"]          := "RemapTo(7)"
  config[">!8"]          := "RemapTo(8)"
  config[">!9"]          := "RemapTo(9)"
  config[">!0"]          := "RemapTo(NumpadDiv)"
  config[">!P"]          := "RemapTo(NumpadMult)"
  config[">!;"]          := "RemapTo(NumpadSub)"
  config[">!/"]          := "RemapTo(NumpadAdd)"
  config[">!."]          := "RemapTo(NumpadDot)"
  config[">!Enter"]      := "RemapTo(NumpadEnter)"
  config["NumpadIns"]    := "RemapTo(0)"
  config["NumpadEnd"]    := "RemapTo(1)"
  config["NumpadDown"]   := "RemapTo(2)"
  config["NumpadPgDn"]   := "RemapTo(3)"
  config["NumpadLeft"]   := "RemapTo(4)"
  config["NumpadClear"]  := "RemapTo(5)"
  config["NumpadRight"]  := "RemapTo(6)"
  config["NumpadHome"]   := "RemapTo(7)"
  config["NumpadUp"]     := "RemapTo(8)"
  config["NumpadPgUp"]   := "RemapTo(9)"
  config["NumpadDel"]    := "RemapTo(.)"

  config["XButton1"]     := "RemapTo(Backspace)"

  config[">+Backspace"]  := "RemapTo(Delete)"
  ; config["^>+Backspace"] := "RemapTo({Ctrl down}{Delete}{Ctrl up})"
  ; config["<+>+Backspace"]:= "RemapTo({Shift down}{Delete}{Shift up})"

  config["!CapsLock"]    := "SwitchSelectedTextCase()"
  config["CapsLock"]     := "SwitchKeyboardLayout()"
  config["*~^Shift"]     := "ShowCurrentKeyboardLayout()"
  config["*~!Shift"]     := "ShowCurrentKeyboardLayout()"
  config["*~+Control"]   := "ShowCurrentKeyboardLayout()"
  config["*~+Alt"]       := "ShowCurrentKeyboardLayout()"
  
  config["^CapsLock"]    := "SwitchSelectedTextLayout(EN,RU)"
  
  ; config["#!CapsLock"]   := "SwitchToNextRDPClientWindow"
  ; config["+CapsLock"]    := "MinimizeRestoreRDPClientWindows"
  ; config["!+CapsLock"]   := "RestoreFullscreenRDPClientWindow"
  ; config["#CapsLock"]    := "LoopRDPClientWindows"
  
  return config
}

SetPropIfNotExist(configSection, propName, propValue) {
  if (!configSection.Has(propName))
    configSection.%propName% := propValue
}

ProcessGeneralConfigSection(configSection) { ;TODO: obsolete, need to check is it already replaced by __DescribeGeneralSettings, so default values will set from there correctly
  SetPropIfNotExist(configSection, "HotkeyInterval"               , 1000)
  SetPropIfNotExist(configSection, "MaxHotkeysPerInterval"        , 1000)
  SetPropIfNotExist(configSection, "KeyboardHookStealersList"     , "TscShellContainerClass")
  SetPropIfNotExist(configSection, "BlocklistGlobalWindowClasses" , "WorkerW Progman Shell_TrayWnd Shell_SecondaryTrayWnd TscShellContainerClass")
  SetPropIfNotExist(configSection, "WindowOnTopBorderColor"       , "0xAACCFF")
  SetPropIfNotExist(configSection, "WindowTransparencyValue"      , 128)
  SetPropIfNotExist(configSection, "WelcomeMessage"               , "Haribol!")
  SetPropIfNotExist(configSection, "ToolTipTimeoutMs"             , 1000)
  SetPropIfNotExist(configSection, "DebugLevel"                   , A_IsCompiled ? 0 : 5)
  SetPropIfNotExist(configSection, "StartupSound"                 , "Assets/mixkit-light-button-2580.wav")
  SetPropIfNotExist(configSection, "NotificationSound"            , "Assets/mixkit-light-button-2580.wav")
  SetPropIfNotExist(configSection, "NotificationPosition"         , "br")
  SetPropIfNotExist(configSection, "NotificationDurationMs"       , 2500)
  SetPropIfNotExist(configSection, "NotificationFontFace"         , "Segoe UI")
  SetPropIfNotExist(configSection, "NotificationTitleFontSize"    , 11)
  SetPropIfNotExist(configSection, "NotificationMessageFontSize"  , 10)
  SetPropIfNotExist(configSection, "NotificationPaddingX"         , 18)
  SetPropIfNotExist(configSection, "NotificationPaddingY"         , 12)
  SetPropIfNotExist(configSection, "NotificationMaxWidth"         , 520)
  SetPropIfNotExist(configSection, "NotificationCornerRadius"     , 10)
  SetPropIfNotExist(configSection, "NotificationShowBorder"       , 0)
  SetPropIfNotExist(configSection, "ReloadAppHotkey"              , "^#!Backspace")
  SetPropIfNotExist(configSection, "SuspendAppHotkey"             , "^#!Esc")
  SetPropIfNotExist(configSection, "DarkTheme"                    , -1)
  SetPropIfNotExist(configSection, "UIScalingPercent"             , 100)
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

ProcessBlocklistsConfigSection(configSection) {
  ; Named blocklists that can be referenced by plugins and actions.
  ; Each entry is a comma-separated list of patterns.
  ; Pattern format:
  ;   ClassName          - match by window class (default)
  ;   class:ClassName    - match by window class (explicit)
  ;   exe:Process.exe    - match by process executable name
  ;   path:substring     - match substring in process full path
  SetPropIfNotExist(configSection, "NoMoveResize"      , "WorkerW, Progman, Shell_TrayWnd, Shell_SecondaryTrayWnd, TscShellContainerClass") ; TODO need to add some prefix symbol for builtin named blocklists and make them readonly for users, so they can be updated with software update, when user trying to edit builtin list, it should create users named blocklist with similar name but without that symbol, and users list should implicitly auto inherit records from builtin blocklist so no duplicated records can be added.
  SetPropIfNotExist(configSection, "NoCtrlCHotkey"     , "class:ConsoleWindowClass, class:PuTTY")
  SetPropIfNotExist(configSection, "NoRightClickGesture", "exe:REAPER.exe")
}

GetDefaultHotkeysConfig() {
  config := Map()
  config["#Esc"]         := 'Run("scrnsave.scr /s")'
  config["RButton"]      := "SkipIfBlocklisted(NoRightClickGesture, EnterGestureMode(1, 4))"
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

  config[">^F8"]         := "RemapKeyTo(Media_Play_Pause)"
  config[">+Backspace"]  := "RemapKeyTo(Delete)"
  config["+!^LWin"]      := "RemapKeyTo({Blind} {vkE8})"
  config[">!M"]          := "RemapKeyTo(0)"
  config[">!J"]          := "RemapKeyTo(1)"
  config[">!K"]          := "RemapKeyTo(2)"
  config[">!L"]          := "RemapKeyTo(3)"
  config[">!U"]          := "RemapKeyTo(4)"
  config[">!I"]          := "RemapKeyTo(5)"
  config[">!O"]          := "RemapKeyTo(6)"
  config[">!7"]          := "RemapKeyTo(7)"
  config[">!8"]          := "RemapKeyTo(8)"
  config[">!9"]          := "RemapKeyTo(9)"
  config[">!0"]          := "RemapKeyTo(NumpadDiv)"
  config[">!P"]          := "RemapKeyTo(NumpadMult)"
  config[">!;"]          := "RemapKeyTo(NumpadSub)"
  config[">!/"]          := "RemapKeyTo(NumpadAdd)"
  config[">!."]          := "RemapKeyTo(NumpadDot)"
  config[">!Enter"]      := "RemapKeyTo(NumpadEnter)"
  config["NumpadIns"]    := "RemapKeyTo(0)"
  config["NumpadEnd"]    := "RemapKeyTo(1)"
  config["NumpadDown"]   := "RemapKeyTo(2)"
  config["NumpadPgDn"]   := "RemapKeyTo(3)"
  config["NumpadLeft"]   := "RemapKeyTo(4)"
  config["NumpadClear"]  := "RemapKeyTo(5)"
  config["NumpadRight"]  := "RemapKeyTo(6)"
  config["NumpadHome"]   := "RemapKeyTo(7)"
  config["NumpadUp"]     := "RemapKeyTo(8)"
  config["NumpadPgUp"]   := "RemapKeyTo(9)"
  config["NumpadDel"]    := "RemapKeyTo(.)"

  config["XButton1"]     := "RemapKeyTo(Backspace)"

  config[">+Backspace"]  := "RemapKeyTo(Delete)"
  ; config["^>+Backspace"] := "RemapKeyTo({Ctrl down}{Delete}{Ctrl up})"
  ; config["<+>+Backspace"]:= "RemapKeyTo({Shift down}{Delete}{Shift up})"

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

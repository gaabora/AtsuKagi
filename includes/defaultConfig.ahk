ProcessGereralConfigSection(configSection) {
  if (!configSection.Has("HotkeyInterval"))
    configSection.HotkeyInterval                         := 1000
  if (!configSection.Has("MaxHotkeysPerInterval"))
    configSection.MaxHotkeysPerInterval                  := 1000
  if (!configSection.Has("KeyboardHookStealersList")) 
    configSection.KeyboardHookStealersList               := "TscShellContainerClass"
  if (!configSection.Has("BlacklistedWindowAhkIds")) 
    configSection.BlacklistedWindowAhkIds                := "WorkerW Progman Shell_TrayWnd Shell_SecondaryTrayWnd TscShellContainerClass"
  if (!configSection.Has("WindowOnTopBorderColor") || IsValidHexColor(configSection.WindowOnTopBorderColor))
    configSection.WindowOnTopBorderColor                 := "0xAACCFF"
  if (!configSection.Has("WindowTransparencyValue"))
    configSection.WindowTransparencyValue                := 128
  if (!configSection.Has("WelcomeMessage"))
    configSection.WelcomeMessage                         := "Enjoy"
  if (!configSection.Has("ToolTipTimeoutMs"))
    configSection.ToolTipTimeoutMs                       := 1000
  if (!configSection.Has("StartupSound"))
    configSection.StartupSound                           := "Assets/mixkit-light-button-2580.wav"
  if (!configSection.Has("NotificationSound"))
    configSection.NotificationSound                      := "Assets/mixkit-light-button-2580.wav"
  if (!configSection.Has("ReloadAppHotkey"))
    configSection.ReloadAppHotkey                        := "^#!Backspace"
  if (!configSection.Has("SuspendAppHotkey"))
    configSection.SuspendAppHotkey                       := "^#!Esc"
  if (!configSection.Has("DarkTheme"))
    configSection.DarkTheme                              := 1
  if (!configSection.Has("SwapMouseXButtons"))
    configSection.SwapMouseXButtons                      := 0
  if (!configSection.Has("ModifierHotkeysHint"))
    configSection.ModifierHotkeysHint                    := "Alt=!, Ctrl=^, Shift=+, LWin=#, AltGr=<^>!"
}

ProcessWindowManagementConfigSection(configSection) {
  if (!configSection.Has("BringToFront")) 
    configSection.BringToFront                       := 0
  if (!configSection.Has("QuickPosition_Hotkey")) 
    configSection.QuickPosition_Hotkey               := "Alt"
  if (!configSection.Has("LockAxis_Hotkey")) 
    configSection.LockAxis_Hotkey                    := "Shift"
  if (!configSection.Has("ShowWindowContent")) 
    configSection.ShowWindowContent                  := 1
  if (!configSection.Has("EnableSnapping")) 
    configSection.EnableSnapping                     := 1
}

; GetDefaultTitlebarActionsConfig() {
;   config := {}
;   config["#RButton"]    := "MinimizeHoveredWindow"
;   config["#MButton"]    := "CloseHoveredWindow"
;   config["#WheelDown"]  := "GoWithHoveredWindowToNextDesktop"
;   config["#WheelUp"]    := "GoWithHoveredWindowToPrevDesktop"
;   return config
; }
; getDefaultTaskbarActionsConfig() {
;   config := {}
;   return config
; }

; getDefaultBlackListMapConfig() {
;   config := {}
;   config["#MButton"]      := "CloseHoveredWindow"
;   config["#WheelDown"]    := "GoWithHoveredWindowToNextDesktop"
;   config["#WheelUp"]      := "GoWithHoveredWindowToPrevDesktop"
;   return config
; }

; getDefaultAppBlackListsConfig() {
;   config := {}
;   ; config[""] := "FocusStealers"
;   config["NeverResize"]    := ""
;   config["NeverMove"]  := ""
;   config[""]    := "GoWithHoveredWindowToPrevDesktop"
;   return config
; }

getDefaultHotkeysConfig() {
  config := {}
  config["RButton"]      := "EnterGestureMode(2)"
  config["XButton2"]     := "EnterGestureMode(4)"

  config["#!i"]          := "ShowHoveredWindowInfo"
  config["#W"]           := "ShowWindowList"

  config["#LButton"]     := "EnterWindowMovingMode"
  config["#RButton"]     := "(IsMouseOverWindowTitlebar) ? MinimizeHoveredWindow : EnterWindowResizingMode"
  config["#MButton"]     := "(IsMouseOverWindowTitlebar) ? CloseHoveredWindow : ToggleHoveredWindowMaximized"
  config["#!MButton"]    := "ToggleHoveredWindowFullScreen"
  config["#F11"]         := "ToggleWindowFullScreen"
  config["+^#!F11"]      := "ToggleWindowFrame"
  config["#Enter"]       := "ToggleWindowMaximized"
  config["#!Enter"]      := "ShowResizeWindowDialog"
  config["#!SPACE"]      := "ToggleWindowOnTop"
  config["^#!SPACE"]     := "ToggleWindowTransparency"
  config["^#!WheelDown"] := "DecreaseHoveredWindowTransparency"
  config["^#!WheelUp"]   := "IncreaseHoveredWindowTransparency"
  
  config["#WheelDown"]   := "(IsMouseOverWindowTitlebar) ? GoWithHoveredWindowToNextDesktop : GoToNextDesktop"
  config["#WheelUp"]     := "(IsMouseOverWindowTitlebar) ? GoWithHoveredWindowToPrevDesktop : GoToPrevDesktop"
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

  config["#!CapsLock"]   := "SwitchToNextRDPClientWindow"
  config["+CapsLock"]    := "MinimizeRestoreRDPClientWindows"
  config["!+CapsLock"]   := "RestoreFullscreenRDPClientWindow"
  ; config["^CapsLock"]    := "LoopRDPClientWindows"

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

  return config
}

; getDefaultRemapsConfig() {
;   config := {}
;   config["+!^LWin"] := "{Blind}{vkE8}"
;   config[">!M"] := "0"
;   config[">!M"] := "0"
;   config[">!J"] := "1"
;   config[">!K"] := "2"
;   config[">!L"] := "3"
;   config[">!U"] := "4"
;   config[">!I"] := "5"
;   config[">!O"] := "6"
;   config[">!7"] := "7"
;   config[">!8"] := "8"
;   config[">!9"] := "9"
;   config[">!0"] := "NumpadDiv"
;   config[">!P"] := "NumpadMult"
;   config[">!;"] := "NumpadSub"
;   config[">!/"] := "NumpadAdd"
;   config[">!."] := "NumpadDot"
;   config[">!Enter"] := "NumpadEnter"
;   config["NumpadIns"]   := "0"
;   config["NumpadEnd"]   := "1"
;   config["NumpadDown"]  := "2"
;   config["NumpadPgDn"]  := "3"
;   config["NumpadLeft"]  := "4"
;   config["NumpadClear"] := "5"
;   config["NumpadRight"] := "6"
;   config["NumpadHome"]  := "7"
;   config["NumpadUp"]    := "8"
;   config["NumpadPgUp"]  := "9"
;   config["NumpadDel"]   := "."

;   config["XButton1"]   := "Backspace"

;   return config
; }

; getTooltipStyleConfig(useDarkTheme:=0) {
;   config := {}
;   config.Border := 1                                       ; default = 1 (0-20)
;   config.Rounded := 5                                      ; default = 3 (0-30)
;   config.Margin := 5                                       ; default = 5 (0-30)
;   config.TabStops := [50, 80, 100]                         ; default = [50] (value must be an array)
;   config.BorderColor := useDarkTheme ? 0xFF545456 : 0xFFB4B4B4     ; 0xAARRGGBB
;   ; config.BorderColorLinearGradientStart := 0xFF121212      ; 0xAARRGGBB
;   ; config.BorderColorLinearGradientEnd := 0xFF181818        ; 0xAARRGGBB
;   ; config.BorderColorLinearGradientAngle := 90              ; Mode=8 Angle 0(L to R) 90(U to D) 180(R to L) 270(D to U)
;   ; config.BorderColorLinearGradientMode := 1                ; Mode=4 Angle 0(L to R) 90(D to U), Range 1-8.
;   config.TextColor := useDarkTheme ? 0xFFFFFFFF : 0xFF000000       ; 0xAARRGGBB
;   ; config.TextColorLinearGradientStart := 0xFFFFFFFF        ; 0xAARRGGBB
;   ; config.TextColorLinearGradientEnd := 0xFFFFFFFF          ; 0xAARRGGBB
;   ; config.TextColorLinearGradientAngle := 90                ; Mode=8 Angle 0(L to R) 90(U to D) 180(R to L) 270(D to U)
;   ; config.TextColorLinearGradientMode := 1                  ; Mode=4 Angle 0(L to R) 90(D to U), Range 1-8.
;   config.BackgroundColor := useDarkTheme ? 0xFF2E2E2E : 0xFFFFFFFF ; 0xAARRGGBB
;   ; config.BackgroundColorLinearGradientStart := 0xFF2F2F2F  ; 0xAARRGGBB
;   ; config.BackgroundColorLinearGradientEnd := 0xFF2B2B2B    ; 0xAARRGGBB
;   ; config.BackgroundColorLinearGradientAngle := 90          ; Mode=8 Angle 0(L to R) 90(U to D) 180(R to L) 270(D to U)
;   ; config.BackgroundColorLinearGradientMode := 1            ; Mode=4 Angle 0(L to R) 90(D to U), Range 1-8.
;   ; config.Font := "Tahoma"
;   config.FontSize := 12                                    ; default = 12
;   config.FontRender := 5                                   ; default = 5 (0-5)
;   config.FontStyle := ""                                   ; (Regular Bold Italic BoldItalic Underline Strikeout)
;   return config
; }

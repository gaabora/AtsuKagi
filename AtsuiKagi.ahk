#SingleInstance force
SetWorkingDir(A_ScriptDir)
ListLines(false)
SetWinDelay(-1)
SetControlDelay(-1)


#Include lib/helpers.ahk
#Include lib/Notify.ahk
#Include lib/IniFile.ahk
#Include includes/defaultConfig.ahk
#Include includes/AKBase.ahk
#Include includes/AKApp.ahk
#Include includes/AKPlugin.ahk

DebugLevel := 5

APP := AKApp()
APP.Debug(DebugLevel)

ToggleAppSuspend() {
  Suspend
  global APP
  APP.ToggleAppSuspend()
}


; if FileExist("includes/ShellMessageHook.ahk") {
;   #Include includes/ShellMessageHook.ahk
;   APP.AddLib("ShellMessageHook", DebugLevel)
; }
if FileExist("includes/GeneralHandlers.ahk") {
  #Include includes/GeneralHandlers.ahk
  APP.AddLib("GeneralHandlers", DebugLevel)
}
if FileExist("includes/WindowManager.ahk") {
  #Include includes/WindowManager.ahk
  APP.AddLib("WindowManager", DebugLevel)
}
if FileExist("includes/VirtualDesktopManager.ahk") {
  #Include includes/VirtualDesktopManager.ahk
  APP.AddLib("VirtualDesktopManager", DebugLevel)
}
if FileExist("includes/KDEMoverSizer.ahk") {
  #Include includes/KDEMoverSizer.ahk
  APP.AddLib("KDEMoverSizer", DebugLevel)
}
if FileExist("includes/TouchGesturesSimulator.ahk") {
  #Include includes/TouchGesturesSimulator.ahk
  APP.AddLib("TouchGesturesSimulator", DebugLevel)
}
if FileExist("includes/RDPWindowHandler.ahk") {
  #Include includes/RDPWindowHandler.ahk
  APP.AddLib("RDPWindowHandler", DebugLevel)
}

APP.BindAll()

if (APP.Config.GENERAL.WelcomeMessage) {
  APP.ShowInfo(APP.Config.GENERAL.WelcomeMessage)

}

; APP.Speak("何 opachika превед медвед, йя кревед")

; APP.SoundPlay(APP.Config.GENERAL.StartupSound)


; https://www.autohotkey.com/boards/viewtopic.php?f=82&t=124099&p=551999&hilit=rdp#p551999
; #UseHook
; #HotIf WinActive("ahk_class TscShellContainerClass")
; ~vkFF::{
;     ; An artificial vkFF keystroke is detected when the RDP client becomes active.
;     ; At that point, the RDP client installs its own keyboard hook which takes
;     ; precedence over ours, so ...
;     if (A_TimeIdlePhysical > A_TimeSinceThisHotkey) {
;         InstallKeybdHook true, true ; ... reinstall our hook.
;         Sleep 50
;     }
; }
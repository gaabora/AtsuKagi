#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance force
ListLines Off
SetBatchLines -1
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%
; #KeyHistory 0
#WinActivateForce



#UseHook
#Persistent


; Process, Priority,, H

SetWinDelay -1
SetControlDelay -1


#Include lib/Ini.ahk
#Include lib/helpers.ahk
#Include includes/defaultConfig.ahk
#Include includes/AKBase.ahk
#Include includes/AKApp.ahk
#Include includes/AKPlugin.ahk

DebugLevel := 5

APP := new AKApp()
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
if FileExist("includes/RDPWindowHandler.ahk") {
  #Include includes/RDPWindowHandler.ahk
  APP.AddLib("RDPWindowHandler", DebugLevel)
}
if FileExist("includes/WindowManager.ahk") {
  #Include includes/WindowManager.ahk
  APP.AddLib("WindowManager", DebugLevel)
}
if FileExist("includes/KDEMoverSizer.ahk") {
  #Include includes/KDEMoverSizer.ahk
  APP.AddLib("KDEMoverSizer", DebugLevel)
}
if FileExist("includes/TouchGesturesSimulator.ahk") {
  #Include includes/TouchGesturesSimulator.ahk
  APP.AddLib("TouchGesturesSimulator", DebugLevel)
}
if FileExist("includes/VirtualDesktopManager.ahk") {
  #Include includes/VirtualDesktopManager.ahk
  APP.AddLib("VirtualDesktopManager", DebugLevel)
}




APP.BindAll()

if (APP.Config.GENERAL.WelcomeMessage) {
  APP.ShowInfo(APP.Config.GENERAL.WelcomeMessage)

}
; APP.Speak("opachika превед медвед, йя кревед")

; APP.SoundPlay(APP.Config.GENERAL.StartupSound)


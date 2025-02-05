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


APP := AKApp()

DebugLevel := A_IsCompiled ? 0 : 5

APP.Debug(DebugLevel)


;TODO: make here include of dynamically generatable file for including plugins:
; App.ScanForPlugins()
; #Include AutogenPluginsList.ahk
; rename ./includes to ./plugins
; list files from ./plugins/
; get disabled plugin names from ini (GENERAL.DisabledPlugins=SomePlugin,AnotherPlugin)
; ... PROFIT

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
if FileExist("includes/TextLocaleManager.ahk") {
  #Include includes/TextLocaleManager.ahk
  APP.AddLib("TextLocaleManager", DebugLevel)
}
; if FileExist("includes/RDPWindowHandler.ahk") {
;   #Include includes/RDPWindowHandler.ahk
;   APP.AddLib("RDPWindowHandler", DebugLevel)
; }

APP.BindAllHotkeys()

if (APP.Config.GENERAL.WelcomeMessage) {
  APP.ShowInfo(APP.Config.GENERAL.WelcomeMessage)

}

; APP.SoundPlay(APP.Config.GENERAL.StartupSound)

#SingleInstance force
SetWorkingDir(A_ScriptDir)
ListLines(false)
SetWinDelay(-1)
SetControlDelay(-1)

; <+>+Backspace::MsgBox('Left and Right Shift')
; >+Backspace::MsgBox('Right Shift Only')

#Include lib/helpers.ahk
#Include lib/Notify.ahk
#Include lib/IniFile.ahk
#Include lib/WebViewToo-main/Lib/WebViewToo.ahk
; #Include lib/ShinsOverlayClass.ahk
#Include includes/defaultConfig.ahk
#Include includes/AKBase.ahk
#Include includes/AKGui.ahk
#Include includes/AKApp.ahk
#Include includes/AKPlugin.ahk

APP := AKApp()
APP.Debug(APP.Config.GENERAL.DebugLevel)

#Include includes/GeneralHandlers.ahk
APP.AddPlugin('GeneralHandlers', 0)

#Include dynamicPlugins.ahk

APP.BindAllHotkeys()

if (APP.Config.GENERAL.WelcomeMessage) {
  APP.ShowInfo(APP.Config.GENERAL.WelcomeMessage)

}

; APP.SoundPlay(APP.Config.GENERAL.StartupSound)

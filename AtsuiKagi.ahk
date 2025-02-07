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

#Include dynamicPlugins.ahk

APP.BindAllHotkeys()

if (APP.Config.GENERAL.WelcomeMessage) {
  APP.ShowInfo(APP.Config.GENERAL.WelcomeMessage)

}

; APP.SoundPlay(APP.Config.GENERAL.StartupSound)

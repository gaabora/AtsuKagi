#SingleInstance force
SetWorkingDir(A_ScriptDir)
ListLines(false)
SetWinDelay(-1)
SetControlDelay(-1)

; <+>+Backspace::MsgBox('Left and Right Shift')
; >+Backspace::MsgBox('Right Shift Only')

#Include lib/helpers.ahk
#Include lib/jsongo.ahk
#Include lib/Notify.ahk
#Include lib/IniFile.ahk
#Include lib/WebViewToo-main/Lib/WebViewToo.ahk
; #Include lib/ShinsOverlayClass.ahk
#Include includes/WindowsConstants.ahk
#Include includes/HotkeyRecorder.ahk
#Include includes/defaultConfig.ahk
#Include includes/AKBase.ahk
#Include includes/AKGui.ahk
#Include includes/AKApp.ahk
#Include includes/AKPlugin.ahk

APP := AKApp()
APP.Debug(APP.Config.GENERAL.DebugLevel)

#Include includes/GeneralHandlers.ahk
APP.AddPlugin('GeneralHandlers')

#Include dynamicPlugins.ahk


APP.BindAllHotkeys()

launchSuspendRequested := GetKeyState("Ctrl", "P")

if (launchSuspendRequested) {
  APP.ToolTip("Safe launch mode: Ctrl was held, hotkeys are suspended. Open Settings to fix mappings", 20, 20, 6000)
  if (!A_IsSuspended)
    APP.ToggleAppSuspend()
} else {
  APP.ToolTip("Tip: Hold Ctrl while launching to start with hotkeys suspended", 20, 20, 4000)
}



if (APP.Config.GENERAL.WelcomeMessage) {
  APP.ShowInfo(APP.Config.GENERAL.WelcomeMessage)

}

; APP.SoundPlay(APP.Config.GENERAL.StartupSound)

; Resources for compiled builds (needed by settings WebView in .exe mode)
;@Ahk2Exe-AddResource lib\WebViewToo-main\Lib\32bit\WebView2Loader.dll, 32bit\WebView2Loader.dll
;@Ahk2Exe-AddResource lib\WebViewToo-main\Lib\64bit\WebView2Loader.dll, 64bit\WebView2Loader.dll
;@Ahk2Exe-AddResource includes\ui\classes\AhkHostBridge.js, includes\ui\classes\AhkHostBridge.js
;@Ahk2Exe-AddResource includes\ui\classes\AutomationsController.js, includes\ui\classes\AutomationsController.js
;@Ahk2Exe-AddResource includes\ui\app.js, includes\ui\app.js
;@Ahk2Exe-AddResource includes\ui\classes\ColorPickerController.js, includes\ui\classes\ColorPickerController.js
;@Ahk2Exe-AddResource includes\ui\classes\HotkeyRecorderController.js, includes\ui\classes\HotkeyRecorderController.js
;@Ahk2Exe-AddResource includes\ui\classes\hotkeyUtils.js, includes\ui\classes\hotkeyUtils.js
;@Ahk2Exe-AddResource includes\ui\vendor\lch-color-wheel.js, includes\ui\vendor\lch-color-wheel.js
;@Ahk2Exe-AddResource includes\ui\classes\LogsController.js, includes\ui\classes\LogsController.js
;@Ahk2Exe-AddResource includes\ui\settings.css, includes\ui\settings.css
;@Ahk2Exe-AddResource includes\ui\settings.html, includes\ui\settings.html
;@Ahk2Exe-AddResource includes\ui\classes\SettingsForm.js, includes\ui\classes\SettingsForm.js
;@Ahk2Exe-AddResource includes\ui\classes\SettingsFormActionsRenderer.js, includes\ui\classes\SettingsFormActionsRenderer.js
;@Ahk2Exe-AddResource includes\ui\classes\SettingsFormPluginPagesRenderer.js, includes\ui\classes\SettingsFormPluginPagesRenderer.js
;@Ahk2Exe-AddResource includes\ui\classes\SettingsFormRenderer.js, includes\ui\classes\SettingsFormRenderer.js
;@Ahk2Exe-AddResource includes\ui\classes\SettingsFormSerializer.js, includes\ui\classes\SettingsFormSerializer.js
;@Ahk2Exe-AddResource includes\ui\Pages\SettingsPage.js, includes\ui\Pages\SettingsPage.js
;@Ahk2Exe-AddResource includes\ui\vendor\windows-ui.min.css, includes\ui\vendor\windows-ui.min.css
;@Ahk2Exe-AddResource includes\ui\vendor\windows-ui.min.js, includes\ui\vendor\windows-ui.min.js
;@Ahk2Exe-AddResource includes\ui\vendor\winui-icons.min.css, includes\ui\vendor\winui-icons.min.css
;@Ahk2Exe-AddResource includes\ui\vendor\winui-icons.slim.css, includes\ui\vendor\winui-icons.slim.css

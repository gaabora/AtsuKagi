class AKGui extends AKBase {
  static PREFERRED_APP_MODE := { Default: 0, AllowDark: 1, ForceDark: 2, ForceLight: 3, Max: 4 }
  static QUOTE_CHAR := Chr(34)
  _settingsGui := 0
  _isLogPageActive := false
  _hotkeyRecorder := unset
  _recordingSuspendedByRecorder := false
  _settingsOpenPage := ""
  _settingsPageRequest := 0
  _settingsRequestSequence := 0

  __New(App) {
    this.App := App
    this._hotkeyRecorder := HotkeyRecorder()
    if (this.IsDarkTheme()) {
      this.SetDarkThemeMode(AKGui.PREFERRED_APP_MODE.ForceDark)
    }
  }
  
  IsDarkTheme() {
    if (this.App.Config.GENERAL.DarkTheme = -1) {
      return NOT RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    } else {
      return this.App.Config.GENERAL.DarkTheme
    }
  }

  GetAccentColor() {
    ; return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent", "AccentColorMenu")
    return RegRead("HKCU\Software\Microsoft\Windows\DWM", "AccentColor")
  }

  SetDarkThemeMode(appMode) {
    uxthemePtr := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
    SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxthemePtr, "Ptr", 135, "Ptr")
    FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxthemePtr, "Ptr", 136, "Ptr")
    DllCall(SetPreferredAppMode, "int", appMode)
    DllCall(FlushMenuThemes)
  }

  ApplyThemeMode() {
    this.SetDarkThemeMode(this.IsDarkTheme() ? AKGui.PREFERRED_APP_MODE.ForceDark : AKGui.PREFERRED_APP_MODE.ForceLight)
    if (this._settingsGui != 0) {
      this._populateSettingsPage(this._settingsGui)
    }
  }

  ; ── Settings Window (WebViewGui / HTML-based) ──────────────────────────────
  ShowSettings(openPage:="", pageRequest:=0) {
    hasNavigationRequest := this._setSettingsNavigationRequest(openPage, pageRequest)
    ; If already open, just focus it
    if (this._settingsGui != 0) {
      try {
        if (hasNavigationRequest)
          this._populateSettingsPage(this._settingsGui)
        WinActivate("ahk_id " this._settingsGui.hWnd)
        return
      } catch {
        this._settingsGui := 0
      }
    }

    webViewSettings := this._getWebViewSettings()
    nw := WebViewGui("+Resize -Caption",,, webViewSettings)
    ; Lock down built-in browser UI chrome for app-like behavior.
    try nw.AreDefaultContextMenusEnabled := false
    try nw.IsStatusBarEnabled := false
    nw.Title := this.App.ScriptName " — Settings"
    this._settingsGui := nw
    this._isLogPageActive := false
    AKBase.SetLogPushHandler(this._pushLogEntry.Bind(this))
    this.outputDebugLine(AKApp.LOG_DEBUG, "Settings window opened", Map("source", "core"))

    ; Register JS → AHK callbacks
    nw.AddCallbackToScript("SaveSettingsJson", (wv, payload:="") => this._saveSettingsJson(payload))
    nw.AddCallbackToScript("SaveGeneralSetting", (wv, key:="", value:="") => this._saveGeneralSetting(key, value))
    nw.AddCallbackToScript("SavePluginSetting", (wv, pluginId:="", key:="", value:="") => this._savePluginSetting(pluginId, key, value))
    nw.AddCallbackToScript("GetAutomations", (wv, *) => this.App.GetAutomationsForSettings())
    nw.AddCallbackToScript("SaveAutomations", (wv, payload:="") => this.App.SaveAutomationsFromSettings(payload))
    nw.AddCallbackToScript("RunAutomation", (wv, automationId:="") => this.App.RunAutomationFromSettings(automationId))
    nw.AddCallbackToScript("TestAutomationAction", (wv, automationId:="") => this.App.TestAutomationActionFromSettings(automationId))
    nw.AddCallbackToScript("EnableAutomation", (wv, automationId:="") => this.App.EnableAutomationFromSettings(automationId))
    nw.AddCallbackToScript("DisableAutomation", (wv, automationId:="") => this.App.DisableAutomationFromSettings(automationId))
    nw.AddCallbackToScript("ToggleAutomation", (wv, automationId:="") => this.App.ToggleAutomationFromSettings(automationId))
    nw.AddCallbackToScript("ShowLowBatteryOsd", (wv, *) => this.App.ShowLowBatteryOsdFromSettings())
    nw.AddCallbackToScript("ShowTimeUntilSleep", (wv, *) => this.App.ShowTimeUntilSleepFromSettings())
    nw.AddCallbackToScript("SaveHotkey", (wv, oldHotKey:="", hotKey:="", action:="", allowRiskyHotkeys:=0) => this._saveHotkey(oldHotKey, hotKey, action, allowRiskyHotkeys))
    nw.AddCallbackToScript("RemoveHotkey", (wv, hotKey:="") => this._removeHotkey(hotKey))
    nw.AddCallbackToScript("AddHotkey", (wv, hotKey:="", action:="", allowRiskyHotkeys:=0) => this._addHotkey(hotKey, action, allowRiskyHotkeys))
    nw.AddCallbackToScript("StartHotkeyRecording", (wv, optionsJson:="") => this._startHotkeyRecording(nw, optionsJson))
    nw.AddCallbackToScript("StopHotkeyRecording", (wv, *) => this._stopHotkeyRecording())
    nw.AddCallbackToScript("TogglePlugin", (wv, pluginId:="", enabled:=1) => this._togglePlugin(pluginId, enabled))
    nw.AddCallbackToScript("SetPluginDebugLevel", (wv, pluginId:="", level:="") => this._setPluginDebugLevel(pluginId, level))
    nw.AddCallbackToScript("SetLogPageActive", (wv, active:=0) => this._setLogPageActive(active))
    nw.AddCallbackToScript("GetLogsSince", (wv, lastId:=0) => jsongo.Stringify(AKBase.GetUiLogsSince(Integer(lastId))))
    nw.AddCallbackToScript("ClearLogs", (wv, *) => AKBase.ClearLogs())
    nw.AddCallbackToScript("CloseSettings", (wv, *) => this._closeSettings())
    nw.AddCallbackToScript("BrowseForFile", (wv, currentPath:="") => this._browseForFile(currentPath))
    nw.AddCallbackToScript("OpenDevTools", (wv, *) => this._openDevTools())

    ; Populate form after page finishes loading
    nw.DOMContentLoaded((ICoreWebView2, Args) => this._populateSettingsPage(nw))

    nw.OnEvent("Close", (*) => this._onSettingsClosed())
    nw.Navigate("includes/ui/settings.html")
    nw.Show("w820 h560") ; TODO: save size/position of conf window, before restoring (probably using some global restore function and inside it check if window restores to visible area, not off-screen and to active monitor) -need to think about this kind of behavior globally for any app and possible problems
    ; if (this.App.Config.GENERAL.DebugLevel >= 4)
    ;   this._openDevTools()
  }

  _getWebViewSettings() {
    settings := {DefaultWidth: 820, DefaultHeight: 560} ;FIXME: refactor to use configurable default size and save size position on close, but on restore also check is it visible on monitor where mouse pointer is and if not move there
    bits := A_PtrSize * 8
    dllRelPath :=  bits "bit\\WebView2Loader.dll"

    ; Compiled build: extract embedded loader into temp and use it.
    ; if (A_IsCompiled) {
    ;   try {
    ;     WebViewCtrl.CreateFileFromResource(dllRelPath, WebViewCtrl.TempDir)
    ;   }
    ;   extractedDll := WebViewCtrl.TempDir "\\" dllRelPath
    ;   if (FileExist(extractedDll)) {
    ;     settings.DllPath := extractedDll
    ;     settings.DataDir := WebViewCtrl.TempDir
    ;     return settings
    ;   }
    ; }

    ; Script mode: use bundled library loader path.
    localDll := A_ScriptDir "\\lib\\WebViewToo-main\\Lib\\" dllRelPath
    if (FileExist(localDll)) {
      settings.DllPath := localDll
    }
    return settings
  }

  _populateSettingsPage(nw) {
    cfg := this.App.Config

    availablePlugins := this.App._getAvailablePlugins()
    disabledPlugins  := this.App._getDisabledPlugins()
    theme := this.IsDarkTheme() ? "dark" : "light"

    hotkeys := []
    if (cfg.HOTKEYS) {
      for k, v in cfg.HOTKEYS {
        hotkeys.Push(Map("hotKey", "" k, "action", "" v))
      }
    }

    state := Map(
      "generalPage", this.App.GetGeneralSettingsPage(),
      "plugins", Map(
        "available", availablePlugins,
        "disabled", disabledPlugins,
        "debugLevels", this.App._getPluginDebugOverrides(),
        "globalDebugLevel", Integer(cfg.GENERAL.DebugLevel),
        "pages", this.App.GetPluginSettingsPages()
      ),
      "defaultActionHotkeys", this.App.GetDefaultActionHotkeys(),
      "hotkeys", hotkeys,
      "logs", AKBase.GetUiLogs(),
      "theme", theme,
      "title", this.App.ScriptName " — Settings"
    )

    if (this._settingsOpenPage != "")
      state["openPage"] := this._settingsOpenPage
    if (IsObject(this._settingsPageRequest))
      state["pageRequest"] := this._settingsPageRequest
    this._settingsOpenPage := ""
    this._settingsPageRequest := 0

    if (AKBase._hasBindingProblems && !state.Has("openPage")) {
      state["openPage"] := "logs"
      state["logLevelFilter"] := [0, 1]
    }

    js := "(() => {`n"
    js .= "  const state = " . jsongo.Stringify(state) . ";`n"
    js .= "  if (window.SettingsPageBridge && typeof window.SettingsPageBridge.applyState === 'function') {`n"
    js .= "    try { window.SettingsPageBridge.applyState(state); } catch (error) { console.error('Failed to apply settings state', error); }`n"
    js .= "  }`n"
    js .= "})();`n"

    if (this.App.Config.GENERAL.DebugLevel >= 4)
      FileOpen(A_ScriptDir "\_debug.js", "w", "UTF-8").Write(js)
    nw.ExecuteScriptAsync(js)
  }

  _setSettingsNavigationRequest(openPage, pageRequest) {
    openPageText := Trim("" openPage)
    if (openPageText = "" && !IsObject(pageRequest))
      return false

    if (openPageText != "") {
      this._settingsOpenPage := openPageText
      this._settingsPageRequest := 0
    }
    if (pageRequest is Map) {
      requestCopy := Map()
      for key, value in pageRequest
        requestCopy[key] := value
      this._settingsRequestSequence += 1
      requestCopy["token"] := this._settingsRequestSequence
      this._settingsPageRequest := requestCopy
    }
    return true
  }

  _saveSettingsJson(payload) {
    this.App.ApplySettingsPayload(payload)
    if (this._settingsGui != 0) {
      this._populateSettingsPage(this._settingsGui)
    }
  }

  _saveGeneralSetting(key, value) {
    return this.App.SaveGeneralSetting(key, value)
  }

  _savePluginSetting(pluginId, key, value) {
    return this.App.SavePluginSetting(pluginId, key, value)
  }

  _saveHotkey(oldHotKey, hotKey, action, allowRiskyHotkeys:=0) {
    return this.App.SaveHotkey(oldHotKey, hotKey, action, allowRiskyHotkeys)
  }

  _removeHotkey(hotKey) {
    return this.App.RemoveHotkey(hotKey)
  }

  _addHotkey(hotKey, action, allowRiskyHotkeys:=0) {
    return this.App.AddHotkey(hotKey, action, allowRiskyHotkeys)
  }

  _startHotkeyRecording(nw, optionsJson:="") {
    ; Parse options from JSON string
    options := Map()
    if (optionsJson != "") {
      try {
        parsed := jsongo.Parse(optionsJson)
        if (parsed is Map || parsed is Object) {
          for key, value in parsed {
            options.Set("" key, value)
          }
        }
      } catch {
        ; Fall through with defaults
      }
    }

    this._hotkeyRecorder.StopRecording()
    this._resumeHotkeysAfterRecording()

    ; Set the callback to push updates to JS
    this._hotkeyRecorder.OnKeyRecorded := (rawHotkey, displayString) => this._pushHotkeyUpdate(nw, rawHotkey, displayString)

    ; Suspend app hotkeys while recording so captured keys do not trigger actions.
    this._suspendHotkeysForRecording()

    ; Start recording
    result := this._hotkeyRecorder.StartRecording(options)
    if (!result)
      this._resumeHotkeysAfterRecording()
    
    return jsongo.Stringify(Map("success", result))
  }

  _stopHotkeyRecording() {
    result := this._hotkeyRecorder.StopRecording()
    this._resumeHotkeysAfterRecording()
    
    ; Return final result
    finalResult := this._hotkeyRecorder.GetResult()
    return jsongo.Stringify(Map(
      "success", result,
      "raw", finalResult["raw"],
      "display", finalResult["display"]
    ))
  }

  _pushHotkeyUpdate(nw, rawHotkey, displayString) {
    if (this._settingsGui = 0)
      return

    ; Build JSON payload
    payload := jsongo.Stringify(Map(
      "raw", rawHotkey,
      "display", displayString
    ))

    ; Push to JS via ExecuteScriptAsync
    js := "(() => {`n"
    js .= "  if (window._onAhkHotkeyRecorded && typeof window._onAhkHotkeyRecorded === 'function') {`n"
    js .= "    try { window._onAhkHotkeyRecorded(" payload "); } catch (error) { console.error('Failed to process hotkey update', error); }`n"
    js .= "  }`n"
    js .= "})();"

    nw.ExecuteScriptAsync(js)
  }

  _togglePlugin(pluginId, enabled) {
    return this.App.TogglePlugin(pluginId, enabled)
  }

  _setPluginDebugLevel(pluginId, level) {
    return this.App.SetPluginDebugLevel(pluginId, level)
  }

  _setLogPageActive(active) {
    activeText := Trim("" active)
    this._isLogPageActive := (active = true || activeText = "1" || activeText = "true")
    return true
  }

  _pushLogEntry(entry) {
    if (this._settingsGui = 0 || !this._isLogPageActive)
      return

    js := "(() => {`n"
    js .= "  if (window.SettingsPageBridge && typeof window.SettingsPageBridge.appendLogs === 'function') {`n"
    js .= "    try { window.SettingsPageBridge.appendLogs(" jsongo.Stringify([entry]) "); } catch (error) { console.error('Failed to append pushed logs', error); }`n"
    js .= "  }`n"
    js .= "})();`n"
    try this._settingsGui.ExecuteScriptAsync(js)
  }

  _openDevTools() {
    if (this._settingsGui = 0)
      return false
    this._settingsGui.AreDevToolsEnabled := true
    this._settingsGui.OpenDevToolsWindow()
    return true
  }

  _browseForFile(currentPath:="", filter:="Audio Files (*.wav; *.mp3; *.ogg; *.flac)") {
    initialDir := A_ScriptDir
    pathText := Trim("" currentPath)
    if (pathText != "") {
      candidate := pathText
      if (!RegExMatch(candidate, "i)^[A-Z]:\\") && !RegExMatch(candidate, "^(\\\\|/)") )
        candidate := A_ScriptDir "\\" candidate
      if (FileExist(candidate))
        initialDir := (InStr(FileExist(candidate), "D")) ? candidate : RegExReplace(candidate, "\\[^\\]*$")
    }

    selectedPath := FileSelect("1", initialDir, "Select file", filter)
    if (selectedPath = "")
      return ""
    if (InStr(StrLower(selectedPath), StrLower(A_ScriptDir "\\")) = 1)
      return SubStr(selectedPath, StrLen(A_ScriptDir) + 2)

    return selectedPath
  }

  _closeSettings() {
    if (this._settingsGui != 0) {
      nw := this._settingsGui
      this._isLogPageActive := false
      AKBase.SetLogPushHandler(0)
      this._hotkeyRecorder.StopRecording()
      this._resumeHotkeysAfterRecording()
      this._settingsGui := 0
      this._settingsOpenPage := ""
      this._settingsPageRequest := 0
      try nw.Destroy()
    }
  }

  _onSettingsClosed() {
    this._isLogPageActive := false
    AKBase.SetLogPushHandler(0)
    this._hotkeyRecorder.StopRecording()
    this._resumeHotkeysAfterRecording()
    this.outputDebugLine(AKApp.LOG_DEBUG, "Settings window closed", Map("source", "core"))
    this._settingsGui := 0
    this._settingsOpenPage := ""
    this._settingsPageRequest := 0
  }

  _suspendHotkeysForRecording() {
    if (A_IsSuspended)
      return
    Suspend(true)
    this._recordingSuspendedByRecorder := true
  }

  _resumeHotkeysAfterRecording() {
    if (!this._recordingSuspendedByRecorder)
      return
    Suspend(false)
    this._recordingSuspendedByRecorder := false
  }

  _applyUIScaling(percent) {
    if (this._settingsGui = 0)
      return
    scale := percent / 100
    js := "document.documentElement.style.setProperty('--ui-scale', '" scale "');"
    try this._settingsGui.ExecuteScriptAsync(js)
  }
}

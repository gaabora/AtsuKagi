class AKGui extends AKBase {
  static PREFERRED_APP_MODE := { Default: 0, AllowDark: 1, ForceDark: 2, ForceLight: 3, Max: 4 }
  static QUOTE_CHAR := Chr(34)
  _settingsGui := 0
  _isLogPageActive := false

  __New(App) {
    this.App := App
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
  ShowSettings() {
    ; If already open, just focus it
    if (this._settingsGui != 0) {
      try {
        WinActivate("ahk_id " this._settingsGui.hWnd)
        return
      } catch {
        this._settingsGui := 0
      }
    }

    webViewSettings := this._getWebViewSettings()
    nw := WebViewGui("+Resize -Caption",,, webViewSettings)
    nw.Title := this.App.ScriptName " — Settings"
    this._settingsGui := nw
    this._isLogPageActive := false
    AKBase.SetLogPushHandler(this._pushLogEntry.Bind(this))
    this.outputDebugLine("Settings window opened", 4, Map("source", "core"))

    ; Register JS → AHK callbacks
    nw.AddCallbackToScript("SaveSettingsJson", (wv, payload:="") => this._saveSettingsJson(payload))
    nw.AddCallbackToScript("SaveGeneralSetting", (wv, key:="", value:="") => this._saveGeneralSetting(key, value))
    nw.AddCallbackToScript("SavePluginSetting", (wv, pluginId:="", key:="", value:="") => this._savePluginSetting(pluginId, key, value))
    nw.AddCallbackToScript("SaveHotkey", (wv, index:=0, hotKey:="", action:="") => this._saveHotkey(index, hotKey, action))
    nw.AddCallbackToScript("RemoveHotkey", (wv, index:=0) => this._removeHotkey(index))
    nw.AddCallbackToScript("AddHotkey", (wv, hotKey:="", action:="") => this._addHotkey(hotKey, action))
    nw.AddCallbackToScript("TogglePlugin", (wv, pluginId:="", enabled:=1) => this._togglePlugin(pluginId, enabled))
    nw.AddCallbackToScript("SetLogPageActive", (wv, active:=0) => this._setLogPageActive(active))
    nw.AddCallbackToScript("GetLogsSince", (wv, lastId:=0) => AK_ToJson(AKBase.GetUiLogsSince(Integer(lastId))))
    nw.AddCallbackToScript("ClearLogs", (wv, *) => AKBase.ClearLogs())
    nw.AddCallbackToScript("CloseSettings", (wv, *) => this._closeSettings())
    nw.AddCallbackToScript("BrowseForFile", (wv, currentPath:="") => this._browseForFile(currentPath))
    nw.AddCallbackToScript("OpenDevTools", (wv, *) => this._openDevTools())

    ; Populate form after page finishes loading
    nw.DOMContentLoaded((ICoreWebView2, Args) => this._populateSettingsPage(nw))

    nw.OnEvent("Close", (*) => (this._isLogPageActive := false, AKBase.SetLogPushHandler(0), this.outputDebugLine("Settings window closed", 4, Map("source", "core")), this._settingsGui := 0))
    nw.Navigate("includes/ui/settings.html")
    nw.Show("w820 h560")
    if (this.App.Config.GENERAL.DebugLevel >= 4)
      this._openDevTools()
  }

  _getWebViewSettings() {
    settings := {DefaultWidth: 820, DefaultHeight: 560}
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
        "pages", this.App.GetPluginSettingsPages()
      ),
      "hotkeys", hotkeys,
      "logs", AKBase.GetUiLogs(),
      "theme", theme,
      "title", this.App.ScriptName " — Settings"
    )

    if (AKBase._hasBindingProblems) {
      state["openPage"] := "logs"
      state["logLevelFilter"] := [0, 1]
    }

    js := "(() => {`n"
    js .= "  const state = " . AK_ToJson(state) . ";`n"
    js .= "  if (window.SettingsPageBridge && typeof window.SettingsPageBridge.applyState === 'function') {`n"
    js .= "    try { window.SettingsPageBridge.applyState(state); } catch (error) { console.error('Failed to apply settings state', error); }`n"
    js .= "  }`n"
    js .= "})();`n"

    if (this.App.Config.GENERAL.DebugLevel >= 4)
      FileOpen(A_ScriptDir "\ak_settings_debug.js", "w", "UTF-8").Write(js)
    nw.ExecuteScriptAsync(js)
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

  _saveHotkey(index, hotKey, action) {
    return this.App.SaveHotkey(index, hotKey, action)
  }

  _removeHotkey(index) {
    return this.App.RemoveHotkey(index)
  }

  _addHotkey(hotKey, action) {
    return this.App.AddHotkey(hotKey, action)
  }

  _togglePlugin(pluginId, enabled) {
    return this.App.TogglePlugin(pluginId, enabled)
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
    js .= "    try { window.SettingsPageBridge.appendLogs(" AK_ToJson([entry]) "); } catch (error) { console.error('Failed to append pushed logs', error); }`n"
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
      this._settingsGui := 0
      try nw.Destroy()
    }
  }
}

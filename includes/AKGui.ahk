class AKGui extends AKBase {
  static PREFERRED_APP_MODE := { Default: 0, AllowDark: 1, ForceDark: 2, ForceLight: 3, Max: 4 }
  static QUOTE_CHAR := Chr(34)
  _settingsGui := 0

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

    ; Register JS → AHK callbacks
    nw.AddCallbackToScript("SaveSettings", (wv, generalEncoded:="", disabledPlugins:="", pluginConfigEncoded:="", hotkeysEncoded:="") => this._saveSettings(generalEncoded, disabledPlugins, pluginConfigEncoded, hotkeysEncoded))
    nw.AddCallbackToScript("CloseSettings", (wv, *) => this._closeSettings())
    nw.AddCallbackToScript("BrowseForFile", (wv, currentPath:="") => this._browseForFile(currentPath))
    nw.AddCallbackToScript("OpenDevTools", (wv, *) => this._openDevTools())

    ; Populate form after page finishes loading
    nw.DOMContentLoaded((ICoreWebView2, Args) => this._populateSettingsPage(nw))

    nw.OnEvent("Close", (*) => (this._settingsGui := 0))
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
      "logsText", AKBase.GetUiLogsText(),
      "problemsText", AKBase.GetUiProblemsText(),
      "theme", theme,
      "title", this.App.ScriptName " — Settings"
    )

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

  _saveSettings(generalEncoded, disabledPlugins, pluginConfigEncoded, hotkeysEncoded:="") {
    cfg := this.App.Config
    oldDisabledPlugins := cfg.GENERAL.DisabledPlugins

    this._applyEncodedGeneralConfig("" generalEncoded)
    cfg.GENERAL.DisabledPlugins := "" disabledPlugins
    this._applyEncodedPluginConfig("" pluginConfigEncoded)
    this._applyEncodedHotkeysConfig("" hotkeysEncoded)

    cfg.Save()
    this.App.ApplySettings(oldDisabledPlugins)
    if (this._settingsGui != 0) {
      this._populateSettingsPage(this._settingsGui)
    }
  }

  _applyEncodedHotkeysConfig(encoded) {
    if (Trim(encoded) = "")
      return

    if (!this.App.Config.Has("HOTKEYS"))
      this.App.Config.HOTKEYS := Map()

    parsed := Map()
    for line in StrSplit(encoded, "`n", "`r") {
      if (line = "")
        continue

      parts := StrSplit(line, "`t")
      if (parts.Length < 2)
        continue

      hk := this._decodeEscapedLinePart(parts[1])
      rawAction := ""
      for idx, part in parts {
        if (idx < 2)
          continue
        if (idx > 2)
          rawAction .= "`t"
        rawAction .= part
      }
      actionText := this._decodeEscapedLinePart(rawAction)

      hk := Trim(hk)
      actionText := Trim(actionText)
      if (!hk || !actionText)
        continue

      parsed[hk] := actionText
    }
    this.App.Config.HOTKEYS := parsed
  }

  _applyEncodedGeneralConfig(encoded) {
    if (Trim(encoded) = "")
      return

    cfg := this.App.Config
    if (!cfg.Has("GENERAL"))
      cfg.GENERAL := {}

    typeIndex := Map()
    for fieldDesc in this.App.GetGeneralConfigSchema() {
      if (!fieldDesc.Has("key"))
        continue
      fieldType := fieldDesc.Has("type") ? fieldDesc["type"] : "string"
      typeIndex[fieldDesc["key"]] := fieldType
    }

    for line in StrSplit(encoded, "`n", "`r") {
      if (line = "")
        continue

      parts := StrSplit(line, "`t")
      if (parts.Length < 2)
        continue

      key := this._decodeEscapedLinePart(parts[1])
      rawValue := ""
      for idx, part in parts {
        if (idx < 2)
          continue
        if (idx > 2)
          rawValue .= "`t"
        rawValue .= part
      }
      value := this._decodeEscapedLinePart(rawValue)

      if (!typeIndex.Has(key)) {
        this.outputDebugLine("Unknown [GENERAL] config key: " . key, 1)
        continue
      }

      valueType := typeIndex[key]
      if (valueType = "boolean") {
        cfg.GENERAL.%key% := (value = "1" || value = "true") ? 1 : 0
      } else if (valueType = "integer") {
        try cfg.GENERAL.%key% := Integer(value)
        catch {
          cfg.GENERAL.%key% := value
        }
      } else if (valueType = "number") {
        try cfg.GENERAL.%key% := Number(value)
        catch {
          cfg.GENERAL.%key% := value
        }
      } else {
        cfg.GENERAL.%key% := value
      }
    }
  }

  ; Parse UI plugin settings payload lines: pluginId`tkey`tvalue
  _applyEncodedPluginConfig(encoded) {
    if (Trim(encoded) = "")
      return

    ; Build type index from loaded plugin descriptors: pluginId -> key -> type
    typeIndex := Map()
    for className, libObj in this.App._addedLibs {
      descriptor := libObj.__GetPluginDescriptor()
      if (!descriptor || !descriptor.Has("plugin") || !descriptor["plugin"].Has("id"))
        continue

      pluginId := descriptor["plugin"]["id"]
      if (!typeIndex.Has(pluginId))
        typeIndex[pluginId] := Map()

      schema := libObj.__GetConfigSchema()
      for fieldDesc in schema {
        if (fieldDesc.Has("key")) {
          fieldType := fieldDesc.Has("type") ? fieldDesc["type"] : "string"
          typeIndex[pluginId][fieldDesc["key"]] := fieldType
        }
      }
    }

    for line in StrSplit(encoded, "`n", "`r") {
      if (line = "")
        continue
      parts := StrSplit(line, "`t")
      if (parts.Length < 3)
        continue

      pluginId := this._decodeEscapedLinePart(parts[1])
      key := this._decodeEscapedLinePart(parts[2])
      rawValue := ""
      for idx, part in parts {
        if (idx < 3)
          continue
        if (idx > 3)
          rawValue .= "`t"
        rawValue .= part
      }
      value := this._decodeEscapedLinePart(rawValue)

      if (!this.App.Config.Has(pluginId))
        this.App.Config[pluginId] := {}

      valueType := "string"
      if (typeIndex.Has(pluginId) && typeIndex[pluginId].Has(key))
        valueType := typeIndex[pluginId][key]

      if (valueType = "boolean") {
        this.App.Config[pluginId][key] := (value = "1" || value = "true") ? true : false
      } else if (valueType = "integer") {
        try this.App.Config[pluginId][key] := Integer(value)
        catch {
          this.App.Config[pluginId][key] := value
        }
      } else if (valueType = "number") {
        try this.App.Config[pluginId][key] := Number(value)
        catch {
          this.App.Config[pluginId][key] := value
        }
      } else {
        this.App.Config[pluginId][key] := value
      }
    }
  }

  _decodeEscapedLinePart(value) {
    text := "" value
    out := ""
    i := 1
    len := StrLen(text)
    while (i <= len) {
      ch := SubStr(text, i, 1)
      if (ch = "\\" && i < len) {
        nxt := SubStr(text, i + 1, 1)
        if (nxt = "n") {
          out .= "`n"
          i += 2
          continue
        }
        if (nxt = "r") {
          out .= "`r"
          i += 2
          continue
        }
        if (nxt = "t") {
          out .= "`t"
          i += 2
          continue
        }
        if (nxt = "\\") {
          out .= "\\"
          i += 2
          continue
        }
      }

      out .= ch
      i += 1
    }
    return out
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
      this._settingsGui := 0
      try nw.Destroy()
    }
  }
}

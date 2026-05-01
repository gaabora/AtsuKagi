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

  _wrapQuotes(text) {
    return AKGui.QUOTE_CHAR text AKGui.QUOTE_CHAR
  }
  _populateSettingsPage(nw) {
    cfg := this.App.Config

    ; Build a state object to pass to the page
    availablePlugins := this.App._getAvailablePlugins()
    disabledPlugins  := this.App._getDisabledPlugins()

    pluginList := []
    for pluginName in availablePlugins {
      pluginList.Push(pluginName)
    }

    generalPage := this.App.GetGeneralSettingsPage()

    logsText := WebViewCtrl.EscapeJavaScript(AKBase.GetUiLogsText())
    problemsText := WebViewCtrl.EscapeJavaScript(AKBase.GetUiProblemsText())
    title := WebViewCtrl.EscapeJavaScript(this.App.ScriptName " — Settings")

    theme := this.IsDarkTheme() ? "dark" : "light"

    ; Build JavaScript to populate page state
    js := "(() => {`n"
    js .= "  window.state = {`n"
    js .= "    generalPage: " this._AhkGeneralPageToJs(generalPage) ",`n"
    js .= "    plugins: {`n"
    js .= "      available: " this._AhkArrayToJs(pluginList) ",`n"
    js .= "      disabled: " this._AhkArrayToJs(disabledPlugins) ",`n"
    js .= "      pages: " this._AhkPluginPagesToJs(this.App.GetPluginSettingsPages()) "`n"
    js .= "    },`n"
    js .= "    hotkeys: " this._AhkHotkeysToJs(cfg.HOTKEYS) ",`n"
    js .= "    logsText: " this._wrapQuotes(logsText) ",`n"
    js .= "    problemsText: " this._wrapQuotes(problemsText) ",`n"
    js .= "    theme: " this._wrapQuotes(theme) ",`n"
    js .= "    title: " this._wrapQuotes(title) ",`n"
    js .= "  };`n"
    js .= "  if (window.SettingsPageBridge && typeof window.SettingsPageBridge.applyState === 'function') {`n"
    js .= "    try { window.SettingsPageBridge.applyState(window.state); } catch (error) { console.error('Failed to apply settings state', error); }`n"
    js .= "  }`n"
    js .= "})();`n"

    if (this.App.Config.GENERAL.DebugLevel >= 4)
      FileOpen(A_ScriptDir "\ak_settings_debug.js", "w", "UTF-8").Write(js)
    nw.ExecuteScriptAsync(js)
  }

  ; Convert general settings page descriptor to JavaScript
  _AhkGeneralPageToJs(page) {
    if (!IsObject(page))
      return "null"

    result := "{"
    result .= "id: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("id") ? page["id"] : "general")) ","
    result .= "title: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("title") ? page["title"] : "General")) ","
    result .= "description: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("description") ? page["description"] : "")) ","
    result .= "icon: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("icon") ? page["icon"] : "icons10-settings")) ","
    result .= "navOrder: " (page.Has("navOrder") ? page["navOrder"] : 0) ","
    result .= "enableDynamicRender: " (page.Has("enableDynamicRender") && page["enableDynamicRender"] ? "true" : "false") ","
    result .= "sections: " this._AhkPluginSectionsToJs(page.Has("sections") ? page["sections"] : []) ","
    result .= "actions: " this._AhkPluginActionsToJs(page.Has("actions") ? page["actions"] : [])
    result .= "}"
    return result
  }

  _AhkArrayToJs(arr) {
    result := ""
    for item in arr {
      result .= this._wrapQuotes(WebViewCtrl.EscapeJavaScript("" item)) ","
    }
    return "[" RTrim(result, ",") "]"
  }

  _AhkHotkeysToJs(hotkeys) {
    result := ""
    if (hotkeys) {
      for k, v in hotkeys {
        hotKey := WebViewCtrl.EscapeJavaScript(k)
        action := WebViewCtrl.EscapeJavaScript(v)
        result .= "{ hotKey: " this._wrapQuotes(hotKey) ", action: " this._wrapQuotes(action) " },"
      }
    }
    return "[" RTrim(result, ",") "]"
  }

  ; Convert plugin pages to JavaScript
  _AhkPluginPagesToJs(pages) {
    parts := ""
    for page in pages {
      item := "{"
      item .= "id: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("id") ? page["id"] : "")) ","
      item .= "title: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("title") ? page["title"] : "")) ","
      item .= "description: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("description") ? page["description"] : "")) ","
      item .= "icon: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(page.Has("icon") ? page["icon"] : "")) ","
      item .= "enabled: " (page.Has("enabled") && page["enabled"] ? "true" : "false") ","
      item .= "sections: " this._AhkPluginSectionsToJs(page.Has("sections") ? page["sections"] : []) ","
      item .= "actions: " this._AhkPluginActionsToJs(page.Has("actions") ? page["actions"] : [])
      item .= "}"
      parts .= item ","
    }
    return "[" RTrim(parts, ",") "]"
  }

  ; Convert plugin sections to JavaScript
  _AhkPluginSectionsToJs(sections) {
    parts := ""
    for section in sections {
      item := "{"
      item .= "id: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(section.Has("id") ? section["id"] : "")) ","
      item .= "title: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(section.Has("title") ? section["title"] : "")) ","
      item .= "fields: " this._AhkPluginFieldsToJs(section.Has("fields") ? section["fields"] : [])
      item .= "}"
      parts .= item ","
    }
    return "[" RTrim(parts, ",") "]"
  }

  ; Convert plugin fields to JavaScript
  _AhkPluginFieldsToJs(fields) {
    parts := ""
    for field in fields {
      item := "{"
      item .= "pluginId: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("pluginId") ? field["pluginId"] : "")) ","
      item .= "key: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("key") ? field["key"] : "")) ","
      item .= "label: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("label") ? field["label"] : "")) ","
      item .= "description: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("description") ? field["description"] : "")) ","
      item .= "type: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("type") ? field["type"] : "string")) ","
      item .= "control: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("control") ? field["control"] : "text")) ","
      item .= "default: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("default") ? field["default"] : "")) ","
      item .= "value: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("value") ? field["value"] : "")) ","
      item .= "scope: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(field.Has("scope") ? field["scope"] : "plugin")) ","
      item .= "validation: " this._AhkValidationToJs(field.Has("validation") ? field["validation"] : 0) ","
      item .= "options: " this._AhkFieldOptionsToJs(field.Has("options") ? field["options"] : [])
      item .= "}"
      parts .= item ","
    }
    return "[" RTrim(parts, ",") "]"
  }

  _AhkValidationToJs(validation) {
    if (!IsObject(validation))
      return "{}"
    parts := ""
    for key, value in validation {
      parts .= this._wrapQuotes(WebViewCtrl.EscapeJavaScript("" key)) ": " this._wrapQuotes(WebViewCtrl.EscapeJavaScript("" value)) ","
    }
    return "{" RTrim(parts, ",") "}"
  }

  _AhkFieldOptionsToJs(options) {
    parts := ""
    for opt in options {
      optValue := IsObject(opt) && opt.Has("value") ? opt["value"] : ""
      optLabel := IsObject(opt) && opt.Has("label") ? opt["label"] : optValue
      parts .= "{ value: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript("" optValue)) ", label: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript("" optLabel)) " },"
    }
    return "[" RTrim(parts, ",") "]"
  }

  ; Convert plugin actions to JavaScript
  _AhkPluginActionsToJs(actions) {
    parts := ""
    for action in actions {
      item := "{"
      item .= "action: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(action.Has("action") ? action["action"] : "")) ","
      item .= "label: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(action.Has("label") ? action["label"] : "")) ","
      item .= "description: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(action.Has("description") ? action["description"] : "")) ","
      item .= "category: " this._wrapQuotes(WebViewCtrl.EscapeJavaScript(action.Has("category") ? action["category"] : "")) ","
      item .= "hotkeys: " this._AhkArrayToJs(action.Has("hotkeys") ? action["hotkeys"] : [])
      item .= "}"
      parts .= item ","
    }
    return "[" RTrim(parts, ",") "]"
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

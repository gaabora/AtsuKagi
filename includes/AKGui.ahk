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

    ; Script mode fallback: use bundled library loader path.
    localDll := A_ScriptDir "\\lib\\WebViewToo-main\\Lib\\" dllRelPath
    if (FileExist(localDll)) {
      settings.DllPath := localDll
    }
    return settings
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

    ; Escape values for JavaScript
    welcomeMsg := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WelcomeMessage)
    darkTheme := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.DarkTheme)
    debugLevel := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.DebugLevel)
    tooltipMs := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.ToolTipTimeoutMs)
    transparency := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WindowTransparencyValue)
    borderColor := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WindowOnTopBorderColor)
    startupSound := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.StartupSound)
    notificationSound := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.NotificationSound)
    reloadHotkey := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.ReloadAppHotkey)
    suspendHotkey := WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.SuspendAppHotkey)
    swapXButtons := cfg.GENERAL.SwapMouseXButtons = 1 ? "true" : "false"

    logsText := WebViewCtrl.EscapeJavaScript(AKBase.GetUiLogsText())
    problemsText := WebViewCtrl.EscapeJavaScript(AKBase.GetUiProblemsText())
    title := WebViewCtrl.EscapeJavaScript(this.App.ScriptName " — Settings")

    theme := this.IsDarkTheme() ? "dark" : "light"

    ; Build JavaScript to populate page state
    js := "(() => {`n"
    js .= "  const state = {`n"
    js .= "    general: {`n"
    js .= "      WelcomeMessage: " AKGui.QUOTE_CHAR welcomeMsg AKGui.QUOTE_CHAR ",`n"
    js .= "      DarkTheme: " AKGui.QUOTE_CHAR darkTheme AKGui.QUOTE_CHAR ",`n"
    js .= "      DebugLevel: " AKGui.QUOTE_CHAR debugLevel AKGui.QUOTE_CHAR ",`n"
    js .= "      ToolTipTimeoutMs: " AKGui.QUOTE_CHAR tooltipMs AKGui.QUOTE_CHAR ",`n"
    js .= "      WindowTransparencyValue: " AKGui.QUOTE_CHAR transparency AKGui.QUOTE_CHAR ",`n"
    js .= "      WindowOnTopBorderColor: " AKGui.QUOTE_CHAR borderColor AKGui.QUOTE_CHAR ",`n"
    js .= "      StartupSound: " AKGui.QUOTE_CHAR startupSound AKGui.QUOTE_CHAR ",`n"
    js .= "      NotificationSound: " AKGui.QUOTE_CHAR notificationSound AKGui.QUOTE_CHAR ",`n"
    js .= "      ReloadAppHotkey: " AKGui.QUOTE_CHAR reloadHotkey AKGui.QUOTE_CHAR ",`n"
    js .= "      SuspendAppHotkey: " AKGui.QUOTE_CHAR suspendHotkey AKGui.QUOTE_CHAR ",`n"
    js .= "      SwapMouseXButtons: " swapXButtons "`n"
    js .= "    },`n"
    js .= "    plugins: {`n"
    js .= "      available: " this._AhkArrayToJs(pluginList) ",`n"
    js .= "      disabled: " this._AhkArrayToJs(disabledPlugins) ",`n"
    js .= "      pages: " this._AhkPluginPagesToJs(this.App.GetPluginSettingsPages()) "`n"
    js .= "    },`n"
    js .= "    hotkeys: " this._AhkHotkeysToJs(cfg.HOTKEYS) ",`n"
    js .= "    logsText: " AKGui.QUOTE_CHAR logsText AKGui.QUOTE_CHAR ",`n"
    js .= "    problemsText: " AKGui.QUOTE_CHAR problemsText AKGui.QUOTE_CHAR ",`n"
    js .= "    theme: " AKGui.QUOTE_CHAR theme AKGui.QUOTE_CHAR ",`n"
    js .= "    title: " AKGui.QUOTE_CHAR title AKGui.QUOTE_CHAR ",`n"
    js .= "  };`n"
    js .= "  if (window.SettingsPageBridge && typeof window.SettingsPageBridge.applyState === 'function') {`n"
    js .= "    window.SettingsPageBridge.applyState(state);`n"
    js .= "  }`n"
    js .= "})();`n"

    nw.ExecuteScriptAsync(js)
  }

  _AhkArrayToJs(arr) {
    result := "["
    first := true
    for item in arr {
      if (!first) result .= ","
      result .= AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript("" item) AKGui.QUOTE_CHAR
      first := false
    }
    result .= "]"
    return result
  }

  _AhkHotkeysToJs(hotkeys) {
    result := "["
    first := true
    if (hotkeys) {
      for k, v in hotkeys {
        if (!first) result .= ","
        hotKey := WebViewCtrl.EscapeJavaScript(k)
        action := WebViewCtrl.EscapeJavaScript(v)
        result .= "{ hotKey: " AKGui.QUOTE_CHAR hotKey AKGui.QUOTE_CHAR ", action: " AKGui.QUOTE_CHAR action AKGui.QUOTE_CHAR " }"
        first := false
      }
    }
    result .= "]"
    return result
  }

  ; Phase 1+: Convert plugin pages to JavaScript
  _AhkPluginPagesToJs(pages) {
    result := "["
    first := true
    
    for page in pages {
      if (!first) result .= ","
      first := false
      
      result .= "{"
      
      ; ID
      result .= "id: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(page.Has("id") ? page["id"] : "") AKGui.QUOTE_CHAR ","
      
      ; Title
      result .= "title: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(page.Has("title") ? page["title"] : "") AKGui.QUOTE_CHAR ","
      
      ; Description
      result .= "description: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(page.Has("description") ? page["description"] : "") AKGui.QUOTE_CHAR ","
      
      ; Icon
      result .= "icon: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(page.Has("icon") ? page["icon"] : "") AKGui.QUOTE_CHAR ","
      
      ; Enabled
      result .= "enabled: " (page.Has("enabled") && page["enabled"] ? "true" : "false") ","
      
      ; Sections (with fields)
      result .= "sections: " this._AhkPluginSectionsToJs(page.Has("sections") ? page["sections"] : []) ","
      
      ; Actions
      result .= "actions: " this._AhkPluginActionsToJs(page.Has("actions") ? page["actions"] : [])
      
      result .= "}"
    }
    
    result .= "]"
    return result
  }

  ; Convert plugin sections to JavaScript
  _AhkPluginSectionsToJs(sections) {
    result := "["
    first := true
    
    for section in sections {
      if (!first) result .= ","
      first := false
      
      result .= "{"
      result .= "id: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(section.Has("id") ? section["id"] : "") AKGui.QUOTE_CHAR ","
      result .= "title: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(section.Has("title") ? section["title"] : "") AKGui.QUOTE_CHAR ","
      result .= "fields: " this._AhkPluginFieldsToJs(section.Has("fields") ? section["fields"] : [])
      result .= "}"
    }
    
    result .= "]"
    return result
  }

  ; Convert plugin fields to JavaScript
  _AhkPluginFieldsToJs(fields) {
    result := "["
    first := true
    
    for field in fields {
      if (!first) result .= ","
      first := false
      
      result .= "{"
      result .= "pluginId: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("pluginId") ? field["pluginId"] : "") AKGui.QUOTE_CHAR ","
      result .= "key: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("key") ? field["key"] : "") AKGui.QUOTE_CHAR ","
      result .= "label: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("label") ? field["label"] : "") AKGui.QUOTE_CHAR ","
      result .= "description: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("description") ? field["description"] : "") AKGui.QUOTE_CHAR ","
      result .= "type: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("type") ? field["type"] : "string") AKGui.QUOTE_CHAR ","
      result .= "control: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("control") ? field["control"] : "text") AKGui.QUOTE_CHAR ","
      result .= "default: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript("" (field.Has("default") ? field["default"] : "")) AKGui.QUOTE_CHAR ","
      result .= "value: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript("" (field.Has("value") ? field["value"] : "")) AKGui.QUOTE_CHAR ","
      result .= "scope: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(field.Has("scope") ? field["scope"] : "plugin") AKGui.QUOTE_CHAR
      result .= "}"
    }
    
    result .= "]"
    return result
  }

  ; Convert plugin actions to JavaScript
  _AhkPluginActionsToJs(actions) {
    result := "["
    first := true
    
    for action in actions {
      if (!first) result .= ","
      first := false
      
      result .= "{"
      result .= "action: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(action.Has("action") ? action["action"] : "") AKGui.QUOTE_CHAR ","
      result .= "label: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(action.Has("label") ? action["label"] : "") AKGui.QUOTE_CHAR ","
      result .= "description: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(action.Has("description") ? action["description"] : "") AKGui.QUOTE_CHAR ","
      result .= "category: " AKGui.QUOTE_CHAR WebViewCtrl.EscapeJavaScript(action.Has("category") ? action["category"] : "") AKGui.QUOTE_CHAR ","
      result .= "hotkeys: " this._AhkArrayToJs(action.Has("hotkeys") ? action["hotkeys"] : [])
      result .= "}"
    }
    
    result .= "]"
    return result
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

      switch key {
        case "WelcomeMessage":
          cfg.GENERAL.WelcomeMessage := value
        case "DarkTheme":
          cfg.GENERAL.DarkTheme := value
        case "DebugLevel":
          cfg.GENERAL.DebugLevel := value
        case "ToolTipTimeoutMs":
          cfg.GENERAL.ToolTipTimeoutMs := value
        case "WindowTransparencyValue":
          cfg.GENERAL.WindowTransparencyValue := value
        case "WindowOnTopBorderColor":
          cfg.GENERAL.WindowOnTopBorderColor := value
        case "StartupSound":
          cfg.GENERAL.StartupSound := value
        case "NotificationSound":
          cfg.GENERAL.NotificationSound := value
        case "ReloadAppHotkey":
          cfg.GENERAL.ReloadAppHotkey := value
        case "SuspendAppHotkey":
          cfg.GENERAL.SuspendAppHotkey := value
        case "SwapMouseXButtons":
          cfg.GENERAL.SwapMouseXButtons := (value = "1" || value = "true") ? 1 : 0
        default:
          this.outputDebugLine("Unknown [GENERAL] config key: " . key, 1)
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

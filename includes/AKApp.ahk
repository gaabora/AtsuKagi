class AKApp extends AKBase {
  ; public (let's agree on PascalCase)
  AvailableActions := Map()
  ; AvailableHooks := Map() ; TODO: maybe implement when needed, currently unused
  ActionDeprecationMap := Map()  

  TrayIconDefault := A_ScriptDir "/assets/app.ico"
  TrayIconDisabled := A_ScriptDir "/assets/disabled.ico"
  HotkeyThrottlingTimeout := 50
  ScriptName := 'AKApp'
  DynamicPluginsAutogenFilePath := "dynamicPlugins.ahk"
  ; private (let's agree on _camelCase)
  _addedLibs := Map()
  _configFile := A_ScriptDir "\config.ini"
  _configFileDefault := A_ScriptDir "\config.ini"
  _assignedHotkeys := Map()
  _toolTipIdsArr := Map()
  _toolTipGuis := Map()
  _warnedDeprecatedActions := Map()
  _warnedActionCollisions := Map()
  _warnedActionNaming := Map()
  
  ; Plugin metadata registries
  _pluginRegistry := Map()        ; pluginId -> descriptor
  _actionRegistry := Map()        ; actionName -> actionDescriptor
  _pluginConfigRegistry := Map()  ; pluginId -> configSchema[]
  _generalTypeIndex := 0
  _pluginTypeIndex := 0

  __New(ConfigFile:=0) {
    this.ActionDeprecationMap["RemapTo"] := "RemapKeyTo"

    Loop 20 {
      this._toolTipIdsArr[A_Index] := 0
    }

    this._configFile := (ConfigFile=0) ? this._configFileDefault : ConfigFile
    this.ScriptName := SubStr(A_ScriptName, 1, -4)

    this._initConfig(this._configFile)
    
    this._initGUI()
    this._initPlugins()
    this._initTrayMenu()
    ; this._initLaunchMenu()

    this._bindControlHotkeys()

    ; #HotkeyInterval this.Config.GENERAL.HotkeyInterval
    ; #MaxHotkeysPerInterval this.Config.GENERAL.MaxHotkeysPerInterval

    this._setTimer("_toolTipOff", 100)
  }

  _validateHotkeysConfig() {
    problems := []
    seenHotkeys := Map()
    if (!this.Config.Has("HOTKEYS"))
      return problems

    for hotkey, actionText in this.Config.HOTKEYS {
      if (Trim(hotkey) = "") {
        problems.Push("[HOTKEYS] empty hotkey key for action '" actionText "'")
        continue
      }

      actionInfo := this._parseActionInfo(actionText)
      if (actionInfo.fnName = "") {
        problems.Push("[HOTKEYS] '" hotkey "' has empty action")
        continue
      }

      if (this._getActionHandler(actionInfo.fnName) = -1)
        problems.Push("[HOTKEYS] '" hotkey "' references unknown action '" actionInfo.fnName "'")

      universalHotkey := convertToUniversalVkHotkey(hotkey)
      if (seenHotkeys.Has(universalHotkey)) {
        problems.Push("[HOTKEYS] duplicate hotkey mapping for '" hotkey "' and '" seenHotkeys[universalHotkey] "' (resolved to " universalHotkey ")")
      } else {
        seenHotkeys[universalHotkey] := hotkey
      }
    }
    return problems
  }

  _updateStartupDiagnostics() {
    pluginsCount := this._addedLibs.Count
    actionsCount := this.AvailableActions.Count
    hotkeysCount := this._assignedHotkeys.Count
    this.outputDebugLine(AKApp.LOG_DEBUG, "Startup diagnostics: plugins=" pluginsCount ", actions=" actionsCount ", hotkeys=" hotkeysCount)
  }

  TestActions() {
    total := this.AvailableActions.Count
    current := 0
    for key, action in this.AvailableActions {
      current += 1
      handlerFn := action['handlerFn']
      Loop {
        Result := MsgBox("[" current "/" total "]`nTesting " action['className'] ' ' action['description'] '. Press "Retry" to run the action.',, "AbortRetryIgnore")
        if Result = "Abort"
          break 2
        if Result = "Retry"
          this.outputDebugLine(AKApp.LOG_DEBUG, 'OUTPUT: ' handlerFn() ' from ' action['className'] ' ' action['description'])
        if Result = "Ignore"
          break
      }
    }
  }

  ; helpText := "Enabled hotkeys:`n"

  ;   usedActions := Map()
  ;   for key, action in this.AvailableActions {
  ;     functionName := this._parseActionInfo(action['description']).fnName
  ;     usedActions[functionName] := Map(
  ;       'className', action['className'],
  ;       'description', action['description'],
  ;       'assignedHotkeys', [],
  ;     )
  ;   }

  ;   for key, hkDef in this._assignedHotkeys {
  ;     functionName := functionName := this._parseActionInfo(hkDef['action']).fnName
  ;     if (usedActions.Has(functionName)) {
  ;       usedActions[functionName]['assignedHotkeys'].Push([hkDef['readable']])
  ;     } else {
  ;       this.outputDebugLine(AKApp.LOG_WARNING, hkDef['action'] ' was not found')
  ;     }
  ;     helpText .= hkDef['readable'] ' (' hkDef['original'] ') ' hkDef['action'] '`n'
  ;   }
    
  ;   helpText .= "`nNot used actions:`n"
  ;   for functionName, usedAction in usedActions {
  ;     if (usedAction['assignedHotkeys'].Length = 0) {
  ;       helpText .= usedAction['className'] '.' usedAction['description'] '`n'
  ;     }
  ;   }

  _initPlugins() {
    availablePlugins := this._getAvailablePlugins()
    disabledPlugins := this._getDisabledPlugins()
    dynamicPlugins := this._getDynamicallyEnabledPlugins()
    
    requiredPlugins := []
    for plugin in availablePlugins {
      if (!ArrayContains(disabledPlugins, plugin)) {
        requiredPlugins.Push(plugin)
      }
    }

    if (Join(requiredPlugins, ',') != Join(dynamicPlugins, ',')) {
      this._generateDynamicPlugins(requiredPlugins)
      this.ReloadApp()
    }
  }
  _getAvailablePlugins() {
    plugins := []
    Loop Files, "./plugins/*.ahk" {
      pluginName := RegExReplace(A_LoopFileName, "\.ahk$")
      plugins.Push(pluginName)
    }
    return plugins
  }
  _getDisabledPlugins() {
    return StrSplit(this.Config.GENERAL.DisabledPlugins, ",", " ")
  }
  _getDynamicallyEnabledPlugins() {
    plugins := []
    if FileExist(this.DynamicPluginsAutogenFilePath) {
      for line in StrSplit(FileRead(this.DynamicPluginsAutogenFilePath), "`n", " ") {
        if RegExMatch(line, "APP\.AddPlugin\('([^']+)'.*?\)", &match) {
          plugins.Push(match[1])
        }
      }
    }
    return plugins
  }
  _generateDynamicPlugins(pluginsArray) {
    outputFile := this.DynamicPluginsAutogenFilePath

    fileContent := "; this file is autogenerated on launch`n"
    for pluginName in pluginsArray {
      fileContent .= "if FileExist('plugins/" pluginName ".ahk') {`n  #Include plugins/" pluginName ".ahk`n  APP.AddPlugin('" pluginName "', " this.debugLevel ")`n}`n"
    }
    FileDelete(outputFile)
    FileAppend(fileContent, outputFile)
  }

  ; ── General Settings Metadata Helpers ─────────────────────────────────────────
  ; Descriptor-style source of truth (mirrors plugin __DescribePlugin() pattern)
  __DescribeGeneralSettings() {
    return Map(
      "page", Map(
        "id", "general",
        "title", "General",
        "description", "Core application settings",
        "icon", "icons10-settings",
        "navOrder", 0,
        "enableDynamicRender", true
      ),
      "fields", [
        Map("key", "WelcomeMessage", "label", "Welcome Message", "description", "Message shown on app startup", "type", "string", "control", "text", "default", "Haribol!", "section", "General"),
        Map("key", "DarkTheme", "label", "Theme", "description", "", "type", "integer", "control", "select", "default", -1, "section", "General", "options", [Map("value", -1, "label", "Auto (follow system)"), Map("value", 0, "label", "Light"), Map("value", 1, "label", "Dark")]),
        Map("key", "UIScalingPercent", "label", "UI Scale", "description", "Scale the settings UI display", "type", "integer", "control", "select", "default", 75, "section", "General", "options", [
          Map("value", 75, "label", "75%"),
          Map("value", 80, "label", "80%"),
          Map("value", 85, "label", "85%"),
          Map("value", 90, "label", "90%"),
          Map("value", 95, "label", "95%"),
          Map("value", 100, "label", "100%"),
          Map("value", 110, "label", "110%"),
          Map("value", 125, "label", "125%"),
          Map("value", 150, "label", "150%"),
        ]),
        Map("key", "DebugLevel", "label", "Debug Level", "description", "0 = Error .. 5 = Trace", "type", "integer", "control", "select", "default", A_IsCompiled ? 0 : 5, "section", "General", "options", [
          Map("value", 0, "label", "0 - Error"),
          Map("value", 1, "label", "1 - Warning"),
          Map("value", 2, "label", "2 - Notice"),
          Map("value", 3, "label", "3 - Info"),
          Map("value", 4, "label", "4 - Debug"),
          Map("value", 5, "label", "5 - Trace")
        ]),
        Map("key", "ToolTipTimeoutMs", "label", "Tooltip Timeout (ms)", "description", "Timeout for tooltip auto-hide", "type", "integer", "control", "range", "default", 1000, "section", "General", "validation", Map("min", 100, "max", 10000, "step", 100)),
        Map("key", "StartupSound", "label", "Startup Sound", "description", "Sound file played when app starts", "type", "path", "control", "path", "default", "Assets/mixkit-light-button-2580.wav", "section", "Sounds"),
        Map("key", "NotificationSound", "label", "Notification Sound", "description", "Sound file used for notifications", "type", "path", "control", "path", "default", "Assets/mixkit-light-button-2580.wav", "section", "Sounds"),
        Map("key", "ReloadAppHotkey", "label", "Reload App", "description", "Global hotkey to reload the app", "type", "hotkey", "control", "hotkey", "default", "^#!Backspace", "section", "App Hotkeys"),
        Map("key", "SuspendAppHotkey", "label", "Suspend App", "description", "Global hotkey to suspend the app", "type", "hotkey", "control", "hotkey", "default", "^#!Esc", "section", "App Hotkeys"),
        Map("key", "SwapMouseXButtons", "label", "Swap Mouse XButtons", "description", "Swap XButton1 and XButton2 behavior", "type", "boolean", "control", "switch", "default", 0, "section", "Misc")
      ]
    )
  }

  GetGeneralConfigSchema() {
    descriptor := this.__DescribeGeneralSettings()
    return descriptor.Has("fields") ? descriptor["fields"] : []
  }

  GetGeneralConfigValues() {
    cfg := this.Config.Has("GENERAL") ? this.Config.GENERAL : Map()
    schema := this.GetGeneralConfigSchema()
    values := []

    for fieldDesc in schema {
      field := Map()
      for k, v in fieldDesc {
        field[k] := v
      }

      key := field.Has("key") ? field["key"] : ""
      if (key && cfg.Has(key)) {
        field["value"] := cfg[key]
      } else if (field.Has("default")) {
        field["value"] := field["default"]
      } else {
        field["value"] := ""
      }

      if (!field.Has("scope"))
        field["scope"] := "general"
      if (!field.Has("pluginId"))
        field["pluginId"] := "GENERAL"

      values.Push(field)
    }

    return values
  }

  GetGeneralSettingsPage() {
    descriptor := this.__DescribeGeneralSettings()
    pageDesc := descriptor.Has("page") ? descriptor["page"] : Map()

    page := Map(
      "id", pageDesc.Has("id") ? pageDesc["id"] : "general",
      "title", pageDesc.Has("title") ? pageDesc["title"] : "General",
      "description", pageDesc.Has("description") ? pageDesc["description"] : "",
      "icon", pageDesc.Has("icon") ? pageDesc["icon"] : "icons10-settings",
      "navOrder", pageDesc.Has("navOrder") ? pageDesc["navOrder"] : 0,
      "enableDynamicRender", pageDesc.Has("enableDynamicRender") ? pageDesc["enableDynamicRender"] : false,
      "enabled", true,
      "sections", this._buildGeneralSections(this.GetGeneralConfigValues()),
      "actions", []
    )

    return page
  }

  _buildGeneralSections(fields) {
    sections := []
    sectionMap := Map()
    sectionOrder := []

    for field in fields {
      sectionId := field.Has("section") ? field["section"] : "General"
      if (!sectionMap.Has(sectionId)) {
        sectionMap[sectionId] := []
        sectionOrder.Push(sectionId)
      }
      sectionMap[sectionId].Push(field)
    }

    for sectionId in sectionOrder {
      sections.Push(Map(
        "id", sectionId,
        "title", sectionId,
        "fields", sectionMap[sectionId]
      ))
    }

    return sections
  }

  ; ── Plugin Settings Metadata Helpers ───────────────────────────────────────────
  ; Get all plugin pages (descriptors with settings pages) for the UI
  GetPluginSettingsPages() {
    pages := []
    disabledPlugins := this._getDisabledPlugins()
    
    for pluginId, descriptor in this._pluginRegistry {
      if (!descriptor.Has("page"))
        continue
      
      settingsPage := descriptor["page"]
      if (settingsPage.Has("hidden") && settingsPage["hidden"])
        continue
      
      ; Determine if plugin is enabled (match by ID or class name)
      isEnabled := true
      for disabledName in disabledPlugins {
        if (disabledName = pluginId) {
          isEnabled := false
          break
        }
      }
      
      ; Build page model
      page := Map(
        "id", pluginId,
        "enabled", isEnabled
      )
      
      if (descriptor.Has("plugin")) {
        pluginDesc := descriptor["plugin"]
        if (pluginDesc.Has("title"))
          page["title"] := pluginDesc["title"]
        if (pluginDesc.Has("description"))
          page["description"] := pluginDesc["description"]
        if (pluginDesc.Has("icon"))
          page["icon"] := pluginDesc["icon"]
      }
      
      if (settingsPage.Has("description"))
        page["description"] := settingsPage["description"]
      if (settingsPage.Has("icon"))
        page["icon"] := settingsPage["icon"]
      if (settingsPage.Has("navOrder"))
        page["navOrder"] := settingsPage["navOrder"]
      else
        page["navOrder"] := 100
      
      ; Add current config values and schema
      page["sections"] := this._buildPluginSections(pluginId, descriptor)
      page["actions"] := this._buildPluginActions(pluginId, descriptor)
      
      pages.Push(page)
    }
    return pages
  }

  ; Build sections for a plugin settings page
  _buildPluginSections(pluginId, descriptor) {
    sections := []
    configSchema := descriptor.Has("config") ? descriptor["config"] : []
    sectionMap := Map() ; group fields by section
    
    ; Find the plugin instance (use className which may differ from pluginId)
    pluginInstance := 0
    for className, instance in this._addedLibs {
      if (instance.__GetPluginDescriptor().Has("plugin") && instance.__GetPluginDescriptor()["plugin"].Has("id")) {
        if (instance.__GetPluginDescriptor()["plugin"]["id"] = pluginId) {
          pluginInstance := instance
          break
        }
      }
    }
    
    for fieldDesc in configSchema {
      if (!fieldDesc.Has("section"))
        continue
      
      sectionId := fieldDesc["section"]
      if (!sectionMap.Has(sectionId)) {
        sectionMap[sectionId] := []
      }
      sectionMap[sectionId].Push(fieldDesc)
    }
    
    ; Convert to array of sections
    for sectionId, fields in sectionMap {
      section := Map(
        "id", sectionId,
        "title", sectionId,
        "fields", []
      )
      
      for fieldDesc in fields {
        fieldKey := fieldDesc.Has("key") ? fieldDesc["key"] : ""
        currentValue := fieldKey && IsObject(pluginInstance) ? 
                        (pluginInstance.Config.Has(fieldKey) ? pluginInstance.Config[fieldKey] : "") : ""
        fieldType := fieldDesc.Has("type") ? fieldDesc["type"] : "string"
        fieldControl := fieldDesc.Has("control") ? fieldDesc["control"] : ""
        if (fieldControl = "") {
          if (fieldType = "boolean")
            fieldControl := "switch"
          else if (fieldType = "integer" || fieldType = "number")
            fieldControl := "number"
          else if (fieldType = "hotkey")
            fieldControl := "hotkey"
          else if (fieldType = "color")
            fieldControl := "color"
          else
            fieldControl := "text"
        }
        
        field := Map(
          "pluginId", pluginId,
          "key", fieldKey,
          "label", fieldDesc.Has("label") ? fieldDesc["label"] : fieldKey,
          "description", fieldDesc.Has("description") ? fieldDesc["description"] : "",
          "type", fieldType,
          "control", fieldControl,
          "default", fieldDesc.Has("default") ? fieldDesc["default"] : "",
          "value", currentValue,
          "scope", fieldDesc.Has("scope") ? fieldDesc["scope"] : "plugin",
          "validation", fieldDesc.Has("validation") ? fieldDesc["validation"] : {},
          "options", fieldDesc.Has("options") ? fieldDesc["options"] : []
        )
        section["fields"].Push(field)
      }
      
      sections.Push(section)
    }
    
    return sections
  }

  ; Build actions list for a plugin settings page
  _buildPluginActions(pluginId, descriptor) {
    actions := []
    actionDefs := descriptor.Has("actions") ? descriptor["actions"] : []
    hotkeysCfg := this.Config.Has("HOTKEYS") ? this.Config.HOTKEYS : 0
    
    for actionDesc in actionDefs {
      actionName := actionDesc.Has("action") ? actionDesc["action"] : ""
      assignedHotkeys := []
      if (hotkeysCfg) {
        for hk, actionText in hotkeysCfg {
          info := this._parseActionInfo(actionText)
          if (info.fnName = actionName)
            assignedHotkeys.Push(convertToReadableHotkey(hk))
        }
      }

      action := Map(
        "action", actionName,
        "label", actionDesc.Has("label") ? actionDesc["label"] : "",
        "description", actionDesc.Has("description") ? actionDesc["description"] : "",
        "category", actionDesc.Has("category") ? actionDesc["category"] : "",
        "hotkeys", assignedHotkeys
      )
      
      if (action["action"]) {
        actions.Push(action)
      }
    }
    
    return actions
  }

  AddPlugin(className, debug:=0) {
    libObj := %className%(this)
    if (!IsObject(libObj)) {
      this.outputDebugLine(AKApp.LOG_ERROR, "Plugin failed to load: " className " - unable to create instance", Map("source", className, "settingRef", Map("page", "plugins")))
      this.ShowWarning("AddPlugin ERROR: Unable to create instance of " className)
      return
    }
    libObj.Debug(debug)
    libObj._processPluginConfig()
    libObj._init()
    this._addedLibs[className] := libObj
    
    ; Register plugin descriptor metadata
    descriptor := libObj.__GetPluginDescriptor()
    if (descriptor && descriptor.Count > 0) {
      pluginId := descriptor.Has("plugin") && descriptor["plugin"].Has("id") ? descriptor["plugin"]["id"] : className
      this._pluginRegistry[pluginId] := descriptor
      
      ; Register actions from descriptor
      actionDefs := libObj.__GetActionDefinitions()
      for actionDesc in actionDefs {
        if (actionDesc.Has("action")) {
          actionName := actionDesc["action"]
          this._actionRegistry[actionName] := actionDesc
        }
      }
      
      ; Register config schema
      configSchema := libObj.__GetConfigSchema()
      if (configSchema.Length > 0) {
        this._pluginConfigRegistry[pluginId] := configSchema
      }
    }

    actions := libObj.__ActionsHelp()
    for actionString, description in actions {
      this._registerAction(libObj, actionString, className, description)
    }
    this.outputDebugLine(AKApp.LOG_INFO, "Plugin loaded: " className, Map("source", className, "settingRef", Map("page", "plugins")))
  }
  
  BindAllHotkeys() {
    runHotkeyActionFn := this._runHotkeyAction.bind(this)
    AKBase.ClearProblems()

    configProblems := this._validateHotkeysConfig()
    AKBase._hasBindingProblems := (configProblems.Length > 0)
    for problem in configProblems {
      this.outputDebugLine(AKApp.LOG_WARNING, problem, Map("source", "hotkeys", "settingRef", Map("page", "hotkeys")))
    }
    if (configProblems.Length > 0) {
      this.outputDebugLine(AKApp.LOG_ERROR, "Hotkey binding validation found " configProblems.Length " problem(s)", Map("source", "hotkeys", "settingRef", Map("page", "hotkeys")))
    }

    if (this.Config.Has("HOTKEYS")) {
      For k, v In this.Config.HOTKEYS {
        this.BindHotkey(k, runHotkeyActionFn, v)
      }
    }
    if (configProblems.Length = 0)
      this.outputDebugLine(AKApp.LOG_INFO, "Hotkey binding validation passed", Map("source", "hotkeys"))
    this._updateStartupDiagnostics()
  }

  UnbindAllHotkeys() {
    for hotkey, hkDef in this._assignedHotkeys {
      try Hotkey(hotkey, "Off")
    }
    this._assignedHotkeys := Map()
  }

  RebindAllHotkeys() {
    this.UnbindAllHotkeys()
    this._bindControlHotkeys()
    this.BindAllHotkeys()
  }

  ApplySettings(oldDisabledPlugins := "") {
    debugLevel := Integer(this.Config.GENERAL.DebugLevel)
    this.Debug(debugLevel)

    for className, libObj in this._addedLibs {
      libObj.Debug(debugLevel)
    }

    this.RebindAllHotkeys()
    this._initTrayMenu()
    this.GUI.ApplyThemeMode()

    if (oldDisabledPlugins != this.Config.GENERAL.DisabledPlugins) {
      availablePlugins := this._getAvailablePlugins()
      disabledPlugins := this._getDisabledPlugins()
      requiredPlugins := []
      for plugin in availablePlugins {
        if (!ArrayContains(disabledPlugins, plugin)) {
          requiredPlugins.Push(plugin)
        }
      }
      this._generateDynamicPlugins(requiredPlugins)
      this.ShowNotice("Plugin enable or disable changes were saved and will apply on next reload", "Settings")
      return
    }

    this.ShowInfo("Settings saved")
  }

  ReloadApp(some*) {
    this.ShowInfo("Reloading " this.ScriptName " ...")
    sleep 1000
    Reload
    return
  }

  ToggleAppSuspend(some*) {
    Suspend
    this.UpdateAppSuspendedStatus()
  }

  UpdateAppSuspendedStatus() {
    Tray:= A_TrayMenu
    if (A_IsSuspended) {
      
      TraySetIcon(this.TrayIconDisabled, 1, true)
      Tray.Check("Disable")
      this.ShowInfo(this.ScriptName " DISABLED")
    } else {
      TraySetIcon(this.TrayIconDefault, 1, false)
      Tray.Uncheck("Disable")
      this.ShowInfo(this.ScriptName " ENABLED")
    }
    return
  }

  SoundPlay(fileName) {
    SoundPlay(fileName)
  }

  ToolTip(text, x:=-1, y:=-1, msec:=1000, forceIdx:=0) {
    idx := (forceIdx = 0) ? this._getFreeTooltipId() : forceIdx

    if (text = "") {
      this._hideToolTip(idx)
      return idx
    }

    this._normalizeToolTipPosition(&x, &y)

    state := this._toolTipGuis.Has(idx) ? this._toolTipGuis[idx] : false
    if (!IsObject(state) || state.text != text) {
      this._destroyToolTip(idx)
      tipGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
      tipGui.BackColor := "1A1A2E"
      tipGui.MarginX := 12
      tipGui.MarginY := 8
      tipGui.SetFont("s10 cE0E0E0", "Segoe UI")

      textOptions := "Center"
      for line in StrSplit(text, "`n") {
        if (StrLen(line) > 60) {
          textOptions .= " w360"
          break
        }
      }
      tipGui.Add("Text", textOptions, text)
      tipGui.Show("AutoSize Hide NoActivate")
      WinSetTransparent(235, "ahk_id " tipGui.Hwnd)
      tipGui.GetPos(,, &tipWidth, &tipHeight)
      try WinSetRegion("0-0 W" tipWidth " H" tipHeight " R8-8", "ahk_id " tipGui.Hwnd)
      state := {
        gui: tipGui,
        text: text,
        width: tipWidth,
        height: tipHeight
      }
      this._toolTipGuis[idx] := state
    }

    this._clampToolTipPosition(&x, &y, state.width, state.height)
    state.gui.Show("x" Round(x) " y" Round(y) " NoActivate")
    expireTime := A_TickCount + msec
    this._toolTipIdsArr[idx] := expireTime
    return idx
  }

  BindHotkey(KeyCombination, HandlerFn, ActionName:='', Options:='On') {
    handlerFnType := Type(HandlerFn)
    if (handlerFnType != 'BoundFunc')
      throw TypeError("HandlerFn parameter must be of type BoundFunc, but got " . handlerFnType)

    actionInfo := this._parseActionInfo(ActionName)
   
    hkDef := Map()
    hkDef['original'] := KeyCombination
    hkDef['universal'] := convertToUniversalVkHotkey(KeyCombination)
    hkDef['readable'] := convertToReadableHotkey(KeyCombination)
    hkDef['action'] := ActionName
    hkDef['handler'] := this._getActionHandler(actionInfo.fnName)
    hkDef['params'] := actionInfo.params

    universalHotkey := (KeyCombination = hkDef['universal']) ? '' : ' (' hkDef['universal'] ')'
    debugText := 'BindHotkey ' KeyCombination . universalHotkey ' [ ' hkDef['readable'] ' ] ' hkDef['action']

    if (hkDef['action'] != '' && !this._actionExists(actionInfo.fnName)) {
      hotkeyError := 'Action not found'
      errorText := 'ERROR: ' . debugText . ' FAILED: ' . hotkeyError
      this.outputDebugLine(AKApp.LOG_ERROR, errorText, Map("source", "hotkeys", "settingRef", Map("page", "hotkeys")))
      return errorText
    } 

    try
      Hotkey(hkDef['universal'], HandlerFn, Options)
    catch Error as err {
      hotkeyError := Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
        , type(err), err.Message, err.File, err.Line, err.What, err.Stack)
      errorText := "ERROR: " . debugText . " FAILED: " . hotkeyError
      this.outputDebugLine(AKApp.LOG_ERROR, errorText, Map("source", "hotkeys", "settingRef", Map("page", "hotkeys")))
      return errorText
    }

    this._assignedHotkeys[hkDef['universal']] := hkDef
    this.outputDebugLine(AKApp.LOG_DEBUG, debugText " OK")
    return 0
  }

  RunAction(ActionString) {
    actionInfo := this._parseActionInfo(ActionString)
    actionHandler := this._getActionHandler(actionInfo.fnName)
    return this._callActionHandler(actionHandler, actionInfo.params, ActionString, this._getCurrentHotkeyLabel())
  }

  IsWindowBlocklisted(hwnd:=0, method:='') {
    windowClass := GetWindowClass(hwnd)
    
    ; Check named blocklist if method maps to one
    if (RegExMatch(method, '(\w+)\.\w+\.(\S+)', &match)) {
      actionName := match[1]
    }

    ; Check the legacy global blocklist
    isBlocklisted := (InStr(this.Config.GENERAL.BlocklistGlobalWindowClasses, windowClass, false) != 0)

    ; Also check the named "Global" blocklist
    if (!isBlocklisted)
      isBlocklisted := this.IsInBlocklist('Global', hwnd)

    this.outputDebugLine(AKApp.LOG_DEBUG, ((isBlocklisted) ? "BLACKLISTED " : "OK ") '' windowClass " hwnd=" hwnd)
    return isBlocklisted
  }

  ; Check if a window matches any pattern in a named blocklist.
  ; Blocklists are defined in [BLACKLISTS] config section.
  ; Pattern formats: "ClassName", "class:ClassName", "exe:Process.exe", "path:substring"
  IsInBlocklist(blocklistName, hwnd:=0) {
    if (hwnd = 0)
      MouseGetPos(,, &hwnd)
    if (!this.Config.Has('BLACKLISTS') || !this.Config.BLACKLISTS.Has(blocklistName))
      return false
    
    blocklistValue := this.Config.BLACKLISTS.%blocklistName%
    if (blocklistValue = '')
      return false

    entries := StrSplit(blocklistValue, ',', ' `t')
    windowClass := ''
    processName := ''
    processPath := ''

    for entry in entries {
      if (entry = '')
        continue

      if (RegExMatch(entry, '^exe:(.+)', &m)) {
        ; Match by process executable name
        if (processName = '')
          processName := GetWindowProcessName(hwnd)
        if (processName != '' && (processName = m[1]))
          return true
      } else if (RegExMatch(entry, '^path:(.+)', &m)) {
        ; Match by process path substring
        if (processPath = '')
          processPath := GetWindowProcessPath(hwnd)
        if (processPath != '' && InStr(processPath, m[1], false))
          return true
      } else {
        ; Match by window class (with optional "class:" prefix)
        matchValue := RegExMatch(entry, '^class:(.+)', &m) ? m[1] : entry
        if (windowClass = '')
          windowClass := GetWindowClass(hwnd)
        if (windowClass = matchValue)
          return true
      }
    }
    return false
  }


  _setTimer(method, period) {
    fn := this.%method%.bind(this)
    SetTimer(fn,period)
    return &fn ; TODO: make fns to delete timers
  }

  _toolTipOff() {
    for idx, val in this._toolTipIdsArr {
      if (val > 0 && A_TickCount >= val) {
        this._hideToolTip(idx)
      }
    }
  }

  _hideToolTip(idx) {
    if (this._toolTipGuis.Has(idx))
      try this._toolTipGuis[idx].gui.Hide()
    this._toolTipIdsArr[idx] := 0
  }

  _destroyToolTip(idx) {
    if (this._toolTipGuis.Has(idx)) {
      try this._toolTipGuis[idx].gui.Destroy()
      this._toolTipGuis.Delete(idx)
    }
    this._toolTipIdsArr[idx] := 0
  }

  _clampToolTipPosition(&x, &y, width, height) {
    monitorIndex := MonitorGetPrimary()
    Loop MonitorGetCount() {
      MonitorGet(A_Index, &left, &top, &right, &bottom)
      if (x >= left && x < right && y >= top && y < bottom) {
        monitorIndex := A_Index
        break
      }
    }

    MonitorGetWorkArea(monitorIndex, &left, &top, &right, &bottom)
    x := Max(left, Min(x, right - width))
    y := Max(top, Min(y, bottom - height))
  }

  _normalizeToolTipPosition(&x, &y) {
    if (x = -1 || y = -1) {
      point := Buffer(8, 0)
      DllCall("GetCursorPos", "Ptr", point.Ptr)
      if (x = -1)
        x := NumGet(point, 0, "Int") + 16
      if (y = -1)
        y := NumGet(point, 4, "Int") + 16
      return
    }

    activeHwnd := WinExist("A")
    if (!activeHwnd || A_CoordModeToolTip = "Screen")
      return

    if (A_CoordModeToolTip = "Client") {
      point := Buffer(8, 0)
      NumPut("Int", x, "Int", y, point)
      if (DllCall("ClientToScreen", "Ptr", activeHwnd, "Ptr", point.Ptr)) {
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int")
      }
      return
    }

    if (A_CoordModeToolTip = "Window") {
      WinGetPos(&windowX, &windowY,,, "ahk_id " activeHwnd)
      x += windowX
      y += windowY
    }
  }

  _getFreeTooltipId() {
    closestIdx := 1
    closestVal := A_TickCount + 10000
    for idx, val in this._toolTipIdsArr {
      if val = 0
        return idx
      if (closestVal > val) {
        closestVal := val
        closestIdx := idx
      }
    }
    return closestIdx
  }

  _initGUI() {
    this.GUI :=  AKGui(this)
    if (this.Config.GENERAL.DebugLevel >= 4)
      this.GUI.ShowSettings()
  }

  _unbindAssignedHotkeyByAction(actionName) {
    target := Trim("" actionName)
    if (target = "")
      return

    toDelete := []
    for hotkey, hkDef in this._assignedHotkeys {
      if (!IsObject(hkDef) || !hkDef.Has("action"))
        continue
      if ("" hkDef["action"] != target)
        continue
      try Hotkey(hotkey, "Off")
      toDelete.Push(hotkey)
    }

    for hotkey in toDelete {
      if (this._assignedHotkeys.Has(hotkey))
        this._assignedHotkeys.Delete(hotkey)
    }
  }

  _rebindControlHotkeys() {
    this._unbindAssignedHotkeyByAction("ReloadApp")
    this._unbindAssignedHotkeyByAction("ToggleAppSuspend")
    this._bindControlHotkeys()
  }

  _bindControlHotkeys() {
    actionName := 'ReloadApp'
    if (!this.AvailableActions.Has(actionName))
      this._registerAction(this, actionName, '', actionName)
    if (this.Config.GENERAL.ReloadAppHotkey) {
      this.BindHotkey(this.Config.GENERAL.ReloadAppHotkey, this.%actionName%.bind(this), actionName)
    }

    actionName := 'ToggleAppSuspend'
    if (!this.AvailableActions.Has(actionName))
      this._registerAction(this, actionName, '', actionName)
    if (this.Config.GENERAL.SuspendAppHotkey) {
      this.BindHotkey(this.Config.GENERAL.SuspendAppHotkey, this.%actionName%.bind(this), actionName, 'On S') ; FIXME: On S - what is 'S'?
    }
  }

  _initTrayMenu() {
    trayMenu:= A_TrayMenu
    trayMenu.Delete()
    fn := this._trayMenuHandler.bind(this)
    if (this.debugLevel = 0)
      trayMenu.Delete() ; V1toV2: not 100% replacement of NoStandard, Only if NoStandard is used at the beginning
    TraySetIcon(this.TrayIconDefault, "1")
    ; this.runMenuHooks() ; TODO
    trayMenu.Add("KeyHistory", fn)
    trayMenu.Add("Test", fn)
    trayMenu.Add()
    trayMenu.Add("Settings", fn)
    trayMenu.Add()
    trayMenu.Add("Reload", fn)
    trayMenu.Add("Disable", fn)
    trayMenu.Add()
    trayMenu.Add("Exit", fn)
  }

  _trayMenuHandler(ItemName, ItemPos, TheMenu) {
    switch (ItemName) {
      case "Test":
        this.TestActions()
        return
      case "KeyHistory":
        KeyHistory
        return
      case "Settings":
        this.GUI.ShowSettings()
        return
      case "Reload":
        this.ReloadApp()
        return
      case "Disable":
        this.ToggleAppSuspend()
        return
      case "Exit":
        ExitApp
        return
      Default:
        this.ShowInfo("no action for " ItemName)
        return
    }
  }

  _initLaunchMenu() {
    static WM_TRAYMESSAGE := 0x404

    static WM_MOUSEMOVE   := 0x200
    static WM_LBUTTONDOWN := 0x201
    static WM_LBUTTONUP   := 0x202
    static WM_RBUTTONDOWN := 0x204
    static WM_RBUTTONUP   := 0x205
    static WM_MBUTTONDOWN := 0x207
    static WM_MBUTTONUP   := 0x208

    this.MyMenu := Menu()
    this.DropGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "DropTarget")
    fn := this._launchMenuHandler.bind(this)

    this.MyMenu.Add("Item 1", fn)
    this.MyMenu.Add("Item 2", fn)
    this.MyMenu.Add()

    Submenu1 := Menu()
    Submenu1.Add("Item A", fn)
    Submenu1.Add("Item B", fn)

    this.MyMenu.Add("My Submenu", Submenu1)

    this.MyMenu.Add()
    this.MyMenu.Add("Item 3", fn)

    ; Create invisible drag target GUI
    this.DropGui.OnEvent("DropFiles", this._handleDrop.bind(this))
    this.DropGui.Show("w100 h100 x99 y99") ; Invisible, off-screen

    OnMessage(WM_TRAYMESSAGE, _trayIconMouseEventHandler)
    _trayIconMouseEventHandler(wParam, lParam, nMsg, hwnd) {
      switch (lParam) {
        case WM_LBUTTONUP:
          this.MyMenu.Show()
          return 1
      }
    }
  }

  _handleDrop(GuiObj, Ctrl, FileArray, X, Y) {
    for file in FileArray {
      this.MyMenu.Add(file, this._launchMenuHandler.bind(this))
    }
    this.MyMenu.Show()
  }

  _launchMenuHandler(ItemName, ItemPos, TheMenu) {
    switch (ItemName) {
      case "Test":
        this.TestActions()
        return

      Default:
        this.ShowInfo("no action for " ItemName)
        return
    }
  }

  _initConfig(ConfigFile) {
    ; FileDelete(ConfigFile) ; FIXME: for debug, REMOVE BEFORE RELEASE!

    if !FileExist(ConfigFile) {
      DefaultSettings := ''
      FileAppend(DefaultSettings, ConfigFile)
    }

    this.Config := IniFile(ConfigFile)

    if (!this.Config.Has("GENERAL"))
      this.Config.GENERAL := {} 
    ProcessGeneralConfigSection(this.Config.GENERAL)
    
    if (!this.Config.Has("THEME"))
      this.Config.THEME := {} 
    ProcessThemeConfigSection(this.Config.THEME)
    
    if (!this.Config.Has("BLACKLISTS"))
      this.Config.BLACKLISTS := {}
    ProcessBlocklistsConfigSection(this.Config.BLACKLISTS)

    if (!this.Config.Has("HOTKEYS"))
      this.Config.HOTKEYS := GetDefaultHotkeysConfig()

    this.outputDebugLine(AKApp.LOG_INFO, "Config loaded from " ConfigFile, Map("source", "core"))
  }

  ApplyEncodedSettings(generalEncoded, disabledPlugins, pluginConfigEncoded, hotkeysEncoded:="") {
    cfg := this.Config
    oldDisabledPlugins := cfg.GENERAL.DisabledPlugins

    this._applyEncodedGeneralConfig("" generalEncoded)
    cfg.GENERAL.DisabledPlugins := "" disabledPlugins
    this._applyEncodedPluginConfig("" pluginConfigEncoded)
    this._applyEncodedHotkeysConfig("" hotkeysEncoded)

    cfg.Save()
    this.ApplySettings(oldDisabledPlugins)
  }

  ApplySettingsPayload(jsonPayload) {
    payloadText := "" jsonPayload
    if (Trim(payloadText) = "")
      return

    try payload := jsongo.Parse(payloadText)
    catch as err {

      this.outputDebugLine(AKApp.LOG_WARNING, "Invalid JSON settings payload: " err.Message)
      this.outputDebugLine(AKApp.LOG_DEBUG, payloadText)
      return
    }

    if (!IsObject(payload) || !(payload is Map)) {
      this.outputDebugLine(AKApp.LOG_WARNING, "Invalid settings payload object")
      return
    }

    cfg := this.Config
    oldDisabledPlugins := cfg.GENERAL.DisabledPlugins

    if (payload.Has("general") && IsObject(payload["general"]) && payload["general"] is Map)
      this._applyGeneralConfigObject(payload["general"])

    if (payload.Has("disabledPlugins") && payload["disabledPlugins"] is Array) {
      parts := []
      for item in payload["disabledPlugins"] {
        name := Trim("" item)
        if (name != "")
          parts.Push(name)
      }
      cfg.GENERAL.DisabledPlugins := Join(parts, ",")
    }

    if (payload.Has("pluginConfigs") && IsObject(payload["pluginConfigs"]) && payload["pluginConfigs"] is Map)
      this._applyPluginConfigObject(payload["pluginConfigs"])

    if (payload.Has("hotkeys") && payload["hotkeys"] is Array)
      this._applyHotkeysObject(payload["hotkeys"])

    cfg.Save()
    this.ApplySettings(oldDisabledPlugins)
  }

  _jsonAtomicResult(ok := true, error := "", extra := 0) {
    result := Map("ok", !!ok)
    if (!ok && error != "")
      result["error"] := "" error
    if (IsObject(extra) && extra is Map) {
      for k, v in extra {
        result[k] := v
      }
    }
    return jsongo.Stringify(result)
  }

  _parseAtomicValue(payload) {
    payloadText := "" payload
    try return jsongo.Parse(payloadText)
    catch {
      return payloadText
    }
  }

  _findPluginInstanceById(pluginId) {
    pluginIdText := Trim("" pluginId)
    if (pluginIdText = "")
      return 0

    if (this._addedLibs.Has(pluginIdText))
      return this._addedLibs[pluginIdText]

    for className, instance in this._addedLibs {
      desc := instance.__GetPluginDescriptor()
      if (desc && desc.Has("plugin") && desc["plugin"].Has("id") && ("" desc["plugin"]["id"] = pluginIdText))
        return instance
    }
    return 0
  }

  SaveGeneralSetting(key, valuePayload) {
    keyText := Trim("" key)
    if (keyText = "")
      return this._jsonAtomicResult(false, "Missing key")

    typeIndex := this._buildGeneralTypeIndex()
    if (!typeIndex.Has(keyText))
      return this._jsonAtomicResult(false, "Unknown [GENERAL] key: " keyText)

    try {
      rawValue := this._parseAtomicValue(valuePayload)
      valueType := typeIndex[keyText]
      coercedValue := this._coerceConfigValue(rawValue, valueType, true)
      this.Config.GENERAL.%keyText% := coercedValue
      this.Config.Save()
      this.outputDebugLine(AKApp.LOG_DEBUG, "Config written to disk", Map("source", "core"))

      if (keyText = "DebugLevel") {
        debugLevel := Integer(coercedValue)
        this.Debug(debugLevel)
        for className, libObj in this._addedLibs {
          libObj.Debug(debugLevel)
        }
      } else if (keyText = "DarkTheme") {
        this.GUI.ApplyThemeMode()
      } else if (keyText = "UIScalingPercent") {
        this.GUI._applyUIScaling(Integer(coercedValue))
      } else if (keyText = "ReloadAppHotkey" || keyText = "SuspendAppHotkey") {
        this._rebindControlHotkeys()
      }

      this.outputDebugLine(AKApp.LOG_DEBUG, "Setting saved: GENERAL" keyText " = " coercedValue, Map("source", "core", "settingRef", Map("page", "general", "key", keyText)))

      return this._jsonAtomicResult(true)
    } catch as err {
      this.outputDebugLine(AKApp.LOG_WARNING, "Failed saving GENERAL" keyText ": " err.Message, Map("source", "core", "settingRef", Map("page", "general", "key", keyText)))
      return this._jsonAtomicResult(false, err.Message)
    }
  }

  SavePluginSetting(pluginId, key, valuePayload) {
    pluginIdText := Trim("" pluginId)
    keyText := Trim("" key)
    if (pluginIdText = "" || keyText = "")
      return this._jsonAtomicResult(false, "Missing pluginId or key")

    try {
      typeIndex := this._buildPluginTypeIndex()
      pluginTypes := typeIndex.Has(pluginIdText) ? typeIndex[pluginIdText] : 0
      valueType := (pluginTypes && pluginTypes.Has(keyText)) ? pluginTypes[keyText] : "string"

      if (!this.Config.Has(pluginIdText))
        this.Config[pluginIdText] := {}

      rawValue := this._parseAtomicValue(valuePayload)
      coercedValue := this._coerceConfigValue(rawValue, valueType, false)
      this.Config[pluginIdText][keyText] := coercedValue
      this.Config.Save()
      this.outputDebugLine(AKApp.LOG_DEBUG, "Config written to disk", Map("source", "core"))

      pluginInstance := this._findPluginInstanceById(pluginIdText)
      if (pluginInstance && HasMethod(pluginInstance, "OnConfigChanged")) {
        try pluginInstance.OnConfigChanged(keyText, coercedValue)
      }

      this.outputDebugLine(AKApp.LOG_DEBUG, "Setting saved: " pluginIdText "." keyText " = " coercedValue, Map("source", pluginIdText, "settingRef", Map("page", "plugin-" pluginIdText, "key", keyText)))

      return this._jsonAtomicResult(true)
    } catch as err {
      this.outputDebugLine(AKApp.LOG_WARNING, "Failed saving " pluginIdText "." keyText ": " err.Message, Map("source", pluginIdText, "settingRef", Map("page", "plugin-" pluginIdText, "key", keyText)))
      return this._jsonAtomicResult(false, err.Message)
    }
  }

  _hotkeyEntriesFromConfig() {
    entries := []
    if (!this.Config.Has("HOTKEYS"))
      this.Config.HOTKEYS := Map()

    for hk, actionText in this.Config.HOTKEYS {
      entries.Push(Map("hotKey", "" hk, "action", "" actionText))
    }
    return entries
  }

  GetDefaultActionHotkeys() {
    defaults := Map()
    defaultHotkeys := GetDefaultHotkeysConfig()

    for hotkey, actionText in defaultHotkeys {
      actionInfo := this._parseActionInfo(actionText)
      actionName := Trim("" actionInfo.fnName)
      if (actionName = "")
        continue

      if (!defaults.Has(actionName))
        defaults[actionName] := []
      defaults[actionName].Push("" hotkey)
    }

    return defaults
  }

  _saveHotkeyEntries(entries) {
    parsed := Map()
    for entry in entries {
      hk := entry.Has("hotKey") ? Trim("" entry["hotKey"]) : ""
      actionText := entry.Has("action") ? Trim("" entry["action"]) : ""
      if (!hk || !actionText)
        continue
      parsed[hk] := actionText
    }
    this.Config.HOTKEYS := parsed
  }

  _unbindAssignedHotkeyByRaw(hotKey) {
    hotKeyText := Trim("" hotKey)
    if (!hotKeyText)
      return

    universal := convertToUniversalVkHotkey(hotKeyText)
    try Hotkey(universal, "Off")
    if (this._assignedHotkeys.Has(universal))
      this._assignedHotkeys.Delete(universal)
  }

  _isDangerousMouseOnlyHotkey(hotKey) {
    hk := Trim("" hotKey)
    if (!hk)
      return false

    normalized := RegExReplace(hk, "\s+", "")

    while (RegExMatch(normalized, "^[*~$]")) {
      normalized := SubStr(normalized, 2)
    }

    hasModifier := false
    loop {
      if (RegExMatch(normalized, "^(<\^|>\^|<!|>!|<\+|>\+|<#|>#)", &m)) {
        hasModifier := true
        normalized := SubStr(normalized, StrLen(m[1]) + 1)
        continue
      }
      if (RegExMatch(normalized, "^[\^!+#]")) {
        hasModifier := true
        normalized := SubStr(normalized, 2)
        continue
      }
      break
    }

    if (hasModifier)
      return false

    if (InStr(normalized, "&"))
      return false

    keyName := StrUpper(Trim(normalized))
    if (!keyName)
      return false

    dangerous := Map(
      "LBUTTON", true,
      "RBUTTON", true,
      "MBUTTON", true,
      "XBUTTON1", true,
      "XBUTTON2", true,
      "WHEELUP", true,
      "WHEELDOWN", true,
      "WHEELLEFT", true,
      "WHEELRIGHT", true
    )

    return dangerous.Has(keyName)
  }

  _validateHotkeyEntry(hotKey, actionText, entries, ignoreIndex := -1, allowRiskyHotkeys := false) {
    problems := []
    hk := Trim("" hotKey)
    actionStr := Trim("" actionText)

    allowDangerous := (allowRiskyHotkeys = true)
    allowText := StrLower(Trim("" allowRiskyHotkeys))
    if (allowText = "1" || allowText = "true")
      allowDangerous := true

    if (!hk)
      problems.Push("Hotkey cannot be empty")
    if (!actionStr)
      problems.Push("Action cannot be empty")

    if (actionStr) {
      actionInfo := this._parseActionInfo(actionStr)
      if (actionInfo.fnName = "") {
        problems.Push("Action cannot be empty")
      } else if (!this._actionExists(actionInfo.fnName)) {
        problems.Push("Unknown action: " actionInfo.fnName)
      }
    }

    if (hk) {
      hkUniversal := convertToUniversalVkHotkey(hk)
      for idx, entry in entries {
        if ((idx - 1) = ignoreIndex)
          continue
        existing := entry.Has("hotKey") ? Trim("" entry["hotKey"]) : ""
        if (!existing)
          continue
        if (convertToUniversalVkHotkey(existing) = hkUniversal) {
          problems.Push("Duplicate hotkey: " hk)
          break
        }
      }
    }

    if (hk && this._isDangerousMouseOnlyHotkey(hk) && !allowDangerous) {
      problems.Push("Risky hotkey blocked: " hk ". Enable 'Allow risky hotkeys' in Manual mode to save it")
    }

    return problems
  }

  SaveHotkey(index, hotKey, action, allowRiskyHotkeys := false) {
    try idx := Integer(index)
    catch {
      return this._jsonAtomicResult(false, "Invalid hotkey index")
    }

    entries := this._hotkeyEntriesFromConfig()
    if (idx < 0 || idx >= entries.Length)
      return this._jsonAtomicResult(false, "Hotkey index out of range")

    problems := this._validateHotkeyEntry(hotKey, action, entries, idx, allowRiskyHotkeys)
    if (problems.Length > 0)
      return this._jsonAtomicResult(false, "Hotkey validation failed", Map("problems", problems))

    oldEntry := entries[idx + 1]
    runHotkeyActionFn := this._runHotkeyAction.bind(this)

    this._unbindAssignedHotkeyByRaw(oldEntry["hotKey"])
    bindResult := this.BindHotkey(hotKey, runHotkeyActionFn, action)
    if (bindResult != 0) {
      ; restore previous binding if replacement failed
      if (oldEntry.Has("hotKey") && oldEntry.Has("action") && oldEntry["hotKey"] != "" && oldEntry["action"] != "")
        this.BindHotkey(oldEntry["hotKey"], runHotkeyActionFn, oldEntry["action"])
      return this._jsonAtomicResult(false, "Hotkey bind failed", Map("problems", ["" bindResult]))
    }

    entries[idx + 1] := Map("hotKey", "" hotKey, "action", "" action)
    this._saveHotkeyEntries(entries)
    this.Config.Save()
    this.outputDebugLine(AKApp.LOG_DEBUG, "Config written to disk", Map("source", "core"))
    this.outputDebugLine(AKApp.LOG_DEBUG, "Hotkey updated at index " idx ": " hotKey " -> " action, Map("source", "hotkeys", "settingRef", Map("page", "hotkeys", "index", idx)))
    return this._jsonAtomicResult(true, "", Map("problems", []))
  }

  RemoveHotkey(index) {
    try idx := Integer(index)
    catch {
      return this._jsonAtomicResult(false, "Invalid hotkey index")
    }

    entries := this._hotkeyEntriesFromConfig()
    if (idx < 0 || idx >= entries.Length)
      return this._jsonAtomicResult(false, "Hotkey index out of range")

    oldEntry := entries[idx + 1]
    this._unbindAssignedHotkeyByRaw(oldEntry["hotKey"])
    entries.RemoveAt(idx + 1)

    this._saveHotkeyEntries(entries)
    this.Config.Save()
    this.outputDebugLine(AKApp.LOG_DEBUG, "Config written to disk", Map("source", "core"))
    this.outputDebugLine(AKApp.LOG_DEBUG, "Hotkey removed at index " idx, Map("source", "hotkeys", "settingRef", Map("page", "hotkeys", "index", idx)))
    return this._jsonAtomicResult(true, "", Map("problems", []))
  }

  AddHotkey(hotKey, action, allowRiskyHotkeys := false) {
    entries := this._hotkeyEntriesFromConfig()
    problems := this._validateHotkeyEntry(hotKey, action, entries, -1, allowRiskyHotkeys)
    if (problems.Length > 0)
      return this._jsonAtomicResult(false, "Hotkey validation failed", Map("problems", problems))

    runHotkeyActionFn := this._runHotkeyAction.bind(this)
    bindResult := this.BindHotkey(hotKey, runHotkeyActionFn, action)
    if (bindResult != 0)
      return this._jsonAtomicResult(false, "Hotkey bind failed", Map("problems", ["" bindResult]))

    entries.Push(Map("hotKey", "" hotKey, "action", "" action))
    this._saveHotkeyEntries(entries)
    this.Config.Save()
    this.outputDebugLine(AKApp.LOG_DEBUG, "Config written to disk", Map("source", "core"))
    this.outputDebugLine(AKApp.LOG_DEBUG, "Hotkey added: " hotKey " -> " action, Map("source", "hotkeys", "settingRef", Map("page", "hotkeys", "index", entries.Length - 1)))
    return this._jsonAtomicResult(true, "", Map("problems", []))
  }

  TogglePlugin(pluginId, enabled) {
    pluginIdText := Trim("" pluginId)
    if (pluginIdText = "")
      return this._jsonAtomicResult(false, "Missing pluginId")

    enabledText := Trim("" enabled)
    enabledBool := (enabled = true || enabledText = "1" || enabledText = "true")

    disabledPlugins := []
    seen := Map()
    for name in this._getDisabledPlugins() {
      nameText := Trim("" name)
      if (nameText = "" || seen.Has(nameText))
        continue
      seen[nameText] := true
      disabledPlugins.Push(nameText)
    }

    nextDisabled := []
    for name in disabledPlugins {
      if (enabledBool && name = pluginIdText)
        continue
      nextDisabled.Push(name)
    }

    if (!enabledBool && !ArrayContains(nextDisabled, pluginIdText))
      nextDisabled.Push(pluginIdText)

    this.Config.GENERAL.DisabledPlugins := Join(nextDisabled, ",")
    this.Config.Save()
    this.outputDebugLine(AKApp.LOG_DEBUG, "Config written to disk", Map("source", "core"))

    availablePlugins := this._getAvailablePlugins()
    requiredPlugins := []
    for pluginName in availablePlugins {
      if (!ArrayContains(nextDisabled, pluginName))
        requiredPlugins.Push(pluginName)
    }
    this._generateDynamicPlugins(requiredPlugins)
    this.outputDebugLine(AKApp.LOG_INFO, "Plugin " pluginIdText " set to " (enabledBool ? "enabled" : "disabled") " (reload required)", Map("source", pluginIdText, "settingRef", Map("page", "plugins")))

    return this._jsonAtomicResult(true, "", Map("requiresReload", true))
  }

  _applyGeneralConfigObject(generalObj) {
    if (!IsObject(generalObj) || !(generalObj is Map))
      return

    cfg := this.Config
    if (!cfg.Has("GENERAL"))
      cfg.GENERAL := {}

    typeIndex := this._buildGeneralTypeIndex()
    for key, rawValue in generalObj {
      keyText := "" key
      if (!typeIndex.Has(keyText)) {
        this.outputDebugLine(AKApp.LOG_WARNING, "Unknown [GENERAL] config key: " . keyText)
        continue
      }
      valueType := typeIndex[keyText]
      cfg.GENERAL.%keyText% := this._coerceConfigValue(rawValue, valueType, true)
    }
  }

  _applyPluginConfigObject(pluginConfigs) {
    if (!IsObject(pluginConfigs) || !(pluginConfigs is Map))
      return

    typeIndex := this._buildPluginTypeIndex()
    for pluginId, cfgObj in pluginConfigs {
      pluginIdText := "" pluginId
      if (!pluginIdText || !IsObject(cfgObj) || !(cfgObj is Map))
        continue

      if (!this.Config.Has(pluginIdText))
        this.Config[pluginIdText] := {}

      pluginTypes := typeIndex.Has(pluginIdText) ? typeIndex[pluginIdText] : 0
      for key, rawValue in cfgObj {
        keyText := "" key
        valueType := (pluginTypes && pluginTypes.Has(keyText)) ? pluginTypes[keyText] : "string"
        this.Config[pluginIdText][keyText] := this._coerceConfigValue(rawValue, valueType, false)
      }
    }
  }

  _applyHotkeysObject(hotkeysArr) {
    if (!(hotkeysArr is Array))
      return

    parsed := Map()
    for entry in hotkeysArr {
      if (!IsObject(entry) || !(entry is Map))
        continue

      hk := entry.Has("hotKey") ? Trim("" entry["hotKey"]) : ""
      actionText := entry.Has("action") ? Trim("" entry["action"]) : ""
      if (!hk || !actionText)
        continue
      parsed[hk] := actionText
    }
    this.Config.HOTKEYS := parsed
  }

  _buildGeneralTypeIndex() {
    if (this._generalTypeIndex && this._generalTypeIndex is Map)
      return this._generalTypeIndex

    typeIndex := Map()
    for fieldDesc in this.GetGeneralConfigSchema() {
      if (!fieldDesc.Has("key"))
        continue
      fieldType := fieldDesc.Has("type") ? fieldDesc["type"] : "string"
      typeIndex["" fieldDesc["key"]] := fieldType
    }
    this._generalTypeIndex := typeIndex
    return typeIndex
  }

  _buildPluginTypeIndex() {
    if (this._pluginTypeIndex && this._pluginTypeIndex is Map)
      return this._pluginTypeIndex

    typeIndex := Map()
    for className, libObj in this._addedLibs {
      descriptor := libObj.__GetPluginDescriptor()
      if (!descriptor || !descriptor.Has("plugin") || !descriptor["plugin"].Has("id"))
        continue

      pluginId := "" descriptor["plugin"]["id"]
      if (!typeIndex.Has(pluginId))
        typeIndex[pluginId] := Map()

      schema := libObj.__GetConfigSchema()
      for fieldDesc in schema {
        if (!fieldDesc.Has("key"))
          continue
        fieldType := fieldDesc.Has("type") ? fieldDesc["type"] : "string"
        typeIndex[pluginId]["" fieldDesc["key"]] := fieldType
      }
    }
    this._pluginTypeIndex := typeIndex
    return typeIndex
  }

  _coerceConfigValue(rawValue, valueType := "string", booleansAsInt := true) {
    text := "" rawValue
    if (valueType = "boolean") {
      boolValue := (rawValue = true || text = "1" || text = "true")
      return booleansAsInt ? (boolValue ? 1 : 0) : boolValue
    }

    if (valueType = "integer") {
      try return Integer(rawValue)
      catch {
        try return Integer(text)
        catch {
          return text
        }
      }
    }

    if (valueType = "number") {
      try return Number(rawValue)
      catch {
        try return Number(text)
        catch {
          return text
        }
      }
    }

    return text
  }

  _encodeEscapedLinePart(value) {
    text := "" value
    text := StrReplace(text, "\\", "\\\\")
    text := StrReplace(text, "`r", "\\r")
    text := StrReplace(text, "`n", "\\n")
    text := StrReplace(text, "`t", "\\t")
    return text
  }

  _applyEncodedHotkeysConfig(encoded) {
    if (Trim(encoded) = "")
      return

    if (!this.Config.Has("HOTKEYS"))
      this.Config.HOTKEYS := Map()

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
    this.Config.HOTKEYS := parsed
  }

  _applyEncodedGeneralConfig(encoded) {
    if (Trim(encoded) = "")
      return

    cfg := this.Config
    if (!cfg.Has("GENERAL"))
      cfg.GENERAL := {}

    typeIndex := Map()
    for fieldDesc in this.GetGeneralConfigSchema() {
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
        this.outputDebugLine(AKApp.LOG_WARNING, "Unknown [GENERAL] config key: " . key)
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
    for className, libObj in this._addedLibs {
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

      if (!this.Config.Has(pluginId))
        this.Config[pluginId] := {}

      valueType := "string"
      if (typeIndex.Has(pluginId) && typeIndex[pluginId].Has(key))
        valueType := typeIndex[pluginId][key]

      if (valueType = "boolean") {
        this.Config[pluginId][key] := (value = "1" || value = "true") ? true : false
      } else if (valueType = "integer") {
        try this.Config[pluginId][key] := Integer(value)
        catch {
          this.Config[pluginId][key] := value
        }
      } else if (valueType = "number") {
        try this.Config[pluginId][key] := Number(value)
        catch {
          this.Config[pluginId][key] := value
        }
      } else {
        this.Config[pluginId][key] := value
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

  _registerAction(libObj, actionString, className, description) {
    this._warnIfActionNameIsNonConventional(actionString, className)

    if (this.AvailableActions.Has(actionString)) {
      existingOwner := this.AvailableActions[actionString]["className"]
      collisionKey := actionString "::" existingOwner "::" className
      if (!this._warnedActionCollisions.Has(collisionKey)) {
        this._warnedActionCollisions[collisionKey] := true
        this.outputDebugLine("Action collision: '" actionString "' from plugin '" className "' conflicts with plugin '" existingOwner "'. Keeping existing registration", 1, Map("source", className, "settingRef", Map("page", "plugins")))
      }
      return false
    }
    this.AvailableActions[actionString] := Map()
    this.AvailableActions[actionString]["handlerFn"] := ObjBindMethod(libObj, actionString) ; SAME AS libObj.%actionString%.bind(libObj)
    this.AvailableActions[actionString]["className"] := className
    this.AvailableActions[actionString]["description"] := description
    return true
  }

  _runHotkeyAction(some*) {
    hkDef := this._assignedHotkeys[A_ThisHotKey]
    ; TODO: HotkeyThrottlingBlocklist?
    if (A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < this.HotkeyThrottlingTimeout) {
      this.outputDebugLine(AKApp.LOG_DEBUG, "Hotkey " hkDef['readable'] " throttled")
      return
    }
    return this._callActionHandler(hkDef['handler'], hkDef['params'], hkDef['action'], hkDef['readable'])
  }

  _callActionHandler(actionHandler, paramsArr, actionText, hotkeyLabel:="") {
    actionInfo := this._parseActionInfo(actionText)
    source := "core"
    if (this.AvailableActions.Has(actionInfo.fnName))
      source := this.AvailableActions[actionInfo.fnName]["className"]
    this.outputDebugLine(AKApp.LOG_DEBUG, "Action started: hotkey=" (hotkeyLabel != "" ? hotkeyLabel : "none") " action=" actionText " " this._getActionWindowContext(), Map("source", source))

    try {
      if (paramsArr.Length > 0) {
        return (IsObject(actionHandler))
          ? actionHandler.Call(paramsArr*)
          : %actionHandler%(paramsArr*)
      } else {
        return (IsObject(actionHandler))
          ? actionHandler.Call()
          : %actionHandler%()
      }
    } catch Error as err {
      this._handleActionError(err, actionText, source)
      return false
    }
  }

  _handleActionError(err, actionText, source) {
    errorDetails := Type(err) ": " err.Message "`nAction: " actionText "`nFile: " err.File "`nLine: " err.Line "`nWhat: " err.What "`nExtra: " err.Extra "`nStack:`n" err.Stack
    try errorDetails .= "`nNumber: " err.Number
    this.outputDebugLine(AKApp.LOG_ERROR, errorDetails, Map("source", source))

    if (this._isAccessDeniedError(err)) {
      message := "Windows blocked running " actionText " because the other app is running as administrator.`nRun " this.ScriptName " as administrator and try again"
      try this.ShowInfo(message, , 7000, "warning")
      return
    }

    try this.ShowInfo("The action could not be completed. Open Logs for technical details.", "Action failed", 6000, "error")
  }

  _isAccessDeniedError(err) {
    try {
      if (err is OSError && err.Number = 5)
        return true
    }
    return InStr(err.Message, "Access is denied", false) > 0
  }

  _getCurrentHotkeyLabel() {
    if (A_ThisHotkey = "")
      return ""
    if (this._assignedHotkeys.Has(A_ThisHotkey))
      return this._assignedHotkeys[A_ThisHotkey]["readable"]
    try return convertToReadableHotkey(A_ThisHotkey)
    return A_ThisHotkey
  }

  _getActionWindowContext() {
    activeHwnd := 0
    hoveredHwnd := 0
    try activeHwnd := WinGetID("A")
    try MouseGetPos(,, &hoveredHwnd)
    return "active={" this._formatActionWindow(activeHwnd) "} hovered={" this._formatActionWindow(hoveredHwnd) "}"
  }

  _formatActionWindow(hwnd) {
    if (!hwnd)
      return "none"

    processName := ""
    className := ""
    title := ""
    try processName := WinGetProcessName("ahk_id " hwnd)
    try className := WinGetClass("ahk_id " hwnd)
    try title := WinGetTitle("ahk_id " hwnd)
    title := StrReplace(StrReplace(title, "`r", " "), "`n", " ")
    return "hwnd=" hwnd " exe=" processName " class=" className " title=" title
  }

  _parseActionInfo(actionString) {
    result := { fnName: '', params: [] }
    if (RegExMatch(actionString, "(\w+)\((.*)\)", &match)) {
      result.fnName := this._resolveDeprecatedActionName(match[1])
      result.params := SplitRespectingParens(match[2])
    } else {
      result.fnName := this._resolveDeprecatedActionName(actionString)
    }
    return result
  }

  _resolveDeprecatedActionName(actionName) {
    if (this.ActionDeprecationMap.Has(actionName)) {
      newName := this.ActionDeprecationMap[actionName]
      if (!this._warnedDeprecatedActions.Has(actionName)) {
        this._warnedDeprecatedActions[actionName] := true
        this.outputDebugLine(AKApp.LOG_WARNING, "Deprecated action alias used: '" actionName "' -> '" newName "'. Update config to the new action name")
      }
      return newName
    }
    return actionName
  }

  _warnIfActionNameIsNonConventional(actionName, className) {
    if (RegExMatch(actionName, "^[A-Z][A-Za-z0-9]*$"))
      return

    warningKey := className "::" actionName
    if (this._warnedActionNaming.Has(warningKey))
      return

    this._warnedActionNaming[warningKey] := true
    this.outputDebugLine(AKApp.LOG_WARNING, "Non-conventional action name '" actionName "' in plugin '" className "'. Use VerbNoun / VerbNounQualifier (PascalCase)")
  }

  _actionExists(actionName) {
    if (this.AvailableActions.Has(actionName))
      return true
    try {
      return !!(%actionName%)
    } catch {
      return false
    }
  }

  _getActionHandler(actionName) {
    if (this.AvailableActions.Has(actionName))
      return this.AvailableActions[actionName]['handlerFn']
    try {
      if (%actionName%)
        return %actionName%.bind(A_ThisHotKey)
    } catch {
    }

    ; throw Error('Unable to get action handler for ' . actionName)
    return (*) => this.ShowNotice('Unable to get action handler for ' . actionName)
  }
}

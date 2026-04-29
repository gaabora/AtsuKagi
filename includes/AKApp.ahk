class AKApp extends AKBase {
  ; public (let's agree on PascalCase)
  AvailableActions := Map()
  AvailableHooks := Map()
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
  _warnedDeprecatedActions := Map()
  _warnedActionCollisions := Map()
  _warnedActionNaming := Map()
  
  ; Phase 1+: Plugin metadata registries
  _pluginRegistry := Map()        ; pluginId -> descriptor
  _actionRegistry := Map()        ; actionName -> actionDescriptor
  _pluginConfigRegistry := Map()  ; pluginId -> configSchema[]

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
    this.outputDebugLine("Startup diagnostics: plugins=" pluginsCount ", actions=" actionsCount ", hotkeys=" hotkeysCount, 3)
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
          this.outputDebugLine('OUTPUT: ' handlerFn() ' from ' action['className'] ' ' action['description'])
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
  ;       this.outputDebugLine('WARN: ' hkDef['action'] ' was not found')
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

  ; ── Phase 1+: Plugin Settings Metadata Helpers ─────────────────────────────────
  ; Get all plugin pages (descriptors with settings pages) for the UI
  GetPluginSettingsPages() {
    pages := []
    disabledPlugins := this._getDisabledPlugins()
    
    for pluginId, descriptor in this._pluginRegistry {
      if (!descriptor.Has("settingsPage"))
        continue
      
      settingsPage := descriptor["settingsPage"]
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
    
    ; this._sortPluginPages(pages)//FIXME: this can be done on js side, no need to do it in AHK
    return pages
  }

  ; _sortPluginPages(&pages) {
  ;   ; Small N expected, so bubble-sort keeps implementation simple and explicit.
  ;   n := pages.Length
  ;   if (n <= 1)
  ;     return

  ;   Loop n - 1 {
  ;     i := 1
  ;     Loop n - A_Index {
  ;       left := pages[i]
  ;       right := pages[i + 1]

  ;       leftOrder := left.Has("navOrder") ? Integer(left["navOrder"]) : 100
  ;       rightOrder := right.Has("navOrder") ? Integer(right["navOrder"]) : 100
  ;       leftTitle := left.Has("title") ? ("" left["title"]) : ""
  ;       rightTitle := right.Has("title") ? ("" right["title"]) : ""

  ;       shouldSwap := (leftOrder > rightOrder) || ((leftOrder = rightOrder) && (leftTitle > rightTitle))
  ;       if (shouldSwap) {
  ;         tmp := pages[i]
  ;         pages[i] := pages[i + 1]
  ;         pages[i + 1] := tmp
  ;       }
  ;       i += 1
  ;     }
  ;   }
  ; }

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
          "scope", fieldDesc.Has("scope") ? fieldDesc["scope"] : "plugin"
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
    
    for actionDesc in actionDefs {
      action := Map(
        "action", actionDesc.Has("action") ? actionDesc["action"] : "",
        "label", actionDesc.Has("label") ? actionDesc["label"] : "",
        "description", actionDesc.Has("description") ? actionDesc["description"] : "",
        "category", actionDesc.Has("category") ? actionDesc["category"] : ""
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
      this.ShowWarning("AddPlugin ERROR: Unable to create instance of " className)
      return
    }
    libObj.Debug(debug)
    libObj._processPluginConfig()
    libObj._processBlocklistConfig()
    libObj._init()
    this._addedLibs[className] := libObj
    
    ; Phase 1+: Register plugin descriptor metadata
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
    this.outputDebugLine("Plugin loaded: " className, 3)

    ; hooks := libObj.__HooksHelp()
    ; for hookString, description in hooks {
    ;   if (this.AvailableHooks.Has(hookString)) {
    ;     this.showWarning("Hook '" hookString "' from Plugin '"  this.AvailableHooks[hookString]["className"] "' overriden by Plugin '" className "'")
    ;   }
    ;   this.AvailableHooks[hookString] := {}
    ;   this.AvailableHooks[hookString]["handlerFn"] := ObjBindMethod(libObj, hookString)
    ;   this.AvailableHooks[hookString]["className"] := className
    ;   this.AvailableHooks[hookString]["description"] := description
    ; }
  }
  
  BindAllHotkeys() {
    runHotkeyActionFn := this._runHotkeyAction.bind(this)
    AKBase.ClearProblems()

    configProblems := this._validateHotkeysConfig()
    for problem in configProblems {
      this.outputDebugLine(problem, 1)
    }

    if (this.Config.Has("HOTKEYS")) {
      For k, v In this.Config.HOTKEYS {
        this.BindHotkey(k, runHotkeyActionFn, v)
      }
    }
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
      this.ShowNotice("Plugin enable or disable changes were saved and will apply on next reload.", "Settings")
      return
    }

    this.ShowInfo("Settings applied.", "Settings")
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
      TraySetIcon(this.TrayIconDisabled,"1")
      Tray.Check("Disable")
      this.ShowInfo(this.ScriptName " DISABLED")
    } else {
      TraySetIcon(this.TrayIconDefault,"1")
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
    expireTime := A_TickCount + msec
    this._toolTipIdsArr[idx] := expireTime

    ToolTip(text, x, y, idx) ; , this.themeSettings)
    
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
      this.outputDebugLine(errorText, 0)
      return errorText
    } 

    try
      Hotkey(hkDef['universal'], HandlerFn, Options)
    catch Error as err {
      hotkeyError := Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
        , type(err), err.Message, err.File, err.Line, err.What, err.Stack)
      errorText := "ERROR: " . debugText . " FAILED: " . hotkeyError
      this.outputDebugLine(errorText, 0)
      return errorText
    }

    this._assignedHotkeys[hkDef['universal']] := hkDef
    this.outputDebugLine(debugText " OK")
    return 0
  }

  RunAction(ActionString) {
    actionInfo := this._parseActionInfo(ActionString)
    actionHandler := this._getActionHandler(actionInfo.fnName)
    return this._callActionHandler(actionHandler, actionInfo.params)
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

    this.outputDebugLine(((isBlocklisted) ? "BLACKLISTED " : "OK ") '' windowClass " hwnd=" hwnd)
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
        ToolTip(,,, idx) ; remove tooltip
        this._toolTipIdsArr[idx] := 0
      }
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
    ProcessGereralConfigSection(this.Config.GENERAL)
    
    if (!this.Config.Has("THEME"))
      this.Config.THEME := {} 
    ProcessThemeConfigSection(this.Config.THEME)
    
    if (!this.Config.Has("BLACKLISTS"))
      this.Config.BLACKLISTS := {}
    ProcessBlocklistsConfigSection(this.Config.BLACKLISTS)

    if (!this.Config.Has("HOTKEYS"))
      this.Config.HOTKEYS := GetDefaultHotkeysConfig()
  }

  _registerAction(libObj, actionString, className, description) {
    this._warnIfActionNameIsNonConventional(actionString, className)

    if (this.AvailableActions.Has(actionString)) {
      existingOwner := this.AvailableActions[actionString]["className"]
      collisionKey := actionString "::" existingOwner "::" className
      if (!this._warnedActionCollisions.Has(collisionKey)) {
        this._warnedActionCollisions[collisionKey] := true
        this.outputDebugLine("Action collision: '" actionString "' from plugin '" className "' conflicts with plugin '" existingOwner "'. Keeping existing registration.", 1)
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
      this.outputDebugLine("Hotkey " hkDef['readable'] " throttled")
      return
    }
    return this._callActionHandler(hkDef['handler'], hkDef['params'])
  }

  _callActionHandler(actionHandler, paramsArr) {
    if (paramsArr.Length > 0) {
      return (IsObject(actionHandler))
        ? actionHandler.Call(paramsArr*)
        : %actionHandler%(paramsArr*)
    } else {
      return (IsObject(actionHandler))
        ? actionHandler.Call()
        : %actionHandler%()
    }
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
        this.outputDebugLine("Deprecated action alias used: '" actionName "' -> '" newName "'. Update config to the new action name.", 1)
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
    this.outputDebugLine("Non-conventional action name '" actionName "' in plugin '" className "'. Use VerbNoun / VerbNounQualifier (PascalCase).", 1)
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

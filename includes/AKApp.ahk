class AKApp extends AKBase {
  ; public (let's agree on PascalCase)
  AvailableActions := Map()
  AvailableHooks := Map()

  TrayIconDefault := A_ScriptDir "/assets/app.ico"
  TrayIconDisabled := A_ScriptDir "/assets/disabled.ico"
  HotkeyThrottlingTimeout := 50
  ScriptName := 'AKApp'
  ; private (let's agree on _camelCase)
  _addedLibs := Map()
  _configFile := A_ScriptDir "/config.ini"
  _configFileDefault := A_ScriptDir "/config.ini"
  _assignedHotkeys := Map()
  _toolTipIdsArr := Map()

  __New(ConfigFile:=0) {

    Loop 20 {
      this._toolTipIdsArr[A_Index] := 0
    }

    this._configFile := (ConfigFile=0) ? this._configFileDefault : ConfigFile
    this.ScriptName := SubStr(A_ScriptName, 1, -4)

    this._initMenu()
    this._initConfig(this._configFile)
    
    actionName := 'ReloadApp'
    this._registerAction(this, actionName, '', actionName)
    if (this.Config.GENERAL.ReloadAppHotkey) {
      this.BindHotkey(this.Config.GENERAL.ReloadAppHotkey, this.%actionName%.bind(this), actionName)
    }
    
    actionName := 'ToggleAppSuspend'
    this._registerAction(this, actionName, '', actionName)
    if (this.Config.GENERAL.SuspendAppHotkey) {
      this.BindHotkey(this.Config.GENERAL.SuspendAppHotkey, this.%actionName%.bind(this), actionName, 'On S')
    }

    ; #HotkeyInterval this.Config.GENERAL.HotkeyInterval
    ; #MaxHotkeysPerInterval this.Config.GENERAL.MaxHotkeysPerInterval

    this._setTimer("_toolTipOff", 100)
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
  ShowHelp() {
    helpText := "Enabled hotkeys:`n"

    usedActions := Map()
    for key, action in this.AvailableActions {
      functionName := this._parseActionInfo(action['description']).fnName
      usedActions[functionName] := Map(
        'className', action['className'],
        'description', action['description'],
        'assignedHotkeys', [],
      )
    }

    for key, hkDef in this._assignedHotkeys {
      functionName := functionName := this._parseActionInfo(hkDef['action']).fnName
      if (usedActions.Has(functionName)) {
        usedActions[functionName]['assignedHotkeys'].Push([hkDef['readable']])
      } else {
        this.outputDebugLine('WARN: ' hkDef['action'] ' was not found')
      }
      helpText .= hkDef['readable'] ' (' hkDef['original'] ') ' hkDef['action'] '`n'
    }
    
    helpText .= "`nNot used actions:`n"
    for functionName, usedAction in usedActions {
      if (usedAction['assignedHotkeys'].Length = 0) {
        helpText .= usedAction['className'] '.' usedAction['description'] '`n'
      }
    }

    MsgBox(helpText)
  }

  AddLib(className, debug:=0) {
    libObj := %className%()
    if (!IsObject(libObj)) {
      this.ShowWarning("AddLib ERROR: Unable to create instance of " className)
      return
    }
    libObj.Debug(debug)
    libObj.App := this
    if (!this.Config.Has(className))
      this.Config[className] := {}
    libObj.Config := this.Config[className]
    libObj.ProcessPluginConfig()
    libObj.ProcessBlacklistConfig()
    this._addedLibs[className] := libObj
    ; TODO: inject configs in libs

    actions := libObj.__ActionsHelp()
    for actionString, description in actions {
      this._registerAction(libObj, actionString, className, description)
    }

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
    if (this.Config.Has("HOTKEYS")) {
      For k, v In this.Config.HOTKEYS {
        this.BindHotkey(k, runHotkeyActionFn, v)
      }
    }
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

    if (hkDef['action'] != '' && hkDef['handler'] = -1) {
      hotkeyError := 'Action not found'
      errorText := 'ERROR: ' . debugText . ' FAILED: ' . hotkeyError
      this.ShowWarning(errorText)
      return errorText
    } 

    try
      Hotkey(hkDef['universal'], HandlerFn, Options)
    catch Error as err {
      hotkeyError := Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
        , type(err), err.Message, err.File, err.Line, err.What, err.Stack)
      errorText := "ERROR: " . debugText . " FAILED: " . hotkeyError
      this.ShowWarning(errorText)
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

  IsWindowBlacklisted(hwnd:=0, method:='') {
    windowClass := GetWindowClass(hwnd)
    
    if (RegExMatch(method, '(\w+)\.\w+\.(\S+)', &match)) {
      actionName := match[1]
      ; TODO: per method blacklist check
      ; [BlacklistGroups]
      ; NoMoveResize=
      ; NoDecoration=
      ; NoCtrlCHotkey=
    ; } else {
    }
    isBlacklisted := (InStr(this.Config.GENERAL.BlacklistGlobalWindowClasses, windowClass, false) != 0)

    this.outputDebugLine(((isBlacklisted) ? "BLACKLISTED " : "OK ") '' windowClass " hwnd=" hwnd)
    return isBlacklisted
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


  _initMenu() {
    Tray:= A_TrayMenu
    Tray.Delete()
    fn := this._menuHandler.bind(this)
    if (this.debugLevel = 0)
      Tray.Delete() ; V1toV2: not 100% replacement of NoStandard, Only if NoStandard is used at the beginning
    TraySetIcon(this.TrayIconDefault, "1")
    ; this.runMenuHooks() ; TODO
    Tray.Add("KeyHistory", fn)
    Tray.Add("Help", fn)
    Tray.Add("Test", fn)
    Tray.Add()
    Tray.Add("Settings", fn)
    Tray.Add()
    Tray.Add("Reload", fn)
    Tray.Add("Disable", fn)
    Tray.Add()
    Tray.Add("Exit", fn)
  }

  _menuHandler(ItemName, ItemPos, MyMenu) {
    switch (ItemName) {
      case "Test":
        this.TestActions()
        return
      case "KeyHistory":
        KeyHistory
        return
      case "Help":
        this.ShowHelp()
        return
      case "Settings":
        ConfigFile := this._configFile
        RunWait(ConfigFile)
        this.ReloadApp()
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

  _initConfig(ConfigFile) {
    FileDelete(ConfigFile) ; FIXME: for debug, REMOVE BEFORE RELEASE!

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
    
    if (!this.Config.Has("HOTKEYS"))
      this.Config.HOTKEYS := GetDefaultHotkeysConfig()
  }

  _registerAction(libObj, actionString, className, description) {
    if (this.AvailableActions.Has(actionString)) {
      this.showWarning("Action '" actionString "' from Plugin '"  this.AvailableActions[actionString]["className"] "' overriden by Plugin '" className "'")
    }
    this.AvailableActions[actionString] := Map()
    this.AvailableActions[actionString]["handlerFn"] := ObjBindMethod(libObj, actionString) ; SAME AS libObj.%actionString%.bind(libObj)
    this.AvailableActions[actionString]["className"] := className
    this.AvailableActions[actionString]["description"] := description
  }

  _runHotkeyAction(some*) {
    hkDef := this._assignedHotkeys[A_ThisHotKey]
    ; TODO: HotkeyThrottlingBlacklist?
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
      result.fnName := match[1]
      result.params := StrSplit(match[2], ",", " ")
    } else {
      result.fnName := actionString
    }
    return result
  }

  _getActionHandler(actionName) {
    if (this.AvailableActions.Has(actionName))
      return this.AvailableActions[actionName]['handlerFn']
    try {
      if (%actionName%)
        return %actionName%.bind(A_ThisHotKey)
    } catch {
    }

    this.ShowWarning('Unable to get action handler for ' . actionName)
    return (*) => this.ShowWarning('Unable to get action handler for ' . actionName)
  }
}

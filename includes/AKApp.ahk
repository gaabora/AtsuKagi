class AKApp extends AKBase {
  ; public (let's agree on pascal case)
  AvailableActions := Map()
  AvailableHooks := Map()
  TrayIconDefault := A_ScriptDir "/assets/app.ico"
  TrayIconDisabled := A_ScriptDir "/assets/disabled.ico"
  HotkeyThrottlingTimeout := 50
  ; private (let's agree on camel case)
  _addedLibs := Map()
  _configFile := A_ScriptDir "/config.ini"
  _configFileDefault := A_ScriptDir "/config.ini"
  _assignedHotkeys := Map()
  _toolTipIdsArr := Map()
  
  isAhkHookTakenByRDP := false

  __New(ConfigFile:=0) {

    Loop 20 {
      this._toolTipIdsArr[A_Index] := 0
    }

    this._configFile := (ConfigFile=0) ? this._configFileDefault : ConfigFile
    this.ScriptName := SubStr(A_ScriptName, 1, -4)

    this._initMenu()
    this._initConfig(this._configFile)
    
    reloadAppFn := this.ReloadApp.bind(this)
    if (this.Config.GENERAL.ReloadAppHotkey)
      this.BindHotkey(this.Config.GENERAL.ReloadAppHotkey, reloadAppFn, ,'ReloadApp')

    if (this.Config.GENERAL.SuspendAppHotkey)
      this.BindHotkey(this.Config.GENERAL.SuspendAppHotkey, "ToggleAppSuspend",, 'ToggleAppSuspend') ; FIXME: 1. move into the class and make unsuspend work 

    ; #HotkeyInterval this.Config.GENERAL.HotkeyInterval
    ; #MaxHotkeysPerInterval this.Config.GENERAL.MaxHotkeysPerInterval

    this.setTimer("toolTipOff", 100)
    ; this.setTimer("checkAhkHook", 100)

    this.textToSpeechObj := ComObject("SAPI.SpVoice")
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
      functionName := this.parseActionInfo(action['description']).fnName
      usedActions[functionName] := Map(
        'className', action['className'],
        'description', action['description'],
        'assignedHotkeys', [],
      )
    }

    for key, hkDef in this._assignedHotkeys {
      functionName := functionName := this.parseActionInfo(hkDef['action']).fnName
      if (usedActions.Has(functionName)) {
        usedActions[functionName]['assignedHotkeys'].Push([hkDef['readable']])
      } else {
        this.outputDebugLine('WARN: ' hkDef['action'] ' was not found')
      }
      helpText .= hkDef['readable'] ' (' hkDef['original'] ') ' hkDef['description'] '`n'
    }
    
    helpText .= "`nNot used actions:`n"
    for functionName, usedAction in usedActions {
      if (usedAction['assignedHotkeys'].Length = 0) {
        helpText .= usedAction['className'] '.' usedAction['description'] '`n'
      }
    }

    MsgBox(helpText)
  }

  Speak(text) {
    this.textToSpeechObj.Speak(text)
  }
  
  AddLib(className, debug:=0) {
    libObj := %className%()
    if (!IsObject(libObj)) {
      this.outputDebugLine("AddLib ERROR: Unable to create instance of " className)
      return
    }
    libObj.Debug(debug)
    libObj.App := this
    ; libObj.AvailableActions := this.AvailableActions
    if (!this.Config.Has(className))
      this.Config[className] := {}
    libObj.Config := this.Config[className]
    libObj.ProcessConfig()
    this._addedLibs[className] := libObj
    ; TODO: inject configs in libs

    actions := libObj.__ActionsHelp()
    for actionString, description in actions {
      if (this.AvailableActions.Has(actionString)) {
        this.showWarning("Action '" actionString "' from Plugin '"  this.AvailableActions[actionString]["className"] "' overriden by Plugin '" className "'")
      }
      this.AvailableActions[actionString] := Map()
      this.AvailableActions[actionString]["handlerFn"] := ObjBindMethod(libObj, actionString)
      this.AvailableActions[actionString]["className"] := className
      this.AvailableActions[actionString]["description"] := description
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

  RegisterAppMethod(methodName, handlerFn) {
    errorPrefix := "Error registering new app method"
    if (this.Has(methodName))
      return errorPrefix ": name '" methodName "' is already used"
    ; TODO: similar check if this has function with same name as methodName

    if (Func(handlerFn))
      return errorPrefix ": handlerFn for method '" methodName "' is not a function"
    this[methodName] := Func(handlerFn).Bind(this) ; maybe fix? handlerFn can be string of Bound Func object
    return 0
  }
  
  BindAll() {
    runHotkeyActionFn := this.runHotkeyAction.bind(this)

    if (this.Config.Has("HOTKEYS")) {
      For k, v In this.Config.HOTKEYS {
        this.BindHotkey(k, runHotkeyActionFn, v, v)
      }
    }
  }

  ReloadApp() {
    this.ShowInfo("Reloading " this.ScriptName " ...")
    sleep 1000
    Reload
    return
  }

  SoundPlay(fileName) {
    SoundPlay(fileName)
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

  ToolTip(text, x:=-1, y:=-1, msec:=1000, forceIdx:=0) {
    idx := (forceIdx = 0) ? this.getFreeTooltipId() : forceIdx
    expireTime := A_TickCount + msec
    this._toolTipIdsArr[idx] := expireTime

    ToolTip(text, x, y, idx) ; , this.themeSettings)
    
    return idx
  }

  BindHotkey(KeyCombination, HandlerFn, HandlerName:="", description:="") {
    actionString := IsObject(HandlerFn) ? HandlerName : HandlerFn
    actionInfo := this.parseActionInfo(actionString)
    hkDef := Map()
    hkDef['description'] := description
    hkDef['original'] := KeyCombination
    hkDef['universal'] := convertToUniversalVkHotkey(KeyCombination)
    hkDef['readable'] := convertToReadableHotkey(KeyCombination)
    hkDef['action'] := actionString
    hkDef['handler'] := this.getActionHandler(actionInfo.fnName)
    hkDef['params'] := actionInfo.params

    hkDef['description'] " " 
    universalHotkey := (KeyCombination = hkDef['universal']) ? "" : " (" hkDef['universal'] ")"
    debugText := "Setting " KeyCombination . universalHotkey " [ " hkDef['readable'] " ] " hkDef['description']
    errorPrefix := "Error setting hotkey"
    if (hkDef['action'] != "" && hkDef['handler'] = -1) {
      hotkeyError := "Action not found"
      this.outputDebugLine("ERROR " debugText " FAILED: " hotkeyError)
      return errorPrefix " " KeyCombination "=" hkDef['action'] ": " hotkeyError
    }

    try
      Hotkey(hkDef['universal'], HandlerFn, "On")
    catch Error as err {
      hotkeyError := Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
        , type(err), err.Message, err.File, err.Line, err.What, err.Stack)
 
      this.outputDebugLine(debugText " FAILED: " hotkeyError)
      return errorPrefix " " KeyCombination "=" hkDef['action'] ": " hotkeyError
    }

    this._assignedHotkeys[hkDef['universal']] := hkDef
    this.outputDebugLine(debugText " OK")
    return 0
  }

  RunAction(ActionString) {
    actionInfo := this.parseActionInfo(ActionString)
    actionHandler := this.getActionHandler(actionInfo.fnName)
    return this._callActionHandler(actionHandler, actionInfo.params)
  }

  IsKeyboardHookStealerWindowActive() {
    ; WinActive("ahk_class Notepad") or WinActive("ahk_class" ClassName)
    return (WinActive("ahk_class TscShellContainerClass"))
  }

  IsWindowBlacklisted(hwnd:=0, method:=0) {
    ; TODO: per method blacklist check
    windowClass := GetWindowClass(hwnd)
    isBlacklisted := (InStr(this.Config.GENERAL.BlacklistedWindowAhkIds, windowClass, false) != 0)
    ; if (isBlacklisted)
    this.outputDebugLine(((isBlacklisted) ? "BLACKLISTED " : "OK ") "" windowClass " hwnd=" hwnd)
    return isBlacklisted
  }

  IsRDPClientWindowActive() { ;;;
    return WinActive("ahk_class TscShellContainerClass")
  }

  setTimer(method, period){
    fn := this.%method%.bind(this)
    SetTimer(fn,period)
    return &fn ; TODO: delete timer fn
  }

  checkAhkHook() {

    if (WinActive("ahk_class TscShellContainerClass")) {
      if (!this.isAhkHookTakenByRDP) {
        this.isAhkHookTakenByRDP := true
        ; Short sleep to make sure the remote desktop keyboard hook is active
        Sleep 100
        ; Coming out of suspend mode recreates the keyboard hook, giving
        ; our hook priority over the remote desktop client's.
        Suspend False
        ; this.ToggleAppSuspend()

        SoundBeep 880
        
      }
    } else {
      if (this.isAhkHookTakenByRDP) {
        this.isAhkHookTakenByRDP := false
        Suspend True
        ; this.ToggleAppSuspend()

        SoundBeep 1760
      }
    }



  }
  toolTipOff() {
    for idx, val in this._toolTipIdsArr {
      if (val > 0 && A_TickCount >= val) {
        
        ToolTip(,,, idx) ; remove tooltip

        this._toolTipIdsArr[idx] := 0
      }
    }
  }

  _initMenu() {
    Tray:= A_TrayMenu
    Tray.Delete()
    fn := this.menuHandler.bind(this)
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

  menuHandler(ItemName, ItemPos, MyMenu) {
    Switch (ItemName) {
      Case "Test":
        this.TestActions()
        return
      Case "KeyHistory":
        KeyHistory
        return
      Case "Help":
        this.ShowHelp()
        return
      Case "Settings":
        ConfigFile := this._configFile
        RunWait(ConfigFile)
        this.ReloadApp()
        return
      Case "Reload":
        this.ReloadApp()
        return
      Case "Disable":
        ToggleAppSuspend() ; FIXME: 1.
        return
      Case "Exit":
        ExitApp
        return
      Default:
        this.ShowInfo("no action for " ItemName)
        return
    }
  }

  _initConfig(ConfigFile) {



    ; FileDelete(ConfigFile) ; FIXME: for debug, REMOVE BEFORE RELEASE!




    if !FileExist(ConfigFile) {
      DefaultSettings := ""
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
      this.Config.HOTKEYS := getDefaultHotkeysConfig()
  }

  getFreeTooltipId() {
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

  runHotkeyAction(some*) {

    if (WinActive("ahk_class TscShellContainerClass")) {
      SoundBeep 440

      Send("{LCtrl down}{LAlt down}{Home}{LAlt up}{LCtrl up}")
      Sleep 500
    }

    ; Sleep 50
    ; WinMinimize ahk_class TscShellContainerClass
    ; if (WinActive(ahk_class TscShellContainerClass))
    ;   WinActivate, ahk_class Shell_TrayWnd
    ; if (WinActive("ahk_class TscShellContainerClass")) {
    ;   WinActivate, ahk_class Shell_TrayWnd
    ; }


    ; if(WinActive("ahk_class TscShellContainerClass")) {
    ;   ; Store the title of the topmost one
    ;   WinGetActiveTitle, RDCMWindowTitle
    ;   Loop {
    ;       ; Need a short sleep here for focus to restore properly.
    ;       Sleep 50
    ;       ; WinMinimize
    ;       ; this.getCenterPos(centerX, centerY)
    ;       ; this.getWinAtPos(centerX, centerY, title)
    ;       ; WinActivate % title
    ;       WinActivate, ahk_class WorkerW ; Shell_TrayWnd

    ;       ; Continue to minimize other RDP windows
    ;   } Until (!WinActive("ahk_class TscShellContainerClass"))
    ;   ;this.ShowInfo(RDCMWindowTitle, "Minimized")
    ; }

    hkDef := this._assignedHotkeys[A_ThisHotKey]
    ; keyCombination := hkDef['original']

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

  parseActionInfo(actionString) {
    result := { fnName: "", params: [] }
    if RegExMatch(actionString, "(\w+)\((.*)\)", &match) {
      result.fnName := match[1]
      result.params := StrSplit(match[2], ",", " ")
    } else {
      result.fnName := actionString
    }
    return result
  }

  getActionHandler(actionName) {
    if (this.AvailableActions.Has(actionName))
      return this.AvailableActions[actionName]['handlerFn']
    if (HasMethod(actionName))
      return actionName
    return -1
  }
}

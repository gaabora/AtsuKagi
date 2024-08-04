class AKApp extends AKBase {
  ; public (let's agree on pascal case)
  AvailableActions := Map()
  AvailableHooks := Map()
  TrayIconDefault := A_ScriptDir "/assets/app.ico"
  TrayIconDisabled := A_ScriptDir "/assets/disabled.ico"
  HotkeyThrottlingTimeout := 50
  ; private (let's agree on camel case)
  __addedLibs := Map()
  __configFileDefault := A_ScriptDir "/config.ini"
  __mappedHotkeys := Map()
  ; __runningTimers := Map()
  __toolTipIdsArr := Map()
  
  isAhkHookTakenByRDP := false

  __New(ConfigFile:=0) {

    Loop 20 {
      this.__toolTipIdsArr[A_Index] := 0
    }

    this.configFile := (ConfigFile=0) ? this.__configFileDefault : ConfigFile
    this.ScriptName := SubStr(A_ScriptName, 1, -4)

    this.initMenu()
    this.initConfig(this.configFile)
    
    reloadAppFn := this.ReloadApp.bind(this)
    if (this.Config.GENERAL.ReloadAppHotkey)
      this.BindHotkey(this.Config.GENERAL.ReloadAppHotkey, reloadAppFn)

    if (this.Config.GENERAL.SuspendAppHotkey)
      this.BindHotkey(this.Config.GENERAL.SuspendAppHotkey, "ToggleAppSuspend") ; FIXME: 1. move into the class and make unsuspend work 

    ; #HotkeyInterval this.Config.GENERAL.HotkeyInterval
    ; #MaxHotkeysPerInterval this.Config.GENERAL.MaxHotkeysPerInterval

    this.setTimer("toolTipOff", 100)
    this.setTimer("checkAhkHook", 100)

    this.textToSpeechObj := ComObject("SAPI.SpVoice")
  }

  ShowHelp() {
    helpText := ""
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
    libObj.Config := this.Config.%className%
    libObj.processConfig()
    this.__addedLibs[className] := libObj
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
    runRemapFn := this.runRemap.bind(this)
    runHotkeyActionFn := this.runHotkeyAction.bind(this)

    if (this.Config.Has("Remaps")) {
      For k, v In this.Config.Remaps 
        this.BindHotkey(k, runRemapFn)
    }
    if (this.Config.Has("Hotkeys")) {
      For k, v In this.Config.Hotkeys
        this.BindHotkey(k, runHotkeyActionFn, v)
    }
    if (this.Config.Has("TitlebarActions")) {
      For k, v In this.Config.TitlebarActions
        this.BindHotkey(k, runHotkeyActionFn, v)
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

  ToolTip(text, x:="", y:="", msec:=1000, forceIdx:=0) {
    idx := (forceIdx = 0) ? this.getFreeTooltipId() : forceIdx
    expireTime := A_TickCount + msec
    this.__toolTipIdsArr[idx] := expireTime
    ToolTip(text, x, y, idx) ; , this.tooltipStyle)
    return idx
  }

  BindHotkey(KeyCombination, HandlerFn, WrappedFn:="") {
    actionString := IsObject(HandlerFn) ? WrappedFn : HandlerFn
    universalKey := convertToUniversalVkHotkey(KeyCombination)
    actionInfo := this.extractActionInfo(actionString)
    actionHandler := this.getActionHandler(actionInfo.fnName)
    debugText := "SET " KeyCombination " " ((KeyCombination = universalKey) ? "" : "(" universalKey ")" ) " " actionString
    errorPrefix := "Error setting hotkey"
    if (actionString != "" && actionHandler = -1) {
      hotkeyError := "Action not found"
      this.outputDebugLine(debugText " FAILED: " hotkeyError)
      return errorPrefix " " KeyCombination "=" actionString ": " hotkeyError
    }

    try
      Hotkey(universalKey, HandlerFn, "On UseErrorLevel")
    catch Error as err {
      hotkeyError := Format("{1}: {2}.`n`nFile:`t{3}`nLine:`t{4}`nWhat:`t{5}`nStack:`n{6}"
			  , type(err), err.Message, err.File, err.Line, err.What, err.Stack)
 
      this.outputDebugLine(debugText " FAILED: " hotkeyError)
      return errorPrefix " " KeyCombination "=" actionString ": " hotkeyError
    }

    this.__mappedHotkeys[universalKey] := KeyCombination
    this.outputDebugLine(debugText " OK")
    return 0
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
    for idx, val in this.__toolTipIdsArr {
      if (val > 0 && A_TickCount >= val) {
        ToolTip(,,, idx) ; remove tooltip
        this.__toolTipIdsArr[idx] := 0
      }
    }
  }

  initMenu() {
    Tray:= A_TrayMenu
    Tray.Delete()
    fn := this.menuHandler.bind(this)
    if (this.debugLevel = 0)
      Tray.Delete() ; V1toV2: not 100% replacement of NoStandard, Only if NoStandard is used at the beginning
    TraySetIcon(this.TrayIconDefault, "1")
    ; this.runMenuHooks() ; TODO
    Tray.Add("Help", fn)
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
      Case "Help":
        this.ShowHelp()
        return
      Case "Settings":
        ConfigFile := this.configFile
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

  initConfig(ConfigFile) {



    ; FileDelete(ConfigFile) ; FIXME: for debug, REMOVE BEFORE RELEASE!




    if !FileExist(ConfigFile) {
      DefaultSettings := ""
      FileAppend(DefaultSettings, ConfigFile)
    }

    this.Config := IniFile(ConfigFile)

    if (!this.Config.Has("GENERAL"))
      this.Config.GENERAL := {}

    general := this.Config.GENERAL
    processGereralConfigSection(general)
    processWindowManagementConfigSection(this.Config.WindowManagement)
    this.tooltipStyle := getTooltipStyleConfig(this.Config.GENERAL.DarkTheme)
    
    if (!this.Config.Has("TitlebarActions"))
      this.Config.TitlebarActions := getDefaultTitlebarActionsConfig()
    
    if (!this.Config.Has("TaskbarActions"))
      this.Config.TaskbarActions := getDefaultTaskbarActionsConfig()
    
    if (!this.Config.Has("Hotkeys"))
      this.Config.Hotkeys := getDefaultHotkeysConfig()

    if (!this.Config.Has("Remaps"))
      this.Config.Remaps := getDefaultRemapsConfig()

  }

  getFreeTooltipId() {
    closestIdx := 1
    closestVal := A_TickCount + 10000
    for idx, val in this.__toolTipIdsArr {
      if val = 0
        return idx
      if (closestVal > val) {
        closestVal := val
        closestIdx := idx
      }
    }
    return closestIdx
  }

  runRemap() {
    key := this.Config.Remaps[A_ThisHotkey]
    if (key = "")
      return
    SendInput("{" key "}")
  }

  runHotkeyAction() {

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

    keyCombination := this.__mappedHotkeys[A_ThisHotKey]

    if (A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < this.HotkeyThrottlingTimeout) {
      this.outputDebugLine("Hotkey " keyCombination " throttled")
      return
    }
    
    if (isMouseOverWindowTitlebar())
      actionString := this.Config.TitlebarActions[keyCombination]

    if (!actionString)
      actionString := this.Config.Hotkeys[keyCombination]

    this.outputDebugLine(keyCombination " runs action: " actionString)

    if (actionString = "")
      return
    
    actionInfo := this.extractActionInfo(actionString)
    actionHandler := this.getActionHandler(actionInfo.fnName)
    paramsArr := actionInfo.params
    if (paramsArr.Length() > 0) {
      if (IsObject(actionHandler))
        actionHandler.Call(paramsArr*)
      else
        %actionHandler%(paramsArr*)
    } else {
      if (IsObject(actionHandler))
        actionHandler.Call()
      else
        %actionHandler%()
    }
  }

  extractActionInfo(actionString) {
    result := { fnName: "", params: [] }
    if RegExMatch(actionString, "(\w+)\(([^)]*)\)", &match) {
      result.fnName := match[1]
      result.params := StrSplit(match[2], ",", " ")
    } else {
      result.fnName := actionString
    }
    return result
  }

  getActionHandler(actionName) {
    if (this.AvailableActions.Has(actionName))
      return this.AvailableActions[actionName].handlerFn
    if (HasMethod(actionName))
      return actionName
    return -1
  }
}

class AKApp extends AKBase {
  ; public (let's agree on pascal case)
  AvailableActions := {}
  AvailableHooks := {}
  TrayIconDefault := A_ScriptDir "/assets/app.ico"
  TrayIconDisabled := A_ScriptDir "/assets/disabled.ico"
  HotkeyThrottlingTimeout := 50
  ; private (let's agree on camel case)
  addedLibs := {}
  configFileDefault := A_ScriptDir "/config.ini"
  mappedHotkeys := {}
  runningTimers := {}
  toolTipIdsArr := {1:0,2:0,3:0,4:0,5:0,6:0,7:0,8:0,9:0,10:0,11:0,12:0,13:0,14:0,15:0,16:0,17:0,18:0,19:0,20:0}
  
  isAhkHookTakenByRDP := false

  __New(ConfigFile:=0) {
    this.configFile := (ConfigFile=0) ? this.configFileDefault : ConfigFile
    this.ScriptName := SubStr(A_ScriptName, 1, -4)

    this.initMenu()
    this.initConfig(this.configFile)
    
    reloadAppFn := this.ReloadApp.bind(this)
    if (this.Config.GENERAL.ReloadAppHotkey)
      this.BindHotkey(this.Config.GENERAL.ReloadAppHotkey, reloadAppFn)

    if (this.Config.GENERAL.SuspendAppHotkey)
      this.BindHotkey(this.Config.GENERAL.SuspendAppHotkey, "ToggleAppSuspend") ; FIXME: 1. move into the class and make unsuspend work 

    #HotkeyInterval this.Config.GENERAL.HotkeyInterval
    #MaxHotkeysPerInterval this.Config.GENERAL.MaxHotkeysPerInterval

    this.setTimer("toolTipOff", 100)
    this.setTimer("checkAhkHook", 100)

    this.textToSpeechObj := ComObjCreate("SAPI.SpVoice")
  }

  ShowHelp() {
    helpText := ""
    MsgBox, %helpText%
  }

  Speak(text) {
    this.textToSpeechObj.Speak(text)
  }
  
  AddLib(className, debug:=0) {
    libObj := new %className%()
    if (!IsObject(libObj)) {
      this.outputDebugLine("AddLib ERROR: Unable to create instance of " className)
      return
    }
    libObj.Debug(debug)
    libObj.App := this
    ; libObj.AvailableActions := this.AvailableActions
    libObj.Config := this.Config[className]
    this.addedLibs[className] := libObj
    ; TODO: inject configs in libs

    actions := libObj.__ActionsHelp()
    for actionString, description in actions {
      if (this.AvailableActions.HasKey(actionString)) {
        this.showWarning("Action '" actionString "' from Plugin '"  this.AvailableActions[actionString]["className"] "' overriden by Plugin '" className "'")
      }
      this.AvailableActions[actionString] := {}
      this.AvailableActions[actionString]["handlerFn"] := ObjBindMethod(libObj, actionString)
      this.AvailableActions[actionString]["className"] := className
      this.AvailableActions[actionString]["description"] := description
    }

    ; hooks := libObj.__HooksHelp()
    ; for hookString, description in hooks {
    ;   if (this.AvailableHooks.HasKey(hookString)) {
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
    if (this.HasKey(methodName))
      return errorPrefix ": name '" methodName "' is already used"
    ; TODO: similar check if this has function with same name as methodName

    if (IsFunc(handlerFn))
      return errorPrefix ": handlerFn for method '" methodName "' is not a function"
    this[methodName] := Func(handlerFn).Bind(this) ; maybe fix? handlerFn can be string of Bound Func object
    return 0
  }
  
  BindAll() {
    runRemapFn := this.runRemap.bind(this)
    runHotkeyActionFn := this.runHotkeyAction.bind(this)

    if (this.Config.HasKey("Remaps")) {
      For k, v In this.Config.Remaps 
        this.BindHotkey(k, runRemapFn)
    }
    if (this.Config.HasKey("Hotkeys")) {
      For k, v In this.Config.Hotkeys
        this.BindHotkey(k, runHotkeyActionFn, v)
    }
    if (this.Config.HasKey("TitlebarActions")) {
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
    SoundPlay, %fileName%
  }

  ToggleAppSuspend() {
    ; Suspend ; FIXME: 1.
    Menu, Tray, ToggleCheck, Disable
    this.ShowInfo(this.ScriptName " " (A_IsSuspended ? "DISABLED" : "ENABLED"))
    if (A_IsSuspended) {
      Menu, Tray, Icon, % this.TrayIconDisabled,, 1
    } else {
      Menu, Tray, Icon, % this.TrayIconDefault,, 1
    }
    return
  }

  ToolTip(text, x:="", y:="", msec:=1000, forceIdx:=0) {
    idx := (forceIdx = 0) ? this.getFreeTooltipId() : forceIdx
    expireTime := A_TickCount + msec
    this.toolTipIdsArr[idx] := expireTime
    btt(text, x, y, idx, this.tooltipStyle)
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

    Hotkey, %universalKey%, %HandlerFn%, On UseErrorLevel

    hotkeyError := GetHotkeyBindingErrorText(ErrorLevel)
    if (hotkeyError != 0) {
      this.outputDebugLine(debugText " FAILED: " hotkeyError)
      return errorPrefix " " KeyCombination "=" actionString ": " hotkeyError
    }

    this.mappedHotkeys[universalKey] := KeyCombination
    this.outputDebugLine(debugText " OK")
    return 0
  }

  IsKeyboardHookStealerWindowActive() {
    WinActive("ahk_class Notepad") or WinActive("ahk_class" ClassName)
    return (WinActive("ahk_class TscShellContainerClass"))
  }

  IsWindowBlacklisted(hwnd=0, method:=0) {
    ; TODO: per method blacklist check
    windowClass := GetWindowClass(hwnd)
    isBlacklisted := (InStr(this.Config.GENERAL.BlacklistedWindowAhkIds, windowClass, CaseSensitive = false) != 0)
    ; if (isBlacklisted)
    this.outputDebugLine(((isBlacklisted) ? "BLACKLISTED " : "OK ") "" windowClass " hwnd=" hwnd)
    return isBlacklisted
  }

  IsRDPClientWindowActive() { ;;;
    return WinActive("ahk_class TscShellContainerClass")
  }

  setTimer(method, period){
		local
		fn := this[method].bind(this)
		SetTimer % fn, % period
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
        suspend off
        ; this.ToggleAppSuspend()

        SoundBeep 880
        
      }
    } else {
      if (this.isAhkHookTakenByRDP) {
        this.isAhkHookTakenByRDP := false
        suspend on
        ; this.ToggleAppSuspend()

        SoundBeep 1760
      }
    }



  }
  toolTipOff() {
    for idx, val in this.toolTipIdsArr {
      if (val > 0 && A_TickCount >= val) {
        btt(,,, idx) ; remove tooltip
        this.toolTipIdsArr[idx] := 0
      }
    }
  }

  initMenu() {
    Menu, Tray, DeleteAll
    fn := this.menuHandler.bind(this)
    if (this.debugLevel = 0)
      Menu, Tray, NoStandard
    Menu, Tray, Icon, % this.TrayIconDefault,, 1
    this.runMenuHooks()
    Menu, Tray, Add, Help, % fn
    Menu, Tray, Add
    Menu, Tray, Add, Settings, % fn
    Menu, Tray, Add
    Menu, Tray, Add, Reload, % fn
    Menu, Tray, Add, Disable, % fn
    Menu, Tray, Add
    Menu, Tray, Add, Exit, % fn
  }

  menuHandler() {
    Switch (A_ThisMenuItem) {
      Case "Help":
        this.ShowHelp()
        return
      Case "Settings":
        ConfigFile := this.configFile
        RunWait, %ConfigFile%
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
        this.ShowInfo("no action for " A_ThisMenuItem)
        return
    }
  }

  initConfig(ConfigFile) {



    FileDelete, %ConfigFile% ; FIXME: for debug, REMOVE BEFORE RELEASE!




    if !FileExist(ConfigFile) {
      DefaultSettings := ""
      FileAppend, %DefaultSettings%, %ConfigFile%
    }

    this.Config := Ini(ConfigFile)

    if (!this.Config.HasKey("GENERAL"))
      this.Config.GENERAL := {}

    processGereralConfigSection(this.Config.GENERAL)
    processWindowManagementConfigSection(this.Config.WindowManagement)
    this.tooltipStyle := getTooltipStyleConfig(this.Config.GENERAL.DarkTheme)
    
    if (!this.Config.HasKey("TitlebarActions"))
      this.Config.TitlebarActions := getDefaultTitlebarActionsConfig()
    
    if (!this.Config.HasKey("TaskbarActions"))
      this.Config.TaskbarActions := getDefaultTaskbarActionsConfig()
    
    if (!this.Config.HasKey("Hotkeys"))
      this.Config.Hotkeys := getDefaultHotkeysConfig()

    if (!this.Config.HasKey("Remaps"))
      this.Config.Remaps := getDefaultRemapsConfig()

  }

  getFreeTooltipId() {
    closestIdx := 1
    closestVal := A_TickCount + 10000
    for idx, val in this.toolTipIdsArr {
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
    SendInput {%key%}
  }

  runHotkeyAction() {

    if (WinActive("ahk_class TscShellContainerClass")) {
      SoundBeep 440

      Send {LCtrl down}{LAlt down}{Home}{LAlt up}{LCtrl up}
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

    keyCombination := this.mappedHotkeys[A_ThisHotKey]

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
    if RegExMatch(actionString, "(\w+)\(([^)]*)\)", match) {
      result.fnName := match1
      result.params := StrSplit(match2, ",", " ")
    } else {
      result.fnName := actionString
    }
    return result
  }

  getActionHandler(actionName) {
    if (this.AvailableActions.HasKey(actionName))
      return this.AvailableActions[actionName].handlerFn
    if (Func(actionName))
      return actionName
    return -1
  }
}

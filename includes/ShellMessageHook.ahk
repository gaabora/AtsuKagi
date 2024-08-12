class ShellMessageHook extends AKPlugin {
  static HSHELL_WINDOWCREATED       := 1
  static HSHELL_WINDOWDESTROYED     := 2
  static HSHELL_ACTIVATESHELLWINDOW := 3
  static HSHELL_WINDOWACTIVATED     := 4
  static HSHELL_GETMINRECT          := 5
  static HSHELL_REDRAW              := 6
  static HSHELL_TASKMAN             := 7
  static HSHELL_LANGUAGE            := 8
  static HSHELL_SYSMENU             := 9
  static HSHELL_ENDTASK             := 10
  static HSHELL_ACCESSIBILITYSTATE  := 11
  static HSHELL_APPCOMMAND          := 12
  static HSHELL_WINDOWREPLACED      := 13
  static HSHELL_WINDOWREPLACING     := 14
  static HSHELL_HIGHBIT             := 15
  static HSHELL_FLASH               := 16
  static HSHELL_RUDEAPPACTIVATED    := 17
  static messageNames := { 1: "WINDOW_CREATED", 2: "WINDOW_DESTROYED", 3: "ACTIVATE_SHELL_WINDOW", 4: "WINDOW_ACTIVATED", 5: "GET_MIN_RECT", 6: "REDRAW", 7: "TASK_MAN", 8: "LANGUAGE", 9: "SYS_MENU", 10: "END_TASK", 11: "ACCESSIBILITY_STATE", 12: "APP_COMMAND", 13: "WINDOW_REPLACED", 14: "WINDOW_REPLACING", 15: "HIGH_BIT", 16: "FLASH", 17: "RUDE_APP_ACTIVATED" }

  eventListeners := { "WindowCreated": [], "WindowActivated": [], "WindowDestroyed": [] }

  __New(config:=0) {
    Gui +LastFound
    hWnd := WinExist()
    onShellMessageFn := this.onShellMessage.bind(this)
    DllCall("RegisterShellHookWindow", UInt,hWnd)
    MsgNum := DllCall("RegisterWindowMessage", Str, "SHELLHOOK")
    OnMessage(MsgNum, onShellMessageFn)
  }

  __UsageHelp() {
    return ""
  }

  __HooksHelp() {
    texts := Map()
    texts["AddEventListener"] := "AddEventListener(eventName, callbackFn)"
    return texts
  }

  ; TODO: RemoveEventListener support?
  AddEventListener(eventName, callbackFn) { ;;;
    errorPrefix := "Error adding event listener"
    if (!this.eventListeners.Has(eventName))
      return errorPrefix ": Unsupported event '" eventName "'. Supported: " Join(Object.Keys(this.eventListeners), ", ")
    if (IsFunc(callbackFn))
      return errorPrefix ": callbackFn for event '" eventName "' is not a function"

    this.eventListeners[eventName].Push(callbackFn)
    return 0
  }

  onShellMessage(msgId, hwnd) { ; actually it has 4 params: wParam, lParam, msg, hwnd, but let's rename/ignore them to avoid bs names confusion
    this.outputDebugLine("msgId=" msgId " hwnd=" hwnd )
    this.processMessage(msgId, hwnd)
  }

  processMessage(msgId, hwnd) {
    Switch (msgId) {
      Case this.HSHELL_WINDOWCREATED:
        return this.runMessageCallbacks("WindowCreated", hwnd)
      Case this.HSHELL_WINDOWDESTROYED:
        return this.runMessageCallbacks("WindowActivated", hwnd)
      Case this.HSHELL_WINDOWACTIVATED:
        return this.runMessageCallbacks("WindowDestroyed", hwnd)
      Case this.HSHELL_ACTIVATESHELLWINDOW:
      Case this.HSHELL_GETMINRECT:
      Case this.HSHELL_REDRAW:
      Case this.HSHELL_TASKMAN:
      Case this.HSHELL_LANGUAGE:
      Case this.HSHELL_SYSMENU:
      Case this.HSHELL_ENDTASK:
      Case this.HSHELL_ACCESSIBILITYSTATE:
      Case this.HSHELL_APPCOMMAND:
      Case this.HSHELL_WINDOWREPLACED:
      Case this.HSHELL_WINDOWREPLACING:
      Case this.HSHELL_HIGHBIT:
      Case this.HSHELL_FLASH:
      Case this.HSHELL_RUDEAPPACTIVATED:
        return this.outputDebugLine("skip " messageNames[msgId] " from hwnd=" hwnd)
      Default:
        return this.outputDebugLine("skip unknown msgId=" msgId " from hwnd=" hwnd)
    }
  }

  runMessageCallbacks(eventName, hwnd) {
    for idx, callbackFn in  this.eventListeners[eventName] {
        %callbackFn%(hwnd)
    }
  }

  ; WinGetTitle, title, ahk_id %hwnd%
  ; WinGet, pname, ProcessName, ahk_id %hwnd%
  ; WinGet, pid, PID, ahk_id %hwnd%

  
  ; If wParam not in %Filters%
  ; {
  ;   If ( Pause = 0 )
  ;   {  
  ;     DecToHex( lParam )
  ;     LV_Add( "", lParam, pname, wParam, msg )
  ;     SendMessage, WM_VSCROLL, SB_BOTTOM, 0, SysListView321, ahk_id %Hwnd%    
  ;   }  
  ; }  

  


  ; msgCode := wParam
  ; ass := MsgNames[msgCode]
  
  ; WinGetTitle, Title, ahk_id %hwnd%
  ; WinGetClass, WinClass, ahk_id %hwnd%
    

  ; watchActiveWindow() {
  ;   hwnd := WinGetID("A")
  ;   windowClass := GetWindowClass(hwnd)

  ;   ; if (InStr(this.Config.GENERAL.KeyboardHookStealersList, windowClass, CaseSensitive = false) != 0) {
  ;   if WinActive("ahk_class TscShellContainerClass") {
  ;     this.outputDebugLine("RDP ACTIVE")
  ;     Suspend on
  ;     Sleep 50
  ;     Suspend off
  ;     this.outputDebugLine("RDP ...")
  ;   }
  ; }

 
}





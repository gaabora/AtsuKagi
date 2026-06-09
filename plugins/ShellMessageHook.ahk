class ShellMessageHook extends AKPlugin { ; FIXME: not used yet. not fully tested
  eventListeners := Map("WindowCreated", [], "WindowActivated", [], "WindowDestroyed", [])

  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "ShellMessageHook",
        "title", "Shell Message Hook",
        "description", "Internal hook system for window creation/destruction/activation events. Plugins can register listeners via AddEventListener()",
        "category", "Window Management"
      ),
      ; "page", Map(
      ;   "description", "Configure shell hook event monitoring",
      ;   "icon", "icons10-window"
      ; ),
      "config", [],
      "actions", [],
      "hooks", [
        Map(
          "hook", "AddEventListener",
          "label", "Add event listener",
          "description", "Register a callback for window events (WindowCreated, WindowActivated, WindowDestroyed)",
          "params", ["eventName", "callbackFn"],
          "category", "Window Events"
        )
      ]
    )
  }

  _processPluginConfig() {
    ; No plugin-specific config to apply
  }

  __New(App) {
    super.__New(App)
    DllCall('RegisterShellHookWindow', 'UInt', A_ScriptHwnd)
    MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    onShellMessageFn := this.onShellMessage.bind(this)
    OnMessage(MsgNum, onShellMessageFn)
  }

  ; TODO: RemoveEventListener support?
  AddEventListener(eventName, handlerFn) { ;;;
    errorPrefix := "Error adding event listener"

    handlerFnType := Type(handlerFn)
    if (handlerFnType != 'BoundFunc')
      return errorPrefix ": HandlerFn parameter must be of type BoundFunc, but got " . handlerFnType

    if (!this.eventListeners.Has(eventName))
      return errorPrefix ": Unsupported event '" eventName "'. Supported: " Join(["WindowCreated", "WindowActivated", "WindowDestroyed"], ", ")

    this.eventListeners[eventName].Push(handlerFn)
    return 0
  }

  onShellMessage(wParam, lParam, msg, hwnd) {
    eventId := wParam
    targetHwnd := lParam
    this.outputDebugLine(AKApp.LOG_TRACE, this.formatShellEventDebug(eventId, targetHwnd))
    this.processMessage(eventId, targetHwnd)
  }

  formatShellEventDebug(msgId, hwnd) {
    eventName := ShellHookCodes.Names.Has(msgId)
      ? ShellHookCodes.Names[msgId]
      : "UNKNOWN"
    return "shell event=" eventName " (" msgId ") " this.formatWindowDebugInfo(hwnd)
  }

  formatWindowDebugInfo(hwnd) {
    if (!hwnd)
      return "hwnd=0"

    winSelector := "ahk_id " hwnd

    try title := WinGetTitle(winSelector)
    catch
      title := ""

    try winClass := WinGetClass(winSelector)
    catch
      winClass := ""

    try processName := WinGetProcessName(winSelector)
    catch
      processName := ""

    try pid := WinGetPID(winSelector)
    catch
      pid := ""

    if (title = "")
      title := "<no title>"
    if (winClass = "")
      winClass := "<unknown class>"
    if (processName = "")
      processName := "<unknown process>"
    if (pid = "")
      pid := "?"

    return "hwnd=" hwnd " pid=" pid " proc=" processName " class=" winClass " title='" title "'"
  }

  processMessage(msgId, hwnd) {
    switch (msgId) {
      case ShellHookCodes.WINDOWCREATED:
        return this.runMessageCallbacks("WindowCreated", hwnd)
      case ShellHookCodes.WINDOWDESTROYED:
        return this.runMessageCallbacks("WindowDestroyed", hwnd)
      case ShellHookCodes.WINDOWACTIVATED:
        return this.runMessageCallbacks("WindowActivated", hwnd)
      case ShellHookCodes.ACTIVATESHELLWINDOW:
      case ShellHookCodes.GETMINRECT:
      case ShellHookCodes.REDRAW:
      case ShellHookCodes.TASKMAN:
      case ShellHookCodes.LANGUAGE:
      case ShellHookCodes.SYSMENU:
      case ShellHookCodes.ENDTASK:
      case ShellHookCodes.ACCESSIBILITYSTATE:
      case ShellHookCodes.APPCOMMAND:
      case ShellHookCodes.WINDOWREPLACED:
      case ShellHookCodes.WINDOWREPLACING:
      case ShellHookCodes.HIGHBIT:
      case ShellHookCodes.FLASH:
      case ShellHookCodes.RUDEAPPACTIVATED:
        return this.outputDebugLine(AKApp.LOG_NOTICE, "skip " ShellHookCodes.Names[msgId] " from hwnd=" hwnd)
      Default:
        return this.outputDebugLine(AKApp.LOG_NOTICE, "skip unknown msgId=" msgId " from hwnd=" hwnd)
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
  ;     this.outputDebugLine(AKApp.LOG_DEBUG, "RDP ACTIVE")
  ;     Suspend on
  ;     Sleep 50
  ;     Suspend off
  ;     this.outputDebugLine(AKApp.LOG_DEBUG, "RDP ...")
  ;   }
  ; }

 
}





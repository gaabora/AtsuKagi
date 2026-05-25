class ShellMessageHook extends AKPlugin { ; FIXME: not used yet. not fully tested
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
  static messageNames := Map(
    1, "WINDOW_CREATED",
    2, "WINDOW_DESTROYED",
    3, "ACTIVATE_SHELL_WINDOW",
    4, "WINDOW_ACTIVATED",
    5, "GET_MIN_RECT",
    6, "REDRAW",
    7, "TASK_MAN",
    8, "LANGUAGE",
    9, "SYS_MENU",
    10, "END_TASK",
    11, "ACCESSIBILITY_STATE",
    12, "APP_COMMAND",
    13, "WINDOW_REPLACED",
    14, "WINDOW_REPLACING",
    15, "HIGH_BIT",
    16, "FLASH",
    17, "RUDE_APP_ACTIVATED"
  )

  eventListeners := Map("WindowCreated", [], "WindowActivated", [], "WindowDestroyed", [])

  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "ShellMessageHook",
        "title", "Shell Message Hook",
        "description", "Internal hook system for window creation/destruction/activation events. Plugins can register listeners via AddEventListener().",
        "category", "Window Management"
      ),
      ; "page", Map(
      ;   "description", "Configure shell hook event monitoring.",
      ;   "icon", "icons10-window"
      ; ),
      "config", [],
      "actions", [],
      "hooks", [
        Map(
          "hook", "AddEventListener",
          "label", "Add event listener",
          "description", "Register a callback for window events (WindowCreated, WindowActivated, WindowDestroyed).",
          "params", ["eventName", "callbackFn"],
          "category", "Window Events"
        )
      ]
    )
  }

  ; ── Legacy Methods (Phase 1-5: TODO: remove after Phase 5) ─────────────────────
  ; These are now derived from __DescribePlugin() by the base class
  _processBlocklistConfig() {
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
    this.outputDebugLine(this.formatShellEventDebug(eventId, targetHwnd))
    this.processMessage(eventId, targetHwnd)
  }

  formatShellEventDebug(msgId, hwnd) {
    eventName := ShellMessageHook.messageNames.Has(msgId)
      ? ShellMessageHook.messageNames[msgId]
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
      case ShellMessageHook.HSHELL_WINDOWCREATED:
        return this.runMessageCallbacks("WindowCreated", hwnd)
      case ShellMessageHook.HSHELL_WINDOWDESTROYED:
        return this.runMessageCallbacks("WindowDestroyed", hwnd)
      case ShellMessageHook.HSHELL_WINDOWACTIVATED:
        return this.runMessageCallbacks("WindowActivated", hwnd)
      case ShellMessageHook.HSHELL_ACTIVATESHELLWINDOW:
      case ShellMessageHook.HSHELL_GETMINRECT:
      case ShellMessageHook.HSHELL_REDRAW:
      case ShellMessageHook.HSHELL_TASKMAN:
      case ShellMessageHook.HSHELL_LANGUAGE:
      case ShellMessageHook.HSHELL_SYSMENU:
      case ShellMessageHook.HSHELL_ENDTASK:
      case ShellMessageHook.HSHELL_ACCESSIBILITYSTATE:
      case ShellMessageHook.HSHELL_APPCOMMAND:
      case ShellMessageHook.HSHELL_WINDOWREPLACED:
      case ShellMessageHook.HSHELL_WINDOWREPLACING:
      case ShellMessageHook.HSHELL_HIGHBIT:
      case ShellMessageHook.HSHELL_FLASH:
      case ShellMessageHook.HSHELL_RUDEAPPACTIVATED:
        return this.outputDebugLine("skip " ShellMessageHook.messageNames[msgId] " from hwnd=" hwnd)
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





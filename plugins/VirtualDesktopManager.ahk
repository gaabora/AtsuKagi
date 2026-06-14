class VirtualDesktopManager extends AKPlugin {
  dllPathDefault := "\lib"
  recentDesktopNumber := 1
  loopFirstAndLast := false
  _isReady := false
  _initError := ""
  
  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "VirtualDesktopManager",
        "title", "Virtual Desktop Manager",
        "description", "Manage Windows 10+ virtual desktops: switch between desktops, move windows, create/remove/rename desktops. Uses VirtualDesktopAccessor.dll https://github.com/Ciantic/VirtualDesktopAccessor/releases. Requires Windows 10 or later",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure virtual desktop management and navigation",
        "icon", "icons10-grid-2"
      ),
      "config", [
        Map(
          "key", "LoopFirstAndLast",
          "label", "Loop first and last desktops",
          "description", "Wrap navigation from the last desktop to the first and from the first desktop to the last",
          "type", "boolean", "control", "switch", "default", true, "section", "Navigation"
        )
      ],
      "actions", [
        Map("action", "GetDesktopName", "label", "Get desktop name", "description", "Get the name of a specified desktop", "params", ["desktopNumber"], "category", "Desktop Info"),
        Map("action", "SetDesktopName", "label", "Set desktop name", "description", "Set the name of a specified desktop", "params", ["desktopNumber", "name"], "category", "Desktop Management"),
        Map("action", "CreateDesktop", "label", "Create desktop", "description", "Create a new virtual desktop", "params", [], "category", "Desktop Management"),
        Map("action", "RemoveDesktop", "label", "Remove desktop", "description", "Remove a virtual desktop", "params", ["RemoveDesktopNumber", "FallbackDesktopNumber"], "category", "Desktop Management"),
        Map("action", "GetCurrentDesktopNumber", "label", "Get current desktop number", "description", "Get the index of the currently active desktop", "params", [], "category", "Desktop Info"),
        Map("action", "GetDesktopCount", "label", "Get desktop count", "description", "Get the total number of virtual desktops", "params", [], "category", "Desktop Info"),
        Map("action", "GetPrevDesktopNumber", "label", "Get previous desktop number", "description", "Get the index of the previous desktop", "params", [], "category", "Desktop Navigation"),
        Map("action", "GetNextDesktopNumber", "label", "Get next desktop number", "description", "Get the index of the next desktop", "params", [], "category", "Desktop Navigation"),
        Map("action", "GoToDesktop", "label", "Go to desktop", "description", "Switch to a specified desktop", "params", ["desktopNumber"], "category", "Desktop Navigation"),
        Map("action", "GoToRecentDesktop", "label", "Go to recent desktop", "description", "Switch to the most recently used desktop", "params", [], "category", "Desktop Navigation"),
        Map("action", "GoToPrevDesktop", "label", "Go to previous desktop", "description", "Switch to the previous desktop", "params", [], "category", "Desktop Navigation"),
        Map("action", "GoToNextDesktop", "label", "Go to next desktop", "description", "Switch to the next desktop", "params", [], "category", "Desktop Navigation"),
        Map("action", "MoveWindowToDesktop", "label", "Move window to desktop", "description", "Move a window to a specified desktop", "params", ["desktopNumber", "hwnd"], "category", "Window Management"),
        Map("action", "MoveWindowToPrevDesktop", "label", "Move window to previous desktop", "description", "Move the current window to the previous desktop", "params", ["hwnd"], "category", "Window Management"),
        Map("action", "MoveWindowToNextDesktop", "label", "Move window to next desktop", "description", "Move the current window to the next desktop", "params", ["hwnd"], "category", "Window Management"),
        Map("action", "MoveHoveredWindowToDesktop", "label", "Move hovered window to desktop", "description", "Move the window at cursor to a specified desktop", "params", ["desktopNumber"], "category", "Window Management"),
        Map("action", "MoveHoveredWindowToPrevDesktop", "label", "Move hovered window to previous desktop", "description", "Move the window at cursor to the previous desktop", "params", [], "category", "Window Management"),
        Map("action", "MoveHoveredWindowToNextDesktop", "label", "Move hovered window to next desktop", "description", "Move the window at cursor to the next desktop", "params", [], "category", "Window Management"),
        Map("action", "GoWithWindowToDesktop", "label", "Go with window to desktop", "description", "Move a window to a desktop and switch to it", "params", ["desktopNumber", "hwnd"], "category", "Window Management"),
        Map("action", "GoWithWindowToPrevDesktop", "label", "Go with window to previous desktop", "description", "Move current window to previous desktop and switch to it", "params", [], "category", "Window Management"),
        Map("action", "GoWithWindowToNextDesktop", "label", "Go with window to next desktop", "description", "Move current window to next desktop and switch to it", "params", [], "category", "Window Management"),
        Map("action", "GoWithHoveredWindowToDesktop", "label", "Go with hovered window to desktop", "description", "Move hovered window to a desktop and switch to it", "params", ["desktopNumber"], "category", "Window Management"),
        Map("action", "GoWithHoveredWindowToPrevDesktop", "label", "Go with hovered window to previous desktop", "description", "Move hovered window to previous desktop and switch to it", "params", [], "category", "Window Management"),
        Map("action", "GoWithHoveredWindowToNextDesktop", "label", "Go with hovered window to next desktop", "description", "Move hovered window to next desktop and switch to it", "params", [], "category", "Window Management")
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    ; Apply descriptor defaults, then any additional processing if needed
    this.__ApplyDefaultConfig()
  }

  OnConfigChanged(key, value) {
    if (key = "LoopFirstAndLast")
      this.loopFirstAndLast := !!value
  }
  
  _init(dllPath:=0) {
    dllName := "VirtualDesktopAccessor.win" GetWindowsRelease() ".dll"
    this.dllPath := dllPath ? dllPath : A_ScriptDir . this.dllPathDefault . "\" dllName

    if (!FileExist(this.dllPath)) {
      this._initError := dllName " not found at " this.dllPath
      this.ShowWarning(this._initError)
      return
    }
    try {
      this.hVirtualDesktopAccessor             := DllCall("LoadLibrary", "Str", this.dllPath, "Ptr")
      if (!this.hVirtualDesktopAccessor)
        throw OSError(A_LastError, "LoadLibrary", this.dllPath)
      this.GetDesktopCountProc                 := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "GetDesktopCount", "Ptr")
      this.GoToDesktopNumberProc               := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "GoToDesktopNumber", "Ptr")
      this.GetCurrentDesktopNumberProc         := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "GetCurrentDesktopNumber", "Ptr")
      this.IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "IsWindowOnCurrentVirtualDesktop", "Ptr")
      this.IsWindowOnDesktopNumberProc         := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "IsWindowOnDesktopNumber", "Ptr")
      this.MoveWindowToDesktopNumberProc       := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "MoveWindowToDesktopNumber", "Ptr")
      this.IsPinnedWindowProc                  := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "IsPinnedWindow", "Ptr")
      this.GetDesktopNameProc                  := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "GetDesktopName", "Ptr")
      this.SetDesktopNameProc                  := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "SetDesktopName", "Ptr")
      this.CreateDesktopProc                   := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "CreateDesktop", "Ptr")
      this.RemoveDesktopProc                   := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "RemoveDesktop", "Ptr")

      ; On change listeners
      this.RegisterPostMessageHookProc         := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "RegisterPostMessageHook", "Ptr")
      this.UnregisterPostMessageHookProc       := DllCall("GetProcAddress", "Ptr", this.hVirtualDesktopAccessor, "AStr", "UnregisterPostMessageHook", "Ptr")
    } catch Error as err {
      this._initError := "Failed to initialize VirtualDesktopManager: " err.Message
      this.ShowWarning(this._initError)
      return
    }

    if (!this.GetDesktopCountProc || !this.GoToDesktopNumberProc || !this.GetCurrentDesktopNumberProc) {
      this._initError := "VirtualDesktopAccessor.dll is loaded but required desktop navigation procedures are missing"
      this.outputDebugLine(AKApp.LOG_ERROR, this._initError)
      return
    }

    desktopCount := DllCall(this.GetDesktopCountProc, "Int")
    currentDesktopIndex := DllCall(this.GetCurrentDesktopNumberProc, "Int")
    if (desktopCount < 1 || currentDesktopIndex < 0 || currentDesktopIndex >= desktopCount) {
      this._initError := "VirtualDesktopAccessor.dll is incompatible with this Windows build: GetDesktopCount=" desktopCount ", GetCurrentDesktopNumber=" currentDesktopIndex
      this.outputDebugLine(AKApp.LOG_ERROR, this._initError)
      return
    }

    this.loopFirstAndLast := !!this.Config.LoopFirstAndLast
    this._isReady := true
    this.outputDebugLine(AKApp.LOG_INFO, "VirtualDesktopAccessor initialized: dll=" this.dllPath ", Windows=" A_OSVersion ", desktops=" desktopCount ", current=" (currentDesktopIndex + 1))
    if (this.RegisterPostMessageHookProc)
      this.addDesktopChangedHook()
    else
      this.outputDebugLine(AKApp.LOG_WARNING, "RegisterPostMessageHook is unavailable; recent-desktop tracking is disabled")
  }

  __Delete() {
    ; TODO UnregisterPostMessageHookProc somehow
    if (this.HasOwnProp("hVirtualDesktopAccessor") && this.hVirtualDesktopAccessor)
      DllCall("FreeLibrary", "Ptr", this.hVirtualDesktopAccessor)
  }

  _requireReady() {
    if (!this._isReady)
      throw Error(this._initError != "" ? this._initError : "VirtualDesktopManager is not initialized")
  }

  _requireProcedure(proc, procedureName) {
    this._requireReady()
    if (!proc)
      throw Error("VirtualDesktopAccessor.dll does not export " procedureName)
  }

  GetDesktopName(desktopNumber) { ;;;
    this._requireProcedure(this.GetDesktopNameProc, "GetDesktopName")
    utf8_buffer := ""
    utf8_buffer_len := VarSetStrCapacity(utf8_buffer, 1024)
    ran := DllCall(this.GetDesktopNameProc, "Int", desktopNumber, "Ptr", &utf8_buffer, "Ptr", utf8_buffer_len, "Int")
    if (ran = -1)
      throw Error("GetDesktopName failed for desktop " desktopNumber)
    name := StrGet(&utf8_buffer, 1024, "UTF-8")
    return name
  }

  SetDesktopName(desktopNumber, name) { ;;;
    this._requireProcedure(this.SetDesktopNameProc, "SetDesktopName")
    ; NOTICE! For UTF-8 to work AHK file must be saved with UTF-8 with BOM
    VarSetStrCapacity(name_utf8, 1024)
    StrPut(name, &name_utf8, "UTF-8")
    ran := DllCall(this.SetDesktopNameProc, "Int", desktopNumber, "Ptr", &name_utf8, "Int")
    if (ran = -1)
      throw Error("SetDesktopName failed for desktop " desktopNumber)
    return ran
  }

  CreateDesktop() { ;;;
    this._requireProcedure(this.CreateDesktopProc, "CreateDesktop")
    ran := DllCall(this.CreateDesktopProc)
    if (ran = -1)
      throw Error("CreateDesktop failed")
    return ran
  }

  RemoveDesktop(desktopNumber, fallbackNumber:=0) { ;;;
    this._requireProcedure(this.RemoveDesktopProc, "RemoveDesktop")
    ran := DllCall(this.RemoveDesktopProc, "Int", desktopNumber, "Int", fallbackNumber, "Int")
    if (ran = -1)
      throw Error("RemoveDesktop failed for desktop " desktopNumber)
    return ran
  }

  GetCurrentDesktopNumber() { ;;;
    this._requireReady()
    idx := DllCall(this.GetCurrentDesktopNumberProc, "Int")
    if (idx < 0)
      throw Error("GetCurrentDesktopNumber failed with result " idx)
    return 1 + idx
  }

  GetDesktopCount() { ;;;
    this._requireReady()
    count := DllCall(this.GetDesktopCountProc, "Int")
    if (count < 1)
      throw Error("GetDesktopCount failed with result " count)
    return count
  }

  GetPrevDesktopNumber() { ;;;
    curr := this.GetCurrentDesktopNumber()
    if (this.loopFirstAndLast) {
      return (curr = 1) ? this.GetDesktopCount() : curr - 1
    } else {
      return (curr = 1) ? 1 : curr - 1
    }
  }

  GetNextDesktopNumber() { ;;;
    curr := this.GetCurrentDesktopNumber()
    last := this.GetDesktopCount()
    if (this.loopFirstAndLast) {
      return (curr = last) ? 1 : curr + 1
    } else {
      return (curr = last) ? last : curr + 1
    }
  }

  GoToDesktop(desktopNumber) { ;;;
    this._requireReady()
    desktopCount := this.GetDesktopCount()
    if (desktopNumber < 1 || desktopNumber > desktopCount)
      throw ValueError("Desktop number must be between 1 and " desktopCount, -1, desktopNumber)
    result := DllCall(this.GoToDesktopNumberProc, "Int", desktopNumber - 1, "Int")
    if (result = -1)
      throw Error("GoToDesktopNumber failed for desktop " desktopNumber)
    return result
  }

  GoToRecentDesktop() { ;;;
    this.GoToDesktop(this.recentDesktopNumber)
  }

  GoToPrevDesktop() { ;;;
    this.GotoDesktop(this.GetPrevDesktopNumber())
  }

  GoToNextDesktop() { ;;;
    this.GotoDesktop(this.GetNextDesktopNumber())
  }

  MoveWindowToDesktop(desktopNumber, hwnd:=0) { ;;;
    this._requireProcedure(this.MoveWindowToDesktopNumberProc, "MoveWindowToDesktopNumber")
    if (hwnd=0)
      hwnd := WinGetID("A")
    result := DllCall(this.MoveWindowToDesktopNumberProc, "Ptr", hwnd, "Int", desktopNumber - 1, "Int")
    if (result = -1)
      throw Error("MoveWindowToDesktopNumber failed for hwnd=" hwnd " desktop=" desktopNumber)
    return result
  }

  MoveWindowToPrevDesktop(hwnd:=0) { ;;;
    this.MoveWindowToDesktop(this.GetPrevDesktopNumber(), hwnd)
  }

  MoveWindowToNextDesktop(hwnd:=0) { ;;;
    this.MoveWindowToDesktop(this.GetNextDesktopNumber(), hwnd)
  }

  MoveHoveredWindowToDesktop(desktopNumber) { ;;;
    MouseGetPos(, , &hwnd)
    this.MoveWindowToDesktop(desktopNumber, hwnd)
  }

  MoveHoveredWindowToPrevDesktop() { ;;;
    MouseGetPos(, , &hwnd)
    this.MoveWindowToDesktop(this.GetPrevDesktopNumber(), hwnd)
  }

  MoveHoveredWindowToNextDesktop() { ;;;
    MouseGetPos(, , &hwnd)
    this.MoveWindowToDesktop(this.GetNextDesktopNumber(), hwnd)
  }

  GoWithWindowToDesktop(desktopNumber, hwnd:=0) { ;;;
    if (hwnd=0)
      hwnd := WinGetID("A")
    this.MoveWindowToDesktop(desktopNumber, hwnd)
    this.GoToDesktop(desktopNumber)
  }

  GoWithWindowToPrevDesktop() { ;;;
    this.GoWithWindowToDesktop(this.GetPrevDesktopNumber())
  }

  GoWithWindowToNextDesktop() { ;;;
    this.GoWithWindowToDesktop(this.GetNextDesktopNumber())
  }
  
  GoWithHoveredWindowToDesktop(desktopNumber) { ;;;
    MouseGetPos(, , &hwnd)
    this.GoWithWindowToDesktop(desktopNumber, hwnd)
  }

  GoWithHoveredWindowToPrevDesktop() { ;;;
    MouseGetPos(, , &hwnd)
    this.GoWithWindowToDesktop(this.GetPrevDesktopNumber(), hwnd)
  }

  GoWithHoveredWindowToNextDesktop() { ;;;
    MouseGetPos(, , &hwnd)
    this.GoWithWindowToDesktop(this.GetNextDesktopNumber(), hwnd)
  }
  addDesktopChangedHook() {
    DllCall(this.RegisterPostMessageHookProc, "Ptr", A_ScriptHwnd, "Int", VirtualDesktopMessages.CHANGE_DESKTOP, "Int")
    onChangeDesktopFn := this.onChangeDesktop.bind(this)
    OnMessage(VirtualDesktopMessages.CHANGE_DESKTOP, onChangeDesktopFn)
  }
  onChangeDesktop(wParam, lParam, msg, hwnd) {
    Critical(100)
    OldDesktop := wParam + 1
    NewDesktop := lParam + 1
    this.outputDebugLine(AKApp.LOG_DEBUG, "Desktop changed from " OldDesktop " to " NewDesktop)
    this.recentDesktopNumber := OldDesktop
    if (GetWindowsRelease() = 10)
      this.ShowInfo("Desktop " NewDesktop)
  }
}

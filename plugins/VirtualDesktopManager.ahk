class VirtualDesktopManager extends AKPlugin {
  dllPathDefault := "\VirtualDesktopAccessor.dll"
  recentDesktopNumber := 1
  loopFirtAndLast := 0
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
        "description", "Configure virtual desktop management and navigation.",
        "icon", "icons10-grid-2"
      ),
      "config", [],
      "actions", [
        Map("action", "GetDesktopName", "label", "Get desktop name", "description", "Get the name of a specified desktop.", "params", ["desktopNumber"], "category", "Desktop Info"),
        Map("action", "SetDesktopName", "label", "Set desktop name", "description", "Set the name of a specified desktop.", "params", ["desktopNumber", "name"], "category", "Desktop Management"),
        Map("action", "CreateDesktop", "label", "Create desktop", "description", "Create a new virtual desktop.", "params", [], "category", "Desktop Management"),
        Map("action", "RemoveDesktop", "label", "Remove desktop", "description", "Remove a virtual desktop.", "params", ["RemoveDesktopNumber", "FallbackDesktopNumber"], "category", "Desktop Management"),
        Map("action", "GetCurrentDesktopNumber", "label", "Get current desktop number", "description", "Get the index of the currently active desktop.", "params", [], "category", "Desktop Info"),
        Map("action", "GetDesktopCount", "label", "Get desktop count", "description", "Get the total number of virtual desktops.", "params", [], "category", "Desktop Info"),
        Map("action", "GetPrevDesktopNumber", "label", "Get previous desktop number", "description", "Get the index of the previous desktop.", "params", [], "category", "Desktop Navigation"),
        Map("action", "GetNextDesktopNumber", "label", "Get next desktop number", "description", "Get the index of the next desktop.", "params", [], "category", "Desktop Navigation"),
        Map("action", "GoToDesktop", "label", "Go to desktop", "description", "Switch to a specified desktop.", "params", ["desktopNumber"], "category", "Desktop Navigation"),
        Map("action", "GoToRecentDesktop", "label", "Go to recent desktop", "description", "Switch to the most recently used desktop.", "params", [], "category", "Desktop Navigation"),
        Map("action", "GoToPrevDesktop", "label", "Go to previous desktop", "description", "Switch to the previous desktop.", "params", [], "category", "Desktop Navigation"),
        Map("action", "GoToNextDesktop", "label", "Go to next desktop", "description", "Switch to the next desktop.", "params", [], "category", "Desktop Navigation"),
        Map("action", "MoveWindowToDesktop", "label", "Move window to desktop", "description", "Move a window to a specified desktop.", "params", ["desktopNumber", "hwnd"], "category", "Window Management"),
        Map("action", "MoveWindowToPrevDesktop", "label", "Move window to previous desktop", "description", "Move the current window to the previous desktop.", "params", ["hwnd"], "category", "Window Management"),
        Map("action", "MoveWindowToNextDesktop", "label", "Move window to next desktop", "description", "Move the current window to the next desktop.", "params", ["hwnd"], "category", "Window Management"),
        Map("action", "MoveHoveredWindowToDesktop", "label", "Move hovered window to desktop", "description", "Move the window at cursor to a specified desktop.", "params", ["desktopNumber"], "category", "Window Management"),
        Map("action", "MoveHoveredWindowToPrevDesktop", "label", "Move hovered window to previous desktop", "description", "Move the window at cursor to the previous desktop.", "params", [], "category", "Window Management"),
        Map("action", "MoveHoveredWindowToNextDesktop", "label", "Move hovered window to next desktop", "description", "Move the window at cursor to the next desktop.", "params", [], "category", "Window Management"),
        Map("action", "GoWithWindowToDesktop", "label", "Go with window to desktop", "description", "Move a window to a desktop and switch to it.", "params", ["desktopNumber", "hwnd"], "category", "Window Management"),
        Map("action", "GoWithWindowToPrevDesktop", "label", "Go with window to previous desktop", "description", "Move current window to previous desktop and switch to it.", "params", [], "category", "Window Management"),
        Map("action", "GoWithWindowToNextDesktop", "label", "Go with window to next desktop", "description", "Move current window to next desktop and switch to it.", "params", [], "category", "Window Management"),
        Map("action", "GoWithHoveredWindowToDesktop", "label", "Go with hovered window to desktop", "description", "Move hovered window to a desktop and switch to it.", "params", ["desktopNumber"], "category", "Window Management"),
        Map("action", "GoWithHoveredWindowToPrevDesktop", "label", "Go with hovered window to previous desktop", "description", "Move hovered window to previous desktop and switch to it.", "params", [], "category", "Window Management"),
        Map("action", "GoWithHoveredWindowToNextDesktop", "label", "Go with hovered window to next desktop", "description", "Move hovered window to next desktop and switch to it.", "params", [], "category", "Window Management")
      ],
      "hooks", []
    )
  }

  ; ── Legacy Methods (Phase 1-5: TODO: remove after Phase 5) ─────────────────────
  ; These are now derived from __DescribePlugin() by the base class
  _processBlocklistConfig() {
  }

  _processPluginConfig() {
    ; Apply descriptor defaults, then any additional processing if needed
    this.__ApplyDefaultConfig()
  }
  
  _init(dllPath:=0, loopFirtAndLast:=0) {
    this.dllPath := (dllPath) ? dllPath : A_ScriptDir . this.dllPathDefault

    if (!FileExist(this.dllPath)) {
      this._initError := "VirtualDesktopAccessor.dll not found at " this.dllPath
      this.ShowWarning(this._initError)
      return
    }
    try {
      this.hVirtualDesktopAccessor             := DllCall("LoadLibrary", "Str", this.dllPath, "Ptr")
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

    if (!this.GetDesktopCountProc || !this.GoToDesktopNumberProc || !this.GetCurrentDesktopNumberProc || !this.MoveWindowToDesktopNumberProc || !this.GetDesktopNameProc || !this.SetDesktopNameProc || !this.CreateDesktopProc || !this.RemoveDesktopProc || !this.RegisterPostMessageHookProc) {
      this._initError := "VirtualDesktopAccessor.dll is loaded but required procedures are missing"
      this.ShowWarning(this._initError)
      return
    }

    this.loopFirtAndLast := loopFirtAndLast
    this._isReady := true
    ; TODO hook
    this.addDesktopChangedHook()
  }

  __Delete() {
    ; TODO UnregisterPostMessageHookProc somehow
      DllCall("FreeLibrary", "Ptr", this.hVirtualDesktopAccessor)
  }

  GetDesktopName(desktopNumber) { ;;;
    utf8_buffer := ""
    utf8_buffer_len := VarSetStrCapacity(utf8_buffer, 1024)
    ran := DllCall(this.GetDesktopNameProc, "Int", desktopNumber, "Ptr", &utf8_buffer, "Ptr", utf8_buffer_len, "Int")
    name := StrGet(&utf8_buffer, 1024, "UTF-8")
    return name
  }

  SetDesktopName(desktopNumber, name) { ;;;
    ; NOTICE! For UTF-8 to work AHK file must be saved with UTF-8 with BOM
    VarSetStrCapacity(name_utf8, 1024)
    StrPut(name, &name_utf8, "UTF-8")
    ran := DllCall(this.SetDesktopNameProc, "Int", desktopNumber, "Ptr", &name_utf8, "Int")
    return ran
  }

  CreateDesktop() { ;;;
    ran := DllCall(this.CreateDesktopProc)
    return ran
  }

  RemoveDesktop(desktopNumber, fallbackNumber:=0) { ;;;
    ran := DllCall(this.RemoveDesktopProc, "Int", desktopNumber, "Int", fallbackNumber, "Int")
    return ran
  }

  GetCurrentDesktopNumber() { ;;;
    idx := DllCall(this.GetCurrentDesktopNumberProc, "Int")
    return 1 + idx
  }

  GetDesktopCount() { ;;;
    count := DllCall(this.GetDesktopCountProc, "Int")
    return count
  }

  GetPrevDesktopNumber() { ;;;
    curr := this.GetCurrentDesktopNumber()
    if (this.loopFirtAndLast) {
      return (curr = 1) ? 1 : curr - 1
    } else {
      return (curr = 1) ? this.GetDesktopCount() : curr - 1
    }
  }

  GetNextDesktopNumber() { ;;;
    curr := this.GetCurrentDesktopNumber()
    last := this.GetDesktopCount()
    if (this.loopFirtAndLast) {
      return (curr = last) ? last : curr + 1
    } else {
      return (curr = last) ? 1 : curr + 1
    }
  }

  GoToDesktop(desktopNumber) { ;;;
    DllCall(this.GoToDesktopNumberProc, "Int", desktopNumber - 1, "Int")
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
    if (hwnd=0)
      hwnd := WinGetID("A")
    DllCall(this.MoveWindowToDesktopNumberProc, "Ptr", hwnd, "Int", desktopNumber - 1, "Int")
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
    CHANGE_DESKTOP_MESSAGE := 0x1400 + 30
    DllCall(this.RegisterPostMessageHookProc, "Ptr", A_ScriptHwnd, "Int", CHANGE_DESKTOP_MESSAGE, "Int")
    onChangeDesktopFn := this.onChangeDesktop.bind(this)
    OnMessage(CHANGE_DESKTOP_MESSAGE, onChangeDesktopFn)
  }
  onChangeDesktop(wParam, lParam, msg, hwnd) {
    Critical(100)
    OldDesktop := wParam + 1
    NewDesktop := lParam + 1
    this.outputDebugLine("Desktop changed from " OldDesktop " to " NewDesktop)
    this.recentDesktopNumber := OldDesktop
  }
}

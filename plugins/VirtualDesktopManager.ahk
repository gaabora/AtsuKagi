class VirtualDesktopManager extends AKPlugin {
  dllPathDefault := "\VirtualDesktopAccessor.dll"
  recentDesktopNumber := 1
  loopFirtAndLast := 0
  
  __New(dllPath:=0, loopFirtAndLast:=0) {
    this.dllPath := (dllPath) ? dllPath : A_ScriptDir . this.dllPathDefault

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

    this.loopFirtAndLast := loopFirtAndLast
    ; TODO hook
    this.addDesktopChangedHook()
  }

  __Delete() {
    ; TODO UnregisterPostMessageHookProc somehow
      DllCall("FreeLibrary", "Ptr", this.hVirtualDesktopAccessor)
  }

  __ConfigHelp() {
    ; TODO
    return []
  }

  __UsageHelp() {
    return "based on VirtualDesktopAccessor by Jari Otto Oskari Pennanen`nget dll from https://github.com/Ciantic/VirtualDesktopAccessor/releases"
  }

  __ActionsHelp() {
    texts := Map()
    texts["GetDesktopName"] := "GetDesktopName(desktopNumber)"
    texts["SetDesktopName"] := "SetDesktopName(desktopNumber, name)"
    texts["CreateDesktop"] := "CreateDesktop()"
    texts["RemoveDesktop"] := "RemoveDesktop(RemoveDesktopNumber, FallbackDesktopNumber)"
    texts["GetCurrentDesktopNumber"] := "GetCurrentDesktopNumber()"
    texts["GetDesktopCount"] := "GetDesktopCount()"
    texts["GetPrevDesktopNumber"] := "GetPrevDesktopNumber()"
    texts["GetNextDesktopNumber"] := "GetNextDesktopNumber()"
    texts["GoToDesktop"] := "GoToDesktop(desktopNumber)"
    texts["GoToRecentDesktop"] := "GoToRecentDesktop()"
    texts["GoToPrevDesktop"] := "GoToPrevDesktop()"
    texts["GoToNextDesktop"] := "GoToNextDesktop()"
    texts["MoveWindowToDesktop"] := "MoveWindowToDesktop(desktopNumber, hwnd:=0)"
    texts["MoveWindowToPrevDesktop"] := "MoveWindowToPrevDesktop(hwnd:=0)"
    texts["MoveWindowToNextDesktop"] := "MoveWindowToNextDesktop(hwnd:=0)"
    texts["MoveHoveredWindowToDesktop"] := "MoveHoveredWindowToDesktop(desktopNumber)"
    texts["MoveHoveredWindowToPrevDesktop"] := "MoveHoveredWindowToPrevDesktop()"
    texts["MoveHoveredWindowToNextDesktop"] := "MoveHoveredWindowToNextDesktop()"
    texts["GoWithWindowToDesktop"] := "GoWithWindowToDesktop(desktopNumber, hwnd:=0)"
    texts["GoWithWindowToPrevDesktop"] := "GoWithWindowToPrevDesktop()"
    texts["GoWithWindowToNextDesktop"] := "GoWithWindowToNextDesktop()"
    texts["GoWithHoveredWindowToDesktop"] := "GoWithHoveredWindowToDesktop(desktopNumber)"
    texts["GoWithHoveredWindowToPrevDesktop"] := "GoWithHoveredWindowToPrevDesktop()"
    texts["GoWithHoveredWindowToNextDesktop"] := "GoWithHoveredWindowToNextDesktop()"
    return texts
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

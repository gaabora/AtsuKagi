class WindowsFakeScreensaver {
  __New(platform, eyeImagePath, logFn:=0) {
    this._platform := platform
    this._eyeImagePath := eyeImagePath
    this._logFn := logFn
    this._screens := Map()
    this._active := false
    this._exitHotkey := ""
    this._exitFn := this.Stop.Bind(this)
    this._hotIfFn := (*) => this._active
    this._pollFn := this._pollMouse.Bind(this)
    this._keepAwakeFn := this._sendKeepAwakePulse.Bind(this)
    this._keepAwakeHotkey := "RShift"
    this._keepAwakeIntervalMs := 10000
  }

  Start(monitorList:="", exitHotkey:="Escape", keepAwakeHotkey:="RShift", keepAwakeIntervalSeconds:=10) {
    selectedMonitors := this._parseMonitorList(monitorList)
    if (selectedMonitors.Length = 0)
      throw ValueError("No valid fake screensaver monitors were selected")
    if (!FileExist(this._eyeImagePath))
      throw Error("Fake screensaver eye image is missing: " this._eyeImagePath)

    this.Stop()
    this._exitHotkey := Trim("" exitHotkey)
    this._keepAwakeHotkey := Trim("" keepAwakeHotkey)
    this._keepAwakeIntervalMs := Max(1000, Integer(keepAwakeIntervalSeconds) * 1000)
    try {
      for monitorIndex in selectedMonitors
        this._createScreen(monitorIndex)
      this._active := true
      this._registerExitHotkey()
      SetTimer(this._pollFn, 100)
      SetTimer(this._keepAwakeFn, this._keepAwakeIntervalMs)
    } catch Error as startError {
      this.Stop()
      throw startError
    }
    this._log(AKBase.LOG_INFO, "Fake screensaver started on " this._screens.Count " monitor(s)")
    return Map("ok", true, "monitors", this._screens.Count)
  }

  Stop(*) {
    SetTimer(this._pollFn, 0)
    SetTimer(this._keepAwakeFn, 0)
    this._unregisterExitHotkey()
    for monitorIndex, screenState in this._screens {
      try screenState["interactionGui"].Destroy()
      try screenState["baseGui"].Destroy()
    }
    wasActive := this._active
    this._screens := Map()
    this._active := false
    if (wasActive)
      this._log(AKBase.LOG_INFO, "Fake screensaver stopped")
    return Map("ok", true, "wasActive", wasActive)
  }

  IsActive() {
    return this._active
  }

  _createScreen(monitorIndex) {
    MonitorGet(monitorIndex, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
    monitorWidth := monitorRight - monitorLeft
    monitorHeight := monitorBottom - monitorTop

    baseGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000", "Automations fake screensaver")
    baseGui.BackColor := "000000"
    baseGui.Show("x" monitorLeft " y" monitorTop " w" monitorWidth " h" monitorHeight " NoActivate")

    interactionGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "Automations fake screensaver controls")
    interactionGui.BackColor := "010101"
    interactionGui.MarginX := 0
    interactionGui.MarginY := 0
    interactionGui.SetFont("s10 cFFFFFF", "Segoe UI")
    instructionControl := interactionGui.AddText("x0 y0 w420 h54 Center BackgroundTrans", "This is not a lock or security screen.`nClick the eye to exit all screens. Right-click it to exit this screen.")
    instructionControl.SetFont("s10 cFFFFFF", "Segoe UI")
    pictureControl := interactionGui.AddPicture("x178 y60 w64 h64 BackgroundTrans", this._eyeImagePath)
    pictureControl.OnEvent("Click", this.Stop.Bind(this))
    pictureControl.OnEvent("ContextMenu", this._stopMonitor.Bind(this, monitorIndex))
    interactionLeft := monitorLeft + Floor((monitorWidth - 420) / 2)
    interactionTop := monitorTop + Floor((monitorHeight - 132) / 2)
    interactionGui.Show("x" interactionLeft " y" interactionTop " w420 h132 Hide NoActivate")
    WinSetTransColor("010101", "ahk_id " interactionGui.Hwnd)

    this._screens[monitorIndex] := Map("monitorIndex", monitorIndex, "left", monitorLeft, "top", monitorTop, "right", monitorRight, "bottom", monitorBottom, "baseGui", baseGui, "interactionGui", interactionGui, "pictureControl", pictureControl, "visible", false, "eyeHovered", false)
  }

  _pollMouse(*) {
    if (!this._active)
      return
    MouseGetPos(&mouseLeft, &mouseTop, &mouseWindowHwnd, &mouseControlHwnd, 2)
    for monitorIndex, screenState in this._screens {
      pointerInside := mouseLeft >= screenState["left"] && mouseLeft < screenState["right"] && mouseTop >= screenState["top"] && mouseTop < screenState["bottom"]
      if (pointerInside && !screenState["visible"]) {
        screenState["interactionGui"].Show("NoActivate")
        screenState["visible"] := true
      } else if (!pointerInside && screenState["visible"]) {
        screenState["interactionGui"].Hide()
        screenState["visible"] := false
      }

      eyeHovered := pointerInside && mouseControlHwnd = screenState["pictureControl"].Hwnd
      if (eyeHovered != screenState["eyeHovered"]) {
        WinSetTransparent(eyeHovered ? 51 : 255, "ahk_id " screenState["baseGui"].Hwnd)
        screenState["eyeHovered"] := eyeHovered
      }
    }
  }

  _stopMonitor(monitorIndex, *) {
    if (!this._screens.Has(monitorIndex))
      return
    screenState := this._screens[monitorIndex]
    try screenState["interactionGui"].Destroy()
    try screenState["baseGui"].Destroy()
    this._screens.Delete(monitorIndex)
    this._log(AKBase.LOG_INFO, "Fake screensaver stopped on monitor " monitorIndex)
    if (this._screens.Count = 0)
      this.Stop()
  }

  _sendKeepAwakePulse(*) {
    if (this._active)
      this._platform.SendKeyPulse(this._keepAwakeHotkey)
  }

  _registerExitHotkey() {
    if (this._exitHotkey = "")
      return
    HotIf(this._hotIfFn)
    try Hotkey(this._exitHotkey, this._exitFn, "On")
    finally {
      HotIf()
    }
  }

  _unregisterExitHotkey() {
    if (this._exitHotkey = "")
      return
    HotIf(this._hotIfFn)
    try Hotkey(this._exitHotkey, "Off")
    catch {
    } finally {
      HotIf()
    }
    this._exitHotkey := ""
  }

  _parseMonitorList(monitorList) {
    monitorCount := MonitorGetCount()
    result := []
    selected := Map()
    monitorListText := Trim("" monitorList)
    if (monitorListText = "") {
      Loop monitorCount
        result.Push(A_Index)
      return result
    }

    for monitorText in StrSplit(StrReplace(monitorListText, ";", ","), ",") {
      try monitorIndex := Integer(Trim(monitorText))
      catch
        continue
      if (monitorIndex >= 1 && monitorIndex <= monitorCount && !selected.Has(monitorIndex)) {
        selected[monitorIndex] := true
        result.Push(monitorIndex)
      }
    }
    return result
  }

  _log(level, message) {
    if (IsObject(this._logFn))
      this._logFn.Call(level, message)
  }
}

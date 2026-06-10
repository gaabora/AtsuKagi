class WindowStash extends AKPlugin {
  StashedWindows := Map()
  RevealedHwnd := 0
  _pollFn := 0
  _exitFn := 0
  _displayChangeFn := 0
  _displayChangeTimerFn := 0
  _displaySignature := ""
  _handleMouseDownFn := 0
  _handleWindows := Map()
  _polling := false
  _draggingHandle := false
  _lastMouseX := ""
  _lastMouseY := ""
  _lastActiveHwnd := 0
  _animating := false
  _overlayGui := ""

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "WindowStash",
        "title", "Window Stash",
        "description", "Temporarily hide windows at a screen edge and reveal them with an always-available handle",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure edge-stashed window behavior",
        "icon", "icons10-window"
      ),
      "config", [
        Map(
          "key", "HoverTolerance",
          "label", "Hide tolerance",
          "description", "Extra pixels around a revealed window before it hides",
          "type", "integer", "control", "range", "default", 15, "section", "Behavior",
          "validation", Map("min", 0, "max", 64, "step", 1)
        ),
        Map(
          "key", "PollInterval",
          "label", "Polling interval",
          "description", "Milliseconds between pointer and active-window checks",
          "type", "integer", "control", "range", "default", 50, "section", "Behavior",
          "validation", Map("min", 20, "max", 250, "step", 10)
        ),
        Map(
          "key", "ShiftFocusWhenStashed",
          "label", "Shift focus",
          "description", "Focus another window when the active window is hidden",
          "type", "boolean", "control", "switch", "default", true, "section", "Behavior"
        ),
        Map(
          "key", "RestorePositionOnUnstash",
          "label", "Restore position on unstash",
          "description", "Return the window to its position from before it was stashed",
          "type", "boolean", "control", "switch", "default", false, "section", "Behavior"
        ),
        Map(
          "key", "WindowEdgeOffset",
          "label", "Window edge offset",
          "description", "Gap in pixels between a revealed stashed window and its screen edge",
          "type", "integer", "control", "range", "default", 0, "section", "Behavior",
          "validation", Map("min", 0, "max", 200, "step", 1)
        ),
        Map(
          "key", "AnimateTransitions",
          "label", "Animate transitions",
          "description", "Animate windows while stashing, revealing, and restoring",
          "type", "boolean", "control", "switch", "default", true, "section", "Visuals"
        ),
        Map(
          "key", "AnimationDuration",
          "label", "Animation duration",
          "description", "Duration of stash transitions in milliseconds",
          "type", "integer", "control", "range", "default", 180, "section", "Visuals",
          "validation", Map("min", 50, "max", 500, "step", 10)
        ),
        Map(
          "key", "RestoreSettleDelay",
          "label", "Window settle delay",
          "description", "Wait before showing or minimizing a stashed window to reduce blinking",
          "type", "integer", "control", "range", "default", 200, "section", "Visuals",
          "validation", Map("min", 0, "max", 1000, "step", 10)
        ),
        Map(
          "key", "ShowWindowContent",
          "label", "Show window content",
          "description", "Animate the live window; when disabled, animate a colored rectangle and move the window at the end",
          "type", "boolean", "control", "switch", "default", true, "section", "Visuals"
        ),
        Map(
          "key", "OverlayColor",
          "label", "Ghost color",
          "description", "Color of the animated rectangle shown instead of window content",
          "type", "color", "control", "color", "default", "6B8AFD", "section", "Visuals"
        ),
        Map(
          "key", "OverlayOpacity",
          "label", "Ghost opacity",
          "description", "Opacity of the animated rectangle",
          "type", "integer", "control", "range", "default", 210, "section", "Visuals",
          "validation", Map("min", 20, "max", 255, "step", 5)
        ),
        Map(
          "key", "HandleColor",
          "label", "Handle color",
          "description", "Color of the stash handle and stashed window border",
          "type", "color", "control", "color", "default", "FF2D55", "section", "Handle"
        ),
        Map(
          "key", "HandleGripColor",
          "label", "Handle grip color",
          "description", "Color of the smaller grip line inside the handle",
          "type", "color", "control", "color", "default", "202020", "section", "Handle"
        ),
        Map(
          "key", "HandleOpacity",
          "label", "Handle opacity",
          "description", "Opacity of the stash handle",
          "type", "integer", "control", "range", "default", 245, "section", "Handle",
          "validation", Map("min", 40, "max", 255, "step", 5)
        ),
        Map(
          "key", "HandleThickness",
          "label", "Visible handle thickness",
          "description", "Visible thickness of the tab; a deeper portion remains beyond the screen edge for pulling",
          "type", "integer", "control", "range", "default", 14, "section", "Handle",
          "validation", Map("min", 6, "max", 40, "step", 1)
        ),
        Map(
          "key", "HandleLength",
          "label", "Handle length",
          "description", "Length of the handle along the screen edge",
          "type", "integer", "control", "range", "default", 72, "section", "Handle",
          "validation", Map("min", 24, "max", 240, "step", 4)
        ),
        Map(
          "key", "HandleDragDistance",
          "label", "Unstash drag distance",
          "description", "How far the handle must be pulled inward to unstash the window",
          "type", "integer", "control", "range", "default", 120, "section", "Handle",
          "validation", Map("min", 40, "max", 400, "step", 10)
        ),
        Map(
          "key", "LockHandleDragAxis",
          "label", "Lock handle drag axis",
          "description", "Choose either repositioning or inward pulling for each handle drag",
          "type", "boolean", "control", "switch", "default", false, "section", "Handle"
        )
      ],
      "actions", [
        Map("action", "StashWindowLeft", "label", "Stash window left", "description", "Stash a specific or active window at the left screen edge", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "StashWindowRight", "label", "Stash window right", "description", "Stash a specific or active window at the right screen edge", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "StashWindowTop", "label", "Stash window top", "description", "Stash a specific or active window at the top screen edge", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "StashWindowBottom", "label", "Stash window bottom", "description", "Stash a specific or active window at the bottom screen edge", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "UnstashWindow", "label", "Unstash window", "description", "Restore a specific or active stashed window", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "UnstashHoveredWindow", "label", "Unstash hovered window", "description", "Restore the stashed window under the pointer", "category", "Stash"),
        Map("action", "RestoreAllStashedWindows", "label", "Restore all stashed windows", "description", "Restore every window managed by Window Stash", "category", "Stash")
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  _init() {
    this._pollFn := this._poll.Bind(this)
    this._exitFn := this._onExit.Bind(this)
    this._displayChangeFn := this._onDisplayChange.Bind(this)
    this._displayChangeTimerFn := this._applyDisplayChange.Bind(this)
    this._handleMouseDownFn := this._onHandleMouseDown.Bind(this)
    this._displaySignature := this._getDisplaySignature()
    OnMessage(0x007E, this._displayChangeFn) ; WM_DISPLAYCHANGE
    OnMessage(0x001A, this._displayChangeFn) ; WM_SETTINGCHANGE
    OnMessage(0x0201, this._handleMouseDownFn) ; WM_LBUTTONDOWN
    OnExit(this._exitFn)
  }

  OnConfigChanged(key, value) {
    if (key = "PollInterval" && this.StashedWindows.Count) {
      SetTimer(this._pollFn, 0)
      SetTimer(this._pollFn, Integer(value))
      return
    }

    if (key = "HandleColor" || key = "HandleGripColor") {
      for hwnd, info in this.StashedWindows {
        if (key = "HandleColor") {
          this._setWindowBorderColor(hwnd, value)
          info["stashBorderColor"] := this._getWindowBorderColor(hwnd)
        }
        this._destroyHandle(info)
        this._showHandle(hwnd, info)
      }
      return
    }

    if (key = "HandleOpacity" || key = "HandleThickness" || key = "HandleLength" || key = "HandleDragDistance") {
      for hwnd, info in this.StashedWindows
        this._showHandle(hwnd, info)
      return
    }

    if (key = "WindowEdgeOffset") {
      for hwnd, info in this.StashedWindows {
        info["revealedFrame"] := this._getEdgeRevealedFrame(info["revealedFrame"], info["monitor"], info["edge"], info["frameInsets"])
        info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], info["monitor"], info["edge"])
        if (info["revealed"])
          this._moveWindow(hwnd, info["revealedFrame"])
        else
          this._parkHiddenWindow(hwnd, info)
        this._showHandle(hwnd, info)
      }
      return
    }
  }

  StashWindowLeft(hwnd:=0) { ;;;
    return this._stashWindow(hwnd, "left")
  }

  StashWindowRight(hwnd:=0) { ;;;
    return this._stashWindow(hwnd, "right")
  }

  StashWindowTop(hwnd:=0) { ;;;
    return this._stashWindow(hwnd, "top")
  }

  StashWindowBottom(hwnd:=0) { ;;;
    return this._stashWindow(hwnd, "bottom")
  }

  UnstashWindow(hwnd:=0) { ;;;
    if (!hwnd)
      hwnd := WinExist("A")
    if (!this.StashedWindows.Has(hwnd) && this.RevealedHwnd)
      hwnd := this.RevealedHwnd
    if (!this.StashedWindows.Has(hwnd) && this.StashedWindows.Count = 1) {
      for stashedHwnd in this.StashedWindows {
        hwnd := stashedHwnd
        break
      }
    }
    return this._unstashWindow(hwnd, true)
  }

  UnstashHoveredWindow() { ;;;
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    hwnd := this._getStashedWindowAtPoint(mouseX, mouseY, true)
    if (!hwnd)
      return false
    return this._unstashWindow(hwnd, true)
  }

  RestoreAllStashedWindows() { ;;;
    hwnds := []
    for hwnd in this.StashedWindows
      hwnds.Push(hwnd)
    for hwnd in hwnds
      this._unstashWindow(hwnd, true)
    return true
  }

  _stashWindow(hwnd, edge) {
    if (!hwnd)
      hwnd := WinExist("A")
    if (!hwnd || !WinExist("ahk_id " hwnd))
      return false

    if (this.IsWindowBlocklisted(hwnd, A_ThisFunc) || this.IsInBlocklist("NoMoveResize", hwnd)) {
      this.ShowInfo("Window stashing is disabled for this window")
      return false
    }

    if (this.StashedWindows.Has(hwnd)) {
      info := this.StashedWindows[hwnd]
      if (info["edge"] = edge) {
        if (info["revealed"])
          this._hideWindow(hwnd)
        else
          this._revealWindow(hwnd, "activation")
        return true
      }

      currentFrame := info["revealed"] ? this._getWindowFrame(hwnd) : info["revealedFrame"]
      if (!currentFrame || this._isWindowMinimized(hwnd))
        currentFrame := info["revealedFrame"]
      currentMonitor := this._getMonitorForRect(currentFrame["x"], currentFrame["y"], currentFrame["w"], currentFrame["h"])
      targetMonitor := this._getMonitorForEdge(currentMonitor, edge)
      info["edge"] := edge
      info["monitor"] := targetMonitor
      info["revealedFrame"] := this._getEdgeRevealedFrame(currentFrame, targetMonitor, edge, info["frameInsets"])
      info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], info["monitor"], edge)
      this._restoreOverlappingWindows(hwnd, edge, info["monitor"], info["hiddenFrame"])
      if (info["revealed"])
        this._hideWindow(hwnd)
      else {
        this._parkHiddenWindow(hwnd, info)
        this._showHandle(hwnd, info)
      }
      return true
    }

    try {
      windowState := WinGetMinMax("ahk_id " hwnd)
      if (windowState = -1) {
        this.ShowInfo("Minimized windows cannot be stashed")
        return false
      }
      wasMaximized := windowState = 1
      if (wasMaximized)
        WinRestore("ahk_id " hwnd)
      WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch as err {
      this.outputDebugLine(AKApp.LOG_WARNING, "Unable to stash hwnd=" hwnd ": " err.Message)
      return false
    }

    currentMonitor := this._getMonitorForRect(x, y, w, h)
    monitor := this._getMonitorForEdge(currentMonitor, edge)
    originalFrame := Map("x", x, "y", y, "w", w, "h", h)
    frameInsets := this._getInvisibleBorderOffsets(hwnd, originalFrame)
    revealedFrame := wasMaximized
      ? Map(
        "x", monitor["left"] - frameInsets["left"],
        "y", monitor["top"] - frameInsets["top"],
        "w", monitor["right"] - monitor["left"] + frameInsets["left"] + frameInsets["right"],
        "h", monitor["bottom"] - monitor["top"] + frameInsets["top"] + frameInsets["bottom"]
      )
      : this._getEdgeRevealedFrame(originalFrame, monitor, edge, frameInsets)
    hiddenFrame := this._getHiddenFrame(revealedFrame, monitor, edge)

    this._restoreOverlappingWindows(hwnd, edge, monitor, hiddenFrame)
    this.StashedWindows[hwnd] := Map(
      "edge", edge,
      "monitor", monitor,
      "originalFrame", originalFrame,
      "wasMaximized", wasMaximized,
      "frameInsets", frameInsets,
      "revealedFrame", revealedFrame,
      "hiddenFrame", hiddenFrame,
      "revealed", true,
      "revealMode", "",
      "activationRevealUntil", 0,
      "restoreRevealUntil", 0,
      "suppressHandleHover", false,
      "suppressActivationReveal", false,
      "parkedMinimized", false,
      "transitionsDisabledByStash", false,
      "restoreTransparency", "",
      "transparencySuppressedByStash", false,
      "borderColor", this._getWindowBorderColor(hwnd),
      "stashBorderColor", "",
      "handleGui", "",
      "handleBody", "",
      "handleGrip", "",
      "handleFrame", "",
      "handleOpacity", ""
    )

    this._setWindowBorderColor(hwnd, this.Config.HandleColor)
    this.StashedWindows[hwnd]["stashBorderColor"] := this._getWindowBorderColor(hwnd)
    this._hideWindow(hwnd)
    this._startPolling()
    return true
  }

  _unstashWindow(hwnd, restoreFrame) {
    if (!this.StashedWindows.Has(hwnd))
      return false

    info := this.StashedWindows[hwnd]
    this._destroyHandle(info)
    this._restoreWindowBorderColor(hwnd, info)
    if (restoreFrame && WinExist("ahk_id " hwnd)) {
      this._prepareRestoredWindow(hwnd, info, info["hiddenFrame"])
      this._transitionWindow(hwnd, this._getUnstashFrame(info, info["revealedFrame"]))
      if (info["wasMaximized"])
        try WinMaximize("ahk_id " hwnd)
      this._restoreWindowTransitions(hwnd, info)
    }

    this.StashedWindows.Delete(hwnd)
    if (this.RevealedHwnd = hwnd)
      this.RevealedHwnd := 0
    if (!this.StashedWindows.Count)
      this._stopPolling()
    return true
  }

  _revealWindow(hwnd, revealMode:="hover") {
    if (!this.StashedWindows.Has(hwnd) || !WinExist("ahk_id " hwnd)) {
      this._unstashWindow(hwnd, false)
      return false
    }

    info := this.StashedWindows[hwnd]
    if (this.RevealedHwnd && this.RevealedHwnd != hwnd)
      this._hideWindow(this.RevealedHwnd, false)

    this._logState("reveal", hwnd, info, "mode=" revealMode)
    wasParked := info["parkedMinimized"] || this._isWindowMinimized(hwnd)
    directExternalRestore := revealMode = "activation" && wasParked
    if (directExternalRestore) {
      restored := 1
      ; restored := this._prepareRestoredWindow(hwnd, info, info["revealedFrame"], true)
      this._restoreWindowTransparency(hwnd, info)
    } else {
      restored := this._prepareRestoredWindow(hwnd, info, info["hiddenFrame"])
      this._transitionWindow(hwnd, info["revealedFrame"])
    }
    this._restoreWindowTransitions(hwnd, info)
    info["revealed"] := true
    info["revealMode"] := revealMode
    info["restoreRevealUntil"] := restored ? A_TickCount + 300 : 0
    info["activationRevealUntil"] := revealMode = "activation"
      ? A_TickCount + Max(500, Integer(this.Config.AnimationDuration) + 250)
      : 0
    info["suppressActivationReveal"] := false
    this.RevealedHwnd := hwnd
    this._showHandle(hwnd, info)

    if (this.Config.ShiftFocusWhenStashed)
      try WinActivate("ahk_id " hwnd)
    return true
  }

  _hideWindow(hwnd, shiftFocus:=true) {
    if (!this.StashedWindows.Has(hwnd) || !WinExist("ahk_id " hwnd)) {
      this._unstashWindow(hwnd, false)
      return false
    }

    info := this.StashedWindows[hwnd]
    this._logState("hide", hwnd, info, "shiftFocus=" shiftFocus)
    if (shiftFocus && this.Config.ShiftFocusWhenStashed && WinExist("A") = hwnd)
      this._focusAnotherWindow(hwnd)

    this._transitionWindow(hwnd, info["hiddenFrame"])
    info["revealed"] := false
    info["revealMode"] := ""
    info["activationRevealUntil"] := 0
    info["restoreRevealUntil"] := 0
    this._parkHiddenWindow(hwnd, info)
    this._showHandle(hwnd, info)
    if (this.RevealedHwnd = hwnd)
      this.RevealedHwnd := 0
    return true
  }

  _startPolling() {
    if (this.StashedWindows.Count != 1)
      return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    this._lastMouseX := mouseX
    this._lastMouseY := mouseY
    this._lastActiveHwnd := WinExist("A")
    SetTimer(this._pollFn, Integer(this.Config.PollInterval))
  }

  _stopPolling() {
    if (this._pollFn)
      SetTimer(this._pollFn, 0)
    this._lastMouseX := ""
    this._lastMouseY := ""
    this._lastActiveHwnd := 0
  }

  _poll() {
    if (this._polling || this._draggingHandle)
      return
    this._polling := true

    try {
      missing := []
      for hwnd in this.StashedWindows {
        if (!WinExist("ahk_id " hwnd))
          missing.Push(hwnd)
      }
      for hwnd in missing
        this._unstashWindow(hwnd, false)
      if (!this.StashedWindows.Count)
        return

      CoordMode("Mouse", "Screen")
      MouseGetPos(&mouseX, &mouseY)
      activeHwnd := WinExist("A")
      mouseMoved := mouseX != this._lastMouseX || mouseY != this._lastMouseY
      activeChanged := activeHwnd != this._lastActiveHwnd
      previousActiveHwnd := this._lastActiveHwnd
      this._lastMouseX := mouseX
      this._lastMouseY := mouseY
      this._lastActiveHwnd := activeHwnd
      if (activeChanged) {
        this._raiseHandles()
        if (this.StashedWindows.Has(activeHwnd))
          this._logState("active changed", activeHwnd, this.StashedWindows[activeHwnd], "from=" previousActiveHwnd)
      }

      for hwnd, info in this.StashedWindows {
        if (info["suppressHandleHover"] && (!IsObject(info["handleFrame"]) || !this._pointInFrame(mouseX, mouseY, info["handleFrame"])))
          info["suppressHandleHover"] := false
        if (info["suppressActivationReveal"] && activeHwnd && activeHwnd != hwnd) {
          info["suppressActivationReveal"] := false
          this._logState("activation suppression cleared", hwnd, info, "active=" activeHwnd)
        }
      }

      if (this.StashedWindows.Has(activeHwnd) && !this.StashedWindows[activeHwnd]["revealed"]) {
        activeInfo := this.StashedWindows[activeHwnd]
        if (activeInfo["suppressActivationReveal"] || this._isWindowMinimized(activeHwnd)) {
          if (activeChanged)
            this._logState("activation reveal suppressed", activeHwnd, activeInfo)
        } else {
          this._revealWindow(activeHwnd, "activation")
          return
        }
      }

      if (this.RevealedHwnd)
        this._updateRevealedFrame(this.RevealedHwnd)

      if (mouseMoved) {
        hoveredHwnd := this._getStashedWindowAtPoint(mouseX, mouseY)
        if (hoveredHwnd) {
          this._revealWindow(hoveredHwnd, "hover")
          return
        }
      }

      if (!this.RevealedHwnd)
        return

      revealedInfo := this.StashedWindows[this.RevealedHwnd]
      pointerOutside := !this._isPointerInRevealArea(revealedInfo, mouseX, mouseY)

      if (revealedInfo["revealMode"] = "handle")
        return

      if (revealedInfo["revealMode"] = "activation") {
        activationSettled := A_TickCount >= revealedInfo["activationRevealUntil"]
        if (activeHwnd && activeHwnd != this.RevealedHwnd && pointerOutside && activationSettled && (activeChanged || mouseMoved))
          this._hideWindow(this.RevealedHwnd, false)
        return
      }

      restoreSettled := A_TickCount >= revealedInfo["restoreRevealUntil"]
      if (pointerOutside && restoreSettled && (mouseMoved || activeChanged))
        this._hideWindow(this.RevealedHwnd, activeHwnd = this.RevealedHwnd)
    } finally {
      this._polling := false
    }
  }

  _getStashedWindowAtPoint(x, y, includeRevealed:=false) {
    for hwnd, info in this.StashedWindows {
      if (!info["revealed"] && !info["suppressHandleHover"] && IsObject(info["handleFrame"]) && this._pointInFrame(x, y, info["handleFrame"]))
        return hwnd
    }

    if (includeRevealed) {
      for hwnd in WinGetList() {
        if (!this.StashedWindows.Has(hwnd))
          continue
        info := this.StashedWindows[hwnd]
        if (info["revealed"] && this._pointInFrame(x, y, info["revealedFrame"]))
          return hwnd
      }
    }
    return 0
  }

  _updateRevealedFrame(hwnd) {
    if (this._animating || !this.StashedWindows.Has(hwnd))
      return

    info := this.StashedWindows[hwnd]
    if (!info["revealed"])
      return

    if (this._isWindowMinimized(hwnd)) {
      info["revealed"] := false
      info["revealMode"] := ""
      info["activationRevealUntil"] := 0
      info["restoreRevealUntil"] := 0
      info["suppressActivationReveal"] := true
      info["parkedMinimized"] := true
      info["transitionsDisabledByStash"] := this._setWindowTransitionsDisabled(hwnd, true)
      this._logState("external minimize detected", hwnd, info, "transitionsDisabled=" info["transitionsDisabledByStash"])
      if (this.RevealedHwnd = hwnd)
        this.RevealedHwnd := 0
      this._showHandle(hwnd, info)
      return
    }

    currentFrame := this._getWindowFrame(hwnd)
    if (!currentFrame || this._framesEqual(currentFrame, info["revealedFrame"]))
      return

    monitor := this._getMonitorForRect(currentFrame["x"], currentFrame["y"], currentFrame["w"], currentFrame["h"])
    info["monitor"] := monitor
    info["frameInsets"] := this._getInvisibleBorderOffsets(hwnd, currentFrame)
    info["revealedFrame"] := currentFrame
    info["hiddenFrame"] := this._getHiddenFrame(currentFrame, monitor, info["edge"])
    this._showHandle(hwnd, info)
  }

  _onDisplayChange(*) {
    SetTimer(this._displayChangeTimerFn, 0)
    SetTimer(this._displayChangeTimerFn, -250)
  }

  _applyDisplayChange() {
    signature := this._getDisplaySignature()
    if (signature = this._displaySignature)
      return

    if (this._animating || this._draggingHandle) {
      SetTimer(this._displayChangeTimerFn, -100)
      return
    }
    this._displaySignature := signature

    for hwnd, info in this.StashedWindows {
      if (!WinExist("ahk_id " hwnd))
        continue

      originalMonitor := this._getMonitorForRect(info["originalFrame"]["x"], info["originalFrame"]["y"], info["originalFrame"]["w"], info["originalFrame"]["h"])
      info["originalFrame"] := this._getClampedFrame(info["originalFrame"], originalMonitor)

      currentMonitor := this._getMonitorForRect(info["revealedFrame"]["x"], info["revealedFrame"]["y"], info["revealedFrame"]["w"], info["revealedFrame"]["h"])
      targetMonitor := this._getMonitorForEdge(currentMonitor, info["edge"])
      info["monitor"] := targetMonitor
      info["revealedFrame"] := this._getEdgeRevealedFrame(info["revealedFrame"], targetMonitor, info["edge"], info["frameInsets"])
      info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], targetMonitor, info["edge"])

      if (info["revealed"])
        this._moveWindow(hwnd, info["revealedFrame"])
      else
        this._parkHiddenWindow(hwnd, info)
      this._showHandle(hwnd, info)
    }
  }

  _restoreOverlappingWindows(newHwnd, edge, monitor, hiddenFrame) {
    overlapping := []
    for hwnd, info in this.StashedWindows {
      if (hwnd = newHwnd || info["edge"] != edge || info["monitor"]["index"] != monitor["index"])
        continue
      if (this._framesOverlapAlongEdge(hiddenFrame, info["hiddenFrame"], edge))
        overlapping.Push(hwnd)
    }
    for hwnd in overlapping
      this._unstashWindow(hwnd, true)
  }

  _framesOverlapAlongEdge(first, second, edge) {
    if (edge = "top" || edge = "bottom")
      return first["x"] < second["x"] + second["w"] && second["x"] < first["x"] + first["w"]
    return first["y"] < second["y"] + second["h"] && second["y"] < first["y"] + first["h"]
  }

  _getMonitorForRect(x, y, w, h) {
    centerX := x + w / 2
    centerY := y + h / 2
    monitorCount := MonitorGetCount()
    bestIndex := MonitorGetPrimary()
    bestOverlap := -1
    bestDistance := 0x7FFFFFFFFFFFFFFF

    Loop monitorCount {
      MonitorGet(A_Index, &left, &top, &right, &bottom)
      if (centerX >= left && centerX < right && centerY >= top && centerY < bottom)
        return this._getMonitorInfo(A_Index)

      overlapWidth := Max(0, Min(x + w, right) - Max(x, left))
      overlapHeight := Max(0, Min(y + h, bottom) - Max(y, top))
      overlapArea := overlapWidth * overlapHeight
      distanceX := centerX < left ? left - centerX : centerX >= right ? centerX - right : 0
      distanceY := centerY < top ? top - centerY : centerY >= bottom ? centerY - bottom : 0
      distance := distanceX * distanceX + distanceY * distanceY

      if (overlapArea > bestOverlap || (overlapArea = bestOverlap && distance < bestDistance)) {
        bestIndex := A_Index
        bestOverlap := overlapArea
        bestDistance := distance
      }
    }
    return this._getMonitorInfo(bestIndex)
  }

  _getMonitorInfo(index) {
    MonitorGet(index, &fullLeft, &fullTop, &fullRight, &fullBottom)
    MonitorGetWorkArea(index, &left, &top, &right, &bottom)
    return Map(
      "index", index,
      "left", left, "top", top, "right", right, "bottom", bottom,
      "fullLeft", fullLeft, "fullTop", fullTop, "fullRight", fullRight, "fullBottom", fullBottom
    )
  }

  _getDisplaySignature() {
    signature := ""
    Loop MonitorGetCount() {
      monitor := this._getMonitorInfo(A_Index)
      signature .= Format("{1}:{2},{3},{4},{5},{6},{7},{8},{9};", A_Index,
        monitor["fullLeft"], monitor["fullTop"], monitor["fullRight"], monitor["fullBottom"],
        monitor["left"], monitor["top"], monitor["right"], monitor["bottom"]
      )
    }
    return signature
  }

  _getMonitorForEdge(currentMonitor, edge) {
    target := currentMonitor
    Loop MonitorGetCount() {
      candidate := this._getMonitorInfo(A_Index)

      if (edge = "left" || edge = "right") {
        overlap := Min(currentMonitor["fullBottom"], candidate["fullBottom"]) - Max(currentMonitor["fullTop"], candidate["fullTop"])
        if (overlap < 100)
          continue
        if (edge = "left" && candidate["fullLeft"] < target["fullLeft"])
          target := candidate
        if (edge = "right" && candidate["fullRight"] > target["fullRight"])
          target := candidate
      } else {
        overlap := Min(currentMonitor["fullRight"], candidate["fullRight"]) - Max(currentMonitor["fullLeft"], candidate["fullLeft"])
        if (overlap < 100)
          continue
        if (edge = "top" && candidate["fullTop"] < target["fullTop"])
          target := candidate
        if (edge = "bottom" && candidate["fullBottom"] > target["fullBottom"])
          target := candidate
      }
    }
    return target
  }

  _getEdgeRevealedFrame(frame, monitor, edge, insets:="") {
    result := this._getClampedFrame(frame, monitor)
    width := result["w"]
    height := result["h"]
    x := result["x"]
    y := result["y"]
    configuredOffset := Max(0, Integer(this.Config.WindowEdgeOffset))
    if (!IsObject(insets))
      insets := Map("left", 0, "top", 0, "right", 0, "bottom", 0)
    visibleWidth := Max(1, width - insets["left"] - insets["right"])
    visibleHeight := Max(1, height - insets["top"] - insets["bottom"])

    switch edge {
      case "left":
        offset := Min(configuredOffset, Max(0, monitor["right"] - monitor["left"] - visibleWidth))
        x := monitor["left"] + offset - insets["left"]
      case "right":
        offset := Min(configuredOffset, Max(0, monitor["right"] - monitor["left"] - visibleWidth))
        x := monitor["right"] - width - offset + insets["right"]
      case "top":
        offset := Min(configuredOffset, Max(0, monitor["bottom"] - monitor["top"] - visibleHeight))
        y := monitor["top"] + offset - insets["top"]
      case "bottom":
        offset := Min(configuredOffset, Max(0, monitor["bottom"] - monitor["top"] - visibleHeight))
        y := monitor["bottom"] - height - offset + insets["bottom"]
    }
    return Map("x", x, "y", y, "w", width, "h", height)
  }

  _getClampedFrame(frame, monitor) {
    width := Min(frame["w"], monitor["right"] - monitor["left"])
    height := Min(frame["h"], monitor["bottom"] - monitor["top"])
    x := this._clamp(frame["x"], monitor["left"], monitor["right"] - width)
    y := this._clamp(frame["y"], monitor["top"], monitor["bottom"] - height)
    return Map("x", x, "y", y, "w", width, "h", height)
  }

  _getInvisibleBorderOffsets(hwnd, frame:="") {
    insets := Map("left", 0, "top", 0, "right", 0, "bottom", 0)
    if (!WinExist("ahk_id " hwnd))
      return insets

    if (!IsObject(frame)) {
      frame := this._getWindowFrame(hwnd)
      if (!frame)
        return insets
    }

    visibleRect := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute",
      "Ptr", hwnd,
      "UInt", WindowFlags.DWMWA_EXTENDED_FRAME_BOUNDS,
      "Ptr", visibleRect.Ptr,
      "UInt", visibleRect.Size,
      "Int") != 0)
      return insets

    visibleLeft := NumGet(visibleRect, 0, "Int")
    visibleTop := NumGet(visibleRect, 4, "Int")
    visibleRight := NumGet(visibleRect, 8, "Int")
    visibleBottom := NumGet(visibleRect, 12, "Int")
    insets["left"] := Max(0, visibleLeft - frame["x"])
    insets["top"] := Max(0, visibleTop - frame["y"])
    insets["right"] := Max(0, frame["x"] + frame["w"] - visibleRight)
    insets["bottom"] := Max(0, frame["y"] + frame["h"] - visibleBottom)
    return insets
  }

  _getHiddenFrame(frame, monitor, edge) {
    x := frame["x"]
    y := frame["y"]

    switch edge {
      case "left":
        x := monitor["left"] - frame["w"]
      case "right":
        x := monitor["right"]
      case "top":
        y := monitor["top"] - frame["h"]
      case "bottom":
        y := monitor["bottom"]
    }
    return Map("x", x, "y", y, "w", frame["w"], "h", frame["h"])
  }

  _showHandle(hwnd, info, inwardOffset:=0) {
    created := false
    if (!IsObject(info["handleGui"])) {
      handleGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
      handleGui.BackColor := this._normalizeColor(this.Config.HandleColor)
      handleBody := handleGui.Add("Text", "x0 y0 w1 h1 Background" this._normalizeColor(this.Config.HandleColor))
      handleGrip := handleGui.Add("Text", "x0 y0 w1 h1 Background" this._normalizeColor(this.Config.HandleGripColor))
      handleGui.Show("Hide NoActivate")
      info["handleGui"] := handleGui
      info["handleBody"] := handleBody
      info["handleGrip"] := handleGrip
      this._handleWindows[handleGui.Hwnd] := hwnd
      this._handleWindows[handleBody.Hwnd] := hwnd
      this._handleWindows[handleGrip.Hwnd] := hwnd
      created := true
    }

    frame := this._getHandleFrame(info, inwardOffset)
    pullProgress := this._clamp(inwardOffset / Max(1, Integer(this.Config.HandleDragDistance)), 0, 1)
    opacity := Round(Number(this.Config.HandleOpacity) * ((1 - pullProgress) ** 2))
    frameChanged := !IsObject(info["handleFrame"]) || !this._framesEqual(info["handleFrame"], frame)
    opacityChanged := info["handleOpacity"] != opacity

    if (frameChanged) {
      info["handleFrame"] := frame
      info["handleGui"].Show(
        "x" Round(frame["x"])
        " y" Round(frame["y"])
        " w" Round(frame["w"])
        " h" Round(frame["h"])
        " NoActivate"
      )

      radius := Max(2, Min(Integer(this.Config.HandleThickness), Floor(Min(frame["w"], frame["h"]) / 2)))
      try WinSetRegion("0-0 W" Round(frame["w"]) " H" Round(frame["h"]) " R" radius "-" radius, "ahk_id " info["handleGui"].Hwnd)
      info["handleBody"].Move(0, 0, Round(frame["w"]), Round(frame["h"]))
      this._positionHandleGrip(info, frame)
      try DllCall("RedrawWindow", "Ptr", info["handleGui"].Hwnd, "Ptr", 0, "Ptr", 0,
        "UInt", RedrawWindowFlags.INVALIDATE | RedrawWindowFlags.ERASE | RedrawWindowFlags.ALLCHILDREN | RedrawWindowFlags.UPDATENOW
      )
    }

    if (opacityChanged) {
      WinSetTransparent(opacity, "ahk_id " info["handleGui"].Hwnd)
      info["handleOpacity"] := opacity
    }
    if (created)
      this._forceTopmost(info["handleGui"].Hwnd)
  }

  _getHandleFrame(info, inwardOffset:=0) {
    monitor := info["monitor"]
    revealedFrame := info["revealedFrame"]
    thickness := Integer(this.Config.HandleThickness)
    hiddenDepth := Max(thickness * 2, Integer(this.Config.HandleDragDistance))
    configuredLength := Integer(this.Config.HandleLength)
    pullProgress := this._clamp(inwardOffset / Max(1, Integer(this.Config.HandleDragDistance)), 0, 1)
    pulledLength := Max(thickness * 2, Round(configuredLength * (1 - 0.55 * pullProgress)))

    if (info["edge"] = "top" || info["edge"] = "bottom") {
      length := Min(pulledLength, monitor["right"] - monitor["left"])
      x := this._clamp(
        revealedFrame["x"] + (revealedFrame["w"] - length) / 2,
        monitor["left"],
        monitor["right"] - length
      )
      y := info["edge"] = "top"
        ? monitor["top"] - hiddenDepth
        : monitor["bottom"] - thickness - inwardOffset
      return Map(
        "x", x, "y", y,
        "w", length, "h", hiddenDepth + thickness + inwardOffset
      )
    }

    length := Min(pulledLength, monitor["bottom"] - monitor["top"])
    y := this._clamp(
      revealedFrame["y"] + (revealedFrame["h"] - length) / 2,
      monitor["top"],
      monitor["bottom"] - length
    )
    x := info["edge"] = "left"
      ? monitor["left"] - hiddenDepth
      : monitor["right"] - thickness - inwardOffset
    return Map("x", x, "y", y, "w", hiddenDepth + thickness + inwardOffset, "h", length)
  }

  _positionHandleGrip(info, frame) {
    if (!info.Has("handleGrip") || !IsObject(info["handleGrip"]))
      return

    thickness := Integer(this.Config.HandleThickness)
    gripThickness := Max(2, Min(4, Floor(thickness / 3)))
    gripLength := Max(8, Round((info["edge"] = "top" || info["edge"] = "bottom" ? frame["w"] : frame["h"]) * 0.42))

    if (info["edge"] = "top" || info["edge"] = "bottom") {
      gripWidth := Min(gripLength, frame["w"] - 4)
      gripHeight := gripThickness
      gripX := (frame["w"] - gripWidth) / 2
      visibleCenterY := info["edge"] = "top" ? frame["h"] - thickness / 2 : thickness / 2
      gripY := visibleCenterY - gripHeight / 2
    } else {
      gripWidth := gripThickness
      gripHeight := Min(gripLength, frame["h"] - 4)
      gripY := (frame["h"] - gripHeight) / 2
      visibleCenterX := info["edge"] = "left" ? frame["w"] - thickness / 2 : thickness / 2
      gripX := visibleCenterX - gripWidth / 2
    }

    info["handleGrip"].Move(Round(gripX), Round(gripY), Round(gripWidth), Round(gripHeight))
    gripRadius := Max(1, Floor(Min(gripWidth, gripHeight) / 2))
    try WinSetRegion("0-0 W" Round(gripWidth) " H" Round(gripHeight) " R" gripRadius "-" gripRadius, "ahk_id " info["handleGrip"].Hwnd)
  }

  _destroyHandle(info) {
    if (!info.Has("handleGui") || !IsObject(info["handleGui"])) {
      if (info.Has("handleFrame"))
        info["handleFrame"] := ""
      if (info.Has("handleOpacity"))
        info["handleOpacity"] := ""
      return
    }

    handleHwnd := info["handleGui"].Hwnd
    if (this._handleWindows.Has(handleHwnd))
      this._handleWindows.Delete(handleHwnd)
    if (info.Has("handleBody") && IsObject(info["handleBody"]) && this._handleWindows.Has(info["handleBody"].Hwnd))
      this._handleWindows.Delete(info["handleBody"].Hwnd)
    if (info.Has("handleGrip") && IsObject(info["handleGrip"]) && this._handleWindows.Has(info["handleGrip"].Hwnd))
      this._handleWindows.Delete(info["handleGrip"].Hwnd)
    try info["handleGui"].Destroy()
    info["handleGui"] := ""
    info["handleBody"] := ""
    info["handleGrip"] := ""
    info["handleFrame"] := ""
    info["handleOpacity"] := ""
  }

  _onHandleMouseDown(wParam, lParam, msg, sourceHwnd) {
    if (!this._handleWindows.Has(sourceHwnd) || this._draggingHandle)
      return

    hwnd := this._handleWindows[sourceHwnd]
    if (!this.StashedWindows.Has(hwnd))
      return

    info := this.StashedWindows[hwnd]

    CoordMode("Mouse", "Screen")
    MouseGetPos(&startX, &startY)
    targetDistance := Max(1, Integer(this.Config.HandleDragDistance))
    clickTolerance := 4
    lastDistance := 0
    maxMovement := 0
    dragDirection := ""
    startedRevealed := info["revealed"]
    if (startedRevealed && this._isWindowMinimized(hwnd)) {
      startedRevealed := false
      info["revealed"] := false
      info["revealMode"] := ""
      info["activationRevealUntil"] := 0
      info["restoreRevealUntil"] := 0
      info["parkedMinimized"] := true
      if (this.RevealedHwnd = hwnd)
        this.RevealedHwnd := 0
    }
    baseRevealedFrame := startedRevealed ? this._getWindowFrame(hwnd) : info["revealedFrame"]
    if (!baseRevealedFrame)
      return
    movedRevealedFrame := baseRevealedFrame
    movedHiddenFrame := this._getHiddenFrame(baseRevealedFrame, info["monitor"], info["edge"])
    info["revealedFrame"] := movedRevealedFrame
    info["hiddenFrame"] := movedHiddenFrame
    this._draggingHandle := true

    try {
      while GetKeyState("LButton", "P") {
        MouseGetPos(&mouseX, &mouseY)
        maxMovement := Max(maxMovement, Abs(mouseX - startX), Abs(mouseY - startY))
        rawAlongDistance := this._getAlongEdgeDragDistance(info["edge"], startX, startY, mouseX, mouseY)
        rawInwardDistance := Max(0, this._getInwardDragDistance(info["edge"], startX, startY, mouseX, mouseY))
        if (!this.Config.LockHandleDragAxis)
          dragDirection := "free"
        else if (dragDirection = "" && maxMovement > clickTolerance)
          dragDirection := rawInwardDistance > Abs(rawAlongDistance) * 1.15 ? "inward" : "along"

        alongDistance := dragDirection = "along" || dragDirection = "free" ? rawAlongDistance : 0
        movedRevealedFrame := this._moveFrameAlongEdge(baseRevealedFrame, info["monitor"], info["edge"], alongDistance)
        movedHiddenFrame := this._getHiddenFrame(movedRevealedFrame, info["monitor"], info["edge"])
        info["revealedFrame"] := movedRevealedFrame
        info["hiddenFrame"] := movedHiddenFrame

        inwardDistance := dragDirection = "inward" || dragDirection = "free" ? rawInwardDistance : 0
        lastDistance := this._clamp(inwardDistance, 0, targetDistance)
        edgeFrame := info["revealed"] ? movedRevealedFrame : movedHiddenFrame

        if (dragDirection = "along" || dragDirection = "free") {
          if (startedRevealed && this.Config.ShowWindowContent)
            this._moveWindow(hwnd, edgeFrame)
          else if (startedRevealed && !this.Config.ShowWindowContent)
            this._showOverlay(edgeFrame)
        }
        this._showHandle(hwnd, info, lastDistance)
        Sleep(10)
      }

      if (lastDistance >= targetDistance) {
        this._unstashWindow(hwnd, true)
      } else if (maxMovement <= clickTolerance) {
        info["revealedFrame"] := baseRevealedFrame
        info["hiddenFrame"] := this._getHiddenFrame(baseRevealedFrame, info["monitor"], info["edge"])
        if (startedRevealed) {
          info["suppressHandleHover"] := true
          this._hideWindow(hwnd)
        } else {
          info["suppressHandleHover"] := false
          this._revealWindow(hwnd, "handle")
        }
      } else {
        edgeFrame := info["revealed"] ? movedRevealedFrame : movedHiddenFrame
        if (dragDirection = "along" || dragDirection = "free") {
          if (startedRevealed)
            this._moveWindow(hwnd, edgeFrame)
          else
            this._parkHiddenWindow(hwnd, info)
        } else if (startedRevealed)
          this._moveWindow(hwnd, edgeFrame)
        this._showHandle(hwnd, info)
      }
    } finally {
      this._destroyOverlay()
      this._draggingHandle := false
    }
  }

  _getInwardDragDistance(edge, startX, startY, mouseX, mouseY) {
    switch edge {
      case "left":
        return mouseX - startX
      case "right":
        return startX - mouseX
      case "top":
        return mouseY - startY
      case "bottom":
        return startY - mouseY
    }
    return 0
  }

  _getAlongEdgeDragDistance(edge, startX, startY, mouseX, mouseY) {
    return edge = "top" || edge = "bottom" ? mouseX - startX : mouseY - startY
  }

  _moveFrameAlongEdge(frame, monitor, edge, distance) {
    x := frame["x"]
    y := frame["y"]

    if (edge = "top" || edge = "bottom")
      x := this._clamp(x + distance, monitor["left"], monitor["right"] - frame["w"])
    else
      y := this._clamp(y + distance, monitor["top"], monitor["bottom"] - frame["h"])

    return Map("x", x, "y", y, "w", frame["w"], "h", frame["h"])
  }

  _getUnstashFrame(info, revealedFrame) {
    if (this.Config.RestorePositionOnUnstash)
      return info["originalFrame"]

    return revealedFrame
  }

  _restoreParkedWindow(hwnd, info, restoreFrame:="") {
    if (!WinExist("ahk_id " hwnd))
      return false

    windowState := 0
    restored := false
    try windowState := WinGetMinMax("ahk_id " hwnd)
    wasParked := info["parkedMinimized"]
    if (wasParked || windowState = -1) {
      this._logState("restore parked", hwnd, info, "windowState=" windowState)
      if (IsObject(restoreFrame))
        this._moveWindow(hwnd, restoreFrame)
      if (windowState = -1) {
        try {
          WinRestore("ahk_id " hwnd)
          restored := true
        }
      }
      if (IsObject(restoreFrame))
        this._moveWindow(hwnd, restoreFrame)
    }
    info["parkedMinimized"] := false
    return restored || wasParked
  }

  _prepareRestoredWindow(hwnd, info, startFrame, keepTransparent:=false) {
    shouldRestore := info["parkedMinimized"] || this._isWindowMinimized(hwnd)
    if (shouldRestore) {
      this._suppressWindowTransparency(hwnd, info)
      this._logState("restore suppression", hwnd, info, "transparent=" info["transparencySuppressedByStash"])
    }

    restored := this._restoreParkedWindow(hwnd, info, startFrame)
    if (restored && info["transparencySuppressedByStash"])
      try WinSetTransparent(0, "ahk_id " hwnd)
    this._moveWindow(hwnd, startFrame)
    if (restored && Integer(this.Config.RestoreSettleDelay) > 0)
      Sleep(Integer(this.Config.RestoreSettleDelay))
    if (!keepTransparent)
      this._restoreWindowTransparency(hwnd, info)
    return restored
  }

  _parkHiddenWindow(hwnd, info) {
    if (!WinExist("ahk_id " hwnd))
      return

    this._suppressWindowTransparency(hwnd, info)
    this._restoreParkedWindow(hwnd, info, info["revealedFrame"])
    this._moveWindow(hwnd, info["revealedFrame"])
    if (Integer(this.Config.RestoreSettleDelay) > 0)
      Sleep(Integer(this.Config.RestoreSettleDelay))
    info["transitionsDisabledByStash"] := this._setWindowTransitionsDisabled(hwnd, true)
    try WinMinimize("ahk_id " hwnd)
    info["parkedMinimized"] := this._isWindowMinimized(hwnd)
    if (!info["parkedMinimized"]) {
      this._moveWindow(hwnd, info["hiddenFrame"])
      this._restoreWindowTransitions(hwnd, info)
    }
    this._restoreWindowTransparency(hwnd, info)
    this._logState("park minimized", hwnd, info)
  }

  _setWindowTransitionsDisabled(hwnd, disabled) {
    if (!WinExist("ahk_id " hwnd))
      return false

    value := disabled ? 1 : 0
    try {
      return DllCall(
        "dwmapi\DwmSetWindowAttribute",
        "Ptr", hwnd,
        "UInt", WindowFlags.DWMWA_TRANSITIONS_FORCEDISABLED,
        "Int*", value,
        "UInt", Win32Sizes.DWORD
      ) = 0
    }
    return false
  }

  _restoreWindowTransitions(hwnd, info) {
    if (!info["transitionsDisabledByStash"])
      return

    this._setWindowTransitionsDisabled(hwnd, false)
    info["transitionsDisabledByStash"] := false
  }

  _restoreWindowTransparency(hwnd, info) {
    if (!info["transparencySuppressedByStash"])
      return

    try {
      if (info["restoreTransparency"] = "")
        WinSetTransparent("OFF", "ahk_id " hwnd)
      else
        WinSetTransparent(info["restoreTransparency"], "ahk_id " hwnd)
    }
    info["restoreTransparency"] := ""
    info["transparencySuppressedByStash"] := false
  }

  _suppressWindowTransparency(hwnd, info) {
    if (info["transparencySuppressedByStash"] || !WinExist("ahk_id " hwnd))
      return

    info["restoreTransparency"] := ""
    try info["restoreTransparency"] := WinGetTransparent("ahk_id " hwnd)
    try {
      WinSetTransparent(0, "ahk_id " hwnd)
      info["transparencySuppressedByStash"] := true
    }
  }

  _logState(event, hwnd, info, details:="") {
    windowState := ""
    try windowState := WinGetMinMax("ahk_id " hwnd)
    message := event " hwnd=" hwnd " active=" WinExist("A") " windowState=" windowState
    message .= " revealed=" info["revealed"] " revealMode=" info["revealMode"]
    message .= " parkedMinimized=" info["parkedMinimized"] " suppressActivationReveal=" info["suppressActivationReveal"]
    message .= " transparencySuppressed=" info["transparencySuppressedByStash"]
    if (info["activationRevealUntil"])
      message .= " activationGraceRemaining=" Max(0, info["activationRevealUntil"] - A_TickCount)
    if (details != "")
      message .= " " details
    this.outputDebugLine(AKApp.LOG_DEBUG, message)
  }

  _setWindowBorderColor(hwnd, color) {
    if (!WinExist("ahk_id " hwnd))
      return

    colorValue := color = -1 ? -1 : "0x" this._normalizeColor(color)
    try this.RunAction("SetWindowBorderColor(" colorValue ", " hwnd ")")
  }

  _getWindowBorderColor(hwnd) {
    if (!WinExist("ahk_id " hwnd))
      return ""

    color := 0
    try {
      if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_BORDER_COLOR, "UInt*", &color, "UInt", Win32Sizes.DWORD) = 0)
        return color
    }
    return ""
  }

  _restoreWindowBorderColor(hwnd, info) {
    if (!WinExist("ahk_id " hwnd) || !info.Has("borderColor"))
      return

    currentColor := this._getWindowBorderColor(hwnd)
    if (info.Has("stashBorderColor") && info["stashBorderColor"] != "" && currentColor != info["stashBorderColor"])
      return

    borderColor := info["borderColor"]
    if (borderColor = "")
      return
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", WindowFlags.DWMWA_BORDER_COLOR, "UInt*", borderColor, "UInt", Win32Sizes.DWORD)
  }

  _normalizeColor(color) {
    return RegExReplace("" color, "i)^0x", "")
  }

  _raiseHandles() {
    for hwnd, info in this.StashedWindows {
      if (IsObject(info["handleGui"]))
        this._forceTopmost(info["handleGui"].Hwnd)
    }
  }

  _forceTopmost(hwnd) {
    try DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", WindowFlags.HWND_TOPMOST, "Int", 0, "Int", 0, "Int", 0, "Int", 0,
      "UInt", WindowFlags.SWP_NOSIZE | WindowFlags.SWP_NOMOVE | WindowFlags.SWP_NOACTIVATE | WindowFlags.SWP_SHOWWINDOW
    )
  }

  _moveWindow(hwnd, frame) {
    try WinMove(frame["x"], frame["y"], frame["w"], frame["h"], "ahk_id " hwnd)
  }

  _getWindowFrame(hwnd) {
    try {
      WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
      return Map("x", x, "y", y, "w", w, "h", h)
    } catch {
      return false
    }
  }

  _isWindowMinimized(hwnd) {
    try return WinGetMinMax("ahk_id " hwnd) = -1
    return false
  }

  _framesEqual(first, second, tolerance:=1) {
    return Abs(first["x"] - second["x"]) <= tolerance
      && Abs(first["y"] - second["y"]) <= tolerance
      && Abs(first["w"] - second["w"]) <= tolerance
      && Abs(first["h"] - second["h"]) <= tolerance
  }

  _transitionWindow(hwnd, targetFrame) {
    startFrame := this._getWindowFrame(hwnd)
    if (!startFrame)
      return false

    if (!this.Config.AnimateTransitions || this._framesEqual(startFrame, targetFrame)) {
      this._moveWindow(hwnd, targetFrame)
      return true
    }

    criticalState := Critical()
    Critical("On")
    this._animating := true

    try {
      duration := Max(1, Integer(this.Config.AnimationDuration))
      steps := Max(2, Round(duration / 15))
      stepDelay := Max(1, Round(duration / steps))
      showContent := this.Config.ShowWindowContent

      if (!showContent)
        this._createOverlay()

      Loop steps {
        progress := A_Index / steps
        eased := progress < 0.5 ? 2 * progress * progress : 1 - ((-2 * progress + 2) ** 2) / 2
        frame := this._interpolateFrame(startFrame, targetFrame, eased)

        if (showContent)
          this._moveWindow(hwnd, frame)
        else
          this._showOverlay(frame)

        if (A_Index < steps)
          Sleep(stepDelay)
      }

      if (!showContent)
        this._moveWindow(hwnd, targetFrame)
      return true
    } finally {
      this._destroyOverlay()
      this._animating := false
      Critical(criticalState)
    }
  }

  _interpolateFrame(startFrame, targetFrame, progress) {
    return Map(
      "x", Round(startFrame["x"] + (targetFrame["x"] - startFrame["x"]) * progress),
      "y", Round(startFrame["y"] + (targetFrame["y"] - startFrame["y"]) * progress),
      "w", Round(startFrame["w"] + (targetFrame["w"] - startFrame["w"]) * progress),
      "h", Round(startFrame["h"] + (targetFrame["h"] - startFrame["h"]) * progress)
    )
  }

  _createOverlay() {
    this._destroyOverlay()
    this._overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    this._overlayGui.BackColor := this.Config.OverlayColor
    this._overlayGui.Show("Hide NoActivate")
    WinSetTransparent(Number(this.Config.OverlayOpacity), "ahk_id " this._overlayGui.Hwnd)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this._overlayGui.Hwnd, "UInt", WindowFlags.DWMWA_WINDOW_CORNER_PREFERENCE, "Int*", WindowFlags.DWMWCP_ROUND, "UInt", Win32Sizes.DWORD)
  }

  _showOverlay(frame) {
    if (!IsObject(this._overlayGui))
      this._createOverlay()
    this._overlayGui.Show("x" Round(frame["x"]) " y" Round(frame["y"]) " w" Round(frame["w"]) " h" Round(frame["h"]) " NoActivate")
  }

  _destroyOverlay() {
    if (!IsObject(this._overlayGui))
      return
    try this._overlayGui.Destroy()
    this._overlayGui := ""
  }

  _focusAnotherWindow(hiddenHwnd) {
    for hwnd in WinGetList() {
      if (hwnd = hiddenHwnd || this.StashedWindows.Has(hwnd))
        continue
      try {
        if (!DllCall("IsWindowVisible", "ptr", hwnd) || WinGetMinMax("ahk_id " hwnd) = -1)
          continue
        if (WinGetTitle("ahk_id " hwnd) = "")
          continue
        WinActivate("ahk_id " hwnd)
        return
      }
    }
  }

  _pointInFrame(x, y, frame, tolerance:=0) {
    return x >= frame["x"] - tolerance
      && x < frame["x"] + frame["w"] + tolerance
      && y >= frame["y"] - tolerance
      && y < frame["y"] + frame["h"] + tolerance
  }

  _isPointerInRevealArea(info, x, y) {
    frame := info["revealedFrame"]
    monitor := info["monitor"]
    tolerance := Integer(this.Config.HoverTolerance)

    switch info["edge"] {
      case "left":
        return x >= monitor["left"] - tolerance
          && x < frame["x"] + frame["w"] + tolerance
          && y >= frame["y"] - tolerance
          && y < frame["y"] + frame["h"] + tolerance
      case "right":
        return x >= frame["x"] - tolerance
          && x < monitor["right"] + tolerance
          && y >= frame["y"] - tolerance
          && y < frame["y"] + frame["h"] + tolerance
      case "top":
        return x >= frame["x"] - tolerance
          && x < frame["x"] + frame["w"] + tolerance
          && y >= monitor["top"] - tolerance
          && y < frame["y"] + frame["h"] + tolerance
      case "bottom":
        return x >= frame["x"] - tolerance
          && x < frame["x"] + frame["w"] + tolerance
          && y >= frame["y"] - tolerance
          && y < monitor["bottom"] + tolerance
    }
    return this._pointInFrame(x, y, frame, tolerance)
  }

  _clamp(value, minimum, maximum) {
    return Max(minimum, Min(value, maximum))
  }

  _onExit(*) {
    this._stopPolling()
    SetTimer(this._displayChangeTimerFn, 0)
    OnMessage(0x007E, this._displayChangeFn, 0)
    OnMessage(0x001A, this._displayChangeFn, 0)
    OnMessage(0x0201, this._handleMouseDownFn, 0)
    for hwnd, info in this.StashedWindows {
      this._destroyHandle(info)
      if (!WinExist("ahk_id " hwnd))
        continue
      this._restoreParkedWindow(hwnd, info)
      this._restoreWindowBorderColor(hwnd, info)
      this._moveWindow(hwnd, info["originalFrame"])
      if (info["wasMaximized"])
        try WinMaximize("ahk_id " hwnd)
      this._restoreWindowTransparency(hwnd, info)
      this._restoreWindowTransitions(hwnd, info)
    }
    this._destroyOverlay()
  }
}

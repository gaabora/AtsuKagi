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
        "description", "Temporarily hide windows at a screen edge and reveal them by hovering over the visible strip",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure edge-stashed window behavior",
        "icon", "icons10-window"
      ),
      "config", [
        Map(
          "key", "PeekSize",
          "label", "Visible strip",
          "description", "Pixels of a stashed window kept visible at the screen edge",
          "type", "integer", "control", "range", "default", 12, "section", "Behavior",
          "validation", Map("min", 2, "max", 64, "step", 1)
        ),
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
          "key", "StashedWindowBorderColor",
          "label", "Stashed window outline",
          "description", "Border color applied while a window is managed by Window Stash",
          "type", "color", "control", "color", "default", "FF2D55", "section", "Visuals"
        ),
        Map(
          "key", "UseStashHandle",
          "label", "Use stash handle",
          "description", "Show a half-hidden rounded tab; hover reveals temporarily, while click or inward drag unstashes",
          "type", "boolean", "control", "switch", "default", true, "section", "Handle"
        ),
        Map(
          "key", "HandleColor",
          "label", "Handle color",
          "description", "Color of the stash handle",
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
          "description", "Visible thickness of the tab; an equal portion remains beyond the screen edge",
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
        )
      ],
      "actions", [
        Map("action", "StashWindowLeft", "label", "Stash window left", "description", "Stash a specific or active window at the left screen edge", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
        Map("action", "StashWindowRight", "label", "Stash window right", "description", "Stash a specific or active window at the right screen edge", "category", "Stash", "params", [Map("name", "hwnd", "default", 0)]),
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

    if (key = "StashedWindowBorderColor") {
      for hwnd in this.StashedWindows
        this._setWindowBorderColor(hwnd, value)
      return
    }

    if (key = "UseStashHandle" || key = "HandleColor" || key = "HandleGripColor" || key = "HandleOpacity"
      || key = "HandleThickness" || key = "HandleLength") {
      for hwnd, info in this.StashedWindows {
        this._destroyHandle(info)
        info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], info["monitor"], info["edge"])
        if (!info["revealed"]) {
          this._moveWindow(hwnd, info["hiddenFrame"])
          this._showHandle(hwnd, info)
        }
      }
      return
    }

    if (key != "PeekSize")
      return

    for hwnd, info in this.StashedWindows {
      info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], info["monitor"], info["edge"])
      if (!info["revealed"] && WinExist("ahk_id " hwnd))
        this._moveWindow(hwnd, info["hiddenFrame"])
    }
  }

  StashWindowLeft(hwnd:=0) { ;;;
    return this._stashWindow(hwnd, "left")
  }

  StashWindowRight(hwnd:=0) { ;;;
    return this._stashWindow(hwnd, "right")
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
      currentMonitor := this._getMonitorForRect(currentFrame["x"], currentFrame["y"], currentFrame["w"], currentFrame["h"])
      targetMonitor := this._getMonitorForEdge(currentMonitor, edge)
      info["edge"] := edge
      info["monitor"] := targetMonitor
      info["revealedFrame"] := this._getEdgeRevealedFrame(currentFrame, targetMonitor, edge)
      info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], info["monitor"], edge)
      this._restoreOverlappingWindows(hwnd, edge, info["monitor"], info["hiddenFrame"])
      this._hideWindow(hwnd)
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
    revealedFrame := wasMaximized
      ? Map("x", monitor["left"], "y", monitor["top"], "w", monitor["right"] - monitor["left"], "h", monitor["bottom"] - monitor["top"])
      : this._getEdgeRevealedFrame(originalFrame, monitor, edge)
    hiddenFrame := this._getHiddenFrame(revealedFrame, monitor, edge)

    this._restoreOverlappingWindows(hwnd, edge, monitor, hiddenFrame)
    this.StashedWindows[hwnd] := Map(
      "edge", edge,
      "monitor", monitor,
      "originalFrame", originalFrame,
      "wasMaximized", wasMaximized,
      "revealedFrame", revealedFrame,
      "hiddenFrame", hiddenFrame,
      "revealed", true,
      "revealMode", "",
      "handleGui", "",
      "handleGrip", "",
      "handleFrame", ""
    )

    this._setWindowBorderColor(hwnd, this.Config.StashedWindowBorderColor)
    this._hideWindow(hwnd)
    this._startPolling()
    return true
  }

  _unstashWindow(hwnd, restoreFrame) {
    if (!this.StashedWindows.Has(hwnd))
      return false

    info := this.StashedWindows[hwnd]
    this._destroyHandle(info)
    this._setWindowBorderColor(hwnd, -1)
    if (restoreFrame && WinExist("ahk_id " hwnd)) {
      this._transitionWindow(hwnd, info["originalFrame"])
      if (info["wasMaximized"])
        try WinMaximize("ahk_id " hwnd)
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

    if (this.RevealedHwnd && this.RevealedHwnd != hwnd)
      this._hideWindow(this.RevealedHwnd, false)

    info := this.StashedWindows[hwnd]
    this._destroyHandle(info)
    this._transitionWindow(hwnd, info["revealedFrame"])
    info["revealed"] := true
    info["revealMode"] := revealMode
    this.RevealedHwnd := hwnd

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
    if (shiftFocus && this.Config.ShiftFocusWhenStashed && WinExist("A") = hwnd)
      this._focusAnotherWindow(hwnd)

    this._transitionWindow(hwnd, info["hiddenFrame"])
    info["revealed"] := false
    info["revealMode"] := ""
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
      this._lastMouseX := mouseX
      this._lastMouseY := mouseY
      this._lastActiveHwnd := activeHwnd

      if (activeChanged && this.StashedWindows.Has(activeHwnd) && !this.StashedWindows[activeHwnd]["revealed"]) {
        this._revealWindow(activeHwnd, "activation")
        return
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

      if (revealedInfo["revealMode"] = "activation") {
        if (activeHwnd != this.RevealedHwnd && pointerOutside && (activeChanged || mouseMoved))
          this._hideWindow(this.RevealedHwnd, false)
        return
      }

      if (pointerOutside && (mouseMoved || activeChanged))
        this._hideWindow(this.RevealedHwnd, activeHwnd = this.RevealedHwnd)
    } finally {
      this._polling := false
    }
  }

  _getStashedWindowAtPoint(x, y, includeRevealed:=false) {
    for hwnd, info in this.StashedWindows {
      if (!info["revealed"] && IsObject(info["handleFrame"]) && this._pointInFrame(x, y, info["handleFrame"]))
        return hwnd
    }

    for hwnd in WinGetList() {
      if (!this.StashedWindows.Has(hwnd))
        continue
      info := this.StashedWindows[hwnd]
      if ((includeRevealed || !info["revealed"]) && this._pointInFrame(x, y, info["hiddenFrame"]))
        return hwnd
      if (includeRevealed && info["revealed"] && this._pointInFrame(x, y, info["revealedFrame"]))
        return hwnd
    }
    return 0
  }

  _updateRevealedFrame(hwnd) {
    if (this._animating || !this.StashedWindows.Has(hwnd))
      return

    info := this.StashedWindows[hwnd]
    if (!info["revealed"])
      return

    currentFrame := this._getWindowFrame(hwnd)
    if (!currentFrame || this._framesEqual(currentFrame, info["revealedFrame"]))
      return

    monitor := this._getMonitorForRect(currentFrame["x"], currentFrame["y"], currentFrame["w"], currentFrame["h"])
    info["monitor"] := monitor
    info["revealedFrame"] := currentFrame
    info["hiddenFrame"] := this._getHiddenFrame(currentFrame, monitor, info["edge"])
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

      originalMonitor := this._getMonitorForRect(
        info["originalFrame"]["x"],
        info["originalFrame"]["y"],
        info["originalFrame"]["w"],
        info["originalFrame"]["h"]
      )
      info["originalFrame"] := this._getClampedFrame(info["originalFrame"], originalMonitor)

      currentMonitor := this._getMonitorForRect(
        info["revealedFrame"]["x"],
        info["revealedFrame"]["y"],
        info["revealedFrame"]["w"],
        info["revealedFrame"]["h"]
      )
      targetMonitor := this._getMonitorForEdge(currentMonitor, info["edge"])
      info["monitor"] := targetMonitor
      info["revealedFrame"] := this._getEdgeRevealedFrame(info["revealedFrame"], targetMonitor, info["edge"])
      info["hiddenFrame"] := this._getHiddenFrame(info["revealedFrame"], targetMonitor, info["edge"])

      targetFrame := info["revealed"] ? info["revealedFrame"] : info["hiddenFrame"]
      this._moveWindow(hwnd, targetFrame)
      if (info["revealed"])
        this._destroyHandle(info)
      else
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
    if (edge = "bottom")
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
      "left", left,
      "top", top,
      "right", right,
      "bottom", bottom,
      "fullLeft", fullLeft,
      "fullTop", fullTop,
      "fullRight", fullRight,
      "fullBottom", fullBottom
    )
  }

  _getDisplaySignature() {
    signature := ""
    Loop MonitorGetCount() {
      monitor := this._getMonitorInfo(A_Index)
      signature .= Format(
        "{1}:{2},{3},{4},{5},{6},{7},{8},{9};",
        A_Index,
        monitor["fullLeft"],
        monitor["fullTop"],
        monitor["fullRight"],
        monitor["fullBottom"],
        monitor["left"],
        monitor["top"],
        monitor["right"],
        monitor["bottom"]
      )
    }
    return signature
  }

  _getMonitorForEdge(currentMonitor, edge) {
    target := currentMonitor
    Loop MonitorGetCount() {
      candidate := this._getMonitorInfo(A_Index)

      if (edge = "left" || edge = "right") {
        overlap := Min(currentMonitor["fullBottom"], candidate["fullBottom"])
          - Max(currentMonitor["fullTop"], candidate["fullTop"])
        if (overlap < 100)
          continue
        if (edge = "left" && candidate["fullLeft"] < target["fullLeft"])
          target := candidate
        if (edge = "right" && candidate["fullRight"] > target["fullRight"])
          target := candidate
      } else {
        overlap := Min(currentMonitor["fullRight"], candidate["fullRight"])
          - Max(currentMonitor["fullLeft"], candidate["fullLeft"])
        if (overlap >= 100 && candidate["fullBottom"] > target["fullBottom"])
          target := candidate
      }
    }
    return target
  }

  _getEdgeRevealedFrame(frame, monitor, edge) {
    result := this._getClampedFrame(frame, monitor)
    width := result["w"]
    height := result["h"]
    x := result["x"]
    y := result["y"]

    switch edge {
      case "left":
        x := monitor["left"]
      case "right":
        x := monitor["right"] - width
      case "bottom":
        y := monitor["bottom"] - height
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

  _getHiddenFrame(frame, monitor, edge) {
    peekSize := this.Config.UseStashHandle ? 0 : Integer(this.Config.PeekSize)
    x := frame["x"]
    y := frame["y"]

    switch edge {
      case "left":
        x := monitor["left"] - frame["w"] + peekSize
      case "right":
        x := monitor["right"] - peekSize
      case "bottom":
        y := monitor["bottom"] - peekSize
    }
    return Map("x", x, "y", y, "w", frame["w"], "h", frame["h"])
  }

  _showHandle(hwnd, info, inwardOffset:=0) {
    if (!this.Config.UseStashHandle) {
      this._destroyHandle(info)
      return
    }

    if (!IsObject(info["handleGui"])) {
      handleGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
      handleGui.BackColor := this._normalizeColor(this.Config.HandleColor)
      handleGrip := handleGui.Add(
        "Text",
        "x0 y0 w1 h1 Background" this._normalizeColor(this.Config.HandleGripColor)
      )
      handleGui.Show("Hide NoActivate")
      WinSetTransparent(Number(this.Config.HandleOpacity), "ahk_id " handleGui.Hwnd)
      info["handleGui"] := handleGui
      info["handleGrip"] := handleGrip
      this._handleWindows[handleGui.Hwnd] := hwnd
      this._handleWindows[handleGrip.Hwnd] := hwnd
    }

    frame := this._getHandleFrame(info, inwardOffset)
    info["handleFrame"] := frame
    info["handleGui"].Show(
      "x" Round(frame["x"])
      " y" Round(frame["y"])
      " w" Round(frame["w"])
      " h" Round(frame["h"])
      " NoActivate"
    )

    radius := Max(2, Floor(Min(frame["w"], frame["h"]) / 2))
    try WinSetRegion(
      "0-0 W" Round(frame["w"]) " H" Round(frame["h"]) " R" radius "-" radius,
      "ahk_id " info["handleGui"].Hwnd
    )
    this._positionHandleGrip(info, frame)
  }

  _getHandleFrame(info, inwardOffset:=0) {
    monitor := info["monitor"]
    revealedFrame := info["revealedFrame"]
    thickness := Integer(this.Config.HandleThickness)
    configuredLength := Integer(this.Config.HandleLength)

    if (info["edge"] = "bottom") {
      length := Min(configuredLength, monitor["right"] - monitor["left"])
      x := this._clamp(
        revealedFrame["x"] + (revealedFrame["w"] - length) / 2,
        monitor["left"],
        monitor["right"] - length
      )
      return Map(
        "x", x,
        "y", monitor["bottom"] - thickness - inwardOffset,
        "w", length,
        "h", thickness * 2
      )
    }

    length := Min(configuredLength, monitor["bottom"] - monitor["top"])
    y := this._clamp(
      revealedFrame["y"] + (revealedFrame["h"] - length) / 2,
      monitor["top"],
      monitor["bottom"] - length
    )
    x := info["edge"] = "left"
      ? monitor["left"] - thickness + inwardOffset
      : monitor["right"] - thickness - inwardOffset
    return Map("x", x, "y", y, "w", thickness * 2, "h", length)
  }

  _positionHandleGrip(info, frame) {
    if (!info.Has("handleGrip") || !IsObject(info["handleGrip"]))
      return

    thickness := Integer(this.Config.HandleThickness)
    gripThickness := Max(2, Min(4, Floor(thickness / 3)))
    gripLength := Max(10, Round(Integer(this.Config.HandleLength) * 0.42))

    if (info["edge"] = "bottom") {
      gripWidth := Min(gripLength, frame["w"] - 4)
      gripHeight := gripThickness
      gripX := (frame["w"] - gripWidth) / 2
      gripY := (thickness - gripHeight) / 2
    } else {
      gripWidth := gripThickness
      gripHeight := Min(gripLength, frame["h"] - 4)
      gripY := (frame["h"] - gripHeight) / 2
      visibleCenterX := info["edge"] = "left" ? thickness * 1.5 : thickness * 0.5
      gripX := visibleCenterX - gripWidth / 2
    }

    info["handleGrip"].Move(
      Round(gripX),
      Round(gripY),
      Round(gripWidth),
      Round(gripHeight)
    )
    gripRadius := Max(1, Floor(Min(gripWidth, gripHeight) / 2))
    try WinSetRegion(
      "0-0 W" Round(gripWidth) " H" Round(gripHeight) " R" gripRadius "-" gripRadius,
      "ahk_id " info["handleGrip"].Hwnd
    )
  }

  _destroyHandle(info) {
    if (!info.Has("handleGui") || !IsObject(info["handleGui"])) {
      if (info.Has("handleFrame"))
        info["handleFrame"] := ""
      return
    }

    handleHwnd := info["handleGui"].Hwnd
    if (this._handleWindows.Has(handleHwnd))
      this._handleWindows.Delete(handleHwnd)
    if (info.Has("handleGrip") && IsObject(info["handleGrip"]) && this._handleWindows.Has(info["handleGrip"].Hwnd))
      this._handleWindows.Delete(info["handleGrip"].Hwnd)
    try info["handleGui"].Destroy()
    info["handleGui"] := ""
    info["handleGrip"] := ""
    info["handleFrame"] := ""
  }

  _onHandleMouseDown(wParam, lParam, msg, sourceHwnd) {
    if (!this._handleWindows.Has(sourceHwnd) || this._draggingHandle)
      return

    hwnd := this._handleWindows[sourceHwnd]
    if (!this.StashedWindows.Has(hwnd))
      return

    info := this.StashedWindows[hwnd]
    if (info["revealed"])
      return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&startX, &startY)
    targetDistance := Max(1, Integer(this.Config.HandleDragDistance))
    lastDistance := 0
    this._draggingHandle := true

    try {
      if (!this.Config.ShowWindowContent)
        this._createOverlay()

      while GetKeyState("LButton", "P") {
        MouseGetPos(&mouseX, &mouseY)
        inwardDistance := this._getInwardDragDistance(info["edge"], startX, startY, mouseX, mouseY)
        lastDistance := this._clamp(inwardDistance, 0, targetDistance)
        progress := lastDistance / targetDistance
        frame := this._interpolateFrame(info["hiddenFrame"], info["originalFrame"], progress)

        if (this.Config.ShowWindowContent)
          this._moveWindow(hwnd, frame)
        else
          this._showOverlay(frame)
        this._showHandle(hwnd, info, lastDistance)
        Sleep(10)
      }

      if (lastDistance >= targetDistance) {
        this._moveWindow(hwnd, info["originalFrame"])
        this._unstashWindow(hwnd, true)
      } else if (lastDistance <= 3) {
        this._moveWindow(hwnd, info["hiddenFrame"])
        this._unstashWindow(hwnd, true)
      } else {
        this._moveWindow(hwnd, info["hiddenFrame"])
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
      case "bottom":
        return startY - mouseY
    }
    return 0
  }

  _setWindowBorderColor(hwnd, color) {
    if (!WinExist("ahk_id " hwnd))
      return

    dwmColor := 0xFFFFFFFF
    if (color != -1) {
      rgb := Integer("0x" this._normalizeColor(color))
      red := (rgb & 0xFF0000) >> 16
      green := (rgb & 0xFF00) >> 8
      blue := rgb & 0xFF
      dwmColor := (blue << 16) | (green << 8) | red
    }
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 34, "UInt*", dwmColor, "UInt", 4)
  }

  _normalizeColor(color) {
    return RegExReplace("" color, "i)^0x", "")
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
        eased := progress < 0.5
          ? 2 * progress * progress
          : 1 - ((-2 * progress + 2) ** 2) / 2
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
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this._overlayGui.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4)
  }

  _showOverlay(frame) {
    if (!IsObject(this._overlayGui))
      this._createOverlay()
    this._overlayGui.Show(
      "x" Round(frame["x"])
      " y" Round(frame["y"])
      " w" Round(frame["w"])
      " h" Round(frame["h"])
      " NoActivate"
    )
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
      this._setWindowBorderColor(hwnd, -1)
      this._moveWindow(hwnd, info["originalFrame"])
      if (info["wasMaximized"])
        try WinMaximize("ahk_id " hwnd)
    }
    this._destroyOverlay()
  }
}

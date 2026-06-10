class WindowResizeDialog extends AKPlugin {
  _dialog := 0
  _selectedHwnd := 0
  _oldX := 0
  _oldY := 0
  _oldW := 0
  _oldH := 0
  _oldState := 0
  _widthControl := 0
  _heightControl := 0
  _dialogHotkeys := Map()
  _dialogHotkeyContext := 0
  _directionKeys := Map()
  _pressedDirectionKeys := Map()
  _inputTimerFn := 0
  _inputTimerRunning := false

  __DescribePlugin() {
    modifierOptions := [
      Map("value", "Alt", "label", "Alt"),
      Map("value", "Ctrl", "label", "Ctrl"),
      Map("value", "Shift", "label", "Shift"),
      Map("value", "Win", "label", "Win")
    ]

    return Map(
      "plugin", Map(
        "id", "WindowResizeDialog",
        "title", "Window Resize Dialog",
        "description", "Resize and position a window with numeric inputs and focused keyboard controls",
        "category", "Window Management"
      ),
      "page", Map(
        "description", "Configure the resize dialog keyboard layout, modifiers, and pixel step sizes",
        "icon", "icons10-resize-four-directions"
      ),
      "config", [
        Map(
          "key", "KeyLayout",
          "label", "Directional keys",
          "description", "Key layout used for resize and move directions",
          "type", "string", "control", "select", "default", "WASD", "section", "Keyboard",
          "options", [
            Map("value", "WASD", "label", "WASD"),
            Map("value", "Arrows", "label", "Arrow keys"),
            Map("value", "HJKL", "label", "HJKL")
          ]
        ),
        Map(
          "key", "MoveModifier",
          "label", "Move modifier",
          "description", "Hold this modifier with the directional keys to move instead of resize",
          "type", "string", "control", "select", "default", "Alt", "section", "Keyboard",
          "options", modifierOptions
        ),
        Map(
          "key", "StepModifier",
          "label", "Step modifier",
          "description", "Hold this modifier to use the alternate precise/normal step size",
          "type", "string", "control", "select", "default", "Shift", "section", "Keyboard",
          "options", modifierOptions
        ),
        Map(
          "key", "UsePreciseModeByDefault",
          "label", "Use precise mode by default",
          "description", "Use the precise step without the step modifier; otherwise the normal step is the default",
          "type", "boolean", "control", "switch", "default", 0, "section", "Steps"
        ),
        Map(
          "key", "PreciseStepSize",
          "label", "Precise step size",
          "description", "Pixels changed in precise mode",
          "type", "integer", "control", "number", "default", 1, "section", "Steps",
          "validation", Map("min", 1, "max", 100)
        ),
        Map(
          "key", "NormalStepSize",
          "label", "Normal step size",
          "description", "Pixels changed in normal mode",
          "type", "integer", "control", "number", "default", 10, "section", "Steps",
          "validation", Map("min", 1, "max", 1000)
        ),
        Map(
          "key", "RepeatDelayMs",
          "label", "Repeat delay",
          "description", "Milliseconds to hold a direction before continuous movement begins",
          "type", "integer", "control", "number", "default", 250, "section", "Timing",
          "validation", Map("min", 0, "max", 2000)
        ),
        Map(
          "key", "PollingIntervalMs",
          "label", "Polling interval",
          "description", "Milliseconds between repeated movement steps while directions are held",
          "type", "integer", "control", "number", "default", 30, "section", "Timing",
          "validation", Map("min", 10, "max", 1000)
        )
      ],
      "actions", [
        Map(
          "action", "ShowResizeWindowDialog",
          "label", "Open resize dialog",
          "description", "Open the interactive resize and position dialog for a specific or active window",
          "category", "Resize",
          "params", [Map("name", "hwnd", "default", 0)]
        )
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  ShowResizeWindowDialog(hwnd:=0) { ;;;
    if (this._dialog) {
      this._closeDialog()
      return
    }

    if (!this._checkHwnd(&hwnd, A_ThisFunc))
      return

    this._selectedHwnd := hwnd
    this._oldState := WinGetMinMax("ahk_id " hwnd)
    if (this._oldState != 0)
      WinRestore("ahk_id " hwnd)

    WinGetPos(&oldX, &oldY, &oldW, &oldH, "ahk_id " hwnd)
    this._oldX := oldX
    this._oldY := oldY
    this._oldW := oldW
    this._oldH := oldH

    this._dialog := Gui()
    this._dialog.Title := "Window size: " WinGetProcessName("ahk_id " hwnd)
    this._dialog.Opt("+ToolWindow +AlwaysOnTop")

    this._dialog.Add("Edit", "w50 number right")
    this._widthControl := this._dialog.Add("UpDown", "vNewW Range24-9999", this._oldW)
    this._widthControl.OnEvent("Change", this._apply.Bind(this))

    this._dialog.Add("Edit", "ys w50 number right")
    this._heightControl := this._dialog.Add("UpDown", "vNewH Range24-9999", this._oldH)
    this._heightControl.OnEvent("Change", this._apply.Bind(this))

    this._dialog.Add("Button", "ys Default", "Apply")
      .OnEvent("Click", this._apply.Bind(this))
    this._dialog.Add("Button", "ys", "OK")
      .OnEvent("Click", this._applyAndClose.Bind(this))
    this._dialog.Add("Button", "ys", "Revert")
      .OnEvent("Click", this._revert.Bind(this))
    this._dialog.Add("Text", "xm y+10", this._getHotkeyHelpText())

    this._dialog.OnEvent("Escape", this._revert.Bind(this))
    this._dialog.OnEvent("Close", this._closeDialog.Bind(this))
    this._dialog.Show()
    this._enableDialogHotkeys()
  }

  _apply(*) {
    if (!this._targetExists())
      return
    values := this._dialog.Submit("0")
    WinMove(,, values.NewW, values.NewH, "ahk_id " this._selectedHwnd)
  }

  _applyAndClose(*) {
    this._apply()
    this._closeDialog()
  }

  _revert(*) {
    if (this._targetExists()) {
      WinMove(this._oldX, this._oldY, this._oldW, this._oldH, "ahk_id " this._selectedHwnd)
      if (this._oldState = 1)
        WinMaximize("ahk_id " this._selectedHwnd)
      else if (this._oldState = -1)
        WinMinimize("ahk_id " this._selectedHwnd)
    }
    this._closeDialog()
  }

  _closeDialog(*) {
    this._disableDialogHotkeys()
    if (this._dialog)
      this._dialog.Destroy()
    this._dialog := 0
    this._widthControl := 0
    this._heightControl := 0
    return true
  }

  _enableDialogHotkeys() {
    this._directionKeys := this._getDirectionKeys()
    this._pressedDirectionKeys := Map()
    this._inputTimerFn := this._processDirectionalInput.Bind(this)
    this._dialogHotkeys := Map()
    for direction, keyName in this._directionKeys {
      downHotkey := "*" keyName
      upHotkey := "*" keyName " up"
      this._dialogHotkeys[downHotkey] := this._setDirectionalKeyState.Bind(this, keyName, true)
      this._dialogHotkeys[upHotkey] := this._setDirectionalKeyState.Bind(this, keyName, false)
    }

    this._dialogHotkeyContext := (*) => this._dialog && WinActive("ahk_id " this._dialog.Hwnd)
    HotIf(this._dialogHotkeyContext)
    for hotkeyName, callback in this._dialogHotkeys
      Hotkey(hotkeyName, callback, "On")
    HotIf()
  }

  _disableDialogHotkeys() {
    this._stopDirectionalInput()
    if (!IsObject(this._dialogHotkeyContext))
      return
    HotIf(this._dialogHotkeyContext)
    for hotkeyName in this._dialogHotkeys
      try Hotkey(hotkeyName, "Off")
    HotIf()
    this._dialogHotkeys := Map()
    this._dialogHotkeyContext := 0
    this._directionKeys := Map()
    this._pressedDirectionKeys := Map()
    this._inputTimerFn := 0
  }

  _setDirectionalKeyState(keyName, pressed, *) {
    if (pressed) {
      if (this._pressedDirectionKeys.Has(keyName))
        return
      this._pressedDirectionKeys[keyName] := true
      this._processDirectionalInput(false)
      if (!this._inputTimerRunning)
        this._startDirectionalRepeat()
    } else {
      if (this._pressedDirectionKeys.Has(keyName))
        this._pressedDirectionKeys.Delete(keyName)
      if (this._pressedDirectionKeys.Count = 0)
        this._stopDirectionalInput()
    }
  }

  _startDirectionalRepeat() {
    this._inputTimerRunning := true
    repeatDelay := Max(0, Integer(this.Config.RepeatDelayMs))
    if (repeatDelay = 0) {
      SetTimer(this._inputTimerFn, Max(10, Integer(this.Config.PollingIntervalMs)))
    } else {
      SetTimer(this._inputTimerFn, -repeatDelay)
    }
  }

  _processDirectionalInput(scheduleNext:=true) {
    if (!this._dialog || !this._targetExists()) {
      this._stopDirectionalInput()
      return
    }

    leftPressed := GetKeyState(this._directionKeys["left"], "P")
    rightPressed := GetKeyState(this._directionKeys["right"], "P")
    upPressed := GetKeyState(this._directionKeys["up"], "P")
    downPressed := GetKeyState(this._directionKeys["down"], "P")
    if (!leftPressed && !rightPressed && !upPressed && !downPressed) {
      this._stopDirectionalInput()
      return
    }

    deltaX := (rightPressed ? 1 : 0) - (leftPressed ? 1 : 0)
    deltaY := (downPressed ? 1 : 0) - (upPressed ? 1 : 0)
    if (deltaX = 0 && deltaY = 0)
      return

    step := this._getCurrentStep()
    if (this._isModifierPressed(this.Config.MoveModifier))
      this._moveWindow(deltaX * step, deltaY * step)
    else
      this._resizeWindow(deltaX * step, deltaY * step)

    if (scheduleNext && this._inputTimerRunning)
      SetTimer(this._inputTimerFn, Max(10, Integer(this.Config.PollingIntervalMs)))
  }

  _stopDirectionalInput() {
    if (IsObject(this._inputTimerFn))
      SetTimer(this._inputTimerFn, 0)
    this._inputTimerRunning := false
  }

  _getCurrentStep() {
    preciseStep := Max(1, Integer(this.Config.PreciseStepSize))
    normalStep := Max(1, Integer(this.Config.NormalStepSize))
    preciseByDefault := !!this.Config.UsePreciseModeByDefault
    alternateMode := this._isModifierPressed(this.Config.StepModifier)
    usePreciseStep := alternateMode ? !preciseByDefault : preciseByDefault
    return usePreciseStep ? preciseStep : normalStep
  }

  _resizeWindow(deltaW, deltaH, *) {
    if (!this._targetExists())
      return
    WinGetPos(,, &width, &height, "ahk_id " this._selectedHwnd)
    width := Max(24, width + deltaW)
    height := Max(24, height + deltaH)
    WinMove(,, width, height, "ahk_id " this._selectedHwnd)
    this._widthControl.Value := width
    this._heightControl.Value := height
  }

  _moveWindow(deltaX, deltaY, *) {
    if (!this._targetExists())
      return
    WinGetPos(&x, &y,,, "ahk_id " this._selectedHwnd)
    WinMove(x + deltaX, y + deltaY,,, "ahk_id " this._selectedHwnd)
  }

  _getDirectionKeys() {
    switch StrLower("" this.Config.KeyLayout) {
      case "arrows":
        return Map("up", "Up", "left", "Left", "down", "Down", "right", "Right")
      case "hjkl":
        return Map("up", "k", "left", "h", "down", "j", "right", "l")
      default:
        return Map("up", "w", "left", "a", "down", "s", "right", "d")
    }
  }

  _isModifierPressed(modifier) {
    switch StrLower("" modifier) {
      case "alt": return GetKeyState("Alt", "P")
      case "ctrl": return GetKeyState("Ctrl", "P")
      case "shift": return GetKeyState("Shift", "P")
      case "win": return GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
      default: return false
    }
  }

  _getHotkeyHelpText() {
    keys := this.Config.KeyLayout
    moveModifier := this.Config.MoveModifier
    stepModifier := this.Config.StepModifier
    preciseStep := Max(1, Integer(this.Config.PreciseStepSize))
    normalStep := Max(1, Integer(this.Config.NormalStepSize))
    preciseByDefault := !!this.Config.UsePreciseModeByDefault
    defaultStep := preciseByDefault ? preciseStep : normalStep
    alternateStep := preciseByDefault ? normalStep : preciseStep
    return keys ": resize " defaultStep " px | " stepModifier ": " alternateStep " px | " moveModifier ": move | combine keys for diagonals"
  }

  _targetExists() {
    return this._selectedHwnd && WinExist("ahk_id " this._selectedHwnd)
  }

  _checkHwnd(&hwnd, fnName) {
    if (hwnd = 0)
      hwnd := WinGetID("A")
    if (!WinExist("ahk_id " hwnd))
      return false
    if (this.IsWindowBlocklisted(hwnd, fnName)) {
      this.ShowInfo(this.beautifyActionName(fnName) " disabled for blocklisted window")
      return false
    }
    return true
  }
}

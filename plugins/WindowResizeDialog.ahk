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
    movePrefix := this._getModifierPrefix(this.Config.MoveModifier)
    stepPrefix := this._getModifierPrefix(this.Config.StepModifier)
    if (movePrefix = stepPrefix) {
      this.ShowWarning("Move modifier and step modifier must be different.")
      return
    }

    keys := this._getDirectionKeys()
    preciseStep := Max(1, Integer(this.Config.PreciseStepSize))
    normalStep := Max(1, Integer(this.Config.NormalStepSize))
    preciseByDefault := !!this.Config.UsePreciseModeByDefault
    defaultStep := preciseByDefault ? preciseStep : normalStep
    alternateStep := preciseByDefault ? normalStep : preciseStep

    this._dialogHotkeys := Map()
    this._addDirectionalBindings(this._dialogHotkeys, keys, "", this._resizeWindow.Bind(this), defaultStep)
    this._addDirectionalBindings(this._dialogHotkeys, keys, stepPrefix, this._resizeWindow.Bind(this), alternateStep)
    this._addDirectionalBindings(this._dialogHotkeys, keys, movePrefix, this._moveWindow.Bind(this), defaultStep)
    this._addDirectionalBindings(this._dialogHotkeys, keys, movePrefix stepPrefix, this._moveWindow.Bind(this), alternateStep)

    this._dialogHotkeyContext := (*) => this._dialog && WinActive("ahk_id " this._dialog.Hwnd)
    HotIf(this._dialogHotkeyContext)
    for hotkeyName, callback in this._dialogHotkeys
      Hotkey(hotkeyName, callback, "On")
    HotIf()
  }

  _disableDialogHotkeys() {
    if (!IsObject(this._dialogHotkeyContext))
      return
    HotIf(this._dialogHotkeyContext)
    for hotkeyName in this._dialogHotkeys
      try Hotkey(hotkeyName, "Off")
    HotIf()
    this._dialogHotkeys := Map()
    this._dialogHotkeyContext := 0
  }

  _addDirectionalBindings(bindings, keys, prefix, callback, step) {
    bindings[prefix keys["up"]] := callback.Bind(0, -step)
    bindings[prefix keys["left"]] := callback.Bind(-step, 0)
    bindings[prefix keys["down"]] := callback.Bind(0, step)
    bindings[prefix keys["right"]] := callback.Bind(step, 0)
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

  _getModifierPrefix(modifier) {
    switch StrLower("" modifier) {
      case "alt": return "!"
      case "ctrl": return "^"
      case "shift": return "+"
      case "win": return "#"
      default: return ""
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
    return keys ": resize " defaultStep " px | " stepModifier ": " alternateStep " px | " moveModifier ": move"
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

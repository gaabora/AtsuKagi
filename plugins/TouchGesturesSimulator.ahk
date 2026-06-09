class TouchGesturesSimulator extends AKPlugin {
  ; TODO: add settings gui for https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/touchpad-tuning-guidelines
  static REG_PATH := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
  static CONFIG_SLIDE_ACTIONS := { 0: "NOTHING", 1: "SWITCH_APPS_AND_SHOW_DESKTOP", 2: "SWITCH_DESKTOPS_AND_SHOW_DESKTOP", 3: "CHANGE_AUDIO_AND_VOLUME" }
  static CONFIG_TAP_ACTIONS := { 0: "NOTHING", 1: "OPEN_SEARCH", 2: "NOTIFICATION_CENTER", 3: "PLAY_PAUSE", 4: "MIDDLE_MOUSE_BUTTON" }
  ; TwoFingerTapEnabled ; maybe TODO?

  TouchPointRadius := 5
  MaxTouchPoints := 10

  _injected := false
  _pointerInfo := 0
  _touchInjectionSupported := true
  _touchInitError := ""
  
  __New(App) {
    super.__New(App)
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")

    this.CONFIG_GESTURES := {
      ThreeFingerSlideEnabled: TouchGesturesSimulator.CONFIG_SLIDE_ACTIONS,
      ThreeFingerTapEnabled: TouchGesturesSimulator.CONFIG_TAP_ACTIONS,
      FourFingerSlideEnabled: TouchGesturesSimulator.CONFIG_SLIDE_ACTIONS,
      FourFingerTapEnabled: TouchGesturesSimulator.CONFIG_TAP_ACTIONS,
    }
    
    is32bit := A_PtrSize = 4
    this.is32bit := is32bit
    this._pointerInfo := (is32bit)
      ? { pointerTypeUInt: 0, pointerIdUInt: 4, frameIdUInt: 8, pointerFlagsUInt: 12, sourceDevicePtr: 16, hwndTargetPtr: 20, ptPixelLocation: { xInt: 24, yInt: 28 }, ptHimetricLocation: { xInt: 32, yInt: 36 }, ptPixelLocationRaw: { xInt: 40, yInt: 44 }, ptHimetricLocationRaw: { xInt: 48, yInt: 52 }, dwTimeUInt: 56, historyCountUInt: 60, InputDataInt: 64, dwKeyStatesUInt: 68, PerformanceCountUInt64: 72, ButtonChangeTypeInt: 80 }
      : { pointerTypeUInt: 0, pointerIdUInt: 4, frameIdUInt: 8, pointerFlagsUInt: 12, sourceDevicePtr: 16, hwndTargetPtr: 24, ptPixelLocation: { xInt: 32, yInt: 36 }, ptHimetricLocation: { xInt: 40, yInt: 44 }, ptPixelLocationRaw: { xInt: 48, yInt: 52 }, ptHimetricLocationRaw: { xInt: 56, yInt: 60 }, dwTimeUInt: 64, historyCountUInt: 68, InputDataInt: 72, dwKeyStatesUInt: 76, PerformanceCountUInt64: 80, ButtonChangeTypeInt: 88 }
    this.touchFlagsUInt := is32bit ? 88 : 96
    this.touchMaskUInt := is32bit ? 92 : 100
    this.rcContact := (is32bit)
      ? { leftInt:  96, topInt: 100, rightInt: 104, bottomInt: 108 }
      : { leftInt: 104, topInt: 108, rightInt: 112, bottomInt: 116 }
    this.rcContactRaw := (is32bit)
      ? { leftInt: 112, topInt: 116, rightInt: 120, bottomInt: 124 }
      : { leftInt: 120, topInt: 124, rightInt: 128, bottomInt: 132 }
    this.orientationUInt := is32bit ? 128 : 136
    this.pressureUInt := is32bit ? 132 : 140
    
    this.pointerTouchInfoSize := is32bit ? 136 : 144

    this.isInGesture := false
    ; this.BypassMouseButtonsWhenNotMoved := ["RButton", "MButton"]
  }

  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "TouchGesturesSimulator",
        "title", "Touch Gestures Simulator",
        "description", "Simulate touchpad input with mouse. Make touchpad gestures using mouse movement and buttons",
        "category", "Input Management"
      ),
      "page", Map(
        "description", "Configure touch input injection and gesture parameters",
        "icon", "icons10-touch"
      ),
      "config", [
        Map(
          "key", "TouchRadiusInPixels",
          "label", "Touch radius in pixels",
          "description", "Radius of each simulated touch point",
          "type", "integer",
          "default", 5,
          "section", "Touch Input"
        ),
        Map(
          "key", "MaxTouchPoints",
          "label", "Max touch points",
          "description", "Maximum number of simultaneous touch points",
          "type", "integer",
          "default", 10,
          "section", "Touch Input"
        )
      ],
      "actions", [
        Map(
          "action", "EnterGestureMode",
          "label", "Enter gesture mode",
          "description", "Simulate multitouch input with mouse. Drag to simulate touch points",
          "params", ["fingers", "movingThreshold", "runIfNoMove"],
          "category", "Touch Gestures"
        ),
        Map(
          "action", "SetPrecisionTouchpadRegistryConfig",
          "label", "Set precision touchpad config",
          "description", "Configure Windows precision touchpad settings (ThreeFingerSlideEnabled, ThreeFingerTapEnabled, FourFingerSlideEnabled, FourFingerTapEnabled)",
          "params", ["key", "value"],
          "category", "Touch Configuration"
        )
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    ; Apply descriptor defaults
    this.__ApplyDefaultConfig()
  }

  _init() {
    user32Ptr := DllCall("GetModuleHandle", "Str", "user32", "Ptr")
    if (!user32Ptr) {
      this._touchInjectionSupported := false
      this._touchInitError := "user32 module is not available"
      this.ShowWarning("TouchGesturesSimulator unavailable: " this._touchInitError)
      return
    }

    initProc := DllCall("GetProcAddress", "Ptr", user32Ptr, "AStr", "InitializeTouchInjection", "Ptr")
    injectProc := DllCall("GetProcAddress", "Ptr", user32Ptr, "AStr", "InjectTouchInput", "Ptr")
    if (!initProc || !injectProc) {
      this._touchInjectionSupported := false
      this._touchInitError := "Touch injection API is not available on this system"
      this.ShowWarning("TouchGesturesSimulator unavailable: " this._touchInitError)
    }
  }

  _ensureTouchInjectionSupported() {
    if (this._touchInjectionSupported)
      return true
    this.outputDebugLine(AKApp.LOG_WARNING, "TouchGesturesSimulator unavailable: " this._touchInitError)
    return false
  }

  EnterGestureMode(fingers:=1, movingThreshold:=0, runIfNoMove:="") { ;;;
    MouseGetPos(&xMouSrc, &yMouSrc)
    thisHotkey := A_ThisHotkey

    if (movingThreshold > 0 ; && ArrayContains(this.BypassMouseButtonsWhenNotMoved, thisHotkey)
        && this.shouldBypassMouseButton(thisHotkey, movingThreshold, xMouSrc, yMouSrc)) {
      if (runIfNoMove = "") {
        this.outputDebugLine(AKApp.LOG_TRACE, "BYPASS")
        Send("{Blind}{" thisHotkey "}")
        return
      } else {
        this.RunAction(runIfNoMove)
      }
    }
    this.outputDebugLine(AKApp.LOG_TRACE, "EnterGestureMode " thisHotkey)
    hotkeyInfo := ExtractHotkeyInfo(thisHotkey)
    Critical(16)
    this.runGesture(hotkeyInfo.key, fingers, xMouSrc, yMouSrc)
    Critical(0)
  }

  SetPrecisionTouchpadRegistryConfig(key, value) { ;;;
    regPath := TouchGesturesSimulator.REG_PATH
    
    if (!(this.CONFIG_GESTURES.HasOwnProp(key))) {
      keys := []
      for k in ObjOwnProps(this.CONFIG_GESTURES)
        keys.Push(k)
      return "Error: Invalid key: '" . key . "'. Possible keys are: " . Join(keys, ", ")
    }
    actionObj := this.CONFIG_GESTURES.%key%
    if (!actionObj.HasOwnProp(value)) {
      vals := []
      for v in ObjOwnProps(actionObj)
        vals.Push(v)
      return "Error: Invalid value '" . value . "' for '" . key . "'. Possible values are: " . Join(vals, ", ")
    }
    RegWrite(value, "REG_DWORD", regPath, key)
    return true
  }

  shouldBypassMouseButton(mouseButton, movingThreshold, xMouSrc:=-1, yMouSrc:=-1) {
    if (xMouSrc = -1 || yMouSrc = -1)
      MouseGetPos(&xMouSrc, &yMouSrc)
    xMouDst := xMouSrc
    yMouDst := yMouSrc
    movedDistance := 0

    Loop {
      if (!IsButtonPressed(mouseButton)) {
        this.outputDebugLine(AKApp.LOG_TRACE, mouseButton " UP")
        break
      }
      xMouLst := xMouDst
      yMouLst := yMouDst
      MouseGetPos(&xMouDst, &yMouDst)
      movedDistance += this.getDistance(xMouLst, yMouLst, xMouDst, yMouDst)
      if (movedDistance > movingThreshold) {
        break
      }
    }
    this.outputDebugLine(AKApp.LOG_TRACE, "movedDistance=" movedDistance)
    if (movedDistance < movingThreshold) 
      return true

    return false
  }

  runGesture(mouseButton, fingers:=1, xMouSrc:=-1, yMouSrc:=-1) {
    if (!this._ensureTouchInjectionSupported())
      return false

    feedbackType := TouchInputFlags.TOUCH_FEEDBACK_DEFAULT

    if (!this._injected) {
      loop {
        this._injected := DllCall("InitializeTouchInjection", "UInt", this.MaxTouchPoints, "UInt", feedbackType)
        if (this._injected) {
          break
        } else {
          switch (this.ShowError("InitializeTouchInjection FAILED in " A_ThisFunc)) {
            case AKBase.DIALOG_CANCEL: ExitApp
            case AKBase.DIALOG_RETRY: continue
            case AKBase.DIALOG_IGNORE: break
          }
        }
      }
    }

    if (this.isInGesture) {
      this.outputDebugLine(AKApp.LOG_WARNING, "START " fingers " fingers gesture FAILED (busy)")
      return
    }

    this.isInGesture := true
    this.outputDebugLine(AKApp.LOG_TRACE, "START " fingers " fingers gesture OK")

    varSize := this.pointerTouchInfoSize * fingers
    contactPoints := Buffer(varSize, 0)

    if (xMouSrc = -1 || yMouSrc = -1)
      MouseGetPos(&xMouSrc, &yMouSrc)
    xMouDst := xMouSrc
    yMouDst := yMouSrc

    flags := TouchInputFlags.POINTER_FLAG_DOWN | TouchInputFlags.POINTER_FLAG_INRANGE | TouchInputFlags.POINTER_FLAG_INCONTACT
    Loop fingers {
      this.modifyTouchPointsBuffer(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
    }
    ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", contactPoints)
    ; this.outputDebugLine(AKApp.LOG_TRACE, "  DOWN " xMouDst "x" yMouDst " " FormatBuffer(contactPoints, 4))
    if (ok) {
      flags := TouchInputFlags.POINTER_FLAG_UPDATE | TouchInputFlags.POINTER_FLAG_INRANGE | TouchInputFlags.POINTER_FLAG_INCONTACT
      Loop {
        MouseGetPos(&xMouDst, &yMouDst)

        if (!IsButtonPressed(mouseButton)) {
          this.outputDebugLine(AKApp.LOG_TRACE, mouseButton " UP")
          break
        }
        
        Loop fingers {
          this.modifyTouchPointsBuffer(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
        }

        ; this.outputDebugLine(AKApp.LOG_TRACE, "MOVE " xMouDst "x" yMouDst " " FormatBuffer(contactPoints, 4))
        ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", contactPoints)
        if (!ok) {
          this.outputDebugLine(AKApp.LOG_TRACE, "TOUCH MOVE " fingers " FAILED")
          break
        }
        Sleep(17)
      }
      
      flags := TouchInputFlags.POINTER_FLAG_UP
      Loop fingers {
        this.modifyTouchPointsBuffer(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
      }

      ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", contactPoints)
      ; this.outputDebugLine(AKApp.LOG_TRACE, "UP " xMouDst "x" yMouDst " " FormatBuffer(contactPoints, 4))
      if (!ok) {
        this.outputDebugLine(AKApp.LOG_TRACE, "TOUCH UP " fingers " FAILED")
      }
    } else {
      this.outputDebugLine(AKApp.LOG_TRACE, "TOUCH DOWN " fingers " FAILED")
    }

    this.isInGesture := false
    return ok
  }

  getDistance(xMouSrc, yMouSrc, xMouDst, yMouDst) {
    if (xMouSrc = xMouDst && yMouSrc = yMouDst)
      return 0
    return sqrt((xMouDst - xMouSrc)**2 + (yMouDst - yMouSrc)**2)
  }

  modifyTouchPointsBuffer(buf, idx, pFlags, x, y) {
    offset := idx * this.pointerTouchInfoSize
    pType := TouchInputFlags.POINTER_INPUT_TYPE_PT_TOUCH
    tMask := TouchInputFlags.TOUCH_MASK_CONTACTAREA | TouchInputFlags.TOUCH_MASK_ORIENTATION | TouchInputFlags.TOUCH_MASK_PRESSURE
    tFlags := TouchInputFlags.TOUCH_FLAG_NONE
    r := this.TouchPointRadius
    orientation := 90
    pressure := 250
    m := 10
    NumPut("UInt", pType,         buf, offset + this._pointerInfo.pointerTypeUInt)
    NumPut("UInt", idx,           buf, offset + this._pointerInfo.pointerIdUInt)
    NumPut("UInt", pFlags,        buf, offset + this._pointerInfo.pointerFlagsUInt)
    NumPut("Int",  x,             buf, offset + this._pointerInfo.ptPixelLocation.xInt)
    NumPut("Int",  x - r*m,       buf, offset + this.rcContact.leftInt)
    NumPut("Int",  x + r*m,       buf, offset + this.rcContact.rightInt)
    NumPut("Int",  y,             buf, offset + this._pointerInfo.ptPixelLocation.yInt)
    NumPut("Int",  y - r*m,       buf, offset + this.rcContact.topInt)    
    NumPut("Int",  y + r*m,       buf, offset + this.rcContact.bottomInt)
    NumPut("UInt", tFlags,        buf, offset + this.touchFlagsUInt)
    NumPut("UInt", tMask,         buf, offset + this.touchMaskUInt)
    NumPut("UInt", orientation,   buf, offset + this.orientationUInt)
    NumPut("UInt", pressure,      buf, offset + this.pressureUInt)
  }
}





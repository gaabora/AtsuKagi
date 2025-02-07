class TouchGesturesSimulator extends AKPlugin {
  ; TODO: static consts to separate class?
  ; TODO: add settings gui for https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/touchpad-tuning-guidelines
  static TOUCH_FEEDBACK_DEFAULT         := 0x1
  static TOUCH_FEEDBACK_INDIRECT        := 0x2
  static TOUCH_FEEDBACK_NONE            := 0x3
  static TOUCH_MASK_NONE                := 0x00000000 ; Default - none of the optional fields are valid
  static TOUCH_MASK_CONTACTAREA         := 0x00000001 ; The rcContact field is valid
  static TOUCH_MASK_ORIENTATION         := 0x00000002 ; The orientation field is valid
  static TOUCH_MASK_PRESSURE            := 0x00000004 ; The pressure field is valid
  static POINTER_FLAG_NONE              := 0x00000000 ; Default
  static POINTER_FLAG_NEW               := 0x00000001 ; New pointer
  static POINTER_FLAG_INRANGE           := 0x00000002 ; Pointer has not departed
  static POINTER_FLAG_INCONTACT         := 0x00000004 ; Pointer is in contact
  static POINTER_FLAG_FIRSTBUTTON       := 0x00000010 ; Primary action
  static POINTER_FLAG_SECONDBUTTON      := 0x00000020 ; Secondary action
  static POINTER_FLAG_THIRDBUTTON       := 0x00000040 ; Third button
  static POINTER_FLAG_FOURTHBUTTON      := 0x00000080 ; Fourth button
  static POINTER_FLAG_FIFTHBUTTON       := 0x00000100 ; Fifth button
  static POINTER_FLAG_PRIMARY           := 0x00002000 ; Pointer is primary
  static POINTER_FLAG_CONFIDENCE        := 0x00004000 ; Pointer is considered unlikely to be accidental
  static POINTER_FLAG_CANCELED          := 0x00008000 ; Pointer is departing in an abnormal manner
  static POINTER_FLAG_DOWN              := 0x00010000 ; Pointer transitioned to down state (made contact)
  static POINTER_FLAG_UPDATE            := 0x00020000 ; Pointer update
  static POINTER_FLAG_UP                := 0x00040000 ; Pointer transitioned from down state (broke contact)
  static POINTER_FLAG_WHEEL             := 0x00080000 ; Vertical wheel
  static POINTER_FLAG_HWHEEL            := 0x00100000 ; Horizontal wheel
  static POINTER_FLAG_CAPTURECHANGED    := 0x00200000 ; Lost capture
  static POINTER_FLAG_HASTRANSFORM      := 0x00400000 ; Input has a transform associated with it
  static POINTER_INPUT_TYPE_PT_POINTER  := 1 ; Generic pointer
  static POINTER_INPUT_TYPE_PT_TOUCH    := 2 ; Touch
  static POINTER_INPUT_TYPE_PT_PEN      := 3 ; Pen
  static POINTER_INPUT_TYPE_PT_MOUSE    := 4 ; Mouse
  static POINTER_INPUT_TYPE_PT_TOUCHPAD := 5 ; Touchpad if(WINVER >= 0x0603)

  static TOUCH_FLAG_NONE := 0x00000000

  static REG_PATH := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
  static CONFIG_SLIDE_ACTIONS := { 0: "NOTHING", 1: "SWITCH_APPS_AND_SHOW_DESKTOP", 2: "SWITCH_DESKTOPS_AND_SHOW_DESKTOP", 3: "CHANGE_AUDIO_AND_VOLUME" }
  static CONFIG_TAP_ACTIONS := { 0: "NOTHING", 1: "OPEN_SEARCH", 2: "NOTIFICATION_CENTER", 3: "PLAY_PAUSE", 4: "MIDDLE_MOUSE_BUTTON" }
  ; TwoFingerTapEnabled ; maybe TODO?

  TouchPointRadius := 1
  MaxTouchPoints := 10

  _injected := false
  _pointerInfo := 0
  
  __New(config:=0) {
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    CoordMode("ToolTip", "Screen")
 
    if (config != 0 && IsObject(config))
      this.config := config

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
    this.BypassMouseButtonsWhenNotMoved := ["RButton", "MButton"]
  }

  __ConfigHelp() {
    ; TODO
    return []
  }
  __UsageHelp() {
    return "Simulates touchpad input with mouse, make touchpad gestures using mouse"
  }

  __ActionsHelp() {
    texts := Map()
    texts["EnterGestureMode"] := "EnterGestureMode(fingers:=1)"
    texts["SetPrecisionTouchpadRegistryConfig"] := "SetPrecisionTouchpadRegistryConfig(key, value) set current user's PrecisionTouchPad settings for ThreeFingerSlideEnabled, ThreeFingerTapEnabled, FourFingerSlideEnabled, FourFingerTapEnabled"
    return texts
  }

  EnterGestureMode(fingers:=1, movingThreshold:=0) { ;;;
    MouseGetPos(&xMouSrc, &yMouSrc)

    if (movingThreshold > 0 && ArrayContains(this.BypassMouseButtonsWhenNotMoved, A_ThisHotkey) && this.shouldBypassMouseButton(A_ThisHotkey, movingThreshold, xMouSrc, yMouSrc)) {
      this.outputDebugLine("BYPASS")
      Send("{Blind}{" A_ThisHotkey "}")
      return
    }
    hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
    this.runGesture(hotkeyInfo.key, fingers, xMouSrc, yMouSrc)
  }

  SetPrecisionTouchpadRegistryConfig(key, value) { ;;;
    regPath := TouchGesturesSimulator.REG_PATH
    
    if (!(this.CONFIG_GESTURES.Has(key)))
      return "Error: Invalid key: '" . key . "'. Possible keys are: " . Join(Object.Keys(this.CONFIG_GESTURES), ", ")
    if (!this.CONFIG_GESTURES[key].Has(value))
      return "Error: Invalid value '" . value . "' for '" . key . "'. Possible values are: " . Join(this.CONFIG_GESTURES[key], ", ")
    RegWrite(value, "REG_DWORD", regPath, key)
    return true
  }

  shouldBypassMouseButton(mouseButton, movingThreshold, xMouSrc:=-1, yMouSrc:=-1) {
    if (xMouSrc = -1 || yMouSrc = -1)
      MouseGetPos(&xMouSrc, &yMouSrc)
    xMouDst := xMouSrc
    yMouDst := yMouSrc
    movedDistance := 0

    Loop{
      MouseButtonState := GetKeyState(mouseButton, "P") ? "D" : "U"
      if (MouseButtonState = "U") {
        this.outputDebugLine(mouseButton " UP " MouseButtonState)
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
    this.outputDebugLine("movedDistance=" movedDistance)
    if (movedDistance < movingThreshold) 
      return true

    return false
  }

  runGesture(mouseButton, fingers:=1, xMouSrc:=-1, yMouSrc:=-1) {
    feedbackType := (this.debugLevel > 0) ? TouchGesturesSimulator.TOUCH_FEEDBACK_DEFAULT : TouchGesturesSimulator.TOUCH_FEEDBACK_NONE

    if (!this._injected) {
      loop
      {
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
      this.outputDebugLine("START " fingers " fingers gesture FAILED (busy)")
      return
    }

    this.isInGesture := true
    this.outputDebugLine("START " fingers " fingers gesture OK")


    varSize := this.pointerTouchInfoSize * fingers
    contactPoints := Buffer(varSize, 0) ; V1toV2: if 'contactPoints' is a UTF-16 string, use 'VarSetStrCapacity(&contactPoints, varSize)'

    if (xMouSrc = -1 || yMouSrc = -1)
      MouseGetPos(&xMouSrc, &yMouSrc)
    xMouDst := xMouSrc
    yMouDst := yMouSrc

    flags := TouchGesturesSimulator.POINTER_FLAG_DOWN | TouchGesturesSimulator.POINTER_FLAG_INRANGE | TouchGesturesSimulator.POINTER_FLAG_INCONTACT
    Loop fingers {
      this.modifyTouchPointsBuffer(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
    }

    groupBytes := 4
    ; this.outputDebugLine("DOWN " FormatBuffer(contactPoints, groupBytes), 6)
    ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", contactPoints)

    if (ok) {
      Sleep(10)
      flags := TouchGesturesSimulator.POINTER_FLAG_UPDATE | TouchGesturesSimulator.POINTER_FLAG_INRANGE | TouchGesturesSimulator.POINTER_FLAG_INCONTACT
      Loop{
        mouseButtonState := GetKeyState(mouseButton, "P") ? "D" : "U"
        if (mouseButtonState = "U") {
          this.outputDebugLine(mouseButton " UP " mouseButtonState)
          break
        }
        MouseGetPos(&xMouDst, &yMouDst)

        Loop fingers {
          this.modifyTouchPointsBuffer(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
        }
        ; this.outputDebugLine("UPDATE " FormatBuffer(contactPoints, groupBytes), 6)
        ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", contactPoints)
        if (!ok) {
          this.outputDebugLine("TOUCH MOVE " fingers " FAILED")
          break
        }
        Sleep(10)
      }
    }

    flags := TouchGesturesSimulator.POINTER_FLAG_UP
    Loop fingers {
      this.modifyTouchPointsBuffer(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
    }
    ; this.outputDebugLine("UP " FormatBuffer(contactPoints, groupBytes), 6)
    ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", contactPoints)
    if (!ok)
      this.outputDebugLine("TOUCH UP " fingers " FAILED")

    this.isInGesture := false
  }

  getDistance(xMouSrc, yMouSrc, xMouDst, yMouDst) {
    if (xMouSrc = xMouDst && yMouSrc = yMouDst)
      return 0
    return sqrt((xMouDst - xMouSrc)**2 + (yMouDst - yMouSrc)**2)
  }

  modifyTouchPointsBuffer(buf, idx, flag, x, y) {
    offset := idx * this.pointerTouchInfoSize
    mode := TouchGesturesSimulator.POINTER_INPUT_TYPE_PT_TOUCH
    mask := TouchGesturesSimulator.TOUCH_MASK_CONTACTAREA | TouchGesturesSimulator.TOUCH_MASK_ORIENTATION | TouchGesturesSimulator.TOUCH_MASK_PRESSURE
    tf := TouchGesturesSimulator.TOUCH_FLAG_NONE
    r := this.TouchPointRadius
    NumPut("UInt", idx, buf, offset + this._pointerInfo.pointerIdUInt)
    NumPut("UInt", mode, buf, offset + this._pointerInfo.pointerTypeUInt)
    NumPut("UInt", flag, buf, offset + this._pointerInfo.pointerFlagsUInt)

    NumPut("Int", x, buf, offset + this._pointerInfo.ptPixelLocation.xInt)
    NumPut("Int", x - r, buf, offset + this.rcContact.leftInt)
    NumPut("Int", x + r, buf, offset + this.rcContact.rightInt)

    NumPut("Int", y, buf, offset + this._pointerInfo.ptPixelLocation.yInt)
    NumPut("Int", y - r, buf, offset + this.rcContact.topInt)    
    NumPut("Int", y + r, buf, offset + this.rcContact.bottomInt)

    NumPut("UInt", tf, buf, offset + this.touchFlagsUInt)
    NumPut("UInt", mask, buf, offset + this.touchMaskUInt)
    NumPut("UInt", 87, buf, offset + this.orientationUInt)
    NumPut("UInt", 256, buf, offset + this.pressureUInt)
  }
}





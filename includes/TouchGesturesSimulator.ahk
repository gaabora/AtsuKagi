class TouchGesturesSimulator extends AKPlugin {
  static TOUCH_FEEDBACK_DEFAULT :=          0x1
  static TOUCH_FEEDBACK_INDIRECT :=         0x2
  static TOUCH_FEEDBACK_NONE :=             0x3
  static TOUCH_MASK_NONE :=                 0x00000000 ; Default - none of the optional fields are valid
  static TOUCH_MASK_CONTACTAREA :=          0x00000001 ; The rcContact field is valid
  static TOUCH_MASK_ORIENTATION :=          0x00000002 ; The orientation field is valid
  static TOUCH_MASK_PRESSURE :=             0x00000004 ; The pressure field is valid
  static POINTER_FLAG_NONE :=               0x00000000 ; Default
  static POINTER_FLAG_NEW :=                0x00000001 ; New pointer
  static POINTER_FLAG_INRANGE :=            0x00000002 ; Pointer has not departed
  static POINTER_FLAG_INCONTACT :=          0x00000004 ; Pointer is in contact
  static POINTER_FLAG_FIRSTBUTTON :=        0x00000010 ; Primary action
  static POINTER_FLAG_SECONDBUTTON :=       0x00000020 ; Secondary action
  static POINTER_FLAG_THIRDBUTTON :=        0x00000040 ; Third button
  static POINTER_FLAG_FOURTHBUTTON :=       0x00000080 ; Fourth button
  static POINTER_FLAG_FIFTHBUTTON :=        0x00000100 ; Fifth button
  static POINTER_FLAG_PRIMARY :=            0x00002000 ; Pointer is primary
  static POINTER_FLAG_CONFIDENCE :=         0x00004000 ; Pointer is considered unlikely to be accidental
  static POINTER_FLAG_CANCELED :=           0x00008000 ; Pointer is departing in an abnormal manner
  static POINTER_FLAG_DOWN :=               0x00010000 ; Pointer transitioned to down state (made contact)
  static POINTER_FLAG_UPDATE :=             0x00020000 ; Pointer update
  static POINTER_FLAG_UP :=                 0x00040000 ; Pointer transitioned from down state (broke contact)
  static POINTER_FLAG_WHEEL :=              0x00080000 ; Vertical wheel
  static POINTER_FLAG_HWHEEL :=             0x00100000 ; Horizontal wheel
  static POINTER_FLAG_CAPTURECHANGED :=     0x00200000 ; Lost capture
  static POINTER_FLAG_HASTRANSFORM :=       0x00400000 ; Input has a transform associated with it
  static POINTER_INPUT_TYPE_PT_POINTER :=   1 ; Generic pointer
  static POINTER_INPUT_TYPE_PT_TOUCH :=     2 ; Touch
  static POINTER_INPUT_TYPE_PT_PEN :=       3 ; Pen
  static POINTER_INPUT_TYPE_PT_MOUSE :=     4 ; Mouse
  static POINTER_INPUT_TYPE_PT_TOUCHPAD :=  5 ; Touchpad if(WINVER >= 0x0603)

  static TOUCH_FLAG_NONE := 0x00000000

  static REG_PATH := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
  static CONFIG_SLIDE_ACTIONS := { 0: "NOTHING", 1: "SWITCH_APPS_AND_SHOW_DESKTOP", 2: "SWITCH_DESKTOPS_AND_SHOW_DESKTOP", 3: "CHANGE_AUDIO_AND_VOLUME" }
  static CONFIG_TAP_ACTIONS := { 0: "NOTHING", 1: "OPEN_SEARCH", 2: "NOTIFICATION_CENTER", 3: "PLAY_PAUSE", 4: "MIDDLE_MOUSE_BUTTON" }
  ; TwoFingerTapEnabled ; maybe TODO?

  TouchPointRadius := 1
  MovingThreshold := 4
  MaxTouchPoints := 10

  __New(config:=0) {
    CoordMode, Mouse, Screen
    CoordMode, Pixel, Screen
    CoordMode, ToolTip, Screen
 
    if (config != 0 && IsObject(config))
      this.config := config

    this.CONFIG_GESTURES := { ThreeFingerSlideEnabled: this.CONFIG_SLIDE_ACTIONS, ThreeFingerTapEnabled: this.CONFIG_TAP_ACTIONS, FourFingerSlideEnabled: this.CONFIG_SLIDE_ACTIONS, FourFingerTapEnabled: this.CONFIG_TAP_ACTIONS }
    
    is32bit := A_PtrSize = 4
    this.is32bit := is32bit
    this.pointerInfo := (is32bit)
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
    texts := []
    texts["EnterGestureMode"] := "EnterGestureMode(fingers:=1)"
    texts["SetPrecisionTouchPadConfig"] := "SetPrecisionTouchPadConfig(key, value) set current user's PrecisionTouchPad settings for ThreeFingerSlideEnabled, ThreeFingerTapEnabled, FourFingerSlideEnabled, FourFingerTapEnabled"
    return texts
  }

  EnterGestureMode(fingers:=1) { ;;;
    MouseGetPos, xMouSrc, yMouSrc
    hotkeyInfo := ExtractHotkeyInfo(A_ThisHotkey)
    if (this.shouldBypassMouseButton(hotkeyInfo, xMouSrc, yMouSrc)) {
      this.outputDebugLine("BYPASS")
      mouseButton := hotkeyInfo.key
      Send {Blind}{%mouseButton%}
    } else {
      
      if (fingers > 2) {
        
      }
      this.runGesture(hotkeyInfo.key, fingers, xMouSrc, yMouSrc)
    }
  }

  SetPrecisionTouchPadConfig(key, value) { ;;;
    regPath := this.REG_PATH
    
    if (!(key in this.CONFIG_GESTURES)) 
      return "Error: Invalid key: '" . key . "'. Possible keys are: " . Join(Object.Keys(this.CONFIG_GESTURES), ", ")
    if (!this.CONFIG_GESTURES[key].HasKey(value))
      return "Error: Invalid value '" . value . "' for '" . key . "'. Possible values are: " . Join(this.CONFIG_GESTURES[key], ", ")
    RegWrite, REG_DWORD, %regPath%, %key%, %value%
    return true
  }

  shouldBypassMouseButton(hotkeyInfo, xMouSrc:=-1, yMouSrc:=-1) {
    mouseButton := hotkeyInfo.key
    if (hotkeyInfo.modifiers.Length() = 0 && hotkeyInfo.customModifier = "" && mouseButton in this.BypassMouseButtonsWhenNotMoved) {
      if (xMouSrc = -1 || yMouSrc = -1)
        MouseGetPos, xMouSrc, yMouSrc
      xMouDst := xMouSrc
      yMouDst := yMouSrc
      movedDistance := 0

      Loop {
        GetKeyState, MouseButtonState, %mouseButton%, P
        if (MouseButtonState = "U") {
          this.outputDebugLine(mouseButton " UP " MouseButtonState)
          break
        }
        xMouLst := xMouDst
        yMouLst := yMouDst
        MouseGetPos, xMouDst, yMouDst
        movedDistance += this.getDistance(xMouLst, yMouLst, xMouDst, yMouDst)
        if (movedDistance > this.MovingThreshold) {
          break
        }
      }
      this.outputDebugLine("movedDistance=" movedDistance)
      if (movedDistance < this.MovingThreshold) 
        return true
    }
    return false
  }

  runGesture(mouseButton, fingers:=1, xMouSrc:=-1, yMouSrc:=-1) {
    feedbackType := (this.debugLevel > 0) ? this.TOUCH_FEEDBACK_DEFAULT : this.TOUCH_FEEDBACK_NONE
    if (!this.injected)
      this.injected := DllCall("InitializeTouchInjection", "UInt", this.MaxTouchPoints, "UInt", feedbackType)
    if (!this.injected)
      this.showError("InitializeTouchInjection FAILED in " A_ThisFunc)

    if (this.isInGesture) {
      this.outputDebugLine("START " fingers " fingers gesture FAILED (busy)")
      return
    }

    this.isInGesture := true
    this.outputDebugLine("START " fingers " fingers gesture OK")


    varSize := this.pointerTouchInfoSize * fingers
    VarSetCapacity(contactPoints, varSize, 0)

    if (xMouSrc = -1 || yMouSrc = -1)
      MouseGetPos, xMouSrc, yMouSrc
    xMouDst := xMouSrc
    yMouDst := yMouSrc

    flags := this.POINTER_FLAG_DOWN | this.POINTER_FLAG_INRANGE | this.POINTER_FLAG_INCONTACT
    Loop, % fingers {
      this.modifyTouchPointsVar(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
    }

    groupBytes := 4
    this.outputDebugLine("DOWN " FormatBinary(contactPoints, groupBytes), 6)
    ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", &contactPoints)

    if (ok) {
      Sleep, 10
      flags := this.POINTER_FLAG_UPDATE | this.POINTER_FLAG_INRANGE | this.POINTER_FLAG_INCONTACT
      Loop {
        GetKeyState, mouseButtonState, %mouseButton%, P
        if (mouseButtonState = "U") {
          this.outputDebugLine(mouseButton " UP " mouseButtonState)
          break
        }
        MouseGetPos, xMouDst, yMouDst

        Loop, % fingers {
          this.modifyTouchPointsVar(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
        }
        this.outputDebugLine("UPDATE " FormatBinary(contactPoints, groupBytes), 6)
        ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", &contactPoints)
        if (!ok) {
          this.outputDebugLine("TOUCH MOVE " fingers " FAILED")
          break
        }
        Sleep, 10
      }
    }

    flags := this.POINTER_FLAG_UP
    Loop, % fingers {
      this.modifyTouchPointsVar(contactPoints, A_Index - 1, flags, xMouDst, yMouDst)
    }
    this.outputDebugLine("UP " FormatBinary(contactPoints, groupBytes), 6)
    ok := DllCall("InjectTouchInput", "UInt", fingers, "Ptr", &contactPoints)
    if (!ok)
      this.outputDebugLine("TOUCH UP " fingers " FAILED")

    this.isInGesture := false
  }

  getDistance(xMouSrc, yMouSrc, xMouDst, yMouDst) {
    if (xMouSrc = xMouDst && yMouSrc = yMouDst)
      return 0
    return sqrt((xMouDst - xMouSrc)^2 + (yMouDst - yMouSrc)^2)
  }

  modifyTouchPointsVar(ByRef bin, idx, flag, x, y) {
    offset += idx * this.pointerTouchInfoSize
    mode := this.POINTER_INPUT_TYPE_PT_TOUCH
    mask := this.TOUCH_MASK_CONTACTAREA | this.TOUCH_MASK_ORIENTATION | this.TOUCH_MASK_PRESSURE
    tf := this.TOUCH_FLAG_NONE
    r := this.TouchPointRadius
    NumPut(idx,     bin, offset + this.pointerInfo.pointerIdUInt, "UInt")
    NumPut(mode,    bin, offset + this.pointerInfo.pointerTypeUInt, "UInt")
    NumPut(flag,    bin, offset + this.pointerInfo.pointerFlagsUInt, "UInt")

    NumPut(x,       bin, offset + this.pointerInfo.ptPixelLocation.xInt, "Int")
    NumPut(x - r,   bin, offset + this.rcContact.leftInt, "Int")
    NumPut(x + r,   bin, offset + this.rcContact.rightInt, "Int")

    NumPut(y,       bin, offset + this.pointerInfo.ptPixelLocation.yInt, "Int")
    NumPut(y - r,   bin, offset + this.rcContact.topInt, "Int")    
    NumPut(y + r,   bin, offset + this.rcContact.bottomInt, "Int")

    NumPut(tf,      bin, offset + this.touchFlagsUInt, "UInt")
    NumPut(mask,    bin, offset + this.touchMaskUInt, "UInt")
    NumPut(87,      bin, offset + this.orientationUInt, "UInt")
    NumPut(256,     bin, offset + this.pressureUInt, "UInt")
  }
}





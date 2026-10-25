class WindowsAutomationPlatform {
  GetLocalTimestamp() {
    return A_Now
  }

  GetUtcTimestamp() {
    return A_NowUTC
  }

  GetUnixSeconds() {
    return DateDiff(this.GetUtcTimestamp(), "19700101000000", "Seconds")
  }

  GetMonotonicMilliseconds() {
    return DllCall("Kernel32\GetTickCount64", "UInt64")
  }

  GetPhysicalIdleMilliseconds() {
    return A_TimeIdlePhysical
  }

  WindowExists(selector) {
    try return WinExist(selector) != 0
    catch
      return false
  }

  WindowIsActive(selector) {
    try return WinActive(selector) != 0
    catch
      return false
  }

  WindowIsTopmost(selector) {
    try {
      for windowHwnd in WinGetList(selector) {
        if (WinGetExStyle("ahk_id " windowHwnd) & 0x8)
          return true
      }
    } catch {
    }
    return false
  }

  GetMatchingWindows(selector) {
    selectorText := Trim("" selector)
    if (selectorText = "")
      throw ValueError("Window selector cannot be empty")
    try return WinGetList(selectorText)
    catch Error as selectorError
      throw ValueError("Invalid window selector: " selectorError.Message)
  }

  WindowHandleExists(windowHwnd) {
    return windowHwnd && WinExist("ahk_id " windowHwnd) != 0
  }

  GetWindowDescription(windowHwnd) {
    if (!this.WindowHandleExists(windowHwnd))
      return Map("hwnd", windowHwnd, "title", "", "process", "")
    windowSelector := "ahk_id " windowHwnd
    try windowTitle := WinGetTitle(windowSelector)
    catch
      windowTitle := ""
    try processName := WinGetProcessName(windowSelector)
    catch
      processName := ""
    return Map("hwnd", windowHwnd, "title", windowTitle, "process", processName)
  }

  ApplyWindowOperation(windowHwnd, operation) {
    if (!this.WindowHandleExists(windowHwnd))
      return false
    windowSelector := "ahk_id " windowHwnd
    switch operation {
      case "remove-topmost": WinSetAlwaysOnTop(0, windowSelector)
      case "lower": this._moveWindowToBottom(windowHwnd)
      case "minimize": WinMinimize(windowSelector)
      case "close": WinClose(windowSelector)
      default: throw ValueError("Unsupported window operation: " operation)
    }
    return true
  }

  SendWindowHotkey(windowHwnd, hotkey) {
    if (!this.WindowHandleExists(windowHwnd))
      return false
    hotkeyText := Trim("" hotkey)
    if (hotkeyText = "")
      throw ValueError("Window dismissal hotkey cannot be empty")
    ControlSend(hotkeyText, , "ahk_id " windowHwnd)
    return true
  }

  SendKeyPulse(hotkey) {
    hotkeyText := Trim("" hotkey)
    if (hotkeyText = "")
      throw ValueError("Keep-awake hotkey cannot be empty")
    if (!RegExMatch(hotkeyText, "^\{.*\}$"))
      hotkeyText := "{" hotkeyText "}"
    SendEvent(hotkeyText)
    return true
  }

  GetBatteryStatus() {
    statusBuffer := Buffer(12, 0)
    if (!DllCall("Kernel32\GetSystemPowerStatus", "Ptr", statusBuffer.Ptr, "Int"))
      throw OSError(A_LastError, "GetSystemPowerStatus")

    acLineStatus := NumGet(statusBuffer, 0, "UChar")
    batteryFlag := NumGet(statusBuffer, 1, "UChar")
    batteryPercent := NumGet(statusBuffer, 2, "UChar")
    batteryLifeSeconds := NumGet(statusBuffer, 4, "UInt")
    powerSource := acLineStatus = 1 ? "ac" : acLineStatus = 0 ? "battery" : "unknown"
    return Map(
      "sampledAt", this.GetUnixSeconds(),
      "powerSource", powerSource,
      "charging", (batteryFlag & 0x8) != 0,
      "hasBattery", (batteryFlag & 0x80) = 0,
      "percent", batteryPercent = 255 ? -1 : batteryPercent,
      "reportedRemainingSeconds", batteryLifeSeconds = 0xFFFFFFFF ? -1 : batteryLifeSeconds,
      "estimatedRemainingSeconds", -1,
      "batteryFlag", batteryFlag
    )
  }

  GetWindowsBatteryPolicy() {
    schemePointer := this._getActivePowerSchemePointer()
    try {
      subgroupGuid := this._guidFromString("e73a048d-bf27-4f12-9731-8b2076e8891f")
      lowLevelGuid := this._guidFromString("8183ba9a-e910-48da-8769-14ae6dc1170a")
      lowActionGuid := this._guidFromString("d8742dcb-3e6a-4b3c-b3fe-374623cdcf06")
      criticalLevelGuid := this._guidFromString("9a66d8d7-4ff7-4ef9-b5a2-5a326ca2a469")
      criticalActionGuid := this._guidFromString("637ea02f-bbcb-4015-8e2c-a1c7b9c0b546")
      lowLevel := this._readPowerSettingValue(schemePointer, subgroupGuid, lowLevelGuid, "battery")
      lowAction := this._readPowerSettingValue(schemePointer, subgroupGuid, lowActionGuid, "battery")
      criticalLevel := this._readPowerSettingValue(schemePointer, subgroupGuid, criticalLevelGuid, "battery")
      criticalAction := this._readPowerSettingValue(schemePointer, subgroupGuid, criticalActionGuid, "battery")
      return Map("known", true, "lowLevel", lowLevel, "lowAction", this._powerActionName(lowAction), "lowActionIndex", lowAction, "criticalLevel", criticalLevel, "criticalAction", this._powerActionName(criticalAction), "criticalActionIndex", criticalAction)
    } finally {
      DllCall("Kernel32\LocalFree", "Ptr", schemePointer, "Ptr")
    }
  }

  GetWindowsSleepCountdown() {
    batteryStatus := this.GetBatteryStatus()
    if (batteryStatus["powerSource"] = "unknown")
      return Map("known", false, "state", "unknown", "source", "Windows power plan")

    schemePointer := this._getActivePowerSchemePointer()
    try {
      subgroupGuid := this._guidFromString("238c9fa8-0aad-41ed-83f4-97be242c8f20")
      standbyTimeoutGuid := this._guidFromString("29f6c1db-86da-48c5-9fdb-f2b67b1f44da")
      timeoutSeconds := this._readPowerSettingValue(schemePointer, subgroupGuid, standbyTimeoutGuid, batteryStatus["powerSource"])
      if (timeoutSeconds = 0)
        return Map("known", false, "state", "never", "source", "Windows power plan", "powerSource", batteryStatus["powerSource"], "activityResets", true)
      idleSeconds := Floor(this.GetPhysicalIdleMilliseconds() / 1000)
      return Map("known", true, "state", "countdown", "secondsUntil", Max(0, timeoutSeconds - idleSeconds), "timeoutSeconds", timeoutSeconds, "idleSeconds", idleSeconds, "source", "Windows power plan", "powerSource", batteryStatus["powerSource"], "activityResets", true)
    } finally {
      DllCall("Kernel32\LocalFree", "Ptr", schemePointer, "Ptr")
    }
  }

  ReadTextFile(path) {
    return FileRead(path, "UTF-8")
  }

  AtomicReplaceText(path, text) {
    temporaryPath := path "." ProcessExist() "." this.GetMonotonicMilliseconds() ".tmp"
    try {
      temporaryFile := FileOpen(temporaryPath, "w", "UTF-8-RAW")
      if (!IsObject(temporaryFile))
        throw Error("Unable to open temporary automation file: " temporaryPath)
      temporaryFile.Write(text)
      temporaryFile.Close()
      moveFlags := 0x1 | 0x8
      if (!DllCall("Kernel32\MoveFileExW", "WStr", temporaryPath, "WStr", path, "UInt", moveFlags, "Int"))
        throw OSError(A_LastError, "MoveFileExW", path)
      return true
    } finally {
      if (FileExist(temporaryPath))
        try FileDelete(temporaryPath)
    }
  }

  _getActivePowerSchemePointer() {
    schemePointer := 0
    errorCode := DllCall("PowrProf\PowerGetActiveScheme", "Ptr", 0, "Ptr*", &schemePointer, "UInt")
    if (errorCode != 0 || !schemePointer)
      throw OSError(errorCode, "PowerGetActiveScheme")
    return schemePointer
  }

  _readPowerSettingValue(schemePointer, subgroupGuid, settingGuid, powerSource) {
    settingValue := 0
    functionName := powerSource = "battery" ? "PowerReadDCValueIndex" : "PowerReadACValueIndex"
    errorCode := DllCall("PowrProf\" functionName, "Ptr", 0, "Ptr", schemePointer, "Ptr", subgroupGuid.Ptr, "Ptr", settingGuid.Ptr, "UInt*", &settingValue, "UInt")
    if (errorCode != 0)
      throw OSError(errorCode, functionName)
    return settingValue
  }

  _guidFromString(guidText) {
    guidBuffer := Buffer(16, 0)
    resultCode := DllCall("Ole32\CLSIDFromString", "WStr", "{" guidText "}", "Ptr", guidBuffer.Ptr, "Int")
    if (resultCode != 0)
      throw Error("Invalid Windows GUID: " guidText)
    return guidBuffer
  }

  _powerActionName(actionIndex) {
    switch Integer(actionIndex) {
      case 0: return "Do nothing"
      case 1: return "Sleep"
      case 2: return "Hibernate"
      case 3: return "Shut down"
    }
    return "Unknown (" actionIndex ")"
  }

  _moveWindowToBottom(windowHwnd) {
    hwndBottom := 1
    noMoveFlag := 0x2
    noSizeFlag := 0x1
    noActivateFlag := 0x10
    if (!DllCall("User32\SetWindowPos", "Ptr", windowHwnd, "Ptr", hwndBottom, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", noMoveFlag | noSizeFlag | noActivateFlag, "Int"))
      throw OSError(A_LastError, "SetWindowPos")
    return true
  }
}

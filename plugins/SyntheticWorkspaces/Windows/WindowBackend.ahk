class WindowsSyntheticWorkspaceWindowBackend {
  static WS_EX_TOPMOST := 0x00000008
  static WS_EX_TOOLWINDOW := 0x00000080
  static GW_OWNER := 4
  static GA_ROOTOWNER := 3
  static MONITOR_DEFAULTTONEAREST := 2
  static DWMWA_EXTENDED_FRAME_BOUNDS := 9
  static DWMWA_CLOAKED := 14
  static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
  static TOKEN_QUERY := 0x0008
  static TOKEN_ELEVATION := 20
  static VT_LPWSTR := 31
  static SHELL_CLASSES := Map("Shell_TrayWnd", true, "Shell_SecondaryTrayWnd", true, "Progman", true, "WorkerW", true)

  __New(blocklistCallback:=0, globalWindowCallback:=0, shellProcessId:=0, internalWindowCallback:=0) {
    this._blocklistCallback := blocklistCallback
    this._globalWindowCallback := globalWindowCallback
    this._shellProcessId := shellProcessId ? shellProcessId : DllCall("GetCurrentProcessId", "UInt")
    this._internalWindowCallback := internalWindowCallback
    this._iconHandlesByPath := Map()
  }

  ReadTopLevelWindowSnapshots() {
    snapshots := []
    previousDetectHiddenWindows := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
      stackIndex := 1
      for windowHwnd in WinGetList() {
        try snapshot := this._readWindowSnapshot(windowHwnd, stackIndex)
        catch Error as snapshotError
          snapshot := this._createFailedSnapshot(windowHwnd, stackIndex)
        this._applyClassification(snapshot)
        snapshots.Push(snapshot)
        stackIndex += 1
      }
    } finally {
      DetectHiddenWindows(previousDetectHiddenWindows)
    }
    return snapshots
  }

  ReadWindowSnapshot(windowHwnd) {
    if (!windowHwnd || !DllCall("IsWindow", "Ptr", windowHwnd))
      return 0
    previousDetectHiddenWindows := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
      stackIndex := this._readStackIndex(windowHwnd)
      try snapshot := this._readWindowSnapshot(windowHwnd, stackIndex)
      catch Error as snapshotError {
        if (!DllCall("IsWindow", "Ptr", windowHwnd))
          return 0
        snapshot := this._createFailedSnapshot(windowHwnd, stackIndex)
      }
      this._applyClassification(snapshot)
      return snapshot
    } finally {
      DetectHiddenWindows(previousDetectHiddenWindows)
    }
  }

  ReadReconciliationWindowSnapshots() {
    snapshots := []
    previousDetectHiddenWindows := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
      stackIndex := 1
      for windowHwnd in WinGetList() {
        try snapshots.Push(this._readReconciliationWindowSnapshot(windowHwnd, stackIndex))
        stackIndex += 1
      }
    } finally {
      DetectHiddenWindows(previousDetectHiddenWindows)
    }
    return snapshots
  }

  Close() {
    for executablePath, iconHandle in this._iconHandlesByPath {
      if (iconHandle)
        try DllCall("DestroyIcon", "Ptr", iconHandle)
    }
    this._iconHandlesByPath := Map()
  }

  __Delete() {
    try this.Close()
  }

  _applyClassification(snapshot) {
    classification := this.ClassifySnapshot(snapshot)
    snapshot["classification"] := classification["class"]
    snapshot["classificationReason"] := classification["reason"]
  }

  ClassifySnapshot(snapshot) {
    if (!(snapshot is Map))
      throw TypeError("Window classification snapshot must be a Map")
    internalWindowResult := this._readRule(this._internalWindowCallback, snapshot.Get("hwnd", 0))
    if (internalWindowResult["matched"])
      return Map("class", "ignored", "reason", "window is an internal synthetic workspace surface")
    if (internalWindowResult["failed"])
      return Map("class", "unsupported", "reason", "internal-window check failed")
    if (snapshot.Get("snapshotFailed", false))
      return Map("class", "unsupported", "reason", "window snapshot could not be read")
    if (snapshot.Get("pid", 0) = this._shellProcessId)
      return Map("class", "shell", "reason", "window belongs to the Haribol process")
    windowClass := snapshot.Get("windowClass", "")
    if (WindowsSyntheticWorkspaceWindowBackend.SHELL_CLASSES.Has(windowClass))
      return Map("class", "shell", "reason", "window is part of the Windows shell")
    if (!snapshot.Get("visible", false))
      return Map("class", "ignored", "reason", "window is hidden")
    if (snapshot.Get("cloaked", false))
      return Map("class", "ignored", "reason", "window is DWM cloaked")
    if (snapshot.Get("toolWindow", false))
      return Map("class", "ignored", "reason", "window uses the tool-window style")
    if (snapshot.Get("blocklistCheckFailed", false))
      return Map("class", "unsupported", "reason", "workspace blocklist check failed")
    if (snapshot.Get("globalRuleCheckFailed", false))
      return Map("class", "unsupported", "reason", "global-window rule check failed")
    if (snapshot.Get("protected", false) || !snapshot.Get("metadataReadable", true))
      return Map("class", "unsupported", "reason", "window process is protected or unreadable")
    if (snapshot.Get("elevated", false))
      return Map("class", "unsupported", "reason", "window process is elevated")
    if (!snapshot.Get("responsive", true))
      return Map("class", "unsupported", "reason", "window is not responding")
    if (snapshot.Get("blocklisted", false))
      return Map("class", "unsupported", "reason", "window matches the workspace blocklist")
    if (snapshot.Get("ownerHwnd", 0) || snapshot.Get("rootOwnerHwnd", snapshot.Get("hwnd", 0)) != snapshot.Get("hwnd", 0))
      return Map("class", "owned-dialog", "reason", "window follows its root owner")
    if (snapshot.Get("globalWindow", false))
      return Map("class", "global", "reason", "window matches an explicit global rule")
    return Map("class", "managed", "reason", "normal controllable top-level window")
  }

  _readWindowSnapshot(windowHwnd, stackIndex) {
    selector := "ahk_id " windowHwnd
    snapshot := Map(
      "hwnd", windowHwnd,
      "pid", 0,
      "isHaribolShell", false,
      "executablePath", "",
      "executableName", "",
      "windowClass", "",
      "title", "",
      "normalizedTitle", "",
      "appUserModelId", "",
      "appUserModelIdAvailable", false,
      "appUserModelIdReason", "AppUserModelID capability is not implemented yet",
      "ownerHwnd", DllCall("GetWindow", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.GW_OWNER, "Ptr"),
      "rootOwnerHwnd", DllCall("GetAncestor", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.GA_ROOTOWNER, "Ptr"),
      "popupHwnd", DllCall("GetLastActivePopup", "Ptr", windowHwnd, "Ptr"),
      "visible", !!DllCall("IsWindowVisible", "Ptr", windowHwnd),
      "minimized", !!DllCall("IsIconic", "Ptr", windowHwnd),
      "maximized", !!DllCall("IsZoomed", "Ptr", windowHwnd),
      "responsive", !DllCall("IsHungAppWindow", "Ptr", windowHwnd),
      "stackIndex", stackIndex,
      "snapshotFailed", false,
      "metadataReadable", true,
      "icon", 0,
      "baseColor", "",
      "colorPreset", ""
    )
    try snapshot["pid"] := WinGetPID(selector)
    catch
      snapshot["metadataReadable"] := false
    snapshot["isHaribolShell"] := snapshot["pid"] = this._shellProcessId
    try snapshot["executablePath"] := WinGetProcessPath(selector)
    catch
      snapshot["metadataReadable"] := false
    try snapshot["executableName"] := WinGetProcessName(selector)
    catch
      snapshot["metadataReadable"] := false
    try snapshot["windowClass"] := WinGetClass(selector)
    catch
      snapshot["metadataReadable"] := false
    try snapshot["title"] := WinGetTitle(selector)
    catch
      snapshot["metadataReadable"] := false
    snapshot["normalizedTitle"] := Trim(RegExReplace(snapshot["title"], "\s+", " "))
    extendedStyle := 0
    try extendedStyle := WinGetExStyle(selector)
    catch
      snapshot["metadataReadable"] := false
    snapshot["topmost"] := (extendedStyle & WindowsSyntheticWorkspaceWindowBackend.WS_EX_TOPMOST) != 0
    snapshot["toolWindow"] := (extendedStyle & WindowsSyntheticWorkspaceWindowBackend.WS_EX_TOOLWINDOW) != 0
    snapshot["cloaked"] := this._isWindowCloaked(windowHwnd)
    snapshot["geometry"] := this._readVisibleFrame(windowHwnd)
    snapshot["monitor"] := this._readMonitor(windowHwnd)
    snapshot["fullscreen"] := this._isFullscreen(snapshot["geometry"], snapshot["monitor"], snapshot["visible"], snapshot["minimized"])
    processAccess := this._readProcessAccess(snapshot["pid"])
    snapshot["elevated"] := processAccess["elevated"]
    snapshot["protected"] := processAccess["protected"]
    blocklistResult := this._readRule(this._blocklistCallback, windowHwnd)
    snapshot["blocklisted"] := blocklistResult["matched"]
    snapshot["blocklistCheckFailed"] := blocklistResult["failed"]
    globalRuleResult := this._readRule(this._globalWindowCallback, windowHwnd)
    snapshot["globalWindow"] := globalRuleResult["matched"]
    snapshot["globalRuleCheckFailed"] := globalRuleResult["failed"]
    appUserModelIdResult := this._readAppUserModelId(windowHwnd)
    snapshot["appUserModelId"] := appUserModelIdResult["value"]
    snapshot["appUserModelIdAvailable"] := appUserModelIdResult["available"]
    snapshot["appUserModelIdReason"] := appUserModelIdResult["reason"]
    snapshot["icon"] := this._readCachedIcon(snapshot["executablePath"])
    snapshot["displayTitle"] := snapshot["title"]
    return snapshot
  }

  _createFailedSnapshot(windowHwnd, stackIndex) {
    return Map(
      "hwnd", windowHwnd,
      "pid", 0,
      "isHaribolShell", false,
      "executablePath", "",
      "executableName", "",
      "windowClass", "",
      "title", "",
      "normalizedTitle", "",
      "appUserModelId", "",
      "appUserModelIdAvailable", false,
      "appUserModelIdReason", "window snapshot could not be read",
      "ownerHwnd", 0,
      "rootOwnerHwnd", windowHwnd,
      "popupHwnd", 0,
      "geometry", Map(),
      "monitor", Map(),
      "visible", false,
      "minimized", false,
      "maximized", false,
      "fullscreen", false,
      "topmost", false,
      "cloaked", false,
      "responsive", false,
      "stackIndex", stackIndex,
      "snapshotFailed", true,
      "metadataReadable", false,
      "elevated", false,
      "protected", true,
      "toolWindow", false,
      "blocklisted", false,
      "blocklistCheckFailed", false,
      "globalWindow", false,
      "globalRuleCheckFailed", false,
      "displayTitle", "",
      "icon", 0,
      "baseColor", "",
      "colorPreset", ""
    )
  }

  _readVisibleFrame(windowHwnd) {
    rectBuffer := Buffer(16, 0)
    try {
      if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rectBuffer.Ptr, "UInt", rectBuffer.Size, "Int") = 0)
        return this._rectBufferToMap(rectBuffer)
    }
    if (!DllCall("GetWindowRect", "Ptr", windowHwnd, "Ptr", rectBuffer.Ptr))
      return Map()
    return this._rectBufferToMap(rectBuffer)
  }

  _rectBufferToMap(rectBuffer) {
    left := NumGet(rectBuffer, 0, "Int")
    top := NumGet(rectBuffer, 4, "Int")
    right := NumGet(rectBuffer, 8, "Int")
    bottom := NumGet(rectBuffer, 12, "Int")
    return Map("left", left, "top", top, "width", right - left, "height", bottom - top)
  }

  _readMonitor(windowHwnd) {
    monitorHandle := DllCall("MonitorFromWindow", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.MONITOR_DEFAULTTONEAREST, "Ptr")
    if (!monitorHandle)
      return Map()
    monitorInfo := Buffer(40, 0)
    NumPut("UInt", monitorInfo.Size, monitorInfo, 0)
    if (!DllCall("User32\GetMonitorInfoW", "Ptr", monitorHandle, "Ptr", monitorInfo.Ptr))
      return Map()
    return Map(
      "handle", monitorHandle,
      "left", NumGet(monitorInfo, 4, "Int"),
      "top", NumGet(monitorInfo, 8, "Int"),
      "right", NumGet(monitorInfo, 12, "Int"),
      "bottom", NumGet(monitorInfo, 16, "Int"),
      "workLeft", NumGet(monitorInfo, 20, "Int"),
      "workTop", NumGet(monitorInfo, 24, "Int"),
      "workRight", NumGet(monitorInfo, 28, "Int"),
      "workBottom", NumGet(monitorInfo, 32, "Int")
    )
  }

  _isFullscreen(geometry, monitor, visible, minimized) {
    if (!visible || minimized || !(geometry is Map) || !(monitor is Map) || !geometry.Count || !monitor.Count)
      return false
    tolerance := 2
    return Abs(geometry["left"] - monitor["left"]) <= tolerance
      && Abs(geometry["top"] - monitor["top"]) <= tolerance
      && Abs(geometry["left"] + geometry["width"] - monitor["right"]) <= tolerance
      && Abs(geometry["top"] + geometry["height"] - monitor["bottom"]) <= tolerance
  }

  _isWindowCloaked(windowHwnd) {
    cloaked := 0
    try return DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.DWMWA_CLOAKED, "UInt*", &cloaked, "UInt", 4, "Int") = 0 && !!cloaked
    return false
  }

  _readProcessAccess(processId) {
    if (!processId)
      return Map("elevated", false, "protected", true)
    processHandle := DllCall("OpenProcess", "UInt", WindowsSyntheticWorkspaceWindowBackend.PROCESS_QUERY_LIMITED_INFORMATION, "Int", false, "UInt", processId, "Ptr")
    if (!processHandle)
      return Map("elevated", false, "protected", true)
    tokenHandle := 0
    try {
      if (!DllCall("Advapi32\OpenProcessToken", "Ptr", processHandle, "UInt", WindowsSyntheticWorkspaceWindowBackend.TOKEN_QUERY, "Ptr*", &tokenHandle))
        return Map("elevated", false, "protected", true)
      elevationBuffer := Buffer(4, 0)
      returnLength := 0
      if (!DllCall("Advapi32\GetTokenInformation", "Ptr", tokenHandle, "Int", WindowsSyntheticWorkspaceWindowBackend.TOKEN_ELEVATION, "Ptr", elevationBuffer.Ptr, "UInt", elevationBuffer.Size, "UInt*", &returnLength))
        return Map("elevated", false, "protected", true)
      return Map("elevated", !!NumGet(elevationBuffer, 0, "UInt"), "protected", false)
    } finally {
      if (tokenHandle)
        DllCall("CloseHandle", "Ptr", tokenHandle)
      DllCall("CloseHandle", "Ptr", processHandle)
    }
  }

  _readRule(callback, windowHwnd) {
    if (!IsObject(callback))
      return Map("matched", false, "failed", false)
    try return Map("matched", !!callback.Call(windowHwnd), "failed", false)
    catch
      return Map("matched", false, "failed", true)
  }

  _readStackIndex(windowHwnd) {
    stackIndex := 1
    for stackedHwnd in WinGetList() {
      if (stackedHwnd = windowHwnd)
        return stackIndex
      stackIndex += 1
    }
    return 0
  }

  _readReconciliationWindowSnapshot(windowHwnd, stackIndex) {
    if (!DllCall("IsWindow", "Ptr", windowHwnd))
      throw Error("Window disappeared during reconciliation")
    selector := "ahk_id " windowHwnd
    title := ""
    extendedStyle := 0
    try title := WinGetTitle(selector)
    try extendedStyle := WinGetExStyle(selector)
    return Map(
      "hwnd", windowHwnd,
      "title", title,
      "ownerHwnd", DllCall("GetWindow", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.GW_OWNER, "Ptr"),
      "rootOwnerHwnd", DllCall("GetAncestor", "Ptr", windowHwnd, "UInt", WindowsSyntheticWorkspaceWindowBackend.GA_ROOTOWNER, "Ptr"),
      "geometry", this._readVisibleFrame(windowHwnd),
      "visible", !!DllCall("IsWindowVisible", "Ptr", windowHwnd),
      "minimized", !!DllCall("IsIconic", "Ptr", windowHwnd),
      "maximized", !!DllCall("IsZoomed", "Ptr", windowHwnd),
      "topmost", (extendedStyle & WindowsSyntheticWorkspaceWindowBackend.WS_EX_TOPMOST) != 0,
      "cloaked", this._isWindowCloaked(windowHwnd),
      "responsive", !DllCall("IsHungAppWindow", "Ptr", windowHwnd),
      "stackIndex", stackIndex
    )
  }

  _readAppUserModelId(windowHwnd) {
    propertyStorePointer := 0
    propertyVariant := 0
    try {
      propertyStoreIid := this._createGuid("{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}")
      result := DllCall("Shell32\SHGetPropertyStoreForWindow", "Ptr", windowHwnd, "Ptr", propertyStoreIid.Ptr, "Ptr*", &propertyStorePointer, "Int")
      if (result < 0 || !propertyStorePointer)
        return Map("value", "", "available", false, "reason", "AppUserModelID unavailable: " this._formatHResult(result))
      propertyKey := this._createGuid("{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", 20)
      NumPut("UInt", 5, propertyKey, 16)
      propertyVariant := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
      getValueMethod := NumGet(NumGet(propertyStorePointer, 0, "Ptr"), 5 * A_PtrSize, "Ptr")
      result := DllCall(getValueMethod, "Ptr", propertyStorePointer, "Ptr", propertyKey.Ptr, "Ptr", propertyVariant.Ptr, "Int")
      if (result < 0)
        return Map("value", "", "available", false, "reason", "AppUserModelID unavailable: " this._formatHResult(result))
      variantType := NumGet(propertyVariant, 0, "UShort")
      if (variantType = 0)
        return Map("value", "", "available", false, "reason", "AppUserModelID is not set")
      if (variantType != WindowsSyntheticWorkspaceWindowBackend.VT_LPWSTR)
        return Map("value", "", "available", false, "reason", "AppUserModelID has an unsupported value type")
      valuePointer := NumGet(propertyVariant, 8, "Ptr")
      appUserModelId := valuePointer ? StrGet(valuePointer, "UTF-16") : ""
      if (appUserModelId = "")
        return Map("value", "", "available", false, "reason", "AppUserModelID is empty")
      return Map("value", appUserModelId, "available", true, "reason", "AppUserModelID read from the window property store")
    } catch Error as appUserModelIdError {
      return Map("value", "", "available", false, "reason", "AppUserModelID unavailable: " appUserModelIdError.Message)
    } finally {
      if (IsObject(propertyVariant))
        try DllCall("Ole32\PropVariantClear", "Ptr", propertyVariant.Ptr)
      if (propertyStorePointer)
        this._releaseComPointer(propertyStorePointer)
    }
  }

  _createGuid(guidText, bufferSize:=16) {
    guidBuffer := Buffer(bufferSize, 0)
    result := DllCall("Ole32\CLSIDFromString", "WStr", guidText, "Ptr", guidBuffer.Ptr, "Int")
    if (result < 0)
      throw Error("CLSIDFromString failed: " this._formatHResult(result))
    return guidBuffer
  }

  _releaseComPointer(interfacePointer) {
    releaseMethod := NumGet(NumGet(interfacePointer, 0, "Ptr"), 2 * A_PtrSize, "Ptr")
    DllCall(releaseMethod, "Ptr", interfacePointer, "UInt")
  }

  _formatHResult(result) {
    return Format("0x{:08X}", result & 0xFFFFFFFF)
  }

  _readCachedIcon(executablePath) {
    if (executablePath = "")
      return 0
    cacheKey := StrLower(executablePath)
    if (this._iconHandlesByPath.Has(cacheKey))
      return this._iconHandlesByPath[cacheKey]
    largeIconHandle := 0
    smallIconHandle := 0
    try DllCall("Shell32\ExtractIconExW", "WStr", executablePath, "Int", 0, "Ptr*", &largeIconHandle, "Ptr*", &smallIconHandle, "UInt", 1, "UInt")
    iconHandle := smallIconHandle ? smallIconHandle : largeIconHandle
    if (smallIconHandle && largeIconHandle)
      DllCall("DestroyIcon", "Ptr", largeIconHandle)
    this._iconHandlesByPath[cacheKey] := iconHandle
    return iconHandle
  }
}

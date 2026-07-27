class WindowsSyntheticWorkspaceWindowEventService {
  static EVENT_SYSTEM_FOREGROUND := 0x0003
  static EVENT_SYSTEM_MINIMIZESTART := 0x0016
  static EVENT_SYSTEM_MINIMIZEEND := 0x0017
  static EVENT_OBJECT_CREATE := 0x8000
  static EVENT_OBJECT_DESTROY := 0x8001
  static EVENT_OBJECT_SHOW := 0x8002
  static EVENT_OBJECT_HIDE := 0x8003
  static EVENT_OBJECT_REORDER := 0x8004
  static EVENT_OBJECT_STATECHANGE := 0x800A
  static EVENT_OBJECT_LOCATIONCHANGE := 0x800B
  static EVENT_OBJECT_NAMECHANGE := 0x800C
  static OBJID_WINDOW := 0
  static CHILDID_SELF := 0
  static WINEVENT_OUTOFCONTEXT := 0x0000
  static WINEVENT_SKIPOWNPROCESS := 0x0002

  __New(reconciliationIntervalMs:=1500) {
    if (!IsNumber(reconciliationIntervalMs) || reconciliationIntervalMs < 1)
      throw ValueError("Reconciliation interval must be a positive number", -1, reconciliationIntervalMs)
    this.ReconciliationIntervalMs := reconciliationIntervalMs
    this._eventCallback := 0
    this._reconciliationCallback := 0
    this._winEventHandler := 0
    this._winEventCallback := 0
    this._winEventHooks := []
    this._reconciliationTimer := this._onReconciliationTimer.Bind(this)
    this._timerStarted := false
    this._reconciliationPaused := false
    this._isRunning := false
    this.LastCallbackError := ""
  }

  Start(eventCallback, reconciliationCallback) {
    if (this._isRunning)
      return false
    this._requireCallback(eventCallback, "window event")
    this._requireCallback(reconciliationCallback, "window reconciliation")
    this._eventCallback := eventCallback
    this._reconciliationCallback := reconciliationCallback
    this.LastCallbackError := ""
    this._isRunning := true
    try {
      this._winEventHandler := this._onWinEvent.Bind(this)
      this._winEventCallback := CallbackCreate(this._winEventHandler,, 7)
      this._registerHook(WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_FOREGROUND, WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_FOREGROUND)
      this._registerHook(WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_MINIMIZESTART, WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_MINIMIZEEND)
      this._registerHook(WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_CREATE, WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_REORDER)
      this._registerHook(WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_STATECHANGE, WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_NAMECHANGE)
      SetTimer(this._reconciliationTimer, this.ReconciliationIntervalMs)
      this._timerStarted := true
      return true
    } catch Error as startError {
      this._cleanup()
      throw startError
    }
  }

  Stop() {
    hadResources := this._isRunning || this._timerStarted || this._winEventHooks.Length || this._winEventCallback
    if (!hadResources)
      return false
    this._cleanup()
    return true
  }

  IsRunning() {
    return this._isRunning
  }

  SetReconciliationPaused(paused) {
    this._reconciliationPaused := !!paused
  }

  __Delete() {
    try this.Stop()
  }

  _registerHook(eventMinimum, eventMaximum) {
    hookHandle := DllCall("SetWinEventHook",
      "UInt", eventMinimum,
      "UInt", eventMaximum,
      "Ptr", 0,
      "Ptr", this._winEventCallback,
      "UInt", 0,
      "UInt", 0,
      "UInt", WindowsSyntheticWorkspaceWindowEventService.WINEVENT_OUTOFCONTEXT | WindowsSyntheticWorkspaceWindowEventService.WINEVENT_SKIPOWNPROCESS,
      "Ptr"
    )
    if (!hookHandle)
      throw OSError(A_LastError, "SetWinEventHook")
    this._winEventHooks.Push(hookHandle)
  }

  _cleanup() {
    this._isRunning := false
    if (this._timerStarted) {
      try SetTimer(this._reconciliationTimer, 0)
      this._timerStarted := false
    }
    for hookHandle in this._winEventHooks {
      try DllCall("UnhookWinEvent", "Ptr", hookHandle)
    }
    this._winEventHooks := []
    if (this._winEventCallback) {
      try CallbackFree(this._winEventCallback)
      this._winEventCallback := 0
    }
    this._winEventHandler := 0
    this._eventCallback := 0
    this._reconciliationCallback := 0
    this._reconciliationPaused := false
  }

  _onWinEvent(hookHandle, nativeEvent, windowHwnd, objectId, childId, eventThreadId, eventTime) {
    if (!this._isRunning || !windowHwnd)
      return
    isChildObjectEvent := nativeEvent >= WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_CREATE && (objectId != WindowsSyntheticWorkspaceWindowEventService.OBJID_WINDOW || childId != WindowsSyntheticWorkspaceWindowEventService.CHILDID_SELF)
    if (isChildObjectEvent)
      return
    eventType := this._getEventType(nativeEvent)
    if (eventType = "")
      return
    eventData := Map("type", eventType, "hwnd", windowHwnd, "nativeEvent", nativeEvent, "eventTime", eventTime)
    try this._eventCallback.Call(eventData)
    catch Error as callbackError
      this.LastCallbackError := callbackError.Message
  }

  _onReconciliationTimer() {
    if (!this._isRunning || this._reconciliationPaused)
      return
    try this._reconciliationCallback.Call()
    catch Error as callbackError
      this.LastCallbackError := callbackError.Message
  }

  _getEventType(nativeEvent) {
    switch nativeEvent {
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_FOREGROUND:
        return "activate"
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_CREATE, WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_SHOW:
        return "create"
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_DESTROY:
        return "destroy"
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_NAMECHANGE:
        return "title"
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_LOCATIONCHANGE:
        return "geometry"
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_REORDER:
        return "stack"
      case WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_MINIMIZESTART, WindowsSyntheticWorkspaceWindowEventService.EVENT_SYSTEM_MINIMIZEEND, WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_HIDE, WindowsSyntheticWorkspaceWindowEventService.EVENT_OBJECT_STATECHANGE:
        return "state"
    }
    return ""
  }

  _requireCallback(callback, callbackName) {
    if (!IsObject(callback) || !HasMethod(callback, "Call"))
      throw TypeError("Synthetic workspace " callbackName " callback must be callable")
  }
}

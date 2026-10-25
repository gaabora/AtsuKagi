#Include Automations\AutomationCron.ahk
#Include Automations\AutomationDefinition.ahk
#Include Automations\WindowsAutomationPlatform.ahk
#Include Automations\AutomationPersistence.ahk
#Include Automations\AutomationBatteryMonitor.ahk
#Include Automations\AutomationScheduler.ahk
#Include Automations\WindowsAutomationOsd.ahk
#Include Automations\WindowsFakeScreensaver.ahk

class Automations extends AKPlugin {
  __New(app) {
    super.__New(app)
    this._platform := 0
    this._jsonStore := 0
    this._historyStore := 0
    this._batteryMonitor := 0
    this._scheduler := 0
    this._osd := 0
    this._fakeScreensaver := 0
    this._automations := []
    this._loadedRawAutomations := []
    this._loadError := ""
    this._exitFn := 0
    this._exitRegistered := false
  }

  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "Automations",
        "title", "Automations",
        "description", "Run App actions from schedules, intervals, idle state, battery state, power source, and window conditions",
        "category", "System Events"
      ),
      "page", Map(
        "description", "Configure the automation scheduler and battery monitoring",
        "icon", "icons10-clock"
      ),
      "config", [
        Map("key", "SchedulerEnabled", "label", "Enable scheduler", "description", "Run enabled automations when their triggers and conditions match", "type", "boolean", "control", "switch", "default", true, "section", "Scheduler"),
        Map("key", "PollingIntervalMs", "label", "Polling interval", "description", "Milliseconds between scheduler checks", "type", "integer", "control", "number", "default", 1000, "section", "Scheduler", "validation", Map("min", 1000, "max", 60000)),
        Map("key", "CatchUpMaximumHours", "label", "Maximum catch-up lateness", "description", "Maximum hours for running the latest missed schedule after startup or resume", "type", "integer", "control", "number", "default", 24, "section", "Scheduler", "validation", Map("min", 1, "max", 24)),
        Map("key", "BatterySampleIntervalMs", "label", "Battery sample interval", "description", "Milliseconds between battery samples", "type", "integer", "control", "number", "default", 30000, "section", "Battery", "validation", Map("min", 1000, "max", 3600000)),
        Map("key", "BatteryHistoryRetentionDays", "label", "Battery history retention", "description", "Days to keep battery trend samples", "type", "integer", "control", "number", "default", 30, "section", "Battery", "validation", Map("min", 1, "max", 365)),
        Map("key", "FakeScreensaverMonitors", "label", "Fake screensaver monitors", "description", "Comma-separated monitor numbers, or empty for all monitors", "type", "string", "control", "text", "default", "", "section", "Fake screensaver")
      ],
      "actions", [
        Map("action", "RunAutomation", "label", "Run automation", "description", "Run an automation now after checking its conditions", "params", ["automationId"], "category", "Automations"),
        Map("action", "TestAutomationAction", "label", "Test automation action", "description", "Run only the stored action without checking triggers or conditions", "params", ["automationId"], "category", "Automations"),
        Map("action", "EnableAutomation", "label", "Enable automation", "description", "Enable an automation by its stable ID", "params", ["automationId"], "category", "Automations"),
        Map("action", "DisableAutomation", "label", "Disable automation", "description", "Disable an automation by its stable ID", "params", ["automationId"], "category", "Automations"),
        Map("action", "ToggleAutomation", "label", "Toggle automation", "description", "Toggle an automation by its stable ID", "params", ["automationId"], "category", "Automations"),
        Map("action", "PreventSleep", "label", "Prevent sleep", "description", "Send a small configured key pulse to keep Windows awake", "params", [Map("name", "hotkey", "default", "RShift")], "category", "Automations"),
        Map("action", "ShowLowBatteryOsd", "label", "Show battery OSD", "description", "Show battery state and Windows low and critical battery policy", "params", [], "category", "Automations"),
        Map("action", "ShowTimeUntilSleep", "label", "Show time until sleep", "description", "Show the earliest known App automation or Windows sleep countdown", "params", [], "category", "Automations"),
        Map("action", "StartFakeScreensaver", "label", "Start fake screensaver", "description", "Cover configured monitors with a black overlay; this does not lock or secure the computer", "params", [Map("name", "hotkeyToExit", "default", "Escape"), Map("name", "hotkeyToKeepAwake", "default", "RShift"), Map("name", "sendHotkeyIntervalSec", "default", 10)], "category", "Automations"),
        Map("action", "StopFakeScreensaver", "label", "Stop fake screensaver", "description", "Close every fake screensaver overlay and stop its timers", "params", [], "category", "Automations"),
        Map("action", "NormalizeMatchingWindows", "label", "Normalize matching windows", "description", "Apply only the explicit remove-topmost, lower, minimize, or close operations", "params", ["windowSelector", "operations"], "category", "Automations"),
        Map("action", "DismissMatchingWindows", "label", "Dismiss matching windows", "description", "Send a configured key to matching windows without activating them", "params", [Map("name", "windowSelector"), Map("name", "hotkey", "default", "{Escape}")], "category", "Automations")
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    this.__ApplyDefaultConfig()
  }

  _init() {
    this._platform := WindowsAutomationPlatform()
    configFilePath := this.App.GetConfigFilePath()
    SplitPath(configFilePath, , &configDirectory)
    if (configDirectory = "")
      configDirectory := A_ScriptDir

    this._jsonStore := AutomationJsonStore(configDirectory "\automations.json", this._platform)
    this._historyStore := WindowsAutomationHistoryStore(configDirectory "\automation-history.sqlite3", Integer(this.Config.BatteryHistoryRetentionDays))
    try this._historyStore.Initialize()
    catch Error as historyError {
      this.outputDebugLine(AKBase.LOG_WARNING, "Battery history is unavailable: " historyError.Message, Map("source", "Automations", "settingRef", Map("page", "plugin-Automations")))
      this._historyStore := 0
    }

    this._batteryMonitor := AutomationBatteryMonitor(this._platform, this._historyStore, Integer(this.Config.BatterySampleIntervalMs), this._log.Bind(this))
    this._scheduler := AutomationScheduler(this._platform, this._batteryMonitor, this._runActionForScheduler.Bind(this), this._log.Bind(this))
    this._osd := WindowsAutomationOsd()
    this._fakeScreensaver := WindowsFakeScreensaver(this._platform, A_ScriptDir "\assets\eye.png", this._log.Bind(this))
    this._loadAutomationFile()
    this._registerExitCallback()
  }

  OnPluginsReady() {
    normalizedResult := this._normalizeCollection(this._loadedRawAutomations, this.App.IsActionAvailable.Bind(this.App))
    this._automations := normalizedResult["automations"]
    this._scheduler.SetAutomations(this._automations)
    this._applySchedulerConfiguration()
  }

  OnConfigChanged(key, value) {
    if (!IsObject(this._scheduler))
      return
    if (key = "BatterySampleIntervalMs")
      this._batteryMonitor.SetSampleInterval(Integer(value))
    else if (key = "BatteryHistoryRetentionDays" && IsObject(this._historyStore))
      this._historyStore.SetRetentionDays(Integer(value))
    this._applySchedulerConfiguration()
  }

  GetAutomationsJson() {
    uiAutomations := []
    for automation in this._automations
      uiAutomations.Push(AutomationDefinition.ToUi(automation))
    result := Map("ok", true, "schemaVersion", AutomationJsonStore.SCHEMA_VERSION, "automations", uiAutomations, "runtime", this._scheduler.GetRuntimeSnapshot(), "availableActions", this.App.GetAvailableActionNames())
    if (this._loadError != "")
      result["loadError"] := this._loadError
    return jsongo.Stringify(result)
  }

  SaveAutomationsJson(payload) {
    try {
      root := jsongo.Parse("" payload)
      if (!(root is Map) || !root.Has("schemaVersion") || Integer(root["schemaVersion"]) != AutomationJsonStore.SCHEMA_VERSION)
        return this._jsonResult(false, "Unsupported automation data schema")
      if (!root.Has("automations") || !(root["automations"] is Array))
        return this._jsonResult(false, "Automation data must contain an automations array")

      normalizedResult := this._normalizeCollection(root["automations"], this.App.IsActionAvailable.Bind(this.App))
      if (normalizedResult["problems"].Length > 0)
        return this._jsonResult(false, "Automation validation failed", Map("problems", normalizedResult["problems"]))

      this._jsonStore.Save(normalizedResult["automations"])
      this._automations := normalizedResult["automations"]
      this._loadedRawAutomations := root["automations"]
      this._loadError := ""
      this._scheduler.SetAutomations(this._automations)
      this._applySchedulerConfiguration()
      return this._jsonResult(true, "", Map("automations", this._getUiAutomations()))
    } catch Error as saveError {
      this._log(AKBase.LOG_ERROR, "Saving automations failed: " saveError.Message)
      return this._jsonResult(false, saveError.Message)
    }
  }

  RunAutomation(automationId) {
    return this._scheduler.RunAutomation(automationId)
  }

  TestAutomationAction(automationId) {
    return this._scheduler.TestAutomationAction(automationId)
  }

  EnableAutomation(automationId) {
    return this._setAutomationEnabled(automationId, true)
  }

  DisableAutomation(automationId) {
    return this._setAutomationEnabled(automationId, false)
  }

  ToggleAutomation(automationId) {
    automation := this._findAutomation(automationId)
    if (!IsObject(automation))
      return Map("ok", false, "error", "Automation not found: " automationId)
    return this._setAutomationEnabled(automationId, !automation["enabled"])
  }

  PreventSleep(hotkey:="RShift") {
    this._platform.SendKeyPulse(hotkey)
    return Map("ok", true, "hotkey", "" hotkey)
  }

  ShowLowBatteryOsd(*) {
    status := this._batteryMonitor.Update(true)
    if (!status["hasBattery"]) {
      this._osd.Show("battery", "Battery", "No system battery was found.", -1, "normal", 5000)
      return Map("ok", true, "hasBattery", false)
    }

    try policy := this._platform.GetWindowsBatteryPolicy()
    catch Error as policyError {
      policy := Map("known", false, "error", policyError.Message)
      this._log(AKBase.LOG_WARNING, "Windows battery policy is unavailable: " policyError.Message)
    }
    remainingSeconds := status["reportedRemainingSeconds"] >= 0 ? status["reportedRemainingSeconds"] : status["estimatedRemainingSeconds"]
    remainingLabel := remainingSeconds >= 0 ? this._formatDuration(remainingSeconds) (status["reportedRemainingSeconds"] >= 0 ? " remaining" : " estimated remaining") : "Remaining time unknown"
    body := status["percent"] "% - " (status["charging"] ? "charging" : status["powerSource"] = "battery" ? "discharging" : status["powerSource"]) "`n" remainingLabel
    urgency := "normal"
    if (policy["known"]) {
      body .= "`nLow " policy["lowLevel"] "%: " policy["lowAction"] "; configured critical " policy["criticalLevel"] "%: " policy["criticalAction"]
      if (status["percent"] <= policy["criticalLevel"])
        urgency := "critical"
      else if (status["percent"] <= policy["lowLevel"])
        urgency := "warning"
      if (!status["charging"] && status["estimatedRemainingSeconds"] >= 0 && status["percent"] > policy["criticalLevel"]) {
        estimatedCriticalSeconds := this._estimateSecondsToBatteryLevel(status["estimatedRemainingSeconds"], status["percent"], policy["criticalLevel"])
        if (estimatedCriticalSeconds >= 0)
          body .= "`nEstimated configured critical level in " this._formatDuration(estimatedCriticalSeconds)
      }
    } else {
      body .= "`nWindows battery policy is unavailable."
    }
    this._osd.Show("battery", "Battery", body, status["percent"], urgency, urgency = "critical" ? 9000 : 6000)
    return Map("ok", true, "battery", status, "policy", policy)
  }

  ShowTimeUntilSleep(*) {
    automationCandidate := this._scheduler.GetNextSleepAutomation()
    try windowsCandidate := this._platform.GetWindowsSleepCountdown()
    catch Error as powerError {
      windowsCandidate := Map("known", false, "state", "unknown", "source", "Windows power plan", "error", powerError.Message)
      this._log(AKBase.LOG_WARNING, "Windows sleep countdown is unavailable: " powerError.Message)
    }

    selectedCandidate := 0
    if (automationCandidate["known"])
      selectedCandidate := automationCandidate
    if (windowsCandidate["known"] && (!IsObject(selectedCandidate) || windowsCandidate["secondsUntil"] < selectedCandidate["secondsUntil"]))
      selectedCandidate := windowsCandidate

    if (IsObject(selectedCandidate)) {
      body := this._formatDuration(selectedCandidate["secondsUntil"]) "`nSource: " selectedCandidate["source"] "`nActivity resets countdown: " (selectedCandidate["activityResets"] ? "yes" : "no")
      this._osd.Show("sleep", "Time until sleep", body, -1, selectedCandidate["secondsUntil"] <= 300 ? "warning" : "normal", 7000)
      return Map("ok", true, "countdown", selectedCandidate, "automation", automationCandidate, "windows", windowsCandidate)
    }

    stateText := windowsCandidate.Has("state") && windowsCandidate["state"] = "never" ? "Never on the current power source" : "Sleep time is unknown"
    this._osd.Show("sleep", "Time until sleep", stateText, -1, "normal", 6000)
    return Map("ok", true, "countdown", Map("known", false, "state", windowsCandidate.Has("state") ? windowsCandidate["state"] : "unknown"), "automation", automationCandidate, "windows", windowsCandidate)
  }

  StartFakeScreensaver(hotkeyToExit:="Escape", hotkeyToKeepAwake:="RShift", sendHotkeyIntervalSec:=10) {
    return this._fakeScreensaver.Start(this.Config.FakeScreensaverMonitors, hotkeyToExit, hotkeyToKeepAwake, sendHotkeyIntervalSec)
  }

  StopFakeScreensaver(*) {
    return this._fakeScreensaver.Stop()
  }

  NormalizeMatchingWindows(windowSelector, operations) {
    operationList := this._parseWindowOperations(operations)
    windowHandles := this._platform.GetMatchingWindows(windowSelector)
    affectedCount := 0
    for windowHwnd in windowHandles {
      for operation in operationList {
        if (!this._platform.WindowHandleExists(windowHwnd))
          break
        if (this.IsWindowBlocklisted(windowHwnd, "Automations.NormalizeMatchingWindows")) {
          this._log(AKBase.LOG_NOTICE, "Skipped blocklisted window hwnd=" windowHwnd " operation=" operation)
          break
        }
        windowDescription := this._platform.GetWindowDescription(windowHwnd)
        if (this._platform.ApplyWindowOperation(windowHwnd, operation)) {
          affectedCount += 1
          this._log(AKBase.LOG_INFO, "Window operation=" operation " hwnd=" windowHwnd " process=" windowDescription["process"] " title=" windowDescription["title"])
        }
      }
    }
    return Map("ok", true, "matchedWindows", windowHandles.Length, "affectedOperations", affectedCount)
  }

  DismissMatchingWindows(windowSelector, hotkey:="{Escape}") {
    windowHandles := this._platform.GetMatchingWindows(windowSelector)
    affectedCount := 0
    for windowHwnd in windowHandles {
      if (!this._platform.WindowHandleExists(windowHwnd))
        continue
      if (this.IsWindowBlocklisted(windowHwnd, "Automations.DismissMatchingWindows")) {
        this._log(AKBase.LOG_NOTICE, "Skipped blocklisted window hwnd=" windowHwnd " hotkey=" hotkey)
        continue
      }
      windowDescription := this._platform.GetWindowDescription(windowHwnd)
      if (this._platform.SendWindowHotkey(windowHwnd, hotkey)) {
        affectedCount += 1
        this._log(AKBase.LOG_INFO, "Window hotkey=" hotkey " hwnd=" windowHwnd " process=" windowDescription["process"] " title=" windowDescription["title"])
      }
    }
    return Map("ok", true, "matchedWindows", windowHandles.Length, "affectedWindows", affectedCount)
  }

  _loadAutomationFile() {
    try {
      root := this._jsonStore.Load()
      this._loadedRawAutomations := root["automations"]
      normalizedResult := this._normalizeCollection(this._loadedRawAutomations)
      this._automations := normalizedResult["automations"]
    } catch Error as loadError {
      this._loadError := loadError.Message
      this._loadedRawAutomations := []
      this._automations := []
      this._log(AKBase.LOG_ERROR, "Loading automations failed: " loadError.Message)
    }
  }

  _normalizeCollection(rawAutomations, actionExistsFn:=0) {
    automations := []
    problems := []
    seenIds := Map()
    for automationIndex, rawAutomation in rawAutomations {
      normalizedResult := AutomationDefinition.Normalize(rawAutomation, actionExistsFn)
      automation := normalizedResult["automation"]
      errors := normalizedResult["errors"]
      automationId := automation["id"]
      if (automationId != "" && seenIds.Has(automationId)) {
        errors.Push("Duplicate automation ID: " automationId)
        automation["enabled"] := false
      } else if (automationId != "") {
        seenIds[automationId] := true
      }
      automation["_validationErrors"] := errors
      automations.Push(automation)
      if (errors.Length > 0) {
        problems.Push(Map("index", automationIndex - 1, "id", automationId, "errors", errors))
        this._log(AKBase.LOG_WARNING, "Automation " (automationId != "" ? automationId : "at index " (automationIndex - 1)) " is disabled: " this._joinErrors(errors))
      }
    }
    return Map("automations", automations, "problems", problems)
  }

  _setAutomationEnabled(automationId, enabled) {
    automation := this._findAutomation(automationId)
    if (!IsObject(automation))
      return Map("ok", false, "error", "Automation not found: " automationId)
    if (enabled && automation["_validationErrors"].Length > 0)
      return Map("ok", false, "error", "Invalid automation cannot be enabled", "problems", automation["_validationErrors"])

    previousEnabled := automation["enabled"]
    automation["enabled"] := !!enabled
    try {
      this._jsonStore.Save(this._automations)
      this._scheduler.SetAutomations(this._automations)
      this._applySchedulerConfiguration()
      return Map("ok", true, "enabled", automation["enabled"])
    } catch Error as saveError {
      automation["enabled"] := previousEnabled
      return Map("ok", false, "error", saveError.Message)
    }
  }

  _applySchedulerConfiguration() {
    this._scheduler.Configure(this.Config.SchedulerEnabled, Integer(this.Config.PollingIntervalMs), Integer(this.Config.CatchUpMaximumHours))
  }

  _runActionForScheduler(actionString, notifyOnError) {
    return this.App.RunActionWithResult(actionString, notifyOnError)
  }

  _getUiAutomations() {
    uiAutomations := []
    for automation in this._automations
      uiAutomations.Push(AutomationDefinition.ToUi(automation))
    return uiAutomations
  }

  _findAutomation(automationId) {
    automationIdText := Trim("" automationId)
    for automation in this._automations {
      if (automation["id"] = automationIdText)
        return automation
    }
    return 0
  }

  _registerExitCallback() {
    if (this._exitRegistered)
      return
    this._exitFn := this._onExit.Bind(this)
    OnExit(this._exitFn)
    this._exitRegistered := true
  }

  _onExit(*) {
    if (IsObject(this._scheduler))
      this._scheduler.Stop()
    if (IsObject(this._fakeScreensaver))
      this._fakeScreensaver.Stop()
    if (IsObject(this._osd))
      this._osd.StopAll()
    if (IsObject(this._historyStore))
      this._historyStore.Close()
    return 0
  }

  _jsonResult(ok, error:="", extra:=0) {
    result := Map("ok", !!ok)
    if (!ok && error != "")
      result["error"] := error
    if (extra is Map) {
      for key, value in extra
        result[key] := value
    }
    return jsongo.Stringify(result)
  }

  _joinErrors(errors) {
    result := ""
    for errorMessage in errors
      result .= (result = "" ? "" : "; ") errorMessage
    return result
  }

  _parseWindowOperations(operations) {
    allowedOperations := Map("remove-topmost", true, "lower", true, "minimize", true, "close", true)
    result := []
    operationText := StrReplace(StrReplace(Trim("" operations), ";", "|"), "+", "|")
    for rawOperation in StrSplit(operationText, "|") {
      operation := StrLower(Trim(rawOperation))
      if (operation = "")
        continue
      if (!allowedOperations.Has(operation))
        throw ValueError("Unsupported window operation: " operation)
      result.Push(operation)
    }
    if (result.Length = 0)
      throw ValueError("At least one window operation is required")
    return result
  }

  _estimateSecondsToBatteryLevel(estimatedEmptySeconds, currentPercent, targetPercent) {
    if (estimatedEmptySeconds < 0 || currentPercent <= 0 || targetPercent >= currentPercent)
      return -1
    return Round(estimatedEmptySeconds * (currentPercent - targetPercent) / currentPercent)
  }

  _formatDuration(totalSeconds) {
    safeSeconds := Max(0, Integer(totalSeconds))
    hours := Floor(safeSeconds / 3600)
    minutes := Floor(Mod(safeSeconds, 3600) / 60)
    seconds := Mod(safeSeconds, 60)
    return Format("{1}:{2:02}:{3:02}", hours, minutes, seconds)
  }

  _log(level, message) {
    this.outputDebugLine(level, message, Map("source", "Automations", "settingRef", Map("page", "plugin-Automations")))
  }
}

class AutomationScheduler {
  __New(platform, batteryMonitor, runActionFn, logFn) {
    this._platform := platform
    this._batteryMonitor := batteryMonitor
    this._runActionFn := runActionFn
    this._logFn := logFn
    this._automations := []
    this._runtimeStates := Map()
    this._cronCache := Map()
    this._pollFn := this._poll.Bind(this)
    this._polling := false
    this._timerRunning := false
    this._timerPeriodMs := 0
    this._schedulerEnabled := true
    this._configuredPollIntervalMs := 1000
    this._catchUpMaximumHours := 24
    this._lastPollTimestamp := ""
  }

  SetAutomations(automations) {
    retainedStates := Map()
    for automation in automations {
      automationId := automation["id"]
      if (automationId != "" && this._runtimeStates.Has(automationId))
        retainedStates[automationId] := this._runtimeStates[automationId]
    }
    this._automations := automations
    this._runtimeStates := retainedStates
    if (this._timerRunning)
      this._restartTimerIfNeeded()
  }

  Configure(schedulerEnabled, pollIntervalMs, catchUpMaximumHours) {
    this._schedulerEnabled := !!schedulerEnabled
    this._configuredPollIntervalMs := Max(1000, Integer(pollIntervalMs))
    this._catchUpMaximumHours := Min(24, Max(1, Integer(catchUpMaximumHours)))
    if (this._schedulerEnabled)
      this.Start()
    else
      this.Stop()
  }

  Start() {
    if (!this._schedulerEnabled)
      return false
    desiredPeriodMs := this._calculateTimerPeriod()
    if (this._timerRunning && desiredPeriodMs = this._timerPeriodMs)
      return true
    if (this._timerRunning)
      SetTimer(this._pollFn, 0)
    this._timerPeriodMs := desiredPeriodMs
    this._lastPollTimestamp := ""
    SetTimer(this._pollFn, this._timerPeriodMs)
    this._timerRunning := true
    return true
  }

  Stop() {
    if (this._timerRunning)
      SetTimer(this._pollFn, 0)
    this._timerRunning := false
    this._timerPeriodMs := 0
    this._lastPollTimestamp := ""
  }

  RunAutomation(automationId) {
    automation := this._findAutomation(automationId)
    if (!IsObject(automation))
      return Map("ok", false, "error", "Automation not found: " automationId)
    if (automation["_validationErrors"].Length > 0)
      return Map("ok", false, "error", "Automation is invalid", "problems", automation["_validationErrors"])

    state := this._getRuntimeState(automation["id"])
    if (state["running"])
      return Map("ok", false, "error", "Automation is already running")
    if (!this._evaluateConditions(automation["conditions"], false))
      return Map("ok", false, "skipped", true, "error", "Automation conditions are not met")
    return this._executeAutomation(automation, state, [], "manual")
  }

  TestAutomationAction(automationId) {
    automation := this._findAutomation(automationId)
    if (!IsObject(automation))
      return Map("ok", false, "error", "Automation not found: " automationId)
    if (automation["action"] = "")
      return Map("ok", false, "error", "Automation action is empty")
    state := this._getRuntimeState(automation["id"])
    if (state["running"])
      return Map("ok", false, "error", "Automation is already running")
    return this._executeAutomation(automation, state, [], "test")
  }

  GetRuntimeSnapshot() {
    currentTimestamp := this._platform.GetLocalTimestamp()
    currentTick := this._platform.GetMonotonicMilliseconds()
    snapshot := Map("running", this._timerRunning, "timerPeriodMs", this._timerPeriodMs, "enabledAutomations", 0, "automations", Map(), "battery", this._batteryMonitor.GetState(), "nextDue", Map("known", false))
    for automation in this._automations {
      if (automation["enabled"] && automation["_validationErrors"].Length = 0)
        snapshot["enabledAutomations"] += 1
      state := this._getRuntimeState(automation["id"])
      nextDue := automation["enabled"] && automation["_validationErrors"].Length = 0 ? this._getNextOccurrence(automation, state, currentTimestamp, currentTick) : Map("known", false)
      snapshot["automations"][automation["id"]] := Map("armed", state["armed"], "running", state["running"], "conditionPassed", state["conditionPassed"], "lastResult", state["lastResult"], "nextDue", nextDue)
      if (nextDue["known"] && (!snapshot["nextDue"]["known"] || nextDue["secondsUntil"] < snapshot["nextDue"]["secondsUntil"]))
        snapshot["nextDue"] := Map("known", true, "automationId", automation["id"], "name", automation["name"], "secondsUntil", nextDue["secondsUntil"], "timestamp", nextDue["timestamp"])
    }
    return snapshot
  }

  GetNextSleepAutomation() {
    currentTimestamp := this._platform.GetLocalTimestamp()
    currentTick := this._platform.GetMonotonicMilliseconds()
    bestMatch := Map("known", false, "state", "unknown", "source", "App automation")
    for automation in this._automations {
      if (!automation["enabled"] || automation["_validationErrors"].Length > 0 || !this._isSleepAction(automation["action"]))
        continue
      state := this._getRuntimeState(automation["id"])
      nextDue := this._getNextOccurrence(automation, state, currentTimestamp, currentTick)
      if (nextDue["known"] && (!bestMatch["known"] || nextDue["secondsUntil"] < bestMatch["secondsUntil"]))
        bestMatch := Map("known", true, "state", "countdown", "source", "Automation: " automation["name"], "automationId", automation["id"], "name", automation["name"], "secondsUntil", nextDue["secondsUntil"], "timestamp", nextDue["timestamp"], "activityResets", false)
    }
    return bestMatch
  }

  _poll(*) {
    if (this._polling) {
      this._log(AKBase.LOG_WARNING, "Automation scheduler skipped an overlapping poll")
      return
    }

    this._polling := true
    currentTimestamp := this._platform.GetLocalTimestamp()
    previousPollTimestamp := this._lastPollTimestamp
    try {
      this._batteryMonitor.Update(false)
      for automation in this._automations {
        if (!automation["enabled"] || automation["_validationErrors"].Length > 0)
          continue
        try this._pollAutomation(automation, currentTimestamp, previousPollTimestamp)
        catch Error as automationError
          this._log(AKBase.LOG_ERROR, "Automation " automation["id"] " poll failed: " automationError.Message)
      }
    } catch Error as pollError {
      this._log(AKBase.LOG_ERROR, "Automation scheduler poll failed: " pollError.Message)
    } finally {
      this._lastPollTimestamp := currentTimestamp
      this._polling := false
    }
  }

  _pollAutomation(automation, currentTimestamp, previousPollTimestamp) {
    state := this._getRuntimeState(automation["id"])
    conditionMode := automation["options"]["conditionMode"]
    conditionsPassed := this._evaluateConditions(automation["conditions"], false)
    state["conditionPassed"] := conditionsPassed

    if (conditionMode = "on-enter" && !state["armed"] && !this._evaluateConditions(automation["conditions"], true))
      state["armed"] := true

    dueTriggers := this._collectDueTriggers(automation, state, currentTimestamp, previousPollTimestamp)
    if (dueTriggers.Length = 0 || !conditionsPassed)
      return
    if (conditionMode = "on-enter" && !state["armed"])
      return
    if (state["running"])
      return

    this._executeAutomation(automation, state, dueTriggers, "scheduler")
    if (conditionMode = "on-enter")
      state["armed"] := false
  }

  _collectDueTriggers(automation, state, currentTimestamp, previousPollTimestamp) {
    dueTriggers := []
    currentTick := this._platform.GetMonotonicMilliseconds()
    for triggerIndex, trigger in automation["triggers"] {
      if (AutomationCron.IsExpired(trigger, currentTimestamp))
        continue
      triggerState := this._getTriggerState(state, triggerIndex, trigger, currentTick)
      if (trigger["type"] = "interval") {
        if (currentTick < triggerState["nextDueTick"])
          continue
        dueTick := triggerState["nextDueTick"]
        periodsElapsed := Floor((currentTick - dueTick) / trigger["value"]) + 1
        triggerState["nextDueTick"] := dueTick + (periodsElapsed * trigger["value"])
        dueTriggers.Push(Map("index", triggerIndex - 1, "type", "interval", "occurrence", dueTick))
        continue
      }

      compiledExpression := this._getCompiledCron(trigger["value"])
      currentSlot := AutomationCron.Slot(currentTimestamp)
      if (AutomationCron.Matches(currentTimestamp, compiledExpression) && triggerState["lastOccurrence"] != currentSlot) {
        triggerState["lastOccurrence"] := currentSlot
        triggerState["startupCatchUpChecked"] := true
        dueTriggers.Push(Map("index", triggerIndex - 1, "type", "schedule", "occurrence", currentSlot))
        continue
      }

      catchUpTimestamp := this._findCatchUpOccurrence(automation, trigger, triggerState, compiledExpression, currentTimestamp, previousPollTimestamp)
      if (catchUpTimestamp != "") {
        catchUpSlot := AutomationCron.Slot(catchUpTimestamp)
        triggerState["lastOccurrence"] := catchUpSlot
        dueTriggers.Push(Map("index", triggerIndex - 1, "type", "schedule-catch-up", "occurrence", catchUpSlot))
      }
    }
    return dueTriggers
  }

  _findCatchUpOccurrence(automation, trigger, triggerState, compiledExpression, currentTimestamp, previousPollTimestamp) {
    if (!automation["options"]["catchUp"])
      return ""

    searchStartTimestamp := ""
    if (!triggerState["startupCatchUpChecked"]) {
      triggerState["startupCatchUpChecked"] := true
      searchStartTimestamp := DateAdd(currentTimestamp, -this._catchUpMaximumHours, "Hours")
    } else if (previousPollTimestamp != "" && DateDiff(currentTimestamp, previousPollTimestamp, "Seconds") > 70) {
      maximumStartTimestamp := DateAdd(currentTimestamp, -this._catchUpMaximumHours, "Hours")
      searchStartTimestamp := DateDiff(previousPollTimestamp, maximumStartTimestamp, "Seconds") > 0 ? previousPollTimestamp : maximumStartTimestamp
    }
    if (searchStartTimestamp = "")
      return ""

    catchUpTimestamp := AutomationCron.FindLatestMatchBefore(compiledExpression, currentTimestamp, searchStartTimestamp)
    if (catchUpTimestamp = "" || AutomationCron.IsExpired(trigger, catchUpTimestamp))
      return ""
    catchUpSlot := AutomationCron.Slot(catchUpTimestamp)
    return triggerState["lastOccurrence"] = catchUpSlot ? "" : catchUpTimestamp
  }

  _evaluateConditions(conditions, hysteresisRelease) {
    batteryStatus := this._batteryMonitor.GetStatus()
    for condition in conditions {
      if (!this._evaluateCondition(condition, batteryStatus, hysteresisRelease))
        return false
    }
    return true
  }

  _evaluateCondition(condition, batteryStatus, hysteresisRelease) {
    conditionType := condition["type"]
    conditionValue := condition["value"]
    switch conditionType {
      case "idle":
        return this._platform.GetPhysicalIdleMilliseconds() >= conditionValue
      case "window-exists":
        return this._platform.WindowExists(conditionValue)
      case "window-active":
        return this._platform.WindowIsActive(conditionValue)
      case "window-topmost":
        return this._platform.WindowIsTopmost(conditionValue)
      case "power-source":
        return batteryStatus["powerSource"] = conditionValue
      case "battery-percent-at-most":
        threshold := conditionValue + (hysteresisRelease ? 2 : 0)
        return batteryStatus["percent"] >= 0 && batteryStatus["percent"] <= threshold
      case "battery-minutes-at-most":
        remainingSeconds := batteryStatus["reportedRemainingSeconds"] >= 0 ? batteryStatus["reportedRemainingSeconds"] : batteryStatus["estimatedRemainingSeconds"]
        thresholdMinutes := conditionValue + (hysteresisRelease ? 5 : 0)
        return remainingSeconds >= 0 && remainingSeconds <= thresholdMinutes * 60
      case "charging":
        return batteryStatus["charging"] = conditionValue
      case "or":
        for childCondition in conditionValue {
          if (this._evaluateCondition(childCondition, batteryStatus, hysteresisRelease))
            return true
        }
        return false
      case "not":
        return !this._evaluateCondition(conditionValue, batteryStatus, hysteresisRelease)
    }
    return false
  }

  _executeAutomation(automation, state, dueTriggers, source) {
    state["running"] := true
    startedAt := this._platform.GetLocalTimestamp()
    try {
      try result := this._runActionFn.Call(automation["action"], automation["options"]["notifyOnError"])
      catch Error as actionError
        result := Map("ok", false, "error", actionError.Message)
      state["lastResult"] := Map("time", startedAt, "ok", !!result["ok"], "source", source)
      if (result.Has("error"))
        state["lastResult"]["error"] := result["error"]
      if (dueTriggers.Length > 0)
        state["lastResult"]["matchedTriggers"] := dueTriggers

      if (automation["options"]["logRuns"]) {
        logLevel := result["ok"] ? AKBase.LOG_INFO : AKBase.LOG_ERROR
        logMessage := "Automation " automation["id"] " (" automation["name"] ") " (result["ok"] ? "completed" : "failed") ": " automation["action"]
        if (result.Has("error"))
          logMessage .= " - " result["error"]
        this._log(logLevel, logMessage)
      }
      return result
    } finally {
      state["running"] := false
      this._skipElapsedIntervals(automation, state)
    }
  }

  _skipElapsedIntervals(automation, state) {
    currentTick := this._platform.GetMonotonicMilliseconds()
    skippedOccurrences := 0
    for triggerIndex, trigger in automation["triggers"] {
      if (trigger["type"] != "interval")
        continue
      triggerState := this._getTriggerState(state, triggerIndex, trigger, currentTick)
      if (currentTick < triggerState["nextDueTick"])
        continue
      periodsElapsed := Floor((currentTick - triggerState["nextDueTick"]) / trigger["value"]) + 1
      triggerState["nextDueTick"] += periodsElapsed * trigger["value"]
      skippedOccurrences += periodsElapsed
    }
    if (skippedOccurrences > 0 && automation["options"]["logRuns"])
      this._log(AKBase.LOG_WARNING, "Automation " automation["id"] " skipped " skippedOccurrences " interval occurrence(s) while its action was running")
  }

  _getRuntimeState(automationId) {
    if (!this._runtimeStates.Has(automationId))
      this._runtimeStates[automationId] := Map("armed", true, "running", false, "conditionPassed", false, "lastResult", Map(), "triggers", Map())
    return this._runtimeStates[automationId]
  }

  _getTriggerState(state, triggerIndex, trigger, currentTick) {
    triggerKey := triggerIndex ":" trigger["type"] ":" trigger["value"] ":" (trigger.Has("expires") ? trigger["expires"] : "")
    if (!state["triggers"].Has(triggerKey)) {
      nextDueTick := trigger["type"] = "interval" ? currentTick + trigger["value"] : 0
      state["triggers"][triggerKey] := Map("nextDueTick", nextDueTick, "lastOccurrence", "", "startupCatchUpChecked", false)
    }
    return state["triggers"][triggerKey]
  }

  _getNextOccurrence(automation, state, currentTimestamp, currentTick) {
    nextOccurrence := Map("known", false)
    for triggerIndex, trigger in automation["triggers"] {
      if (AutomationCron.IsExpired(trigger, currentTimestamp))
        continue
      if (trigger["type"] = "interval") {
        triggerState := this._getTriggerState(state, triggerIndex, trigger, currentTick)
        secondsUntil := Max(0, Ceil((triggerState["nextDueTick"] - currentTick) / 1000))
        occurrenceTimestamp := DateAdd(currentTimestamp, secondsUntil, "Seconds")
      } else {
        compiledExpression := this._getCompiledCron(trigger["value"])
        occurrenceTimestamp := AutomationCron.FindNextMatch(compiledExpression, currentTimestamp)
        if (occurrenceTimestamp = "")
          continue
        if (trigger.Has("expires") && DateDiff(occurrenceTimestamp, StrReplace(trigger["expires"], "-") "235959", "Seconds") > 0)
          continue
        secondsUntil := Max(0, DateDiff(occurrenceTimestamp, currentTimestamp, "Seconds"))
      }

      if (!nextOccurrence["known"] || secondsUntil < nextOccurrence["secondsUntil"])
        nextOccurrence := Map("known", true, "secondsUntil", secondsUntil, "timestamp", occurrenceTimestamp, "triggerIndex", triggerIndex - 1, "triggerType", trigger["type"])
    }
    return nextOccurrence
  }

  _isSleepAction(actionString) {
    return RegExMatch(Trim("" actionString), "i)^(SleepComputer|HibernateComputer|SuspendComputer|Hibernate|Suspend)\s*\(") != 0
  }

  _getCompiledCron(expression) {
    if (!this._cronCache.Has(expression))
      this._cronCache[expression] := AutomationCron.Parse(expression)
    return this._cronCache[expression]
  }

  _calculateTimerPeriod() {
    timerPeriodMs := this._configuredPollIntervalMs
    for automation in this._automations {
      if (!automation["enabled"] || automation["_validationErrors"].Length > 0)
        continue
      for trigger in automation["triggers"] {
        if (trigger["type"] = "interval")
          timerPeriodMs := Min(timerPeriodMs, trigger["value"])
      }
    }
    return Max(1000, timerPeriodMs)
  }

  _restartTimerIfNeeded() {
    desiredPeriodMs := this._calculateTimerPeriod()
    if (desiredPeriodMs = this._timerPeriodMs)
      return
    SetTimer(this._pollFn, 0)
    this._timerPeriodMs := desiredPeriodMs
    SetTimer(this._pollFn, this._timerPeriodMs)
  }

  _findAutomation(automationId) {
    automationIdText := Trim("" automationId)
    for automation in this._automations {
      if (automation["id"] = automationIdText)
        return automation
    }
    return 0
  }

  _log(level, message) {
    if (IsObject(this._logFn))
      this._logFn.Call(level, message)
  }
}

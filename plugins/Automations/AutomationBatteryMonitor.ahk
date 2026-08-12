class AutomationBatteryMonitor {
  __New(platform, historyStore:=0, sampleIntervalMs:=30000, logFn:=0) {
    this._platform := platform
    this._historyStore := historyStore
    this._sampleIntervalMs := sampleIntervalMs
    this._logFn := logFn
    this._nextSampleTick := 0
    this._lastPruneUnixSeconds := 0
    this._status := Map("sampledAt", 0, "powerSource", "unknown", "charging", false, "hasBattery", false, "percent", -1, "reportedRemainingSeconds", -1, "estimatedRemainingSeconds", -1, "batteryFlag", 0)
  }

  SetSampleInterval(sampleIntervalMs) {
    this._sampleIntervalMs := Max(1000, Integer(sampleIntervalMs))
    this._nextSampleTick := 0
  }

  Update(force:=false) {
    currentTick := this._platform.GetMonotonicMilliseconds()
    if (!force && this._nextSampleTick && currentTick < this._nextSampleTick)
      return this._status

    this._status := this._platform.GetBatteryStatus()
    this._nextSampleTick := currentTick + this._sampleIntervalMs
    if (IsObject(this._historyStore) && this._status["hasBattery"] && this._status["percent"] >= 0) {
      try {
        this._historyStore.AddBatterySample(this._status)
        this._status["estimatedRemainingSeconds"] := this._estimateRemainingSeconds(this._status["sampledAt"])
        if (!this._lastPruneUnixSeconds || this._status["sampledAt"] - this._lastPruneUnixSeconds >= 86400) {
          this._historyStore.Prune(this._status["sampledAt"])
          this._lastPruneUnixSeconds := this._status["sampledAt"]
        }
      } catch Error as historyError {
        this._log(AKBase.LOG_WARNING, "Battery history update failed: " historyError.Message)
      }
    }
    return this._status
  }

  GetStatus() {
    return this.Update(false)
  }

  GetState() {
    status := this.GetStatus()
    return Map("sampledAt", status["sampledAt"], "powerSource", status["powerSource"], "charging", status["charging"], "hasBattery", status["hasBattery"], "percent", status["percent"], "reportedRemainingSeconds", status["reportedRemainingSeconds"], "estimatedRemainingSeconds", status["estimatedRemainingSeconds"])
  }

  _estimateRemainingSeconds(currentUnixSeconds) {
    samples := this._historyStore.GetRecentBatterySamples(currentUnixSeconds - 14400, 480)
    dischargingSamples := []
    for sample in samples {
      if (sample["powerSource"] = "battery" && !sample["charging"] && sample["percent"] >= 0)
        dischargingSamples.Push(sample)
    }
    if (dischargingSamples.Length < 3)
      return -1

    oldestSample := dischargingSamples[1]
    newestSample := dischargingSamples[dischargingSamples.Length]
    elapsedSeconds := newestSample["sampledAt"] - oldestSample["sampledAt"]
    percentDrop := oldestSample["percent"] - newestSample["percent"]
    if (elapsedSeconds < 300 || percentDrop < 1)
      return -1

    estimateSeconds := Round((elapsedSeconds / percentDrop) * newestSample["percent"])
    return estimateSeconds > 0 && estimateSeconds <= 604800 ? estimateSeconds : -1
  }

  _log(level, message) {
    if (IsObject(this._logFn))
      this._logFn.Call(level, message)
  }
}

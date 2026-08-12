class AutomationJsonStore {
  static SCHEMA_VERSION := 1

  __New(path, platform) {
    this._path := path
    this._platform := platform
  }

  Load() {
    if (!FileExist(this._path))
      return Map("schemaVersion", AutomationJsonStore.SCHEMA_VERSION, "automations", [])

    root := jsongo.Parse(this._platform.ReadTextFile(this._path))
    if (!(root is Map))
      throw Error("automations.json root must be an object")
    if (!root.Has("schemaVersion") || Integer(root["schemaVersion"]) != AutomationJsonStore.SCHEMA_VERSION)
      throw Error("Unsupported automations.json schema version")
    if (!root.Has("automations") || !(root["automations"] is Array))
      throw Error("automations.json must contain an automations array")
    return root
  }

  Save(automations) {
    persistedAutomations := []
    for automation in automations
      persistedAutomations.Push(AutomationDefinition.ToPersisted(automation))
    root := Map("schemaVersion", AutomationJsonStore.SCHEMA_VERSION, "automations", persistedAutomations)
    this._platform.AtomicReplaceText(this._path, jsongo.Stringify(root, , 2))
    return root
  }

  GetPath() {
    return this._path
  }
}

class WindowsAutomationHistoryStore {
  static SQLITE_OK := 0
  static SQLITE_ROW := 100
  static SQLITE_DONE := 101

  __New(path, retentionDays:=30) {
    this._path := path
    this._retentionDays := retentionDays
    this._databaseHandle := 0
  }

  Initialize() {
    if (!FileExist(A_WinDir "\System32\winsqlite3.dll"))
      throw Error("winsqlite3.dll is not available")

    databaseHandle := 0
    resultCode := DllCall("winsqlite3\sqlite3_open16", "WStr", this._path, "Ptr*", &databaseHandle, "CDecl Int")
    this._databaseHandle := databaseHandle
    if (resultCode != WindowsAutomationHistoryStore.SQLITE_OK) {
      errorMessage := this._lastError()
      this.Close()
      throw Error("Unable to open battery history database: " errorMessage)
    }

    try {
      DllCall("winsqlite3\sqlite3_busy_timeout", "Ptr", this._databaseHandle, "Int", 2000, "CDecl Int")
      this._exec("PRAGMA auto_vacuum=INCREMENTAL; PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")
      this._exec("CREATE TABLE IF NOT EXISTS battery_samples (sampled_at INTEGER NOT NULL, percent INTEGER NOT NULL, remaining_seconds INTEGER NOT NULL, charging INTEGER NOT NULL, power_source TEXT NOT NULL);")
      this._exec("CREATE INDEX IF NOT EXISTS battery_samples_sampled_at ON battery_samples(sampled_at);")
      return true
    } catch Error as initializationError {
      this.Close()
      throw initializationError
    }
  }

  SetRetentionDays(retentionDays) {
    this._retentionDays := Min(365, Max(1, Integer(retentionDays)))
  }

  AddBatterySample(status) {
    this._ensureOpen()
    statement := this._prepare("INSERT INTO battery_samples(sampled_at, percent, remaining_seconds, charging, power_source) VALUES(?, ?, ?, ?, ?);")
    try {
      this._bindInt64(statement, 1, status["sampledAt"])
      this._bindInt(statement, 2, status["percent"])
      this._bindInt(statement, 3, status["reportedRemainingSeconds"])
      this._bindInt(statement, 4, status["charging"] ? 1 : 0)
      this._bindText(statement, 5, status["powerSource"])
      this._expectDone(statement)
    } finally {
      this._finalize(statement)
    }
  }

  GetRecentBatterySamples(sinceUnixSeconds, maximumSamples:=480) {
    this._ensureOpen()
    samples := []
    sql := "SELECT sampled_at, percent, remaining_seconds, charging, power_source FROM (SELECT sampled_at, percent, remaining_seconds, charging, power_source FROM battery_samples WHERE sampled_at >= ? ORDER BY sampled_at DESC LIMIT ?) ORDER BY sampled_at ASC;"
    statement := this._prepare(sql)
    try {
      this._bindInt64(statement, 1, sinceUnixSeconds)
      this._bindInt(statement, 2, maximumSamples)
      Loop {
        resultCode := DllCall("winsqlite3\sqlite3_step", "Ptr", statement, "CDecl Int")
        if (resultCode = WindowsAutomationHistoryStore.SQLITE_DONE)
          break
        if (resultCode != WindowsAutomationHistoryStore.SQLITE_ROW)
          throw Error("Unable to read battery history: " this._lastError())
        samples.Push(Map(
          "sampledAt", DllCall("winsqlite3\sqlite3_column_int64", "Ptr", statement, "Int", 0, "CDecl Int64"),
          "percent", DllCall("winsqlite3\sqlite3_column_int", "Ptr", statement, "Int", 1, "CDecl Int"),
          "reportedRemainingSeconds", DllCall("winsqlite3\sqlite3_column_int", "Ptr", statement, "Int", 2, "CDecl Int"),
          "charging", DllCall("winsqlite3\sqlite3_column_int", "Ptr", statement, "Int", 3, "CDecl Int") != 0,
          "powerSource", this._columnText(statement, 4)
        ))
      }
    } finally {
      this._finalize(statement)
    }
    return samples
  }

  Prune(currentUnixSeconds) {
    this._ensureOpen()
    cutoffUnixSeconds := currentUnixSeconds - (this._retentionDays * 86400)
    statement := this._prepare("DELETE FROM battery_samples WHERE sampled_at < ?;")
    try {
      this._bindInt64(statement, 1, cutoffUnixSeconds)
      this._expectDone(statement)
    } finally {
      this._finalize(statement)
    }
    this._exec("PRAGMA incremental_vacuum(64);")
  }

  Close() {
    if (!this._databaseHandle)
      return
    DllCall("winsqlite3\sqlite3_close_v2", "Ptr", this._databaseHandle, "CDecl Int")
    this._databaseHandle := 0
  }

  _exec(sql) {
    this._ensureOpen()
    errorMessagePointer := 0
    resultCode := DllCall("winsqlite3\sqlite3_exec", "Ptr", this._databaseHandle, "AStr", sql, "Ptr", 0, "Ptr", 0, "Ptr*", &errorMessagePointer, "CDecl Int")
    if (resultCode = WindowsAutomationHistoryStore.SQLITE_OK)
      return
    errorMessage := errorMessagePointer ? StrGet(errorMessagePointer, "UTF-8") : this._lastError()
    if (errorMessagePointer)
      DllCall("winsqlite3\sqlite3_free", "Ptr", errorMessagePointer, "CDecl Int")
    throw Error("SQLite error: " errorMessage)
  }

  _prepare(sql) {
    statement := 0
    resultCode := DllCall("winsqlite3\sqlite3_prepare_v2", "Ptr", this._databaseHandle, "AStr", sql, "Int", -1, "Ptr*", &statement, "Ptr", 0, "CDecl Int")
    if (resultCode != WindowsAutomationHistoryStore.SQLITE_OK)
      throw Error("Unable to prepare battery history statement: " this._lastError())
    return statement
  }

  _bindInt(statement, parameterIndex, value) {
    resultCode := DllCall("winsqlite3\sqlite3_bind_int", "Ptr", statement, "Int", parameterIndex, "Int", value, "CDecl Int")
    this._checkBindResult(resultCode)
  }

  _bindInt64(statement, parameterIndex, value) {
    resultCode := DllCall("winsqlite3\sqlite3_bind_int64", "Ptr", statement, "Int", parameterIndex, "Int64", value, "CDecl Int")
    this._checkBindResult(resultCode)
  }

  _bindText(statement, parameterIndex, value) {
    resultCode := DllCall("winsqlite3\sqlite3_bind_text", "Ptr", statement, "Int", parameterIndex, "AStr", value, "Int", -1, "Ptr", -1, "CDecl Int")
    this._checkBindResult(resultCode)
  }

  _checkBindResult(resultCode) {
    if (resultCode != WindowsAutomationHistoryStore.SQLITE_OK)
      throw Error("Unable to bind battery history value: " this._lastError())
  }

  _expectDone(statement) {
    resultCode := DllCall("winsqlite3\sqlite3_step", "Ptr", statement, "CDecl Int")
    if (resultCode != WindowsAutomationHistoryStore.SQLITE_DONE)
      throw Error("Unable to write battery history: " this._lastError())
  }

  _columnText(statement, columnIndex) {
    valuePointer := DllCall("winsqlite3\sqlite3_column_text", "Ptr", statement, "Int", columnIndex, "CDecl Ptr")
    return valuePointer ? StrGet(valuePointer, "UTF-8") : ""
  }

  _finalize(statement) {
    if (statement)
      DllCall("winsqlite3\sqlite3_finalize", "Ptr", statement, "CDecl Int")
  }

  _lastError() {
    if (!this._databaseHandle)
      return "database is not open"
    errorPointer := DllCall("winsqlite3\sqlite3_errmsg", "Ptr", this._databaseHandle, "CDecl Ptr")
    return errorPointer ? StrGet(errorPointer, "UTF-8") : "unknown SQLite error"
  }

  _ensureOpen() {
    if (!this._databaseHandle)
      throw Error("Battery history database is not open")
  }
}

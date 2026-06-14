class AKBase {
  static DIALOG_TIMEOUT := "TIMEOUT"
  static DIALOG_OK := "OK"
  static DIALOG_CANCEL := "CANCEL"
  static DIALOG_ABORT := "ABORT"
  static DIALOG_RETRY := "RETRY"
  static DIALOG_IGNORE := "IGNORE"
  static DIALOG_YES := "YES"
  static DIALOG_NO := "NO"
  static DIALOG_CONTINUE := "CONTINUE"

  static LOG_ERROR := 0
  static LOG_WARNING := 1
  static LOG_NOTICE := 2
  static LOG_INFO := 3
  static LOG_DEBUG := 4
  static LOG_TRACE := 5

  debugLevel := 0 ; 0: error, 1: warning, 2: notice, 3: info, 4: debug
  static _uiLogs := []
  static _nextLogId := 0
  static _hasBindingProblems := false
  static _logPushHandler := 0
  static _nextNotificationId := 0
  Debug(level:=0) {
    this.debugLevel := level
    ; this.initMenu()
  }
  ShowError(text, title:="") {
    this.outputDebugLine(AKApp.LOG_ERROR, text, 0)
    return this.MsgBox(text, title ? title : "ERROR", , MSGBOX_OPTS.BUTTONS_CANCEL_RETRY_CONTINUE | MSGBOX_OPTS.ICON_ERROR | MSGBOX_OPTS.DEFAULT_BUTTON_2)
  }
  ShowWarning(text, title:="", timeout:=15000) {
    this.outputDebugLine(AKApp.LOG_WARNING, text)
    return this.msgBox(text, title ? title : "WARNING", timeout, MSGBOX_OPTS.BUTTONS_OK | MSGBOX_OPTS.ICON_WARNING)
  }
  ShowNotice(text, title:="", timeout:=10000) {
    this.outputDebugLine(AKApp.LOG_NOTICE, text, 2)
    return this.msgBox(text, title ? title : "NOTICE", timeout, MSGBOX_OPTS.BUTTONS_OK | MSGBOX_OPTS.ICON_INFO)
  }
  ShowInfo(text, title:="", timeout:=2000, style:="info") {
    style := this._getNotificationStyle(style)
    this.outputDebugLine(style["logLevel"], text, style["logLevel"])
    AKBase._nextNotificationId += 1
    notificationTag := "AKNotification" AKBase._nextNotificationId
    options := "dur=0 pos=ct style=round show=fade@100 bc=" style["backgroundColor"] " tc=" style["accentColor"] " mc=" style["messageColor"] " tag=" notificationTag
    Notify.Show(title, text,,,, options)
    if (timeout > 0)
      SetTimer(infoNotificationOff, -timeout)
    return notificationTag
  
    infoNotificationOff() {
      Notify.Destroy(notificationTag)
    }
  }
  _getNotificationStyle(style) {
    switch StrLower(Trim("" style)) {
      case "success":
        return Map("backgroundColor", "14261D", "accentColor", "4ADE80", "messageColor", "F0FDF4", "logLevel", AKBase.LOG_INFO)
      case "warning":
        return Map("backgroundColor", "2B2314", "accentColor", "FBBF24", "messageColor", "FFFBEB", "logLevel", AKBase.LOG_WARNING)
      case "error":
        return Map("backgroundColor", "2C1719", "accentColor", "F87171", "messageColor", "FEF2F2", "logLevel", AKBase.LOG_ERROR)
      default:
        return Map("backgroundColor", "172033", "accentColor", "7DD3FC", "messageColor", "F8FAFC", "logLevel", AKBase.LOG_INFO)
    }
  }
  msgBox(text, title:="", timeout:=0, options:=0) {
    timeoutSec := timeout ? " T" (timeout / 1000) : ""
    msgResult := MsgBox(text, title, options . timeoutSec)

    switch(msgResult) {
      case "Timeout":
        return AKBase.DIALOG_TIMEOUT
      case "Ok":
        return AKBase.DIALOG_OK
      case "Cancel":
        return AKBase.DIALOG_CANCEL
      case "Abort":
        return AKBase.DIALOG_ABORT
      case "Retry":
        return AKBase.DIALOG_RETRY
      case "Ignore":
        return AKBase.DIALOG_IGNORE
      case "Yes":
        return AKBase.DIALOG_YES
      case "No":
        return AKBase.DIALOG_NO
      case "Continue":
        return AKBase.DIALOG_CONTINUE
    }
  }
  outputDebugLine(level, line, meta:=0) {
    if (level > this.debugLevel)
      return
    OutputDebug(AKBase._logLevelToString(level) ": " line) ;  "`n"
    AKBase._bufferLogMessage(line, level, meta)
  }
  static SetLogPushHandler(handler := 0) {
    AKBase._logPushHandler := handler
  }
  static _logLevelToString(level) {
    switch (level) {
      case 0: return 'ERROR'
      case 1: return 'WARNING'
      case 2: return 'NOTICE'
      case 3: return 'INFO'
      case 4: return 'DEBUG'
      case 5: return 'TRACE'
      default: return 'WUT?'
    }
  }

  static _bufferLogMessage(line, level:=4, meta:=0) {
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logEntry := Map(
      "id",       AKBase._nextLogId,
      "time",     timestamp,
      "level",    level,
      "text",     "" line
    )

    if (IsObject(meta)) {
      if (meta is Map) {
        if (meta.Has("source"))
          logEntry["source"] := "" meta["source"]
        if (meta.Has("settingRef") && IsObject(meta["settingRef"]))
          logEntry["settingRef"] := meta["settingRef"]
      } else {
        if (meta.HasOwnProp("source"))
          logEntry["source"] := "" meta.source
        if (meta.HasOwnProp("settingRef") && IsObject(meta.settingRef))
          logEntry["settingRef"] := meta.settingRef
      }
    }

    AKBase._nextLogId++

    AKBase._uiLogs.Push(logEntry)
    if (AKBase._uiLogs.Length > 500)
      AKBase._uiLogs.RemoveAt(1)

    if (IsObject(AKBase._logPushHandler)) {
      try AKBase._logPushHandler.Call(logEntry)
    }
  }
  static GetUiLogs() {
    return AKBase._uiLogs
  }
  static GetUiLogsSince(lastId) {
    result := []
    for entry in AKBase._uiLogs {
      if (entry["id"] > lastId)
        result.Push(entry)
    }
    return result
  }
  static ClearLogs() {
    AKBase._uiLogs := []
  }
  static ClearProblems() {
    ; kept for backward compat; use ClearLogs() instead
    AKBase.ClearLogs()
  }
}

class MSGBOX_OPTS {
  static BUTTONS_OK                    := 0x0       ; OK (that is, only an OK button is displayed)   0   0x0
  static BUTTONS_OK_CANCEL             := 0x1       ; OK/Cancel   1   0x1
  static BUTTONS_ABORT_RETRY_IGNORE    := 0x2       ; Abort/Retry/Ignore   2   0x2
  static BUTTONS_YES_NO_CANCEL         := 0x3       ; Yes/No/Cancel   3   0x3
  static BUTTONS_YES_NO                := 0x4       ; Yes/No   4   0x4
  static BUTTONS_RETRY_CANCEL          := 0x5       ; Retry/Cancel   5   0x5
  static BUTTONS_CANCEL_RETRY_CONTINUE := 0x6       ; Cancel/Try Again/Continue   6   0x6
  static ICON_ERROR                    := 0x10      ; Icon Hand (stop/error)   16   0x10
  static ICON_QUESTION                 := 0x20      ; Icon Question   32   0x20
  static ICON_WARNING                  := 0x30      ; Icon Exclamation   48   0x30
  static ICON_INFO                     := 0x40      ; Icon Asterisk (info)   64   0x40
  static DEFAULT_BUTTON_2              := 0x100     ; Makes the 2nd button the default   256   0x100
  static DEFAULT_BUTTON_3              := 0x200     ; Makes the 3rd button the default   512   0x200
  static DEFAULT_BUTTON_4              := 0x300     ; Makes the 4th button the default (requires the Help button to be present)   768   0x300
  static MODALITY_SYSTEM_MODAL         := 0x1000    ; System Modal (always on top)   4096   0x1000
  static MODALITY_TASK_MODAL           := 0x2000    ; Task Modal   8192   0x2000
  static MODALITY_ALWAYS_ON_TOP        := 0x40000   ; Always-on-top (style WS_EX_TOPMOST) (like System Modal but omits title bar icon)   262144   0x40000
  static OTHER_ADD_HELP_BUTTON         := 0x4000    ; Adds a Help button (see remarks below)   16384   0x4000
  static OTHER_JUSTIFY_TEXT_TO_RIGHT   := 0x80000   ; Make the text right-justified   524288   0x80000
  static OTHER_TEXT_RIRGHT_TO_LEFT     := 0x100000  ; Right-to-left reading order for Hebrew/Arabic   1048576   0x100000
}

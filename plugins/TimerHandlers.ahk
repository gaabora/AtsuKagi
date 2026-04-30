class TimerHandlers extends AKPlugin { ; TODO: not yet fully implemented, needs better naming for actions, like 'cron' is not a right part of name 
  ScheduledTasks := Map()
  
  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "TimerHandlers",
        "title", "Timer Handlers",
        "description", "Cron-like scheduled tasks and system event handling based on time and idle state triggers.",
        "icon", "icons10-clock",
        "category", "System Events"
      ),
      "settingsPage", Map(
        "description", "Configure scheduled tasks and system monitoring triggers.",
        "icon", "icons10-clock"
      ),
      "config", [],
      "actions", [],
      "hooks", []
    )
  }

  ; ── Legacy Methods (Phase 1-5: TODO: remove after Phase 5) ─────────────────────
  ; These are now derived from __DescribePlugin() by the base class
  _processBlocklistConfig() {
  }

  _processPluginConfig() {
    ; No plugin-specific config to apply
  }

  ; this._setTimer("_processScheduledTasks", 1000)

  AddCronJob(CronString) { ;;;
    ; jobDetails := this._parseCronString(CronString)
    ; this.CronJobs[JobName] := jobDetails
  }
  
  _processScheduledTasks() {

    ControlSend("{Escape}", , "ahk_class TRegCheckDlg") ; fuck rad studio license manager popups

    if (A_TimeIdlePhysical > 10000) {
      if ((A_Hour>8) && (A_Hour<17)) {
        Send("{Shift}")
      }
    }

  }


  _parseCronString(CronString) {
    ; Create an empty map to store job details
    jobDetails := Map()
    
    ; Split the cron string by commas
    cronParts := StrSplit(CronString, ",")
    
    ; Process each part and add to jobDetails
    for _, part in cronParts {
        keyValue := StrSplit(part, ":")
        key := keyValue[1]
        value := keyValue[2]

        ; Handle the special case for the action part (e.g., Action:SendInput(Shift))
        if (key = "Action") {
            ; Extract the function name and parameter
            fn := StrSplit(value, "(")[1]
            param := StrReplace(StrSplit(value, "(")[2], ")", "")
            jobDetails["Action"] := {fn: fn, param: param}
        } else {
            jobDetails[key] := value
        }
    }
    return jobDetails
}

_processCronJobs() {
    ; Get current time and idle time
    currTime := Format("{:02}:{:02}", A_Hour, A_Min)
    idleTime := A_TimeIdlePhysical

    ; Iterate over each cron job
    for JobName, jobDetails in this.CronJobs {
        ; Check the cron job's conditions
        if (this._checkCronConditions(jobDetails, currTime, idleTime)) {
            ; Execute the action
            this._executeAction(jobDetails["Action"])
        }
    }
}

_checkCronConditions(jobDetails, currTime, idleTime) {
    ; Check idle time condition (IfIdleSec)
    if (jobDetails.HasKey("IfIdleSec")) {
        if (idleTime < jobDetails["IfIdleSec"] * 1000) ; AHK gives idle in ms
            return false
    }

    ; Check IfTimeMore (start time) condition
    if (jobDetails.HasKey("IfTimeMore")) {
        if (currTime < jobDetails["IfTimeMore"])
            return false
    }

    ; Check IfTimeLess (end time) condition
    if (jobDetails.HasKey("IfTimeLess")) {
        if (currTime > jobDetails["IfTimeLess"])
            return false
    }

    ; Check IfTimeIs (exact match) condition
    if (jobDetails.HasKey("IfTimeIs")) {
        if (currTime != jobDetails["IfTimeIs"])
            return false
    }

    ; All conditions passed
    return true
}



  ; SetTimer, CheckIdle, 5000
  ; CheckIdle:
  ; ControlSend, , {Escape},  ahk_class TRegCheckDlg ; fuck rad studio license manager popups
  ; if (A_TimeIdlePhysical > 10000) {
  ;   If ((A_Hour>8) && (A_Hour<17)) {
  ;     Send {Shift}
  ;   }
  ;   ; WriteLog(" and ")
  ; }
}
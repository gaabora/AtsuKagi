class TimerHandlers extends AKPlugin {
  ScheduledTasks := Map()
  
  ; this._setTimer("_processScheduledTasks", 1000)
  __ActionsHelp() {
    texts := Map()
    ; texts["IfThenElse"] := "IfThenElse(IfActionString, ThenActionString, ElseActionString)"
    ; texts["RemapTo"]    := "RemapTo(Hotkey)"
    ; texts["DoNothing"]  := "DoNothing()"
    ; texts["ShowInfo"]   := "ShowInfo(text, title:='', timeout:=2000)"
    return texts
  }

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
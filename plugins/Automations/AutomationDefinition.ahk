class AutomationDefinition {
  static Normalize(rawAutomation, actionExistsFn:=0) {
    errors := []
    if (!(rawAutomation is Map))
      return Map("automation", this._emptyAutomation(), "errors", ["Automation must be an object"])

    automation := this._emptyAutomation()
    automation["id"] := rawAutomation.Has("id") ? Trim("" rawAutomation["id"]) : ""
    automation["name"] := rawAutomation.Has("name") ? Trim("" rawAutomation["name"]) : ""
    automation["enabled"] := rawAutomation.Has("enabled") ? this._toBoolean(rawAutomation["enabled"]) : false
    automation["action"] := rawAutomation.Has("action") ? Trim("" rawAutomation["action"]) : ""

    if (automation["id"] = "")
      errors.Push("ID cannot be empty")
    if (automation["name"] = "")
      errors.Push("Name cannot be empty")
    if (automation["action"] = "")
      errors.Push("Action cannot be empty")
    else if (IsObject(actionExistsFn) && !actionExistsFn.Call(automation["action"]))
      errors.Push("Unknown action: " automation["action"])

    rawTriggers := rawAutomation.Has("triggers") ? rawAutomation["triggers"] : 0
    if (!(rawTriggers is Array) || rawTriggers.Length = 0) {
      errors.Push("At least one trigger is required")
    } else {
      for triggerIndex, rawTrigger in rawTriggers {
        triggerResult := this._normalizeTrigger(rawTrigger, triggerIndex)
        automation["triggers"].Push(triggerResult["trigger"])
        for triggerError in triggerResult["errors"]
          errors.Push(triggerError)
      }
    }

    rawConditions := rawAutomation.Has("conditions") ? rawAutomation["conditions"] : []
    if (!(rawConditions is Array)) {
      errors.Push("Conditions must be an array")
    } else {
      for conditionIndex, rawCondition in rawConditions {
        conditionResult := this._normalizeCondition(rawCondition, 1, "Condition " conditionIndex)
        automation["conditions"].Push(conditionResult["condition"])
        for conditionError in conditionResult["errors"]
          errors.Push(conditionError)
      }
    }

    rawOptions := rawAutomation.Has("options") && (rawAutomation["options"] is Map) ? rawAutomation["options"] : Map()
    conditionMode := rawOptions.Has("conditionMode") ? Trim("" rawOptions["conditionMode"]) : "each-trigger"
    if (conditionMode != "each-trigger" && conditionMode != "on-enter") {
      errors.Push("Repeat behavior must be each-trigger or on-enter")
      conditionMode := "each-trigger"
    }
    automation["options"] := Map(
      "catchUp", rawOptions.Has("catchUp") ? this._toBoolean(rawOptions["catchUp"]) : false,
      "conditionMode", conditionMode,
      "logRuns", rawOptions.Has("logRuns") ? this._toBoolean(rawOptions["logRuns"]) : true,
      "notifyOnError", rawOptions.Has("notifyOnError") ? this._toBoolean(rawOptions["notifyOnError"]) : false,
      "showInTray", rawOptions.Has("showInTray") ? this._toBoolean(rawOptions["showInTray"]) : false
    )
    if (conditionMode = "on-enter" && automation["conditions"].Length = 0)
      errors.Push("on-enter requires at least one condition")

    if (errors.Length > 0)
      automation["enabled"] := false
    automation["_validationErrors"] := errors
    return Map("automation", automation, "errors", errors)
  }

  static ToPersisted(automation) {
    return Map(
      "id", automation["id"],
      "name", automation["name"],
      "enabled", !!automation["enabled"],
      "triggers", automation["triggers"],
      "conditions", automation["conditions"],
      "action", automation["action"],
      "options", automation["options"]
    )
  }

  static ToUi(automation) {
    uiAutomation := this.ToPersisted(automation)
    uiAutomation["validationErrors"] := automation.Has("_validationErrors") ? automation["_validationErrors"] : []
    return uiAutomation
  }

  static _emptyAutomation() {
    return Map("id", "", "name", "", "enabled", false, "triggers", [], "conditions", [], "action", "", "options", Map(), "_validationErrors", [])
  }

  static _normalizeTrigger(rawTrigger, triggerIndex) {
    errors := []
    trigger := Map("type", "", "value", "")
    errorPrefix := "Trigger " triggerIndex ": "
    if (!(rawTrigger is Map))
      return Map("trigger", trigger, "errors", [errorPrefix "must be an object"])

    triggerType := rawTrigger.Has("type") ? StrLower(Trim("" rawTrigger["type"])) : ""
    trigger["type"] := triggerType
    if (triggerType = "schedule") {
      trigger["value"] := rawTrigger.Has("value") ? Trim("" rawTrigger["value"]) : ""
      try AutomationCron.Parse(trigger["value"])
      catch Error as cronError
        errors.Push(errorPrefix cronError.Message)
    } else if (triggerType = "interval") {
      rawValue := rawTrigger.Has("value") ? rawTrigger["value"] : ""
      if (!this._tryInteger(rawValue, &intervalMs)) {
        errors.Push(errorPrefix "interval must be an integer number of milliseconds")
        intervalMs := 0
      }
      trigger["value"] := intervalMs
      if (intervalMs < 1000 || intervalMs >= 60000)
        errors.Push(errorPrefix "interval must be at least 1000 ms and less than 60000 ms")
    } else {
      errors.Push(errorPrefix "unsupported type: " triggerType)
    }

    if (rawTrigger.Has("expires") && Trim("" rawTrigger["expires"]) != "") {
      trigger["expires"] := Trim("" rawTrigger["expires"])
      if (!AutomationCron.ValidateExpiry(trigger["expires"]))
        errors.Push(errorPrefix "expiry must be a valid YYYY-MM-DD date")
    }
    return Map("trigger", trigger, "errors", errors)
  }

  static _normalizeCondition(rawCondition, depth, path) {
    errors := []
    condition := Map("type", "", "value", "")
    if (!(rawCondition is Map))
      return Map("condition", condition, "errors", [path " must be an object"])
    if (depth > 3)
      errors.Push(path " exceeds the supported nesting depth")

    conditionType := rawCondition.Has("type") ? StrLower(Trim("" rawCondition["type"])) : ""
    rawValue := rawCondition.Has("value") ? rawCondition["value"] : ""
    condition["type"] := conditionType
    switch conditionType {
      case "idle":
        condition["value"] := this._normalizeIntegerValue(rawValue, 0, 2147483647, path, "idle milliseconds", errors)
      case "window-exists", "window-active", "window-topmost":
        condition["value"] := Trim("" rawValue)
        if (condition["value"] = "")
          errors.Push(path " window selector cannot be empty")
      case "power-source":
        condition["value"] := StrLower(Trim("" rawValue))
        if (condition["value"] != "ac" && condition["value"] != "battery")
          errors.Push(path " power source must be ac or battery")
      case "battery-percent-at-most":
        condition["value"] := this._normalizeIntegerValue(rawValue, 0, 100, path, "battery percent", errors)
      case "battery-minutes-at-most":
        condition["value"] := this._normalizeIntegerValue(rawValue, 0, 10080, path, "battery minutes", errors)
      case "charging":
        condition["value"] := this._toBoolean(rawValue)
      case "or":
        condition["value"] := []
        if (!(rawValue is Array) || rawValue.Length = 0) {
          errors.Push(path " OR group must contain at least one condition")
        } else {
          for childIndex, childCondition in rawValue {
            childResult := this._normalizeCondition(childCondition, depth + 1, path ".OR[" childIndex "]")
            condition["value"].Push(childResult["condition"])
            for childError in childResult["errors"]
              errors.Push(childError)
          }
        }
      case "not":
        if (!(rawValue is Map)) {
          errors.Push(path " NOT group must contain one condition object")
          condition["value"] := Map("type", "", "value", "")
        } else {
          childResult := this._normalizeCondition(rawValue, depth + 1, path ".NOT")
          condition["value"] := childResult["condition"]
          for childError in childResult["errors"]
            errors.Push(childError)
        }
      default:
        errors.Push(path " has unsupported type: " conditionType)
    }
    return Map("condition", condition, "errors", errors)
  }

  static _normalizeIntegerValue(rawValue, minimumValue, maximumValue, path, label, errors) {
    if (!this._tryInteger(rawValue, &integerValue)) {
      errors.Push(path " " label " must be an integer")
      return 0
    }
    if (integerValue < minimumValue || integerValue > maximumValue)
      errors.Push(path " " label " must be between " minimumValue " and " maximumValue)
    return integerValue
  }

  static _toBoolean(value) {
    valueText := StrLower(Trim("" value))
    return value = true || valueText = "1" || valueText = "true"
  }

  static _tryInteger(value, &integerValue) {
    try {
      integerValue := Integer(value)
      return true
    } catch {
      integerValue := 0
      return false
    }
  }
}

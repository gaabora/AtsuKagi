class AutomationCron {
  static Parse(expression) {
    expressionText := Trim("" expression)
    fieldTexts := this._splitFields(expressionText)
    if (fieldTexts.Length != 5)
      throw Error("Cron schedule must contain five fields")

    fields := []
    fields.Push(this._parseField(fieldTexts[1], 0, 59, false, "minute"))
    fields.Push(this._parseField(fieldTexts[2], 0, 23, false, "hour"))
    fields.Push(this._parseField(fieldTexts[3], 1, 31, false, "day of month"))
    fields.Push(this._parseField(fieldTexts[4], 1, 12, false, "month"))
    fields.Push(this._parseField(fieldTexts[5], 0, 7, true, "weekday"))
    return Map("expression", expressionText, "fields", fields)
  }

  static Matches(timestamp, compiledExpression) {
    fields := compiledExpression["fields"]
    minute := Integer(SubStr(timestamp, 11, 2))
    hour := Integer(SubStr(timestamp, 9, 2))
    dayOfMonth := Integer(SubStr(timestamp, 7, 2))
    month := Integer(SubStr(timestamp, 5, 2))
    weekday := Integer(FormatTime(timestamp, "WDay")) - 1

    if (!fields[1]["values"].Has(minute) || !fields[2]["values"].Has(hour) || !fields[4]["values"].Has(month))
      return false

    dayOfMonthMatches := fields[3]["values"].Has(dayOfMonth)
    weekdayMatches := fields[5]["values"].Has(weekday)
    if (fields[3]["restricted"] && fields[5]["restricted"])
      return dayOfMonthMatches || weekdayMatches
    return dayOfMonthMatches && weekdayMatches
  }

  static Slot(timestamp) {
    return SubStr(timestamp, 1, 12)
  }

  static IsExpired(trigger, timestamp) {
    if (!trigger.Has("expires") || trigger["expires"] = "")
      return false
    expiresAt := StrReplace(trigger["expires"], "-") "235959"
    return DateDiff(timestamp, expiresAt, "Seconds") > 0
  }

  static FindLatestMatchBefore(compiledExpression, timestamp, earliestTimestamp) {
    candidateTimestamp := DateAdd(SubStr(timestamp, 1, 12) "00", -1, "Minutes")
    while (DateDiff(candidateTimestamp, earliestTimestamp, "Seconds") >= 0) {
      if (this.Matches(candidateTimestamp, compiledExpression))
        return candidateTimestamp
      candidateTimestamp := DateAdd(candidateTimestamp, -1, "Minutes")
    }
    return ""
  }

  static FindNextMatch(compiledExpression, timestamp, maximumMinutes:=527040) {
    candidateTimestamp := DateAdd(SubStr(timestamp, 1, 12) "00", 1, "Minutes")
    Loop maximumMinutes {
      if (this.Matches(candidateTimestamp, compiledExpression))
        return candidateTimestamp
      candidateTimestamp := DateAdd(candidateTimestamp, 1, "Minutes")
    }
    return ""
  }

  static ValidateExpiry(expiryDate) {
    expiryText := Trim("" expiryDate)
    if (!RegExMatch(expiryText, "^\d{4}-\d{2}-\d{2}$"))
      return false
    timestamp := StrReplace(expiryText, "-") "000000"
    try return FormatTime(timestamp, "yyyy-MM-dd") = expiryText
    catch
      return false
  }

  static _splitFields(expression) {
    fields := []
    for fieldText in StrSplit(expression, " `t") {
      if (fieldText != "")
        fields.Push(fieldText)
    }
    return fields
  }

  static _parseField(fieldText, minimumValue, maximumValue, normalizeSunday, fieldName) {
    fieldValueText := Trim("" fieldText)
    if (fieldValueText = "")
      throw Error("Cron " fieldName " field is empty")

    values := Map()
    for itemText in StrSplit(fieldValueText, ",")
      this._addItemValues(values, itemText, minimumValue, maximumValue, normalizeSunday, fieldName)
    if (values.Count = 0)
      throw Error("Cron " fieldName " field has no values")
    return Map("values", values, "restricted", fieldValueText != "*")
  }

  static _addItemValues(values, itemText, minimumValue, maximumValue, normalizeSunday, fieldName) {
    itemParts := StrSplit(Trim(itemText), "/")
    if (itemParts.Length > 2 || itemParts[1] = "")
      throw Error("Invalid cron " fieldName " item: " itemText)

    stepValue := 1
    if (itemParts.Length = 2) {
      if (!this._tryInteger(itemParts[2], &stepValue) || stepValue <= 0)
        throw Error("Invalid cron " fieldName " step: " itemText)
    }

    baseText := itemParts[1]
    if (baseText = "*") {
      rangeStart := minimumValue
      rangeEnd := maximumValue
    } else if (InStr(baseText, "-")) {
      rangeParts := StrSplit(baseText, "-")
      if (rangeParts.Length != 2 || !this._tryInteger(rangeParts[1], &rangeStart) || !this._tryInteger(rangeParts[2], &rangeEnd))
        throw Error("Invalid cron " fieldName " range: " itemText)
    } else {
      if (!this._tryInteger(baseText, &rangeStart))
        throw Error("Invalid cron " fieldName " value: " itemText)
      rangeEnd := itemParts.Length = 2 ? maximumValue : rangeStart
    }

    if (rangeStart < minimumValue || rangeEnd > maximumValue || rangeStart > rangeEnd)
      throw Error("Cron " fieldName " value is outside " minimumValue "-" maximumValue ": " itemText)

    currentValue := rangeStart
    while (currentValue <= rangeEnd) {
      normalizedValue := normalizeSunday && currentValue = 7 ? 0 : currentValue
      values[normalizedValue] := true
      currentValue += stepValue
    }
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

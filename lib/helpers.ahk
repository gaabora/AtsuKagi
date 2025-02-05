; OutputDebug(params*) {
;   tickCount := A_TickCount
;   text := ""
;   if (params.Length = 1) {
;     text := params[1]
;   } else {
;     sep := "`t"
;     for index,param in params
;       text .= param . sep
;   }
;   time := FormatTime(, "hh:mm:ss")
;   ms := Mod(tickCount, 1000)
;   text := time . "." . Format("{:03d}", ms) . ": " . text
;   OutputDebug(text)
; }

ArrayContains(Haystack, Needle) {
  for val in Haystack {
    if (Needle == val)
      return true
  }
  return false
}

GetWindowClass(hwnd:=0) {
  if (hwnd=0)
    hwnd := WinGetID("A")
  className := WinGetClass("ahk_id " hwnd)
  return className
}

ExtractHotkeyInfo(hotkeyString) {
  SPECIAL_REGEX := "(~|\$|\*)"
  MODIFIER_REGEX := "(<\^>!|<!|>!|<#|>#|<\^|>\^|<\+|>\+|!|#|\^|\+)"

  result := {}
  result.special := RegexMatchGlobal(hotkeyString, SPECIAL_REGEX)
  result.modifiers := RegexMatchGlobal(hotkeyString, MODIFIER_REGEX)
  result.customModifier := ""

  cleanedHotkey := hotkeyString
  for char in result.special
    cleanedHotkey := StrReplace(cleanedHotkey, char)
  for char in result.modifiers
    cleanedHotkey := StrReplace(cleanedHotkey, char)

  customCombination := StrSplit(cleanedHotkey, " & ")
  if (customCombination.Length = 2) {
    result.customModifier := customCombination[1]
    result.key := customCombination[2]
  } else {
    result.key := cleanedHotkey
  }

  return result
}

convertToReadableHotkey(KeyCombination) {
  static modMapping := Map(
    "<^>!", "AltGr + ",
    "<^", "LCtrl + ",
    ">^", "RCtrl + ",
    "^", "Ctrl + ",
    "<+", "LShift + ",
    ">+", "RShift + ",
    "+", "Shift + ",
    "<!", "LAlt + ",
    ">!", "RAlt + ",
    "!", "Alt + ",
    "<#", "LWin + ",
    ">#", "RWin + ",
    "#", "Win + ",
    "*", "[wildcard] ",
    "~", "[passthru] ",
  )

  k := ExtractHotkeyInfo(KeyCombination)

  modifiersStr := ""
  for _, modifier in k.special {

    modifiersStr .= modMapping[modifier]
  }
  for _, modifier in k.modifiers {

    modifiersStr .= modMapping[modifier]
  }
  keyName := k.key
  result := modifiersStr . (k.customModifier ? k.customModifier . " & " : "") . GetKeyName(keyName)
  return result

}

ConvertToUniversalVkHotkey(KeyCombination) {
  k := ExtractHotkeyInfo(KeyCombination)
  if (StrLen(k.key) = 1) {
    modifiersStr := ""
    for _, modifier in k.special
      modifiersStr .= modifier
    for _, modifier in k.modifiers
      modifiersStr .= modifier
    keyName := Format("vk{:X}", GetKeyVK(k.key))
    result := modifiersStr . (k.customModifier ? k.customModifier . " & " : "") . keyName
    return result
  }
  return KeyCombination
}

RegexMatchGlobal(Haystack, NeedleRegEx) {
  matches := []
  pos := 1
  while (pos <= StrLen(Haystack)) {
      if (match := RegExMatch(Haystack, NeedleRegEx, &matchObj, pos)) {
          matches.Push(matchObj[0])
          pos := match + StrLen(matchObj[0])
      } else {
          break
      }
  }
  return matches
}

FilterArray(sourceArr, filterVal) {
  resultArr := []
  for k, v in sourceArr
  {
    if (v != filterVal)
      resultArr.Push(v)
  }
  return resultArr
}

Join(arr, delimiter) {
; REMOVED:   SetBatchLines, -1 ; Disable line batch to ensure timely execution
  result := ""
  for index, element in arr
    result := result . (index > 1 ? delimiter : "") . element
  return result
}

IsValidHexColor(hexColor) {
  return RegExMatch(hexColor, "0x[0-9A-Fa-f]{6}") ? true : false
}



GetCurrentScreenBorders(&CurrentScreenLeft, &CurrentScreenRight, &CurrentScreenTop, &CurrentScreenBottom) {
  MouseGetPos(&xMouse, &yMouse)
  MonitorCount := MonitorGetCount()
  Loop MonitorCount {
    MonitorGetWorkArea(A_Index, &MonitorWorkAreaLeft, &MonitorWorkAreaTop, &MonitorWorkAreaRight, &MonitorWorkAreaBottom)
    if (xMouse >= MonitorWorkAreaLeft) AND (xMouse <= MonitorWorkAreaRight) AND ( yMouse >= MonitorWorkAreaTop) AND ( yMouse <= MonitorWorkAreaBottom) {
      CurrentScreenLeft   := MonitorWorkAreaLeft
      CurrentScreenRight  := MonitorWorkAreaRight
      CurrentScreenTop    := MonitorWorkAreaTop
      CurrentScreenBottom := MonitorWorkAreaBottom
      break
    }
  }
}


FormatBuffer(buf, groupBytes:=1) {
  static CRYPT_STRING_HEX := 0x40000000
  static CRYPT_STRING_NOCR := 0x00000004
  Local flags := CRYPT_STRING_HEX | CRYPT_STRING_NOCR
  Local binarySize := VarSetStrCapacity(&buf) ; V1toV2: if 'buf' is NOT a UTF-16 string, use 'buf := Buffer()'
  Local hexBufferSize := (binarySize * (flags ? 3 : 2)) * (1 ? 2 : 1)
  Local buffer := hexString := Buffer(hexBufferSize, 0) ; V1toV2: if 'hexString' is a UTF-16 string, use 'VarSetStrCapacity(&hexString, hexBufferSize)'
  
  DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", buf, "Int", binarySize, "Int", flags ? flags : 12, "Str", hexString, "UIntP", &hexBufferSize)

  if (groupBytes = 1)
    return hexString

  local pattern := "(.{" . 2 * groupBytes . "})"
  Local formattedHexString := RegExReplace(hexString, "\s")
  formattedHexString := RegExReplace(formattedHexString, pattern, "$1 ")
  return formattedHexString
}

FormatCamelCaseToSentence(text) {
  words := RegexMatchGlobal(text, "(([A-Z]?[a-z]+)|([A-Z]))")
  results := []
  abbr := ""
  for idx, word in words {
    if (StrLen(word) = 1) {
      abbr := abbr . word
    } else {
      if (StrLen(abbr)) {
        results.Push(Format("{:U}", abbr))
        abbr := ""
      }
      results.Push((idx = 1) ? Format("{:T}", word) : Format("{:L}", word))
    }
  }
  if (StrLen(abbr))
    results.Push(abbr)

  return Join(results, " ")
}
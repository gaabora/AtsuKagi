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

; Split a string by commas, but respect nested parentheses.
; e.g. "A, B(1, 2), C" => ["A", "B(1, 2)", "C"]
SplitRespectingParens(str) {
  result := []
  depth := 0
  current := ""
  Loop Parse, str {
    ch := A_LoopField
    if (ch = "(") {
      depth += 1
      current .= ch
    } else if (ch = ")") {
      depth -= 1
      current .= ch
    } else if (ch = "," && depth = 0) {
      result.Push(Trim(current))
      current := ""
    } else {
      current .= ch
    }
  }
  if (Trim(current) != "")
    result.Push(Trim(current))
  return result
}

GetWindowProcessName(hwnd:=0) {
  if (hwnd = 0)
    hwnd := WinGetID("A")
  try
    return WinGetProcessName("ahk_id " hwnd)
  catch
    return ""
}

GetWindowProcessPath(hwnd:=0) {
  if (hwnd = 0)
    hwnd := WinGetID("A")
  try
    return WinGetProcessPath("ahk_id " hwnd)
  catch
    return ""
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

DecToHex(decNumber) {
  return Format("{:04X}", decNumber)
}

IsValidHexColor(hexColor) {
  return RegExMatch(hexColor, "0x[0-9A-Fa-f]{6}") ? true : false
}

IsButtonPressed(buttonName) {
  return GetKeyState(buttonName, 'P') == 1
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

ReverseBuffer(buf) {
    newBuf := Buffer(buf.Size)
    Loop buf.Size {
      NumPut("UChar", NumGet(buf.Ptr + (buf.Size - A_Index), "UChar"), newBuf.Ptr + (A_Index - 1))
    }
    return newBuf
}

FormatBuffer(buf, groupBytes := 1) {
    static CRYPT_STRING_HEX := 0x40000000
    static CRYPT_STRING_NOCR := 0x00000004
    local flags := CRYPT_STRING_HEX | CRYPT_STRING_NOCR

    reBuf := ReverseBuffer(buf)
    local binarySize := reBuf.Size
    local hexBufferSize := (binarySize * 3 + 1) * 2 ; generous estimate for UTF-16 string
    local hexBuffer := Buffer(hexBufferSize, 0)
    
    ; Windows APIs use little-endian byte order, where the least significant byte comes first in memory
    ; so to have sane formatted output we reverse buffer
    DllCall("Crypt32.dll\CryptBinaryToStringW",
      "Ptr", reBuf,
      "UInt", binarySize,
      "UInt", flags,
      "Ptr", hexBuffer.Ptr,
      "UIntP", &hexBufferSize,
    )
    
    local hexString := StrGet(hexBuffer, hexBufferSize, "UTF-16")

    if (groupBytes = 1)
      return hexString

    local pattern := "(.{" . 2 * groupBytes . "})"
    hexString := RegExReplace(hexString, "\s") ; remove any spaces (shouldn't be there though)
    return RegExReplace(hexString, pattern, "$1 ")
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

AK_JsonEscape(text) {
  escaped := "" text
  escaped := StrReplace(escaped, "\\", "\\\\")
  escaped := StrReplace(escaped, '"', '\"')
  escaped := StrReplace(escaped, "`r", "\\r")
  escaped := StrReplace(escaped, "`n", "\\n")
  escaped := StrReplace(escaped, "`t", "\\t")
  return escaped
}

AK_ToJson(value) {
  if (value is Array) {
    parts := ""
    for item in value
      parts .= AK_ToJson(item) ","
    return "[" RTrim(parts, ",") "]"
  }

  if (value is Map) {
    parts := ""
    for key, item in value
      parts .= '"' AK_JsonEscape("" key) '":' AK_ToJson(item) ","
    return "{" RTrim(parts, ",") "}"
  }

  if (value is Integer || value is Float)
    return "" value

  if (!IsObject(value))
    return '"' AK_JsonEscape(value) '"'

  try {
    parts := ""
    for key, item in value.OwnProps()
      parts .= '"' AK_JsonEscape("" key) '":' AK_ToJson(item) ","
    return "{" RTrim(parts, ",") "}"
  } catch {
    return "null"
  }
}

AK_JsonParse(jsonText) {
  parser := AK_JsonParser(jsonText)
  return parser.Parse()
}

class AK_JsonParser {
  __New(text) {
    this.text := "" text
    this.len := StrLen(this.text)
    this.pos := 1
  }

  Parse() {
    value := this._parseValue()
    this._skipWhitespace()
    if (this.pos <= this.len)
      throw Error("Unexpected trailing JSON at position " this.pos)
    return value
  }

  _parseValue() {
    this._skipWhitespace()
    ch := this._peek()
    if (ch = "")
      throw Error("Unexpected end of JSON")

    if (ch = "{")
      return this._parseObject()
    if (ch = "[")
      return this._parseArray()
    if (ch = '"')
      return this._parseString()
    if (ch = "t") {
      this._expectWord("true")
      return true
    }
    if (ch = "f") {
      this._expectWord("false")
      return false
    }
    if (ch = "n") {
      this._expectWord("null")
      return ""
    }
    return this._parseNumber()
  }

  _parseObject() {
    obj := Map()
    this._expectChar("{")
    this._skipWhitespace()
    if (this._peek() = "}") {
      this.pos += 1
      return obj
    }

    loop {
      this._skipWhitespace()
      key := this._parseString()
      this._skipWhitespace()
      this._expectChar(":")
      value := this._parseValue()
      obj[key] := value
      this._skipWhitespace()
      ch := this._peek()
      if (ch = "}") {
        this.pos += 1
        break
      }
      this._expectChar(",")
    }
    return obj
  }

  _parseArray() {
    arr := []
    this._expectChar("[")
    this._skipWhitespace()
    if (this._peek() = "]") {
      this.pos += 1
      return arr
    }

    loop {
      arr.Push(this._parseValue())
      this._skipWhitespace()
      ch := this._peek()
      if (ch = "]") {
        this.pos += 1
        break
      }
      this._expectChar(",")
    }
    return arr
  }

  _parseString() {
    this._expectChar('"')
    out := ""
    while (this.pos <= this.len) {
      ch := SubStr(this.text, this.pos, 1)
      this.pos += 1
      if (ch = '"')
        return out

      if (ch = "\\") {
        if (this.pos > this.len)
          throw Error("Invalid escape at end of JSON string")
        esc := SubStr(this.text, this.pos, 1)
        this.pos += 1
        if (esc = '"')
          out .= '"'
        else if (esc = "\\")
          out .= "\\"
        else if (esc = "/")
          out .= "/"
        else if (esc = "b")
          out .= Chr(8)
        else if (esc = "f")
          out .= Chr(12)
        else if (esc = "n")
          out .= "`n"
        else if (esc = "r")
          out .= "`r"
        else if (esc = "t")
          out .= "`t"
        else if (esc = "u") {
          if (this.pos + 3 > this.len)
            throw Error("Invalid unicode escape sequence")
          hex := SubStr(this.text, this.pos, 4)
          if (!RegExMatch(hex, "i)^[0-9a-f]{4}$"))
            throw Error("Invalid unicode escape sequence: " hex)
          out .= Chr("0x" hex)
          this.pos += 4
        } else {
          throw Error("Unsupported escape sequence: \\" esc)
        }
      } else {
        out .= ch
      }
    }
    throw Error("Unterminated JSON string")
  }

  _parseNumber() {
    token := SubStr(this.text, this.pos)
    if (!RegExMatch(token, "^-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?", &m))
      throw Error("Invalid JSON number at position " this.pos)
    raw := m[0]
    this.pos += StrLen(raw)
    if (InStr(raw, ".") || InStr(raw, "e") || InStr(raw, "E"))
      return Number(raw)
    return Integer(raw)
  }

  _skipWhitespace() {
    while (this.pos <= this.len) {
      ch := SubStr(this.text, this.pos, 1)
      if (ch = " " || ch = "`t" || ch = "`n" || ch = "`r")
        this.pos += 1
      else
        break
    }
  }

  _peek() {
    return (this.pos <= this.len) ? SubStr(this.text, this.pos, 1) : ""
  }

  _expectChar(ch) {
    got := this._peek()
    if (got != ch)
      throw Error("Expected '" ch "' at position " this.pos ", got '" got "'")
    this.pos += 1
  }

  _expectWord(word) {
    got := SubStr(this.text, this.pos, StrLen(word))
    if (got != word)
      throw Error("Expected '" word "' at position " this.pos)
    this.pos += StrLen(word)
  }
}

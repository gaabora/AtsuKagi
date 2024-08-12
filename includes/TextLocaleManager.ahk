class TextLocaleManager extends AKPlugin {
  __UsageHelp() {
    return ""
  }

  __ActionsHelp() {
    texts := Map()
    texts["IsTextSelectCursor"] := "IsTextSelectCursor()"

    return texts
  }

 ; Function to check if the cursor is in text selection mode
  IsTextSelectCursor() { ;;;
    ; Constants for cursor types
    OCR_IBEAM := 32513  ; I-beam cursor

    ; Struct to hold cursor information
    VarSetStrCapacity(cursorInfo, 20)
    NumPut(20, cursorInfo, 0, "UInt")  ; cbSize
    ; Call GetCursorInfo to get cursor information
    if (DllCall("GetCursorInfo", "UInt", &cursorInfo)) {
        cursorType := NumGet(cursorInfo, 8, "UInt")
        ; Check if the cursor type is OCR_IBEAM
        return (cursorType = OCR_IBEAM)
    }
    return false
  }

  ; Example usage
  SetTimer, CheckCursor, 1000  ; Check every 1 second
  return

  CheckCursor:
  if (IsTextSelectCursor()) {
    MsgBox, The cursor is in text selection mode!
  } else {
    MsgBox, The cursor is not in text selection mode.
  }
  return

}
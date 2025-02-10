_getLastWord() {
    ; TODO BlacklistCtrlCHotkeyWindowClasses
    DEBUG_TIMEOUT := 300

    selectedText := ''

    clipboardBackup := ClipboardAll() 
    A_Clipboard := ''

    Loop 10 {
      SendInput(this.HOTKEY_CTRL_SHIFT_LEFT)
      OutputDebug('SELECT_WORD_LEFT `n')
      sleep(DEBUG_TIMEOUT)

      SendInput(this.HOTKEY_CTRL_C)
      OutputDebug('COPY `n')
      sleep(DEBUG_TIMEOUT)

      if (!ClipWait(1)) {
        OutputDebug("No text found on attempt " A_Index . '`n')
        break
      }

      if RegExMatch(A_Clipboard, "([ \t])", &Found) && A_Index != 1 {
        SendInput(this.HOTKEY_CTRL_SHIFT_RIGHT)
        OutputDebug('SELECT_WORD_RIGHT `n')
        sleep(DEBUG_TIMEOUT)

        clippedText := SubStr(A_Clipboard, (Found.Pos[1] + 1) < 1 ? (Found.Pos[1] + 1) - 1 : (Found.Pos[1] + 1))
        OutputDebug("Returning clipped text after matching space/tab: " clippedText . '`n')
        selectedText := clippedText
        break
      }

      prevClipboard := A_Clipboard
      A_Clipboard := ''
      SendInput(this.HOTKEY_SHIFT_LEFT)
      OutputDebug('SELECT_SYMBOL_LEFT `n')
      sleep(DEBUG_TIMEOUT)

      SendInput(this.HOTKEY_CTRL_C)
      OutputDebug('COPY `n')
      sleep(DEBUG_TIMEOUT)

      if (!ClipWait(1)) {
        OutputDebug("Error waiting for clipboard after shift left on attempt " A_Index . '`n')
        break
      }

      if (StrLen(A_Clipboard) = StrLen(prevClipboard)) {
        A_Clipboard := ''
        SendInput(this.HOTKEY_SHIFT_LEFT)
        OutputDebug('SELECT_SYMBOL_LEFT `n')
        sleep(DEBUG_TIMEOUT)

        SendInput(this.HOTKEY_CTRL_C)
        OutputDebug('COPY `n')
        sleep(DEBUG_TIMEOUT)

        if (!ClipWait(1)) {
          OutputDebug("Error waiting for clipboard after another shift left on attempt " A_Index . '`n')
          break
        }

        if (StrLen(A_Clipboard) = StrLen(prevClipboard)) {
          OutputDebug("Returning clipboard after matching lengths: " A_Clipboard . '`n')
          selectedText := A_Clipboard
          break
        } else {
          SendInput(this.HOTKEY_Shift_RIGHT)
          OutputDebug('SELECT_SYMBOL_RIGHT `n')
          sleep(DEBUG_TIMEOUT)

          SendInput(this.HOTKEY_Shift_RIGHT)
          OutputDebug('SELECT_SYMBOL_RIGHT `n')
          sleep(DEBUG_TIMEOUT)

          OutputDebug("Returning previous clipboard after shift right: " prevClipboard . '`n')
          selectedText := prevClipboard
          break
        }
      }

      SendInput(this.HOTKEY_Shift_RIGHT)
      OutputDebug('SELECT_SYMBOL_RIGHT `n')
      sleep(DEBUG_TIMEOUT)

      s := SubStr(A_Clipboard, 1, 1)
      
      if (s ~= "^(?i:" RegExReplace(RegExReplace(" ,`t,`n,`r", "[\\\.\*\?\+\[\{\|\(\)\^\$]", "\$0"), "\s*,\s*", "|") ")$") {
        A_Clipboard := ''
        SendInput(this.HOTKEY_SHIFT_LEFT)
        OutputDebug('SELECT_SYMBOL_LEFT `n')
        sleep(DEBUG_TIMEOUT)

        SendInput(this.HOTKEY_CTRL_C)
        OutputDebug('COPY `n')
        sleep(DEBUG_TIMEOUT)

        if (!ClipWait(1)) {
          OutputDebug("Error waiting for clipboard after regex match on attempt " A_Index . '`n')
          break
        }
        OutputDebug("Returning clipboard after regex match: " A_Clipboard . '`n')
        selectedText := A_Clipboard
        break
      }

      A_Clipboard := ''
    }

    A_Clipboard := clipboardBackup
    
    return selectedText
  }
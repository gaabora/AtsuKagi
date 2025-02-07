class TextLocaleManager extends AKPlugin {
  KEY_MAPPING_DICT := Map()
  USER_KEYBOARD_LAYOUTS := []

  HOTKEY_CTRL_C := '^{vk43}'
  HOTKEY_CTRL_X := '^{vk58}'
  HOTKEY_CTRL_V := '^{vk56}'
  HOTKEY_SHIFT_LEFT := '+{Left}'
  HOTKEY_Shift_RIGHT := '+{Right}'
  HOTKEY_CTRL_SHIFT_LEFT := '^+{Left}'
  HOTKEY_CTRL_SHIFT_RIGHT := '^+{Right}'

  __UsageHelp() {
    return ''
  }

  __ActionsHelp() {
    texts := Map()
    texts["SwapTextLayout"]               := "SwapTextLayout(incorrectText, layoutA, layoutB)"
    texts["ShowCurrentKeyboardLayout"]    := "ShowCurrentKeyboardLayout()"
    texts["ShowUsersKeyboardLayouts"]     := "ShowUsersKeyboardLayouts()"
    texts["GetCurrentKeyboardLayoutName"] := "GetCurrentKeyboardLayoutName()"
    texts["SwitchKeyboardLayout"]         := "SwitchKeyboardLayout(layoutNameOrId:='')"
    texts["SwitchSelectedTextLayout"]     := "SwitchSelectedTextLayout(layoutA, layoutB)"
    texts["SwitchSelectedTextCase"]       := "SwitchSelectedTextCase()"
    return texts
  }
  ProcessBlacklistConfig() {
    
  }
  ProcessPluginConfig() {
   if (!this.Config.Has("BlacklistCtrlCHotkeyWindowClasses"))
      this.Config.BlacklistCtrlCHotkeyWindowClasses := 'ConsoleWindowClass,PuTTY'
  }

  __New() {
    this.KEY_MAPPING_DICT['EN-RU'] := Map()
    
    ; Groups prioritize layout detection by certainty:
    ; - The first group contains unique symbols highly indicative of the layout (e.g., '~', '#', 'Q', 'W' for EN).
    ; - The next groups include symbols that help distinguish layouts but with decreasing certainty (e.g., 'Ж', 'Э' for RU).
    ; - Groups are ordered from most to least reliable, allowing fast, accurate layout detection with minimal comparisons.
    this.KEY_MAPPING_DICT['EN-RU']['EN'] := ["~#QWERTYUIOP{}ASDFGHJKLZXCVBNM<>``qwertyuiop[]asdfghjkl'zxcvbnm", ':";,.', '@$^&|', '?/']
    this.KEY_MAPPING_DICT['EN-RU']['RU'] := ["Ё№ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЯЧСМИТЬБЮёйцукенгшщзхъфывапролдэячсмить",  'ЖЭжбю', '";:?/', ',.']

    this.WHITESPACE_SYMBOLS := " `t`n"

    this.USER_KEYBOARD_LAYOUTS := this._getUsersKeyboardLayouts()
  }

  SwapTextLayout(incorrectText, layoutA, layoutB) { ;;;
    oldLayout := ''
    newLayout := ''
    newText := ''

    Loop Parse, incorrectText
    {
      currentSymbol := A_LoopField

      if (newLayout = '') {
        newLayout := this._detectLayout(currentSymbol, layoutA, layoutB)
      }

      if (newLayout = layoutA) {
        oldLayout := layoutB
        convertedSymbol := this._convertSymbol(currentSymbol, oldLayout, newLayout)
        if (convertedSymbol = currentSymbol) {
          convertedSymbol := this._convertSymbol(currentSymbol, newLayout, oldLayout)
          if (convertedSymbol != currentSymbol) {
            newLayout := oldLayout
          }
        }
        newText .= convertedSymbol
      } else if (newLayout = layoutB) {
        oldLayout := layoutA
        convertedSymbol := this._convertSymbol(currentSymbol, oldLayout, newLayout)
        if (convertedSymbol = currentSymbol) {
          convertedSymbol := this._convertSymbol(currentSymbol, newLayout, oldLayout)
          if (convertedSymbol != currentSymbol) {
            newLayout := oldLayout
          }
        }
        newText .= convertedSymbol
      } else {
        newText .= currentSymbol
      }

    }

    return {newText: newText, newLayout: newLayout}
  }

  ShowCurrentKeyboardLayout() { ;;;
    MouseGetPos(&x, &y)
    offset := 12
    this.ToolTip(this.GetCurrentKeyboardLayoutName(), offset + x, offset + y)
  }

  ShowUsersKeyboardLayouts() { ;;;
    outputText := ''
    for (layoutData in this._getUsersKeyboardLayouts()) {
      outputText .= layoutData.name . ' (' . layoutData.alias . ' ' . layoutData.value . ')`n'
    }
    this.ShowInfo(outputText)
  }

  GetCurrentKeyboardLayoutName() { ;;;
    return INPUT_LOCALES.GetKeyboardLayoutName(this._getKeyboardLayoutCode())
  }

  SwitchKeyboardLayout(layoutNameOrId:='') { ;;;
    static WM_INPUTLANGCHANGEREQUEST := 0x50
    static INPUTLANGCHANGE_SYSCHARSET := 1

    layoutId := (IsNumber(layoutNameOrId)) ? layoutNameOrId : INPUT_LOCALES.GetLayoutCodeNumber(layoutNameOrId)
    layoutName := INPUT_LOCALES.GetKeyboardLayoutName(layoutId)
    if (layoutId != INPUT_LOCALES._NEXT && !this._isLayoutValid(layoutId))
      throw TypeError('Keyboard layout ' . layoutNameOrId . ' is not valid or was not added for current user')

    hwnd := ControlGetFocus("A") || WinExist("A")

    SendMessage(WM_INPUTLANGCHANGEREQUEST, INPUTLANGCHANGE_SYSCHARSET, layoutId,, hwnd)

    this.ShowCurrentKeyboardLayout()
  }

  SwitchSelectedTextLayout(layoutA, layoutB) { ;;;
    selectedText := this._getSelectedText() 
    converted := this.SwapTextLayout(selectedText, layoutA, layoutB)

    OutputDebug('selectedText' . selectedText . '`n')
    OutputDebug('newText' . converted.newText . '`n')
    OutputDebug('newLayout' . converted.newLayout . '`n')

    this._putText(converted.newText)

    this.SwitchKeyboardLayout(converted.newLayout)
  }

  SwitchSelectedTextCase() { ;;;
    textCase := Menu()
    ; TODO: refactor to support translations
    textCase.Add("&UPPERCASE", ChangeCaseMenuHandler)
    textCase.Add("&lowercase", ChangeCaseMenuHandler)
    textCase.Add("&Title Case", ChangeCaseMenuHandler)
    textCase.Add("&Sentence case", ChangeCaseMenuHandler)
    textCase.Add()
    textCase.Add("&Windows linebreaks", ChangeCaseMenuHandler)
    textCase.Add("&Unix linebreaks", ChangeCaseMenuHandler)
    textCase.Add("Remove &duplicating spaces", ChangeCaseMenuHandler)
    textCase.Add("Remove traili&ng whitespace", ChangeCaseMenuHandler)
    textCase.Add("&Whitespace mess > single space", ChangeCaseMenuHandler)
    textCase.Add()
    textCase.Add("Re&verse", ChangeCaseMenuHandler)

    selectedText := this._getSelectedText()
    changedText := selectedText
    
    textCase.Show()

    ReplaceUsingMapping(replaceMap, text) {
      changedText := text
      for search, replace in replaceMap {
        Loop {
          changedText := StrReplace(changedText, search, replace, , &replacedCount)
          if (replacedCount = 0 || changedText = text)
            break
        }
      }
      return changedText
    }

    ChangeCaseMenuHandler(itemName, itemIdx, opts*) {
      ; TODO: refactor based on CHANGE_CASE (make port of node CHANGE-CASE)
      switch (itemName) {
        case "&UPPERCASE":
          changedText := StrUpper(selectedText)

        case "&lowercase":
          changedText := StrLower(changedText)

        case "&Title Case":
          changedText := StrTitle(changedText)

        case "&Sentence case":
          changedText := StrLower(changedText)
          Loop {
            changedText := RegExReplace(changedText, "((?:^|[.!?]\s+)[a-z])", "$u1", &replacedCount)
            if (replacedCount = 0)
              break 
          }

        case "&Windows linebreaks":
          changedText := RegExReplace(changedText, '\R', '`r`n', &replacedCount)

        case "&Unix linebreaks":
          changedText := RegExReplace(changedText, '\R', '`n', &replacedCount)

        case "Remove &duplicating spaces":
          Loop {
            changedText := StrReplace(changedText, '  ', ' ',, &replacedCount)
            if (replacedCount = 0)
              break 
          }

        case "Remove traili&ng whitespace":
          replaceMap := Map(' `r`n', '`r`n', ' `n', '`n', '`t`r`n', '`r`n', '`t`n', '`n')
          changedText := ReplaceUsingMapping(replaceMap, changedText)

        case "&Whitespace mess > single space":
          replaceMap := Map('`t', ' ', '  ', ' ')
          changedText := ReplaceUsingMapping(replaceMap, changedText)

        case "Re&verse":
          tempText := ''
          changedText := StrReplace(changedText, "`r`n", Chr(29))
          Loop Parse, changedText
            tempText := A_LoopField . tempText
          changedText := StrReplace(tempText, Chr(29), "`r`n")
  
        default:
          throw Error('Unregistered itemName: ' . itemName)
      }
      this._putText(changedText)
    }
  }

  _getSelectedText() {
    ; TODO BlacklistCtrlCHotkeyWindowClasses

    clipboardBackup := ClipboardAll()
    A_Clipboard := ''
    SendInput(this.HOTKEY_CTRL_C)
    selectedText := (ClipWait(1) && A_Clipboard != '')
      ? A_Clipboard
      : ''
    A_Clipboard := clipboardBackup
    return selectedText
  }

  _putText(text) {
    clipboardBackup := ClipboardAll() 
    Sleep(20)
    A_Clipboard := text
    Send(this.HOTKEY_CTRL_V)
    Sleep(100)
    A_Clipboard := clipboardBackup
  }

  _getHeyMapDict(layoutA, layoutB) {
    combA := layoutA . '-' . layoutB
    if (this.KEY_MAPPING_DICT.Has(combA))
      return this.KEY_MAPPING_DICT[combA]
    combB := layoutB . '-' . layoutA
    if (this.KEY_MAPPING_DICT.Has(combB))
      return this.KEY_MAPPING_DICT[combB]
    throw Error('No key mapping dictionaries found for layouts combinations ' . combA . ', ' . combB)
  }

  _detectLayout(currentSymbol, layoutA, layoutB) {
    keyMapDict := this._getHeyMapDict(layoutA, layoutB)

    for (idx, fromGroup in keyMapDict[layoutA]) {
        if (InStr(keyMapDict[layoutA][idx], currentSymbol, true)) {
            return layoutB
        }
        if (InStr(keyMapDict[layoutB][idx], currentSymbol, true)) {
            return layoutA
        }
    }
  }

  _isLayoutValid(layoutId) {
    for (layoutData in this._getUsersKeyboardLayouts()) {
      if (layoutData.value = layoutId)
        return true
    }
    return false
  }
  
  _getUsersKeyboardLayouts() {
    keyboardLayouts := []
    Loop Reg, "HKCU\Keyboard Layout\Preload", "R KV" ; recursively keys+values
    {
      if (A_LoopRegType != "key") {
        value := RegRead()
        if (value != "") {
          alias := '0x' . value
          intValue := Integer(alias)
          name := INPUT_LOCALES.GetKeyboardLayoutName(intValue)
          keyboardLayouts.Push({ alias: alias, name: name, value: intValue })
        }
      }
    }
    return keyboardLayouts
  }

  _convertSymbol(currentSymbol, fromLayout, toLayout) {
    keyMapDict := this._getHeyMapDict(fromLayout, toLayout)
    for (idx, fromGroup in keyMapDict[fromLayout]) {
      dictIdx := InStr(fromGroup, currentSymbol, true)
      if (dictIdx > 0) {
        return SubStr(keyMapDict[toLayout][idx], dictIdx, 1)
      }
    }
    return currentSymbol
  }

  _getKeyboardLayoutCode() {
    activeWindow := WinExist("A")
    threadId := DllCall("User32.dll\GetWindowThreadProcessId", "Ptr", activeWindow, "Ptr", 0, "UInt")
    codeNumber := DllCall("User32.dll\GetKeyboardLayout", "UInt", threadId, "Ptr")
    return codeNumber
  }
}

class INPUT_LOCALES {
  static _NEXT := 0x0
  static LAYOUTS := { 
    ; https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11
    ; TODO Add more cases for other layouts
    CHN: 0x0404,
    ENG: 0x0409,
    FIN: 0x040b,
    FRA: 0x040c,
    GER: 0x0407, 
    ITA: 0x0410,
    JAP: 0x0411,
    KOR: 0x0412,
    RUS: 0x0419,
    SPA: 0x0c0a 
  }

  static GetLayoutCodeNumber(layoutName) {
    try {
      return INPUT_LOCALES.LAYOUTS.%layoutName%
    } catch {
      return INPUT_LOCALES._NEXT
    }
  }

  static GetKeyboardLayoutName(layoutCodeNumber) {
    layoutCodeNumberMaskedLow16Bits := layoutCodeNumber & 0xFFFF
    for name, code in INPUT_LOCALES.LAYOUTS.OwnProps() {
      if (code = layoutCodeNumberMaskedLow16Bits)
        return name
    }
    return Format("0x{:x}", layoutCodeNumber)
  }
}

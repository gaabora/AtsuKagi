class TextLocaleManager extends AKPlugin { ; TODO: needs review, maybe some fixes
  KEY_MAPPING_DICT := Map()
  USER_KEYBOARD_LAYOUTS := []
  SUPPORTED_USER_LAYOUTS := Map()
  SUPPORTED_LAYOUT_PAIRS := []
  TEXT_LAYOUT_ALIASES := Map("EN", "EN", "ENG", "EN", "RU", "RU", "RUS", "RU")
  SUPPORTED_TEXT_LAYOUT_KLIDS := Map("EN", Map("00000409", true), "RU", Map("00000419", true))
  IMPLICIT_LINE_COPY_PROCESSES := Map("Code.exe", true, "Code - Insiders.exe", true, "VSCodium.exe", true, "Cursor.exe", true) ; TODO: make configurable by using some named blocklist with simple understandable description

  HOTKEY_CTRL_C := '^{vk43}'
  HOTKEY_CTRL_X := '^{vk58}'
  HOTKEY_CTRL_V := '^{vk56}'
  HOTKEY_SHIFT_LEFT := '+{Left}'
  HOTKEY_Shift_RIGHT := '+{Right}'
  HOTKEY_CTRL_SHIFT_LEFT := '^+{Left}'
  HOTKEY_CTRL_SHIFT_RIGHT := '^+{Right}'

  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "TextLocaleManager",
        "title", "Text Locale Manager",
        "description", "Manage multiple keyboard layouts: detect current layout, switch layouts, fix mistyped text between layouts",
        "category", "Input Management"
      ),
      "page", Map(
        "description", "Configure keyboard layout switching and text conversion",
        "icon", "icons10-translation"
      ),
      "config", [],
      "actions", [
        Map(
          "action", "ShowCurrentKeyboardLayout",
          "label", "Show current keyboard layout",
          "description", "Display the name of the currently active keyboard layout",
          "params", [],
          "category", "Layout Management"
        ),
        Map(
          "action", "ShowUsersKeyboardLayouts",
          "label", "Show user's keyboard layouts",
          "description", "Display all keyboard layouts installed for the current user",
          "params", [],
          "category", "Layout Management"
        ),
        Map(
          "action", "GetCurrentKeyboardLayoutName",
          "label", "Get current keyboard layout name",
          "description", "Return the name of the currently active keyboard layout",
          "params", [],
          "category", "Layout Management"
        ),
        Map(
          "action", "SwitchKeyboardLayout",
          "label", "Switch keyboard layout",
          "description", "Switch to a specified keyboard layout by name or ID",
          "params", ["layoutNameOrId"],
          "category", "Layout Management"
        ),
        Map(
          "action", "SwapTextLayout",
          "label", "Swap text layout",
          "description", "Convert text from one keyboard layout to another (e.g., EN to RU)",
          "params", [Map("name", "incorrectText"), Map("name", "layoutA"), Map("name", "layoutB")],
          "category", "Text Conversion"
        ),
        Map(
          "action", "SwitchSelectedTextLayout",
          "label", "Switch selected text layout",
          "description", "Fix mistyped selected text by converting between two keyboard layouts",
          "params", [Map("name", "layoutA", "default", ""), Map("name", "layoutB", "default", "")],
          "category", "Text Conversion"
        ),
        Map(
          "action", "SwitchSelectedTextCase",
          "label", "Switch selected text case",
          "description", "Change case of selected text (uppercase, lowercase, title case, etc.)",
          "params", [],
          "category", "Text Conversion"
        )
      ],
      "hooks", []
    )
  }

  _processPluginConfig() {
    ; Apply descriptor defaults, then any additional processing if needed
    this.__ApplyDefaultConfig()
  }

  _init() {

    this.KEY_MAPPING_DICT['EN-RU'] := Map()
    
    ; Groups prioritize layout detection by certainty:
    ; - The first group contains unique symbols highly indicative of the layout (e.g., '~', '#', 'Q', 'W' for EN).
    ; - The next groups include symbols that help distinguish layouts but with decreasing certainty (e.g., 'Ж', 'Э' for RU).
    ; - Groups are ordered from most to least reliable, allowing fast, accurate layout detection with minimal comparisons.
    this.KEY_MAPPING_DICT['EN-RU']['EN'] := ["~#QWERTYUIOP{}ASDFGHJKLZXCVBNM<>``qwertyuiop[]asdfghjkl'zxcvbnm", ':";,.', '@$^&|', '?/']
    this.KEY_MAPPING_DICT['EN-RU']['RU'] := ["Ё№ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЯЧСМИТЬБЮёйцукенгшщзхъфывапролдэячсмить",  'ЖЭжбю', '";:?/', ',.']

    this.WHITESPACE_SYMBOLS := " `t`n"

    this.USER_KEYBOARD_LAYOUTS := this._getUsersKeyboardLayouts()
    this._refreshSupportedLayoutPairs()
  }

  SwapTextLayout(incorrectText, layoutA, layoutB) { ;;;
    layoutA := this._resolveTextLayoutName(layoutA)
    layoutB := this._resolveTextLayoutName(layoutB)
    oldLayout := ''
    newLayout := this._detectLayout(incorrectText, layoutA, layoutB)
    newText := ''

    if (newLayout = '')
      return {newText: incorrectText, newLayout: ''}

    Loop Parse, incorrectText
    {
      currentSymbol := A_LoopField

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
      textLayoutName := this._resolveInstalledTextLayoutName(layoutData)
      supportText := (textLayoutName != '') ? 'supported as ' . textLayoutName : 'unsupported'
      outputText .= layoutData.name . ' (' . layoutData.alias . ' ' . layoutData.value . ') - ' . supportText . '`n'
    }
    this.ShowInfo(outputText)
  }

  GetCurrentKeyboardLayoutName() { ;;;
    return INPUT_LOCALES.GetKeyboardLayoutName(this._getKeyboardLayoutCode())
  }

  SwitchKeyboardLayout(layoutNameOrId:='') { ;;;
    targetHwnd := this._getKeyboardLayoutTargetHwnd()
    isNextLayout := !IsNumber(layoutNameOrId) && Trim("" layoutNameOrId) = ""
    if (isNextLayout) {
      this._requestKeyboardLayout(0, KeyboardInputFlags.INPUTLANGCHANGE_FORWARD, targetHwnd)
    } else {
      layoutData := this._resolveInstalledKeyboardLayout(layoutNameOrId)
      if (!layoutData)
        throw TypeError('Keyboard layout ' . layoutNameOrId . ' is not valid or was not added for current user')
      this._requestKeyboardLayout(layoutData.hkl, KeyboardInputFlags.INPUTLANGCHANGE_SYSCHARSET, targetHwnd)
    }

    this.ShowCurrentKeyboardLayout()
  }

  SwitchSelectedTextLayout(params*) { ;;;
    layoutPair := this._getTextLayoutPair(params*)
    if (!layoutPair)
      return

    selectedText := this._getSelectedText()
    if (selectedText = '')
      return

    converted := this.SwapTextLayout(selectedText, layoutPair.layoutA, layoutPair.layoutB)
    if (converted.newLayout = '' || converted.newText = selectedText)
      return

    targetLayoutData := this._getPairLayoutData(layoutPair, converted.newLayout)
    if (!targetLayoutData || !targetLayoutData.hkl)
      return

    targetHwnd := this._getKeyboardLayoutTargetHwnd()
    this._putText(converted.newText)
    this._requestKeyboardLayout(targetLayoutData.hkl, KeyboardInputFlags.INPUTLANGCHANGE_SYSCHARSET, targetHwnd)
    this.ShowCurrentKeyboardLayout()
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
    ; Check named blocklist for windows where Ctrl+C should not be sent
    MouseGetPos(,, &hwnd)
    if (this.IsInBlocklist('NoCtrlCHotkey', hwnd)) {
      this.outputDebugLine(AKBase.LOG_NOTICE, '_getSelectedText: skipped Ctrl+C for blocklisted window')
      return ''
    }

    clipboardBackup := ClipboardAll()
    A_Clipboard := ''
    SendInput(this.HOTKEY_CTRL_C)
    selectedText := (ClipWait(1) && A_Clipboard != '')
      ? A_Clipboard
      : ''
    A_Clipboard := clipboardBackup
    if (selectedText != '' && this._isLikelyImplicitLineCopy(selectedText))
      return ''
    return selectedText
  }

  _isLikelyImplicitLineCopy(text, processName := '') {
    text := "" text
    if (!RegExMatch(text, "^[^\r\n]*\R$"))
      return false
    processName := Trim("" processName)
    if (processName = '') {
      try processName := WinGetProcessName("A")
      catch {
        processName := ''
      }
    }
    return processName != '' && this.IMPLICIT_LINE_COPY_PROCESSES.Has(processName)
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
    layoutA := this._resolveTextLayoutName(layoutA)
    layoutB := this._resolveTextLayoutName(layoutB)
    combA := layoutA . '-' . layoutB
    if (this.KEY_MAPPING_DICT.Has(combA))
      return this.KEY_MAPPING_DICT[combA]
    combB := layoutB . '-' . layoutA
    if (this.KEY_MAPPING_DICT.Has(combB))
      return this.KEY_MAPPING_DICT[combB]
    throw Error('No key mapping dictionaries found for layouts combinations ' . combA . ', ' . combB)
  }

  _detectLayout(text, layoutA, layoutB) {
    layoutA := this._resolveTextLayoutName(layoutA)
    layoutB := this._resolveTextLayoutName(layoutB)
    keyMapDict := this._getHeyMapDict(layoutA, layoutB)

    Loop Parse, text
    {
      currentSymbol := A_LoopField
      symbolLayout := this._getSymbolTextLayout(currentSymbol, keyMapDict, layoutA, layoutB)
      if (symbolLayout = layoutA)
        return layoutB
      if (symbolLayout = layoutB)
        return layoutA
    }
    return ''
  }

  _getSymbolTextLayout(symbol, keyMapDict, layoutA, layoutB) {
    isInLayoutA := this._isSymbolInTextLayout(symbol, keyMapDict[layoutA])
    isInLayoutB := this._isSymbolInTextLayout(symbol, keyMapDict[layoutB])
    if (isInLayoutA = isInLayoutB)
      return ''
    return isInLayoutA ? layoutA : layoutB
  }

  _isSymbolInTextLayout(symbol, layoutGroups) {
    for layoutGroup in layoutGroups {
      if (InStr(layoutGroup, symbol, true))
        return true
    }
    return false
  }

  _getTextLayoutPair(params*) {
    if (params.Length = 0)
      return this.SUPPORTED_LAYOUT_PAIRS.Length ? this.SUPPORTED_LAYOUT_PAIRS[1] : false
    if (params.Length != 2)
      throw ValueError('Both text layout names are required')
    layoutAParam := Trim("" params[1])
    layoutBParam := Trim("" params[2])
    if (layoutAParam = "" && layoutBParam = "")
      return this.SUPPORTED_LAYOUT_PAIRS.Length ? this.SUPPORTED_LAYOUT_PAIRS[1] : false
    if (layoutAParam = "" || layoutBParam = "")
      throw ValueError('Both text layout names are required')
    layoutA := this._resolveTextLayoutName(layoutAParam)
    layoutB := this._resolveTextLayoutName(layoutBParam)
    return this._createSupportedLayoutPair(layoutA, layoutB)
  }

  _refreshSupportedLayoutPairs() {
    this.SUPPORTED_USER_LAYOUTS := Map()
    this.SUPPORTED_LAYOUT_PAIRS := []
    for (layoutData in this.USER_KEYBOARD_LAYOUTS) {
      textLayoutName := this._resolveInstalledTextLayoutName(layoutData)
      if (textLayoutName != '')
        this.SUPPORTED_USER_LAYOUTS[textLayoutName] := layoutData
    }
    layoutPair := this._createSupportedLayoutPair("EN", "RU")
    if (layoutPair)
      this.SUPPORTED_LAYOUT_PAIRS.Push(layoutPair)
  }

  _createSupportedLayoutPair(layoutA, layoutB) {
    if (!this.SUPPORTED_USER_LAYOUTS.Has(layoutA) || !this.SUPPORTED_USER_LAYOUTS.Has(layoutB))
      return false
    installedLayoutA := this.SUPPORTED_USER_LAYOUTS[layoutA]
    installedLayoutB := this.SUPPORTED_USER_LAYOUTS[layoutB]
    if (!installedLayoutA.hkl || !installedLayoutB.hkl)
      return false
    try this._getHeyMapDict(layoutA, layoutB)
    catch
      return false
    return {
      layoutA: layoutA,
      layoutB: layoutB,
      installedLayoutA: installedLayoutA,
      installedLayoutB: installedLayoutB
    }
  }

  _getPairLayoutData(layoutPair, textLayoutName) {
    if (layoutPair.layoutA = textLayoutName)
      return layoutPair.installedLayoutA
    if (layoutPair.layoutB = textLayoutName)
      return layoutPair.installedLayoutB
    return false
  }

  _resolveInstalledTextLayoutName(layoutData) {
    if (!layoutData.HasOwnProp("klid") || !layoutData.HasOwnProp("hkl") || layoutData.klid = '' || !layoutData.hkl)
      return ''
    layoutKlid := StrUpper(layoutData.klid)
    for textLayoutName, supportedKlids in this.SUPPORTED_TEXT_LAYOUT_KLIDS {
      if (supportedKlids.Has(layoutKlid))
        return textLayoutName
    }
    return ''
  }

  _resolveTextLayoutName(layoutName) {
    layoutName := StrUpper(Trim("" layoutName))
    if (layoutName = '')
      return ''
    if (this.TEXT_LAYOUT_ALIASES.Has(layoutName))
      return this.TEXT_LAYOUT_ALIASES[layoutName]
    throw ValueError('Unknown text conversion layout ' . layoutName)
  }

  _resolveInstalledKeyboardLayout(layoutNameOrId) {
    requestedLayoutId := IsNumber(layoutNameOrId) ? layoutNameOrId : INPUT_LOCALES.GetLayoutCodeNumber(layoutNameOrId)
    normalizedRequestedHkl := this._normalizeKeyboardLayoutHandle(requestedLayoutId)
    for layoutData in this.USER_KEYBOARD_LAYOUTS {
      if (layoutData.hkl && (layoutData.value = requestedLayoutId || this._normalizeKeyboardLayoutHandle(layoutData.hkl) = normalizedRequestedHkl))
        return layoutData
    }
    return false
  }

  _getKeyboardLayoutTargetHwnd() {
    targetHwnd := 0
    try targetHwnd := ControlGetFocus("A")
    if (!targetHwnd)
      targetHwnd := WinExist("A")
    if (!targetHwnd)
      throw TargetError('Active window or focused control not found')
    return targetHwnd
  }

  _requestKeyboardLayout(layoutHkl, requestFlags, targetHwnd) {
    SendMessage(KeyboardInputFlags.WM_INPUTLANGCHANGEREQUEST, requestFlags, layoutHkl,, "ahk_id " . targetHwnd)
  }
  
  _getUsersKeyboardLayouts() {
    keyboardLayouts := []
    activeHandlesByLanguage := Map()
    for keyboardLayoutHkl in this._getActiveKeyboardLayoutHandles() {
      normalizedHkl := this._normalizeKeyboardLayoutHandle(keyboardLayoutHkl)
      languageId := normalizedHkl & 0xFFFF
      if (!activeHandlesByLanguage.Has(languageId))
        activeHandlesByLanguage[languageId] := []
      activeHandlesByLanguage[languageId].Push(keyboardLayoutHkl)
    }

    configuredKlids := this._getConfiguredKeyboardLayoutKlids()
    configuredKlidsByLanguage := Map()
    for layoutKlid in configuredKlids {
      languageId := Integer("0x" layoutKlid) & 0xFFFF
      if (!configuredKlidsByLanguage.Has(languageId))
        configuredKlidsByLanguage[languageId] := []
      configuredKlidsByLanguage[languageId].Push(layoutKlid)
    }

    for layoutKlid in configuredKlids {
      layoutValue := Integer("0x" layoutKlid)
      languageId := layoutValue & 0xFFFF
      matchingActiveHandles := activeHandlesByLanguage.Has(languageId) ? activeHandlesByLanguage[languageId] : []
      matchingConfiguredKlids := configuredKlidsByLanguage[languageId]
      keyboardLayoutHkl := (matchingActiveHandles.Length = 1 && matchingConfiguredKlids.Length = 1) ? matchingActiveHandles[1] : 0
      layoutName := INPUT_LOCALES.GetKeyboardLayoutName(languageId)
      keyboardLayouts.Push({alias: '0x' . layoutKlid, klid: layoutKlid, name: layoutName, value: layoutValue, hkl: keyboardLayoutHkl})
    }
    return keyboardLayouts
  }

  _getConfiguredKeyboardLayoutKlids() {
    configuredKlids := []
    configuredKlidsSet := Map()
    Loop Reg, "HKCU\Keyboard Layout\Preload", "V"
    {
      layoutKlid := StrUpper(Trim("" RegRead()))
      try layoutKlid := StrUpper(Trim("" RegRead("HKCU\Keyboard Layout\Substitutes", layoutKlid)))
      if (!RegExMatch(layoutKlid, "^[0-9A-F]{8}$") || configuredKlidsSet.Has(layoutKlid))
        continue
      configuredKlidsSet[layoutKlid] := true
      configuredKlids.Push(layoutKlid)
    }
    return configuredKlids
  }

  _getActiveKeyboardLayoutHandles() {
    keyboardLayoutHandles := []
    layoutCount := DllCall("User32.dll\GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    if (layoutCount <= 0)
      return keyboardLayoutHandles
    layoutBuffer := Buffer(layoutCount * A_PtrSize)
    copiedLayoutCount := DllCall("User32.dll\GetKeyboardLayoutList", "Int", layoutCount, "Ptr", layoutBuffer.Ptr, "Int")
    Loop copiedLayoutCount
      keyboardLayoutHandles.Push(NumGet(layoutBuffer, (A_Index - 1) * A_PtrSize, "Ptr"))
    return keyboardLayoutHandles
  }

  _normalizeKeyboardLayoutHandle(keyboardLayoutHkl) {
    return keyboardLayoutHkl & 0xFFFFFFFF
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
  static LAYOUT_ALIASES := {
    EN: "ENG",
    RU: "RUS"
  }
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
    layoutName := INPUT_LOCALES.ResolveLayoutName(layoutName)
    if (layoutName = '')
      return INPUT_LOCALES._NEXT
    try {
      return INPUT_LOCALES.LAYOUTS.%layoutName%
    } catch {
      throw ValueError('Unknown keyboard layout ' . layoutName)
    }
  }

  static ResolveLayoutName(layoutName) {
    layoutName := StrUpper(Trim(layoutName))
    if (layoutName = '')
      return ''
    try {
      return INPUT_LOCALES.LAYOUT_ALIASES.%layoutName%
    } catch {
      return layoutName
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

; class TextLocaleManager extends AKPlugin {
class TextLocaleManager {
  KEY_MAPPING_DICT := Map()
  USER_KEYBOARD_LAYOUTS := []

  __UsageHelp() {
    return ''
  }

  __ActionsHelp() {
    texts := Map()
    ; texts["IsTextSelectCursor"] := "IsTextSelectCursor()"
    texts["SwapTextLayout"]                := "SwapTextLayout(incorrectText, layoutA, layoutB)"
    texts["ShowCurrentKeyboardLayout"]            := "ShowCurrentKeyboardLayout()"
    texts["GetUsersKeyboardLayouts"]       := "GetUsersKeyboardLayouts()"
    texts["GetCurrentKeyboardLayoutName"]  := "GetCurrentKeyboardLayoutName()"
    texts["SwitchKeyboardLayout"]          := "SwitchKeyboardLayout(layoutName:='')"
    return texts
  }

  __New() {
    #DllLoad "Imm32" ; Internationalization for Windows Applications (docs.microsoft.com/en-us/windows/win32/api/imm/)

    this.KEY_MAPPING_DICT['EN-RU'] := Map()
    this.KEY_MAPPING_DICT['EN-RU']['EN'] := ["~#QWERTYUIOP{}ASDFGHJKLZXCVBNM<>``qwertyuiop[]asdfghjkl'zxcvbnm", ':";,.', '@$^&|', '?/']
    this.KEY_MAPPING_DICT['EN-RU']['RU'] := ["Ё№ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЯЧСМИТЬБЮёйцукенгшщзхъфывапролдэячсмить",  'ЖЭжбю', '";:?/', ',.']

    this.WHITESPACE_SYMBOLS := " `t`n"

    this.USER_KEYBOARD_LAYOUTS := this.GetUsersKeyboardLayouts()
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
    Sleep(200)
    
    currentLayout := this.GetCurrentKeyboardLayoutName()
    ToolTip(currentLayout)
  }

  GetUsersKeyboardLayouts() { ;;;
    keyboardLayouts := []
    Loop Reg, "HKCU\Keyboard Layout\Preload", "R KV" ; Recursively, keys and values.
    {
      if (A_LoopRegType != "key") {
        value := RegRead()
        if (value != "") {
          alias := '0x' . value
          intValue := Integer(alias)
          name := this._getKeyboardLayoutName(intValue)
          keyboardLayouts.Push({ alias: alias, name: name, value: intValue })
        }
      }
    }
    return keyboardLayouts
  }

  GetCurrentKeyboardLayoutName() { ;;;
    return this._getKeyboardLayoutName(this._getKeyboardLayoutCode())
  }

  SwitchKeyboardLayout(layoutName:='') { ;;;
    static WM_INPUTLANGCHANGEREQUEST := 0x50
    static INPUTLANGCHANGE_SYSCHARSET := 1

    langId := this._getLayoutCodeNumber(layoutName)

    hwnd := ControlGetFocus("A") || WinExist("A")

    SendMessage(WM_INPUTLANGCHANGEREQUEST, INPUTLANGCHANGE_SYSCHARSET, langId,, hwnd)

    this.ShowCurrentKeyboardLayout()
  }

  SwitchTextLayout(layoutA, layoutB) { 
    ; _saveClipboardState()
    TempClipboard := ClipboardAll()

    SelText := this._getSelectedTextOrLastWord() 
    convResult := this.SwapTextLayout(SelText, layoutA, layoutB)
    A_Clipboard := convResult.newText
    hotkeyCtrlV := "^{vk56}" 
    SendInput(hotkeyCtrlV)
    Sleep(50)
    this.SwitchKeyboardLayout(convResult.newLayout)
    Sleep(50)
  
    ; _restoreClipboardState()
    A_Clipboard := TempClipboard
  }


  _getSelectedTextOrLastWord() {
    SetKeyDelay(0)
    hotkeyCtrlC := '^{vk43}'
    hotkeyShiftLeft := '+{Left}'
    hotkeyShiftRight := '+{Right}'
    hotkeyCtrlShiftLeft := '^+{Left}'
    hotkeyCtrlShiftRight := '^+{Right}'

    A_Clipboard := ''
    SendInput(hotkeyCtrlC)
    Sleep(100)
    if (A_Clipboard != '') {
      return A_Clipboard
    }
    while (A_Index < 10) {
      SendInput(hotkeyCtrlShiftLeft . ' ' . hotkeyCtrlC)
      Errorlevel := !ClipWait(1)
      if ErrorLevel
        return

      if (RegExMatch(A_Clipboard, "([ \t])", &Found) && A_Index != 1) {
        SendInput(hotkeyCtrlShiftRight)
        return SubStr(A_Clipboard, (Found.Pos[1] + 1)<1 ? (Found.Pos[1] + 1)-1 : (Found.Pos[1] + 1))
      }

      PrevClipboard := A_Clipboard
      A_Clipboard := ''
      SendInput(hotkeyShiftLeft . hotkeyCtrlC)
      Errorlevel := !ClipWait(1)
      if ErrorLevel {
        return
      }
      if (StrLen(A_Clipboard) = StrLen(PrevClipboard)) {
        A_Clipboard := ''
        SendInput(hotkeyShiftLeft . hotkeyCtrlC)
        Errorlevel := !ClipWait(1)
        if ErrorLevel
          return

        if (StrLen(A_Clipboard) = StrLen(PrevClipboard)) {
          return A_Clipboard
        } else {
          SendInput(hotkeyShiftRight . hotkeyShiftRight)
          return PrevClipboard
        }
      }

      SendInput(hotkeyShiftRight)

      s := SubStr(A_Clipboard, 1, 1)
      if (s ~= "^(?i:" RegExReplace(RegExReplace(A_Space "," A_Tab ",`n,`r","[\\\.\*\?\+\[\{\|\(\)\^\$]","\$0"),"\s*,\s*","|") ")$")
      {
        A_Clipboard := ''
        SendInput(hotkeyShiftLeft . hotkeyCtrlC)
        Errorlevel := !ClipWait(1)
        if (ErrorLevel) {
          return
        }
        return A_Clipboard
      }
      A_Clipboard := ''
    }
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

  _getLayoutCodeNumber(layoutName) {
    switch(layoutName) {
      case "GER": return 0x00000407
      case "ENG": return 0x00000409
      case "FRA": return 0x0000040c
      case "ITA": return 0x00000410
      case "JAP": return 0x00000411
      case "KOR": return 0x00000412
      case "RUS": return 0x00000419
      case "CHI": return 0x00000404
      case "SPA": return 0x00000c0a
      default:
        return 0
    }
  }
  ; https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11
  ; TODO Add more cases for other layouts
  _getKeyboardLayoutName(layoutCodeNumber) {
    switch(Integer(layoutCodeNumber)) {
      case 0x04070407: return "GER"
      case 0x04090409: return "ENG"
      case 0x040c040c: return "FRA"
      case 0x04100410: return "ITA"
      case 0x04110411: return "JAP"
      case 0x04120412: return "KOR"
      case 0x04190419: return "RUS"
      case 0x08040404: return "CHI"
      case 0x0c0a0c0a: return "SPA"

      case 0x00000407: return "GER"
      case 0x00000409: return "ENG"
      case 0x0000040c: return "FRA"
      case 0x00000410: return "ITA"
      case 0x00000411: return "JAP"
      case 0x00000412: return "KOR"
      case 0x00000419: return "RUS"
      case 0x00000404: return "CHI"
      case 0x00000c0a: return "SPA"
      default:
        return Format("{:x}", layoutCodeNumber)
    }
  }


  ; IsTextSelectCursor() { ;;;
  ;   ; Constants for cursor types
  ;   OCR_IBEAM := 32513  ; I-beam cursor

  ;   ; Struct to hold cursor information
  ;   VarSetStrCapacity(cursorInfo, 20)
  ;   NumPut("UInt", 20, cursorInfo, 0)  ; cbSize
  ;   ; Call GetCursorInfo to get cursor information
  ;   if (DllCall("GetCursorInfo", "UInt", cursorInfo)) {
  ;       cursorType := NumGet(cursorInfo, 8, "UInt")
  ;       ; Check if the cursor type is OCR_IBEAM
  ;       return (cursorType = OCR_IBEAM)
  ;   }
  ;   return false
  ; }

  ; SetTimer(CheckCursor,1000)


  ; CheckCursor() {
  ;   if (IsTextSelectCursor()) {
  ;     Tooltip("selection mode!")
  ;   } else {
  ;     Tooltip("NO")
  ;   }
  ; }


; ; 2. Get a handle for Imm32\ImmGetDefaultIMEWnd function to be used later in a GetCurLayout function
;   ; Faster performance by looking up the function's address beforehand lexikos.github.io/v2/docs/commands/DllCall.htm.
; global getDefIMEWnd := DllCall("GetProcAddress", "Ptr",DllCall("GetModuleHandle", "Str","Imm32", "Ptr"), "AStr","ImmGetDefaultIMEWnd", "Ptr") ; HWND ImmGetDefaultIMEWnd(HWND Arg1) docs.microsoft.com/en-us/windows/win32/api/imm/nf-imm-immgetdefaultimewnd

; WM_INPUTLANGCHANGEREQUEST := 0x50

; ; 3. Use this 'getDefIMEWnd' function to get a special handle to a window that contains input layout information for a Console window

; GetCurLayout(&hWord :="", &lWord :="") {
;   fgWin := DllCall("GetForegroundWindow") ; Get handle (HWND) to the foreground window docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getforegroundwindow
;   if WinActive("ahk_class ConsoleWindowClass") { ; get layout for Console
;     IMEWnd := DllCall(getDefIMEWnd, "Ptr",fgWin) ; DllCall("Imm32.dll\ImmGetDefaultIMEWnd", "Ptr",fgWin)
;     if (IMEWnd == 0) {
;       Return
;     } else {
;       fgWin := IMEWnd
;     }
;   } else if WinActive("ahk_class vguiPopupWindow") or WinActive("ahk_class ApplicationFrameWindow") { ; Steam, some UWP apps, get layout from a keyboard focused control since can't read it from a regular window autohotkey.com/boards/viewtopic.php?f=76&t=69414
;     Focused := ControlGetFocus("A")
;     if (Focused == 0) {
;       Return
;     } else {
;       CtrlID := ControlGetHwnd(Focused, "A")
;       Case := CtrlID: return ';       fgWin'
;     }
;   }
;   Case := DllCall("GetWindowThreadProcessId" ,  "Ptr",fgWin , "Ptr",0) ; DWORD GetWindowThreadProcessId(HWND hWnd, LPDWORD lpdwProcessId) docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid: return ';   threadID    '
;   Case , "UInt",threadID) ; In some examples ends with ', "UInt"' return type, but this isn't precise enough to catch differences between my custom layouts, so need the full '0xfffffffff0c00409' value: return ';   inputLocaleID := DllCall("GetKeyboardLayout"      '
;     ;+---------+-------------+ docs.microsoft.com/en-us/windows/win32/intl/language-identifiers
;     ;|SubLangID|PrimaryLangID|
;     ;+---------+-------------+
;     ;15     10 9             0 bit
;   Case ; Device handle to the physical layout. Bitwise right shift by 16 bits = 4 hex characters (i.e. size of lWord): return ';   hWord := inputLocaleID >> 16  '
;   lWord := inputLocaleID & 0xFFFF ; Language Identifier for the input language
;   Return inputLocaleID
;   }

; ; 4 Use that input layout information to switch to the other one (in the example below with 'Alt-CapsLock')

; ; Find your layout name for the 'YourLanguageCodeFromTheRegistry1' parameter @ the folder name in 'Computer\HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Keyboard Layouts', e.g. '00000409' for the US English
; Language1 := DllCall("LoadKeyboardLayout" , "Str","YourLanguageCodeFromTheRegistry1" , "Int",1)
; Language2 := DllCall("LoadKeyboardLayout" , "Str","YourLanguageCodeFromTheRegistry2" , "Int",1)

; LayoutSwitch() {
;   global Language1,Language2
;   local curlayout := GetCurLayout(hWord, lWord)
;   local targetWin := "A" ; Active window to PostMessage to, needs to be changed for '#32770' class (dialog window)

;   if WinActive("ahk_class #32770") {
;     targetWin := ControlGetFocus("A") ; Retrieves which control of the target window has keyboard focus, if any. autohotkey.com/boards/viewtopic.php?p=233011
;   }
;   if (curlayout = Language1) {
;     PostMessage WM_INPUTLANGCHANGEREQUEST, 0, Language2,       , targetWin
;     ;           Msg,            w/, lParam ,Control, WinTitle
;   } else if (curlayout = Language2) { ; or you can just remove the 'if ...' part and always switch to Language 1 whenever some other layout is active (remove the next 'else' as well then)
;     PostMessage WM_INPUTLANGCHANGEREQUEST, 0, Language1,       , targetWin
;   } else {
;     MsgBox("Layout neither Language1 nor Language2, not switching anything")
;   }
;   Return
;   }
  





  ; Case := Menu()
  ; Case.Add()
  ; Case.Delete()
  ; Case.Add("&UPPERCASE", CCase)
  ; Case.Add("&lowercase", CCase)
  ; Case.Add("&Title Case", CCase)
  ; Case.Add("&Sentence case", CCase)
  ; Case.Add()
  ; Case.Add("&Fix Linebreaks", CCase)
  ; Case.Add("&Reverse", CCase)
  ; Case.Add()
  ; Case.Add("&Remove Spaces", CCase)

  ; GetText(Txt)
  ; If NOT ERRORLEVEL
  ;   Case.Show()
  ; Return
  ; } ; V1toV2: Added Bracket before label

  ; CCase(A_ThisMenuItem, A_ThisMenuItemPos, MyMenu)
  ; { ; V1toV2: Added bracket
  ; p:=A_ThisMenuItemPos
  ; If (p=1)
  ;   Txt := StrUpper(Txt)
  ; Else If (p=2)
  ;   Txt := StrLower(Txt)
  ; Else If (p=3)
  ;   Txt := StrTitle(Txt)
  ; Else If (p=4)
  ; {
  ;   Txt := StrLower(Txt)
  ;   Txt := RegExReplace(Txt, "((?:^|[.!?]\s+)[a-z])", "$u1")
  ; }
  ; Else If (p=6)
  ; {
  ;   Txt := RegExReplace(Txt, "\R", "`r`n")
  ; }
  ; Else If (p=7)
  ; {
  ;   Temp2 := ''
  ;   ; StrReplace() is not case sensitive
  ;   ; check for StringCaseSense in v1 source script
  ;   ; and change the CaseSense param in StrReplace() if necessary
  ;   Txt := StrReplace(Txt, "`r`n", Chr(29))
  ;   Loop Parse, Txt
  ;     Temp2 := A_LoopField . Temp2
  ;   ; StrReplace() is not case sensitive
  ;   ; check for StringCaseSense in v1 source script
  ;   ; and change the CaseSense param in StrReplace() if necessary
  ;   Txt := StrReplace(Temp2, Chr(29), "`r`n")
  ; }
  ; Else If (p=9)
  ; {
  ;   Loop
  ;   { 
  ;   ; StrReplace() is not case sensitive
  ;   ; check for StringCaseSense in v1 source script
  ;   ; and change the CaseSense param in StrReplace() if necessary
  ;   Txt := StrReplace(Txt, A_Space '' A_Space, A_Space,, &ErrorLevel)
  ;   if (ErrorLevel = 0)
  ;     break 
  ;   }
  ; }
  ; PutText(Txt)
  ; Return
  ; } ; V1toV2: Added bracket before function

  ; GetText(&MyText := '') {
  ;   SavedClip := ClipboardAll()
  ;   A_Clipboard := ''
  ;   Send("hotkeyCtrlC") ;Ctrl C
  ;   Errorlevel := !ClipWait(0.5)
  ;   If ERRORLEVEL
  ;   {
  ;     A_Clipboard := SavedClip
  ;     MyText := ''
  ;     Return
  ;   }
  ;   MyText := A_Clipboard
  ;   A_Clipboard := SavedClip
  ;   Return MyText
  ; }

  ;   PutText(MyText) {
  ;     SavedClip := ClipboardAll() 
  ;     A_Clipboard := ''
  ;     Sleep(20)
  ;     A_Clipboard := MyText
  ;     Send("^{vk56}") ;Ctrl V
  ;     Sleep(100)
  ;     A_Clipboard := SavedClip
  ;     Return
  ;   }

  ; ; } 


}






ooo := TextLocaleManager()


^CapsLock::ooo.SwitchTextLayout('EN', 'RU')
+CapsLock::ooo.SwitchKeyboardLayout()

*~^Shift::ooo.ShowCurrentKeyboardLayout()
*~!Shift::ooo.ShowCurrentKeyboardLayout()
*~+Control::ooo.ShowCurrentKeyboardLayout()
*~+Alt::ooo.ShowCurrentKeyboardLayout()

ass := ooo.SwapTextLayout('ns pyfto, БреьдЮ а не, <html> <f[f]','EN','RU')



aa := 1


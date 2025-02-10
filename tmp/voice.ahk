
CONFIG := {
  DEFAULT_LOCALE: 'en-US',
  SpeachVoices: '<voice xml:lang="ru-RU" gender="female">',
  
}

MsgBox(_getVoicesList())
; Microsoft David Desktop - English (United States)
; Microsoft Hazel Desktop - English (Great Britain)
; Microsoft Zira Desktop - English (United States)
; Microsoft Haruka Desktop - Japanese
; Microsoft Irina Desktop - Russian

_textToWhatNameThisFunction(text, lang:='auto', voice:='auto', someAdditionalParamsIfNeeded*) {

}

Speak(text, lang:='auto', voice:='auto') {
  if (lang = 'auto') {
    mainLocale := CONFIG.DEFAULT_LOCALE
  }
  ssmlText := '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="' . mainLocale. '">' . _textToWhatNameThisFunction(text, lang, voice) . '</speak>'

  voice := ComObject("SAPI.SpVoice")
  voice.Speak(ssmlText)
}



Speak("time is 19:23. вреия 19:23. 時刻は19:23です")



  ; Initialize to track the current detected language based on Unicode
  lastLangByUnicode := "en-US"

  ; Split the string into words
  for word in StrSplit(stringToSpeak, " `t`n,.-()[]{};:") {
    OutputDebug(word '`n')
      ; Check for language prefixes like [en-US]
      if (SubStr(word, 1, 1) = "[" && SubStr(word, -1) = "]") {
          ; Append the current text in the previous language
          if (currentText != "") {
              result .= "<voice xml:lang='" currentLang "'>" Trim(currentText) "</voice>"
              currentText := "" ; Reset the text for the new language
          }
          
          ; Extract the language code from the prefix
          langCode := SubStr(word, 2, StrLen(word) - 2)
          if prefixes.Has(langCode) {
              currentLang := prefixes[langCode]
          }
          continue
      }

      ; Detect by Unicode character ranges (Japanese, Cyrillic, etc.)
      if RegExMatch(word, "[\x{3040}-\x{30FF}]") {  ; Japanese (Hiragana + Katakana)
          if currentLang != "ja-JP" {
              if currentText != "" {
                  result .= "<voice xml:lang='" currentLang "'>" Trim(currentText) "</voice>`n"
                  currentText := ""
              }
              currentLang := "ja-JP"
          }
      } else if RegExMatch(word, "[\x{0400}-\x{04FF}]") {  ; Russian (Cyrillic)
          if currentLang != "ru-RU" {
              if currentText != "" {
                  result .= "<voice xml:lang='" currentLang "'>" Trim(currentText) "</voice>"
                  currentText := ""
              }
              currentLang := "ru-RU"
          }
      } else if currentLang != "en-US" && !RegExMatch(word, "[\x{3040}-\x{30FF}\x{0400}-\x{04FF}]") {
          ; Default back to English if there is no special Unicode match or prefix
          if currentText != "" {
              result .= "<voice xml:lang='" currentLang "'>" Trim(currentText) "</voice>"
              currentText := ""
          }
          currentLang := "en-US"
      }

      ; Accumulate the current text for the current language
      currentText .= word " "
  }

  ; Append the remaining text in the current language
  if currentText != "" {
      result .= "<voice xml:lang='" currentLang "'>" Trim(currentText) "</voice>"
  }

  ; Close the SSML tag
  result .= "</speak>"
OutputDebug(result '`n')
  ; Output the result (or call SAPI.SpVoice to speak)
  MsgBox result  ; For debugging, show the final SSML

}

_getVoicesList() {
  voice := ComObject("SAPI.SpVoice")
  tokens := voice.GetVoices()
  
  voicesList := ""
  for token in tokens {
      voicesList .= token.GetDescription() "`n"
  }
  
  return voicesList
}

MsgBox(_getVoicesList())
; Microsoft David Desktop - English (United States)
; Microsoft Hazel Desktop - English (Great Britain)
; Microsoft Zira Desktop - English (United States)
; Microsoft Haruka Desktop - Japanese
; Microsoft Irina Desktop - Russian


; APP.Speak("何 opachika превед медвед, йя кревед")
Speak("<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>" .
    "<voice xml:lang='en-US'>Hello, ass</voice>" .
    "<voice xml:lang='fi-FI'>Huomenta perse</voice>" .
    "<voice xml:lang='ru-RU'>превед медвед, йa кревед</voice>" .
    "<voice xml:lang='ja-JP'>何</voice>" .
    "</speak>")

Speak("time is 19:23. вреия 19:23. 時刻は19:23です")

; can u fully rewrite it without comments but with selfdescriptive code using logic:
; write detectTextLocale(text, localePriority:='')
; where goes logic of locale detection, where you can set localePriority:='fi-FI,en-US,ru-RU'
; so
; make formatTextToSpeak(text) that first splits text to arrayWordObjects,  with some calculated values like:
; [{text: 'Hello,', locale: 'en-US'},...] locale is calculated from detectTextLocale('word', lastDetectedLocale)
; then loop thru arrayWordObjects to combine words with same locale to smaller array
; like
; [{text: 'time is 19:23. ', locale: 'en-US'}, {text: 'вреия 19:23. ', locale: 'ru-RU'}, ...]

config := {}
config.DarkThemeBackgroundColor := 0xFF2E2E2E  ; 0xAARRGGBB
config.DarkThemeBorderColor := 0xFF545456      ; 0xAARRGGBB
config.DarkThemeTextColor := 0xFFFFFFFF        ; 0xAARRGGBB
config.LightThemeBackgroundColor := 0xFFFFFFFF ; 0xAARRGGBB
config.LightThemeBorderColor := 0xFFB4B4B4     ; 0xAARRGGBB
config.LightThemeTextColor := 0xFF000000       ; 0xAARRGGBB
config.BorderWidth := 1
config.BorderRadius := 5
config.FontFace := "Tahoma"
config.FontSize := 12
config.FontStyle := "" ; (Regular Bold Italic BoldItalic Underline Strikeout)
config.Margin := 5      


showGui()
showGui() {
  static inputDialog := ''
  if (inputDialog) {
    inputDialog.Destroy()
    inputDialog := ''
    return
  }

  inputDialog := Gui()
  inputDialog.Title := "Input hotkey combination"
  inputDialog.Opt("+ToolWindow +AlwaysOnTop")

  inputDialog.Add("Button", "Default", "Set")
    .OnEvent("Click", (*) => InputHotkey())

  inputDialog.Show()
}


InputHotkey() {
    InstallKeybdHook

    

    iHook := InputHook(,"{ENTER}")

    iHook.KeyOpt("{All}", "ES")  ; End and Suppress
    ; Exclude the modifiers
    iHook.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-ES")

    iHook.Start()
    iHook.Wait()
    iHook.Stop()

    ass :=iHook.EndMods . iHook.EndKey
    OutputDebug('input=' ass '.')
}



+F1::	; Shift-F1 ---> Display Hotkey CheatSheet from tab separated file, two columns: HOTKEYS.txt
{
  myGui := Gui()
  myGui.BackColor := "0x06666" ; Green
  myGui.Title := "AHK MasterHotkeys CheatSheet"
  myGui.SetFont("s11", "Verdana")
  myGui.OnEvent("Close", GuiClose)
  myGuiLV := myGui.Add("ListView", "r26 w1200 +Grid", ["Command", "Description"])
  ImageListID := IL_Create(10)  ; Create an ImageList to hold 10 small icons.
  myGuiLV.SetImageList(ImageListID)  ; Assign the above ImageList to the current ListView.
  Loop 10  ; Load the ImageList with a series of icons from the DLL.
      IL_Add(ImageListID, "shell32.dll", A_Index) 
  Loop Read, "HOTKEYS.txt"
  {
      var_ := StrSplit(A_LoopReadLine,A_TAB)
      myGuiLV.Add("", "Icon", var_[2])
  }
  myGuiLV.ModifyCol(1, 300)
  ogcButtonOK := myGui.Add("Button", "w1200 h30", "< &OK >")
  ogcButtonOK.OnEvent("Click", GuiClose)  ; Call GuiClose when clicked.
  myGui.Show()
  ogcButtonOK.Focus()


	GuiClose(*)
	{
		myGui.Destroy()
	}
}




MyGui := Gui()
MyGui.Opt("+AlwaysOnTop -Caption +ToolWindow")  ; +ToolWindow avoids a taskbar button and an alt-tab menu item.
MyGui.BackColor := config.DarkThemeBackgroundColor  ; Can be any RGB color (it will be made transparent below).
MyGui.SetFont("s32")  ; Set a large font size (32-point).
CoordText := MyGui.Add("Text", "c" . config.DarkThemeTextColor, "XXXXX YYYYY")  ; XX & YY serve to auto-size the window.
; Make all pixels of this color transparent and make the text itself translucent (150):
; WinSetTransColor(MyGui.BackColor " 150", MyGui)
SetTimer(UpdateOSD, 200)
UpdateOSD()  ; Make the first update immediate rather than waiting for the timer.
MyGui.Show("x0 y400 NoActivate")  ; NoActivate avoids deactivating the currently active window.

UpdateOSD(*)
{
    MouseGetPos &MouseX, &MouseY
    CoordText.Value := "X" MouseX ", Y" MouseY
}


class WindowManager {
  static WS_BORDER           := 0x800000   ; 	+/-Border. Creates a window that has a thin-line border.
  static WS_POPUP            := 0x80000000 ; 	Creates a pop-up window. This style cannot be used with the WS_CHILD style.
  static WS_CAPTION          := 0xC00000   ; 	+/-Caption. Creates a window that has a title bar. This style is a numerical combination of WS_BORDER and WS_DLGFRAME.
  static WS_CLIPSIBLINGS     := 0x4000000  ; 	Clips child windows relative to each other; that is, when a particular child window receives a WM_PAINT message, the WS_CLIPSIBLINGS style clips all other overlapping child windows out of the region of the child window to be updated. If WS_CLIPSIBLINGS is not specified and child windows overlap, it is possible, when drawing within the client area of a child window, to draw within the client area of a neighboring child window.
  static WS_DISABLED         := 0x8000000  ; 	+/-Disabled. Creates a window that is initially disabled.
  static WS_DLGFRAME         := 0x400000   ; 	Creates a window that has a border of a style typically used with dialog boxes.
  static WS_GROUP            := 0x20000    ; 	+/-Group. Indicates that this control is the first one in a group of controls. This style is automatically applied to manage the "only one at a time" behavior of radio buttons. In the rare case where two groups of radio buttons are added consecutively (with no other control types in between them), this style may be applied manually to the first control of the second radio group, which splits it off from the first.
  static WS_HSCROLL          := 0x100000   ; 	Creates a window that has a horizontal scroll bar.
  static WS_MAXIMIZE         := 0x1000000  ; 	Creates a window that is initially maximized.
  static WS_MAXIMIZEBOX      := 0x10000    ; 	+/-MaximizeBox. Creates a window that has a maximize button. Cannot be combined with the WS_EX_CONTEXTHELP style. The WS_SYSMENU style must also be specified.
  static WS_MINIMIZE         := 0x20000000 ; 	Creates a window that is initially minimized.
  static WS_MINIMIZEBOX      := 0x20000    ; 	+/-MinimizeBox. Creates a window that has a minimize button. Cannot be combined with the WS_EX_CONTEXTHELP style. The WS_SYSMENU style must also be specified.
  static WS_OVERLAPPED       := 0x0        ; 	Creates an overlapped window. An overlapped window has a title bar and a border. Same as the WS_TILED style.
  static WS_OVERLAPPEDWINDOW := 0xCF0000   ; 	Creates an overlapped window with the WS_OVERLAPPED, WS_CAPTION, WS_SYSMENU, WS_THICKFRAME, WS_MINIMIZEBOX, and WS_MAXIMIZEBOX styles. Same as the WS_TILEDWINDOW style.
  static WS_POPUPWINDOW      := 0x80880000 ; 	Creates a pop-up window with WS_BORDER, WS_POPUP, and WS_SYSMENU styles. The WS_CAPTION and WS_POPUPWINDOW styles must be combined to make the window menu visible.
  static WS_SIZEBOX          := 0x40000    ; 	+/-Resize. Creates a window that has a sizing border. Same as the WS_THICKFRAME style.
  static WS_SYSMENU          := 0x80000    ; 	+/-SysMenu. Creates a window that has a window menu on its title bar. The WS_CAPTION style must also be specified.
  static WS_TABSTOP          := 0x10000    ; 	+/-Tabstop. Specifies a control that can receive the keyboard focus when the user presses Tab. Pressing Tab changes the keyboard focus to the next control with the WS_TABSTOP style.
  static WS_THICKFRAME       := 0x40000    ; 	Creates a window that has a sizing border. Same as the WS_SIZEBOX style.
  static WS_VSCROLL          := 0x200000   ; 	Creates a window that has a vertical scroll bar.
  static WS_VISIBLE          := 0x10000000 ; 	Creates a window that is initially visible.
  static WS_CHILD            := 0x40000000 ; 	Creates a child window. A window with this style cannot have a menu bar. This style cannot be used with the WS_POPUP style.
}

_hasWindowState(hwnd, state) {
  Style := WinGetStyle("ahk_id " hwnd)
  ass := Style & WindowManager.%state%
  if (ass) {
    MsgBox "has state " state
    return true
  }
  return false
}

_hasWindowStyle(hwnd, style) {
  Style := WinGetStyle("ahk_id " hwnd)
  if (style & WindowManager.WS_CAPTION) {
    return true
  } else {
    return false
  }
}

_setWindowStyle(hwnd, style, enable) {
  prefix := (enable) ? '+' : '-'
  WinSetStyle(Format("{2}{1:#x}", style, prefix), "ahk_id " hwnd)
}


#C::{
  hwnd := WinGetID("A")
  isMaximized := WinGetMinMax("ahk_id " hwnd)
  
  ; if (_hasWindowStyle(hwnd, WindowManager.WS_SIZEBOX)) {
  ;   _setWindowStyle(hwnd, WindowManager.WS_SIZEBOX, false)
  ; } else {
  ;   _setWindowStyle(hwnd, WindowManager.WS_SIZEBOX, true)
  ; }
  if (_hasWindowStyle(hwnd, WindowManager.WS_CAPTION)) {
    _setWindowStyle(hwnd, WindowManager.WS_CAPTION, false)
  } else {
    _setWindowStyle(hwnd, WindowManager.WS_CAPTION, true)
  }
  
    ; if (isCaptionRemoved != 0xC40000) { 
    ;   WinSetStyle("+0xC40000", "ahk_id " hwnd)  ; Restore WS_CAPTION|WS_SIZEBOX.
    ;   WinRestore("ahk_id " hwnd)
    ;   this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
    ; } else {
    ;   if (isMaximized) {
    ;     WinRestore("ahk_id " hwnd)
    ;   }
    ;   WinSetStyle("-0xC40000", "ahk_id " hwnd)  ; Remove WS_CAPTION|WS_SIZEBOX.
    ;   WinMaximize("ahk_id " hwnd)
    ;   this.ShowInfo(this._getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
    ; }

}


; #Include ../lib/Notify.ahk
; Notify.MonitorGetInfo()
; Notify.Show('The quick brown fox jumps over the lazy dog.',,,,, 'dur=4 pos=tc')
; Notify.Show('Alert!', 'You are being warned.', 'icon!',,, 'TC=black MC=black BC=DCCC75')
; Notify.Show('Error', 'Something has gone wrong!', 'iconx', 'soundx',, 'BC=C72424 style=edge show=expand hide=expand')
; Notify.Show('Info', 'Some information to show.', 'iconi',,, 'TC=black MC=black BC=75AEDC style=edge show=slideWest@250 hide=slideEast@250')
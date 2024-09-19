; class TextLocaleManager extends AKPlugin {
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

  ; ; Example usage
  SetTimer, CheckCursor, 1000  ; Check every 1 second
  return

  CheckCursor:
  if (IsTextSelectCursor()) {
    MsgBox, The cursor is in text selection mode!
  } else {
    MsgBox, The cursor is not in text selection mode.
  }
  return



SwitchTextEnRu() {
	WinGet, hwnd, ID, A
	SelText := GetWord(TempClipboard) 
	Clipboard := ConvertTextEnRu(SelText, Locale)
	SendInput, ^{vk56}   ; Ctrl + V
	Sleep, 50
	SwitchLocale(Locale)
	Sleep, 50
	Clipboard := TempClipboard
}


GetWord(ByRef TempClipboard) {
	SetBatchLines, -1
	SetKeyDelay, 0
	
	TempClipboard := ClipboardAll
	Clipboard =
	SendInput, ^{vk43}
	Sleep, 100
	if (Clipboard != "") {
		return Clipboard
	}
	while A_Index < 10
	{
		SendInput, ^+{Left}^{vk43}
		ClipWait, 1
		if ErrorLevel
			return

		if (RegExMatch(Clipboard, "P)([ \t])", Found) && A_Index != 1) {
			SendInput, ^+{Right}
			return SubStr(Clipboard, FoundPos1 + 1)
		}

		PrevClipboard := Clipboard
		Clipboard =
		SendInput, +{Left}^{vk43}
		ClipWait, 1
		if ErrorLevel {
			return
		}
		if (StrLen(Clipboard) = StrLen(PrevClipboard)) {
			Clipboard =
			SendInput, +{Left}^{vk43}
			ClipWait, 1
			if ErrorLevel
				return

			if (StrLen(Clipboard) = StrLen(PrevClipboard)) {
				return Clipboard
			} else {
				SendInput, +{Right 2}
				return PrevClipboard
			}
		}

		SendInput, +{Right}

		s := SubStr(Clipboard, 1, 1)
		if s in %A_Space%,%A_Tab%,`n,`r
		{
			Clipboard =
			SendInput, +{Left}^{vk43}
			ClipWait, 1
			if (ErrorLevel) {
				return
			}
			return Clipboard
		}
		Clipboard =
	}
}

ConvertTextEnRu(Text, ByRef LocaleRef) {
	Static RU := "Ё№ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЯЧСМИТЬБЮёйцукенгшщзхъфывапролдэячсмить"
		, EN := "~#QWERTYUIOP{}ASDFGHJKLZXCVBNM<>``qwertyuiop[]asdfghjkl'zxcvbnm"
		, RUsp := "ЖЭжбю"";:?/,."
		, ENsp := ":"";,.@$^&|?/"

	NewLocale := ""
	
	Loop, parse, Text
	{
		CurrentSymbol := A_LoopField
		DictIdx := 0
				
		if (NewLocale = "") {
			if InStr(EN, CurrentSymbol, true) {
				NewLocale := "RU"
			} else if InStr(RU, CurrentSymbol, true) {
				NewLocale := "EN"
			} else if InStr(";[.,':{><""", CurrentSymbol, true) {
				NewLocale := "RU"
			} else if InStr("жхюбэжЖХЮБЭ", CurrentSymbol, true) {
				NewLocale := "EN"
			}
		}

		if (NewLocale = "EN") {
			DictIdx := InStr(RU, CurrentSymbol, true)
			if (DictIdx > 0) {
				NewText .= SubStr(EN, DictIdx, 1)
			} else {
				DictIdx := InStr(RUsp, CurrentSymbol, true)
				if (DictIdx > 0) {
					NewText .= SubStr(ENsp, DictIdx, 1)
				} else {
					DictIdx := InStr(EN, CurrentSymbol, true)
					if (DictIdx > 0) {
						NewText .= SubStr(RU, DictIdx, 1)
						NewLocale := "RU"
					} else {
						DictIdx := InStr(ENsp, CurrentSymbol, true)
						if (DictIdx > 0) {
							NewText .= SubStr(RUsp, DictIdx, 1)
							NewLocale := "RU"
						} else {
							NewLocale := ""
						}
					}
				}
			}
		}
		if (NewLocale = "RU") {
			DictIdx := InStr(EN, CurrentSymbol, true)
			if (DictIdx > 0) {
				NewText .= SubStr(RU, DictIdx, 1)
			} else {
				DictIdx := InStr(ENsp, CurrentSymbol, true)
				
				if (DictIdx > 0) {
					NewText .= SubStr(RUsp, DictIdx, 1)
				} else {
					DictIdx := InStr(RU, CurrentSymbol, true)
					if (DictIdx > 0) {
						NewText .= SubStr(EN, DictIdx, 1)
						NewLocale := "EN"
					} else {
						DictIdx := InStr(RUsp, CurrentSymbol, true)
						if (DictIdx > 0) {
							NewText .= SubStr(ENsp, DictIdx, 1)
							NewLocale := "EN"
						} else {
							NewLocale := ""
						}
					}
				}
			}
		}
		if (NewLocale = "") {
			NewText .= CurrentSymbol
		} else {
			LastLocale := NewLocale
		}
		; Dbg("CurrentSymbol=" + CurrentSymbol "`n NewLocale="+ NewLocale "`n NewText=" + NewText , 300)
	}
	; Dbg("CurrentSymbol=" + CurrentSymbol "`n NewLocale="+ NewLocale "`n NewText=" + NewText , 3000)
	
	LocaleRef := LastLocale

	return NewText
}


ShowLayout() {
	Sleep, 200
	ThreadId := DllCall("User32.dll\GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
	hCurrentKBLayout := DllCall("User32.dll\GetKeyboardLayout", "UInt", ThreadId, "Ptr")
	Locale := GetLayoutCode(hCurrentKBLayout)
	ToolTip(Locale)
}

GetLayoutCode(LayoutID) {
  if (0x4070407 = LayoutID) {
		return "GER"
	}
  if (0x4090409 = LayoutID) {
		return "ENG"
	}
  if (0x40c040c = LayoutID) {
		return "FRA"
	}
  if (0x4100410 = LayoutID) {
		return "ITA"
	}
  if (0x4110411 = LayoutID) {
		return "JAP"
	}
  if (0x4120412 = LayoutID) {
		return "KOR"
	}
  if (0x4190419 = LayoutID) {
		return "RUS"
	}
  if (0x8040404 = LayoutID) {
		return "CHI"
	}
  if (0xc0a0c0a = LayoutID) {
		return "SPA"
	}
  ; Add more cases for other layouts
  return Format("{:x}", LayoutID)
}

SwitchLocale(Locale=0) {
	ControlGetFocus, CtrlFocus, A
	if (Locale = "EN") {
		PostMessage, WM_INPUTLANGCHANGEREQUEST := 0x50,, 0x4090409, %CtrlFocus%, A
	} else if (Locale = "EN") {
		PostMessage, WM_INPUTLANGCHANGEREQUEST := 0x50,, 0x4190419, %CtrlFocus%, A
	} else {
		PostMessage, WM_INPUTLANGCHANGEREQUEST := 0x50, 2, 0, %CtrlFocus%, A
	}
	; PostMessage, 0x50, 2, 0,, A 
	; SetFormat, Integer, H
	ShowLayout()
}


Dbg(Text,Sleep=5000) {
	ToolTip(Text,,, Sleep)
	sleep %Sleep%
}
ToolTip(S, X="", Y="", msec=1000) {
  SetTimer, Off, %msec%
  ToolTip, %S%, %X%, %Y%
  return
  
  Off:
    ToolTip
    SetTimer, Off, Off
  return
}


Menu Case, Add
Menu Case, DeleteAll
Menu Case, Add, &UPPERCASE, CCase
Menu Case, Add, &lowercase, CCase
Menu Case, Add, &Title Case, CCase
Menu Case, Add, &Sentence case, CCase
Menu Case, Add
Menu Case, Add, &Fix Linebreaks, CCase
Menu Case, Add, &Reverse, CCase
Menu Case, Add
Menu Case, Add, &Remove Spaces, CCase

GetText(Txt)
If NOT ERRORLEVEL
  Menu Case, Show
Return

CCase:
p:=A_ThisMenuItemPos
If (p=1)
  StringUpper, Txt, Txt
Else If (p=2)
  StringLower, Txt, Txt
Else If (p=3)
  StringLower, Txt, Txt, T
Else If (p=4)
{
  StringLower, Txt, Txt
  Txt := RegExReplace(Txt, "((?:^|[.!?]\s+)[a-z])", "$u1")
}
Else If (p=6)
{
  Txt := RegExReplace(Txt, "\R", "`r`n")
}
Else If (p=7)
{
  Temp2 =
  StringReplace, Txt, Txt, `r`n, % Chr(29), All
  Loop Parse, Txt
    Temp2 := A_LoopField . Temp2
  StringReplace, Txt, Temp2, % Chr(29), `r`n, All
}
Else If (p=9)
{
  Loop 
  { 
  StringReplace, Txt, Txt, %A_Space%%A_Space%, %A_Space%, UseErrorLevel 
  if ErrorLevel = 0  
    break 
  }
}
PutText(Txt)
Return

GetText(ByRef MyText = "") {
  SavedClip := ClipboardAll
  Clipboard =
  Send ^{vk43} ;Ctrl C
  ClipWait 0.5
  If ERRORLEVEL
  {
    Clipboard := SavedClip
    MyText =
    Return
  }
  MyText := Clipboard
  Clipboard := SavedClip
  Return MyText
}

  PutText(MyText) {
    SavedClip := ClipboardAll 
    Clipboard =
    Sleep 20
    Clipboard := MyText
    Send ^{vk56} ;Ctrl V
    Sleep 100
    Clipboard := SavedClip
    Return
  }

; }
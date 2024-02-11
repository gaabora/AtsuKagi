OutputDebug(params*) {
	tickCount := A_TickCount
	text := ""
  if (params.Length() = 1) {
    text := params[1]
  } else {
    sep := "`t"
    for index,param in params
      text .= param . sep
  }
	FormatTime, time, , hh:mm:ss
	ms := Mod(tickCount, 1000)
	text := time . "." . Format("{:03d}", ms) . ": " . text
	OutputDebug, %text%
}

GetWindowClass(hwnd:=0) {
	if (hwnd=0)
		WinGet, hwnd, ID, A
	WinGetClass, className, ahk_id %hwnd%
	return ahk_class className
}

ExtractHotkeyInfo(hotkeyString) {
	SPECIAL_REGEX := "(~|\$|\*)"
	MODIFIER_REGEX := "(<\^>!|<!|>!|<#|>#|<\^|>\^|<\+|>\+|!|#|\^|\+)"

	result := {}
	result.special := RegexMatchGlobal(hotkeyString, SPECIAL_REGEX)
	result.modifiers := RegexMatchGlobal(hotkeyString, MODIFIER_REGEX)
	result.customModifier := ""

	cleanedHotkey := hotkeyString
	for idx in result.special
		cleanedHotkey := StrReplace(cleanedHotkey, result.special[idx])
	for idx in result.modifiers
		cleanedHotkey := StrReplace(cleanedHotkey, result.modifiers[idx])

	customCombination := StrSplit(cleanedHotkey, " & ")
	if (customCombination.Length() = 2) {
		result.customModifier := customCombination[1]
		result.key := customCombination[2]
	} else {
		result.key := cleanedHotkey
	}

	return result
}

ConvertToUniversalVkHotkey(KeyCombination) {
  k := ExtractHotkeyInfo(KeyCombination)
  if (StrLen(k.key) = 1) {
    modifiersStr := ""
    for _, modifier in k.modifiers
      modifiersStr .= modifier
    result := k.special . modifiersStr . (k.customModifier ? k.customModifier . " & " : "") . Format("vk{:X}", GetKeyVK(k.key))
    return result
  }
  return KeyCombination
}

CheckHotkeyForErrors(KeyCombination) {
  Hotkey, %KeyCombination%,, Off UseErrorLevel                                               
  return GetHotkeyBindingErrorText(ErrorLevel)
}

GetHotkeyBindingErrorText(ErrorLvl) {
  Switch ErrorLvl	{
		Case 1:
			return "The Label parameter specifies a nonexistent label name."
		Case 2:
			return "The KeyName parameter specifies one or more keys that are either not recognized or not supported by the current keyboard layout/language."
		Case 3:
			return "Unsupported prefix key. For example, using the mouse wheel as a prefix in a hotkey such as WheelDown & Enter is not supported."
		Case 4:
			return "The KeyName parameter is not suitable for use with the AltTab or ShiftAltTab actions. A combination of (at most) two keys is required. For example: RControl & RShift::AltTab."
		Case 5:
			return "The command attempted to modify a nonexistent hotkey."
		Case 6:
			return "The command attempted to modify a nonexistent variant of an existing hotkey. To solve this, use Hotkey IfWin to set the criteria to match those of the hotkey to be modified."
		Case 98:
			return "Creating this hotkey would exceed the limit of hotkeys per script (however, each hotkey can have an unlimited number of variants, and there is no limit to the number of hotstrings). The limit was raised from 700 to 1000 in [v1.0.48], and to 32762 in [v1.1.30]."
		Case 99:
			return "Out of memory. This is very rare and usually happens only when the operating system has become unstable."
	}
	return 0
}

RegexMatchGlobal(Haystack, NeedleRegEx) {
	matches := []
	pos := 1
	while (pos := RegExMatch(Haystack, NeedleRegEx, match, pos + StrLen(match)))
		matches.Push(match)
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
	SetBatchLines, -1 ; Disable line batch to ensure timely execution
	result := ""
	for index, element in arr
		result := result . (index > 1 ? delimiter : "") . element
	return result
}

IsValidHexColor(hexColor) {
	return RegExMatch(hexColor, "0x[0-9A-Fa-f]{6}") ? true : false
}

IsMouseOverTaskbar() {
	MouseGetPos,,, hwnd
	hoverTaskbar := WinExist("ahk_class Shell_TrayWnd ahk_id " hwnd)
	hoverSecondaryTaskbar := WinExist("ahk_class Shell_SecondaryTrayWnd ahk_id " hwnd)
	return hoverTaskbar || hoverSecondaryTaskbar
}

GetCurrentScreenBorders(ByRef CurrentScreenLeft, ByRef CurrentScreenRight, ByRef CurrentScreenTop, ByRef CurrentScreenBottom) {
  MouseGetPos, xMouse, yMouse
  SysGet, MonitorCount, MonitorCount
  Loop, %MonitorCount% {
    SysGet, MonitorWorkArea, MonitorWorkArea, %A_Index%
    if (xMouse >= MonitorWorkAreaLeft) AND (xMouse <= MonitorWorkAreaRight) AND ( yMouse >= MonitorWorkAreaTop) AND ( yMouse <= MonitorWorkAreaBottom) {
      CurrentScreenLeft   := MonitorWorkAreaLeft
      CurrentScreenRight  := MonitorWorkAreaRight
      CurrentScreenTop    := MonitorWorkAreaTop
      CurrentScreenBottom := MonitorWorkAreaBottom
      break
    }
  }
}

GetHoveredWindowAreaCode() {
	CoordMode, Mouse, Screen 
	MouseGetPos, x, y, hwnd
	WM_NCHITTEST := 0x84
	SendMessage, WM_NCHITTEST, 0, (x & 0xFFFF) | (y & 0xFFFF) << 16,, ahk_id %hwnd%
	return 1 * ErrorLevel
}

IsMouseOverWindowTitlebar() {
	areaCode := GetHoveredWindowAreaCode()
	return (areaCode = 2 || areaCode = 3 || areaCode = 8 || areaCode = 9 || areaCode = 20 || areaCode = 21) && !IsMouseOverTaskbar()
}

IsMouseOverWindowAnyBorder() {
	areaCode := GetHoveredWindowAreaCode()
	return (areaCode >= 10 && areaCode <= 18) && !IsMouseOverTaskbar()
}

IsMouseOverWindowResizableBorder() {
	areaCode := GetHoveredWindowAreaCode()
	return (areaCode >= 10 && areaCode <= 17) && !IsMouseOverTaskbar()
}

GetHoveredAreaName() {
	if (IsMouseOverTaskbar())
		return "TASKBAR"
	areaCode := GetHoveredWindowAreaCode()
	Switch areaCode	{
		Case -2:	; HTERROR             (-2)			On the screen background or on a dividing line between windows (same as HTNOWHERE, except that the DefWindowProc function produces a system beep to indicate an error).
			return "ERROR"
		Case -1:	; HTTRANSPARENT       (-1)			In a window currently covered by another window in the same thread (the message will be sent to underlying windows in the same thread until one of them returns a code that is not HTTRANSPARENT).
			return "TRANSPARENT"
		Case 0:		; HTNOWHERE           0				On the screen background or on a dividing line between windows.
			return "NOWHERE"
		Case 1:		; HTCLIENT            1				In a client area.
			return "CLIENT"
		Case 2:		; HTCAPTION           2				In a title bar.
			return "CAPTION"
		Case 3:		; HTSYSMENU           3				In a window menu or in a Close button in a child window.
			return "SYSMENU"
		Case 4:		; HTGROWBOX or HTSIZE 4				In a size box (same as HTSIZE).
			return "GROWBOX"
		Case 5:		; HTMENU              5				In a menu (works for basic menus like notepad, not for menu **bars like in MS Word)
			return "MENU"
		Case 6:		; HTHSCROLL           6				In a horizontal scroll bar.
			return "HSCROLL"
		Case 7:		; HTVSCROLL           7				In the vertical scroll bar.
			return "VSCROLL"
		Case 8:		; HTMINBUTTON         8				In a Minimize button.
			return "MINBUTTON"
		Case 9:		; HTMAXBUTTON         9				In a Maximize button.
			return "MAXBUTTON"
		Case 10:	; HTLEFT              10			In the left border of a resizable window (the user can click the mouse to resize the window horizontally).
			return "LEFT"
		Case 11:	; HTRIGHT             11			In the right border of a resizable window (the user can click the mouse to resize the window horizontally).
			return "RIGHT"
		Case 12:	; HTTOP               12			In the upper-horizontal border of a window.
			return "TOP"
		Case 13:	; HTTOPLEFT           13			In the upper-left corner of a window border.
			return "TOPLEFT"
		Case 14:	; HTTOPRIGHT          14			In the upper-right corner of a window border.
			return "TOPRIGHT"
		Case 15:	; HTBOTTOM            15			In the lower-horizontal border of a resizable window (the user can click the mouse to resize the window vertically).
			return "BOTTOM"
		Case 16:	; HTBOTTOMLEFT        16			In the lower-left corner of a border of a resizable window (the user can click the mouse to resize the window diagonally).
			return "BOTTOMLEFT"
		Case 17:	; HTBOTTOMRIGHT       17			In the lower-right corner of a border of a resizable window (the user can click the mouse to resize the window diagonally).
			return "BOTTOMRIGHT"
		Case 18:	; HTBORDER            18			In the border of a window that does not have a sizing border.
			return "BORDER"
		Case 20:	; HTCLOSE             20			In a Close button.
			return "CLOSE"
		Case 21:	; HTHELP              21			In a Help button.
			return "HELP"
		Default:
			return "UNKNOWN_" ErrorLevel
	}
}

FormatBinary(ByRef binaryData, groupBytes:=1) {
	static CRYPT_STRING_HEX := 0x40000000
	static CRYPT_STRING_NOCR := 0x00000004
  Local flags := CRYPT_STRING_HEX | CRYPT_STRING_NOCR
	Local binarySize := VarSetCapacity(binaryData)
	Local hexBufferSize := (binarySize * (flags ? 3 : 2)) * (A_IsUnicode ? 2 : 1)
	Local buffer := VarSetCapacity(hexString, hexBufferSize, 0)
	
	DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &binaryData, "Int", binarySize, "Int", flags ? flags : 12, "Str", hexString, "UIntP", hexBufferSize)

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
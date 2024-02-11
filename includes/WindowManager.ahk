class WindowManager extends AKPlugin {
  __ConfigHelp() {
    ; TODO
    return []
  }

  __UsageHelp() {
    return ""
  }

	__ActionsHelp() {
		texts := []
		texts["GetWindowList"] :=							"GetWindowList()"
		texts["ShowHoveredWindowInfo"] :=							"ShowHoveredWindowInfo()"
		texts["ShowResizeWindowDialog"] :=						"ShowResizeWindowDialog(hwnd:=0)"
		texts["MinimizeWindow"] :=										"MinimizeWindow(hwnd:=0)"
		texts["MinimizeHoveredWindow"] :=							"MinimizeHoveredWindow()"
		texts["CloseWindow"] :=												"CloseWindow(hwnd:=0)"
		texts["CloseHoveredWindow"] :=								"CloseHoveredWindow()"
		texts["ToggleWindowMaximized"] :=							"ToggleWindowMaximized(hwnd:=0)"
		texts["ToggleHoveredWindowMaximized"] :=			"ToggleHoveredWindowMaximized()"
		texts["ToggleHoveredWindowOnTop"] :=					"ToggleHoveredWindowOnTop(BorderColor:=-1)"
		texts["ToggleWindowOnTop"] :=									"ToggleWindowOnTop(BorderColor:=-1, hwnd:=0)"
		texts["ToggleWindowFullScreen"] :=						"ToggleWindowFullScreen(hwnd:=0)"
		texts["ToggleHoveredWindowFullScreen"] :=			"ToggleHoveredWindowFullScreen()"
		texts["ToggleWindowFrame"] :=									"ToggleWindowFrame(hwnd:=0)"
		texts["ToggleHoveredWindowFrame"] :=					"ToggleHoveredWindowFrame()"
		texts["ToggleWindowTransparency"] :=					"ToggleWindowTransparency(TransparencyValue:=128, hwnd:=0)"
		texts["ToggleHoveredWindowTransparency"] :=		"ToggleHoveredWindowTransparency(TransparencyValue:=128)"
		texts["IncreaseWindowTransparency"] :=				"IncreaseWindowTransparency(ByValue:=32, hwnd:=0)"
		texts["IncreaseHoveredWindowTransparency"] :=	"IncreaseHoveredWindowTransparency(ByValue:=32)"
		texts["DecreaseWindowTransparency"] :=				"DecreaseWindowTransparency(ByValue:=32, hwnd:=0)"
		texts["DecreaseHoveredWindowTransparency"] :=	"DecreaseHoveredWindowTransparency(ByValue:=32)"
		texts["SetWindowBorderColor"] :=							"SetWindowBorderColor(color:=-1, hwnd:=0)"
		return texts
	}
	
	ShowHoveredWindowInfo() { ;;;
		MouseGetPos,,, hwnd
		WinGet, vPName, ProcessName, % "ahk_id " hWnd
		WinGet, vPPath, ProcessPath, % "ahk_id " hWnd
		WinGet, vPID, PID, % "ahk_id " hWnd
		;Win32_Process class - Windows applications | Microsoft Docs https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process
		oWMI := ComObjGet("winmgmts:")
		oQueryEnum := oWMI.ExecQuery("Select * from Win32_Process where ProcessId=" vPID)._NewEnum()
		if oQueryEnum[oProcess]
			vCmdLn := oProcess.CommandLine
			, vPPath32 := oProcess.ExecutablePath
		oWMI := oQueryEnum := oProcess := ""

		this.showNotice("WindowClass: "  GetWindowClass(hwnd) "`nHoveredArea: " GetHoveredAreaName() "`nPID" vPID "`nProcessName: " vPName "`nProcessPath:`n" vPPath ((vPPath != vPPath32) ? "`n" vPPath32 : "") "`nCommandLine: " vCmdLn)
		return
	}

	GetWindowList() { ;;;
		WinGet, windowList, List  ;get the list of all windows
		; Sendinput, #m  ;mimimize all windows by using the windows shortcut win+m
		; sleep, 200
		text := ""
		Loop % windowList {
				WinGet, fileName, ProcessName, % "ahk_id " windowList%A_Index%
				WinGet, minMaxState, MinMax, % "ahk_id " windowList%A_Index%
				WinGet, minMaxState, MinMax, % "ahk_id " windowList%A_Index%
				WinGetClass, className, ahk_id %hwnd%
				text .= fileName " class=" className ", minMax=" minMaxState "`n"
		}
		this.ToolTip(text,,,6000) 
	}

	ShowResizeWindowDialog(hwnd:=0) { ;;;
		static SelectedWindowHWND := 0
		static OldW := 0
		static OldH := 0
		static NewW := 0
		static NewH := 0

		WinGet, SelectedWindowHWND, ID, % hwnd ? "ahk_id " . hwnd : "A"

		WinGet, IsMaximized, MinMax, ahk_id %SelectedWindowHWND%
		
		if (IsMaximized) {
			WinRestore, ahk_id %SelectedWindowHWND% ; restore, cause can not resize maximized
		}

		WinGetPos, OldX, OldY, OldW, OldH, ahk_id %SelectedWindowHWND%

		DialogTitle := "Set window size"

		if (WinActive(DialogTitle)) {
			Gui, ResizeDialog: Destroy
			return
		}

		Gui, ResizeDialog: New
		Gui, ResizeDialog: +ToolWindow +AlwaysOnTop
		
		Gui, ResizeDialog: Add, Edit, w50 number right
		Gui, ResizeDialog: Add, UpDown, gApply vNewW Range24-9999, % OldW
		
		Gui, ResizeDialog: Add, Edit, ys w50 number right
		Gui, ResizeDialog: Add, UpDown, gApply vNewH Range24-9999, % OldH

		Gui, ResizeDialog: Add, Button, ys gApply Default, Apply
		Gui, ResizeDialog: Add, Button, ys gRevert, Revert

		Gui, ResizeDialog: Show, , % DialogTitle

		Return

		ResizeDialogGuiEscape:
			Gui, ResizeDialog: Destroy 
		return

		Apply:
				Gui, Submit, NoHide
				WinMove, ahk_id %SelectedWindowHWND%,,,, NewW, NewH
		return

		Revert:
				WinMove, ahk_id %SelectedWindowHWND%,,,, OldW, OldH
				Gui, ResizeDialog: Destroy
		return
	}

	MinimizeWindow(hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		PostMessage, 0x112, 0xF020,,, ahk_id %hwnd% ; 0x112 = WM_SYSCOMMAND, 0xF020 = SC_MINIMIZE
		; WinMinimize, ahk_id %hwnd%
		this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd))
	}

	MinimizeHoveredWindow() { ;;;
		MouseGetPos,,, hwnd
		this.MinimizeWindow(hwnd)	
	}
	
	CloseWindow(hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		WinClose, ahk_id %hwnd%
		this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd))
	}

	CloseHoveredWindow() { ;;;
		MouseGetPos,,, hwnd
		this.CloseWindow(hwnd)	
	}

	ToggleWindowMaximized(hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		WinGet maximized, MinMax, ahk_id %hwnd%
		if (maximized) {
			WinRestore, ahk_id %hwnd%
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		} else {
			WinMaximize, ahk_id %hwnd%
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		}
	}

	ToggleHoveredWindowMaximized() { ;;;
		MouseGetPos,,, hwnd
		this.ToggleWindowMaximized(hwnd)	
	}

	ToggleHoveredWindowOnTop(BorderColor:=-1) { ;;;
		MouseGetPos,,, hwnd
		this.ToggleWindowOnTop(hwnd)	
	}
	ToggleWindowOnTop(BorderColor:=-1, hwnd:=0) { ;;;
		HexColor := (BorderColor = -1) ? 0x00FFFF : BorderColor

		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}

		WinGet, windowStyle, ExStyle, % "ahk_id " . hwnd
		if (windowStyle & 0x8) { ; 0x8 is WS_EX_TOPMOST.
				WinSet, AlwaysOnTop, Off, % "ahk_id " . hwnd
				this.SetWindowBorderColor(,hwnd)
				this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
			} else {
				WinSet, AlwaysOnTop, On, % "ahk_id " . hwnd
				this.SetWindowBorderColor(HexColor, hwnd)
				this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		}
	}

	ToggleWindowFullScreen(hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}

		WinGet, style, Style, ahk_id %hwnd%	
		WinGet, maximized, MinMax, ahk_id %hwnd%

		if (style & 0xC40000) != 0xC40000 { ; WS_CAPTION|WS_SIZEBOX is removed
			WinSet, Style, +0xC40000, ahk_id %hwnd%	; Restore WS_CAPTION|WS_SIZEBOX.
			WinRestore, ahk_id %hwnd%
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		} else {
			if (maximized) {
				WinRestore, ahk_id %hwnd%
			}
			WinSet, Style, -0xC40000, ahk_id %hwnd%	; Remove WS_CAPTION|WS_SIZEBOX.
			WinMaximize, ahk_id %hwnd%
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		}
	}

	ToggleHoveredWindowFullScreen() { ;;;
		MouseGetPos,,, hwnd
		this.ToggleWindowFullScreen(hwnd)	
	}


	ToggleWindowFrame(hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}

		WinGet, style, Style, ahk_id %hwnd%	
		WinGetPos, Xpos, Ypos, Width, Height, ahk_id %hwnd%
		
		if (style & 0xC40000) != 0xC40000 { ; WS_CAPTION|WS_SIZEBOX is removed
			WinSet, Style, +0xC40000, ahk_id %hwnd%	; Restore WS_CAPTION|WS_SIZEBOX.
			WinMove, ahk_id %hwnd%,,Xpos, Ypos, Width, Height
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		} else {
			WinSet, Style, -0xC40000, ahk_id %hwnd%	; Remove WS_CAPTION|WS_SIZEBOX.
			WinMove, ahk_id %hwnd%,,Xpos, Ypos, Width, Height
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		}
	}

	ToggleHoveredWindowFrame() { ;;;
		MouseGetPos,,, hwnd
		this.ToggleWindowFrame(hwnd)	
	}


	ToggleWindowTransparency(TransparencyValue:=128, hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		WinGet, Transparency, Transparent, % "ahk_id " . hwnd
		if (Transparency = "") {
			WinSet, Transparent, % TransparencyValue, % "ahk_id " . hwnd
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		} else {
			WinSet, Transparent, OFF, % "ahk_id " . hwnd
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		}
	}

	ToggleHoveredWindowTransparency(TransparencyValue:=128) { ;;;
		MouseGetPos,,, hwnd
		this.ToggleWindowTransparency(TransparencyValue, hwnd)	
	}

	IncreaseWindowTransparency(ByValue:=32, hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		DetectHiddenWindows, on
		WinGet, Transparency, Transparent, % "ahk_id " . hwnd
		if (Transparency = "")
			Transparency := 255
		Transparency := Transparency + ByValue
		if (Transparency > 255 || Transparency < 0) 
			Transparency := 255
		this.ShowInfo(Transparency)
		WinSet, Transparent, %Transparency%, % "ahk_id " . hwnd
	}

	IncreaseHoveredWindowTransparency(ByValue:=32) { ;;;
		MouseGetPos,,, hwnd
		this.IncreaseWindowTransparency(ByValue, hwnd)	
	}

	DecreaseWindowTransparency(ByValue:=32, hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		DetectHiddenWindows, on
		WinGet, Transparency, Transparent, % "ahk_id " . hwnd
		if (Transparency = "")
			Transparency := 255
		Transparency := Transparency - ByValue
		if (Transparency > 255 || Transparency < ByValue) 
			Transparency := ByValue
		this.ShowInfo(Transparency)
		WinSet, Transparent, %Transparency%, % "ahk_id " . hwnd
	}

	DecreaseHoveredWindowTransparency(ByValue:=32) { ;;;
		MouseGetPos,,, hwnd
		this.DecreaseWindowTransparency(ByValue, hwnd)	
	}

	SetWindowBorderColor(color:=-1, hwnd:=0) { ;;;
		if (hwnd=0)
			WinGet, hwnd, ID, A
		DWMWA_BORDER_COLOR := 34
		R := (color & 0xFF0000) >> 16
		G := (color & 0xFF00) >> 8
		B := (color & 0xFF)
		newColor := (B << 16) | (G << 8) | R
		DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", DWMWA_BORDER_COLOR, "int*", (color = -1) ? 0xFFFFFFFF : newColor, "int", 4)
	}

	; builtin in win10+ todo if ever need win 7 support
	; FocuslessScroll(scrollStep:=120) { ; -120 for other direction
  ;   Critical
	; 	WM_MOUSEACTIVATE := 0x20A
  ;   MouseGetPos, xMou, yMou, WinID, Control1
  ;   MouseGetPos,,,, Control2, 2
  ;   MouseGetPos,,,, Control3, 3
  ;   ;TrayTip,, winid %WinID%   ctl1 _%Control1%_   ctl2 _%Control2%_   ctl3 _%Control3%_

  ;   wParam := scrollStep << 16
  ;   If(GetKeyState("Shift", "P"))
  ;       wParam := wParam | 0x4
  ;   If(GetKeyState("Ctrl", "P"))
  ;       wParam := wParam | 0x8

  ;   if (Control2 = "") {
	; 		PostMessage, WM_MOUSEACTIVATE, wParam, (yMou << 16) | (xMou &0xFFFF),, ahk_id %WinID%  ; SendMessage does not work for TotalCommander Lister
  ;   } else {
	; 		if (Control2 != Control3)
	; 			SendMessage, WM_MOUSEACTIVATE, wParam, (yMou << 16) | (xMou &0xFFFF),, ahk_id %Control3%
	; 		else
	; 			SendMessage, WM_MOUSEACTIVATE, wParam, (yMou << 16) | (xMou &0xFFFF),, ahk_id %Control2%
  ;   }
	; }

	getFunctionExecutedMessage(fnName, hwnd, state:="") {
		return this.beautifyActionName(fnName) " " (state="" ? "" : " " state " ") this.getWindowDescription(hwnd)
	}

	getFunctionDisabledMessage(fnName, hwnd) {
		return this.beautifyActionName(fnName) " disabled for blacklisted " this.getWindowDescription(hwnd)
	}

	getWindowDescription(hwnd) {
		windowClass := GetWindowClass(hwnd)
		WinGet, vPName, ProcessName, % "ahk_id " hWnd
		return vPName " (" windowClass ")"
	}
}
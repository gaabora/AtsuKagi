class WindowManager extends AKPlugin {
  __ConfigHelp() {
    ; TODO
    return []
  }

  __UsageHelp() {
    return ""
  }

	__ActionsHelp() {
		texts := Map()
		texts["ShowWindowList"] :=							      "ShowWindowList()"
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
		MouseGetPos(,, &hwnd)
		vPName := WinGetProcessName("ahk_id " hwnd)
		vPPath := WinGetProcessPath("ahk_id " hwnd)
		vPID := WinGetPID("ahk_id " hwnd)
		;Win32_Process class - Windows applications | Microsoft Docs https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process
		oWMI := ComObjGet("winmgmts:")
		oQueryEnum := oWMI.ExecQuery("Select * from Win32_Process where ProcessId=" vPID)._NewEnum()
		if oQueryEnum[oProcess]
			vCmdLn := oProcess.CommandLine			, vPPath32 := oProcess.ExecutablePath
		oWMI := oQueryEnum := oProcess := ""

		this.showNotice("WindowClass: "  GetWindowClass(hwnd) "`nHoveredArea: " GetHoveredAreaName() "`nPID" vPID "`nProcessName: " vPName "`nProcessPath:`n" vPPath ((vPPath != vPPath32) ? "`n" vPPath32 : "") "`nCommandLine: " vCmdLn)
		return
	}

	ShowWindowList() { ;;;
		windowList := WinGetList()
		text := ""
		For hwnd in windowList { 
			fileName := WinGetProcessName("ahk_id " hwnd)
			minMaxState := WinGetMinMax("ahk_id " hwnd)
			minMaxState := WinGetMinMax("ahk_id " hwnd)
			className := WinGetClass("ahk_id " hwnd)
			text .= fileName " class=" className ", minMax=" minMaxState "`n"
		}
		this.showNotice(text) 
	}

	ShowResizeWindowDialog(hwnd:=0) { ;;;
		static SelectedWindowhwnd := 0
		static OldW := 0
		static OldH := 0
		static NewW := 0
		static NewH := 0

		SelectedWindowhwnd := WinGetID(hwnd ? "ahk_id " . hwnd : "A")

		IsMaximized := WinGetMinMax("ahk_id " SelectedWindowhwnd)
		
		if (IsMaximized) {
			WinRestore("ahk_id " SelectedWindowhwnd) ; restore, cause can not resize maximized
		}

		WinGetPos(&OldX, &OldY, &OldW, &OldH, "ahk_id " SelectedWindowhwnd)

		DialogTitle := "Set window size"

		if (WinActive(DialogTitle)) {
			ResizeDialog := Gui()
			ResizeDialog.OnEvent("Escape", ResizeDialogGuiEscape)
			ResizeDialog.Destroy()
			return
		}

		ResizeDialog.New()
		ResizeDialog.Opt("+ToolWindow +AlwaysOnTop")
		
		ResizeDialog.Add("Edit", "w50 number right")
		ResizeDialog.Add("UpDown", "vNewW Range24-9999", OldW)
			.OnEvent("Change", Apply.Bind("Change"))
		
		ResizeDialog.Add("Edit", "ys w50 number right")
		ResizeDialog.Add("UpDown", "vNewH Range24-9999", OldH)
			.OnEvent("Change", Apply.Bind("Change"))

		ResizeDialog.Add("Button", "ys  Default", "Apply")
			.OnEvent("Change", Apply.Bind("Change"))
		ResizeDialog.Add("Button", "ys", "Revert")
			.OnEvent("Change", Revert.Bind("Change"))

		ResizeDialog.Show(, DialogTitle)

		Return

		ResizeDialogGuiEscape(){
			ResizeDialog.Destroy()
		}

		Apply(A_GuiEvent, GuiCtrlObj, Info) {
			oSaved := ResizeDialog.Submit("0")
			NewW := oSaved.NewW
			NewH := oSaved.NewH
			WinMove(,,NewW, NewH, "ahk_id " SelectedWindowhwnd)
		}

		Revert(A_GuiEvent, GuiCtrlObj, Info) {
				WinMove(,,OldW, OldH, "ahk_id " SelectedWindowhwnd)
				ResizeDialog.Destroy()
		}
	}

	MinimizeWindow(hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		PostMessage(0x112, 0xF020,,, "ahk_id " hwnd) ; 0x112 = WM_SYSCOMMAND, 0xF020 = SC_MINIMIZE
		; WinMinimize, ahk_id %hwnd%
		this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd))
	}

	MinimizeHoveredWindow() { ;;;
		MouseGetPos(,, &hwnd)
		this.MinimizeWindow(hwnd)	
	}
	
	CloseWindow(hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		WinClose("ahk_id " hwnd)
		this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd))
	}

	CloseHoveredWindow() { ;;;
		MouseGetPos(,, &hwnd)
		this.CloseWindow(hwnd)	
	}

	ToggleWindowMaximized(hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		maximized := WinGetMinMax("ahk_id " hwnd)
		if (maximized) {
			WinRestore("ahk_id " hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		} else {
			WinMaximize("ahk_id " hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		}
	}

	ToggleHoveredWindowMaximized() { ;;;
		MouseGetPos(,, &hwnd)
		this.ToggleWindowMaximized(hwnd)	
	}

	ToggleHoveredWindowOnTop(BorderColor:=-1) { ;;;
		MouseGetPos(,, &hwnd)
		this.ToggleWindowOnTop(hwnd)	
	}
	ToggleWindowOnTop(BorderColor:=-1, hwnd:=0) { ;;;
		HexColor := (BorderColor = -1) ? 0x00FFFF : BorderColor

		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}

		windowStyle := WinGetExStyle("ahk_id " . hwnd)
		if (windowStyle & 0x8) { ; 0x8 is WS_EX_TOPMOST.
				WinSetAlwaysOnTop(False, "ahk_id " . hwnd)
				this.SetWindowBorderColor(,hwnd)
				this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
			} else {
				WinSetAlwaysOnTop(True, "ahk_id " . hwnd)
				this.SetWindowBorderColor(HexColor, hwnd)
				this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		}
	}

	ToggleWindowFullScreen(hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}

		style := WinGetStyle("ahk_id " hwnd)
		maximized := WinGetMinMax("ahk_id " hwnd)

		if (style & 0xC40000) != 0xC40000 { ; WS_CAPTION|WS_SIZEBOX is removed
			WinSetStyle(+0xC40000, "ahk_id " hwnd)	; Restore WS_CAPTION|WS_SIZEBOX.
			WinRestore("ahk_id " hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		} else {
			if (maximized) {
				WinRestore("ahk_id " hwnd)
			}
			WinSetStyle(-0xC40000, "ahk_id " hwnd)	; Remove WS_CAPTION|WS_SIZEBOX.
			WinMaximize("ahk_id " hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		}
	}

	ToggleHoveredWindowFullScreen() { ;;;
		MouseGetPos(,, &hwnd)
		this.ToggleWindowFullScreen(hwnd)	
	}


	ToggleWindowFrame(hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}

		style := WinGetStyle("ahk_id " hwnd)
		WinGetPos(&Xpos, &Ypos, &Width, &Height, "ahk_id " hwnd)
		
		if (style & 0xC40000) != 0xC40000 { ; WS_CAPTION|WS_SIZEBOX is removed
			WinSetStyle(+0xC40000, "ahk_id " hwnd)	; Restore WS_CAPTION|WS_SIZEBOX.
			WinMove(Xpos, Ypos, Width, Height, "ahk_id " hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		} else {
			WinSetStyle(-0xC40000, "ahk_id " hwnd)	; Remove WS_CAPTION|WS_SIZEBOX.
			WinMove(Xpos, Ypos, Width, Height, "ahk_id " hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		}
	}

	ToggleHoveredWindowFrame() { ;;;
		MouseGetPos(,, &hwnd)
		this.ToggleWindowFrame(hwnd)	
	}


	ToggleWindowTransparency(TransparencyValue:=128, hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		Transparency := WinGetTransparent("ahk_id " . hwnd)
		if (Transparency = "") {
			WinSetTransparent(TransparencyValue, "ahk_id " . hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "ON"))
		} else {
			WinSetTransparent("OFF", "ahk_id " . hwnd)
			this.ShowInfo(this.getFunctionExecutedMessage(A_ThisFunc, hwnd, "OFF"))
		}
	}

	ToggleHoveredWindowTransparency(TransparencyValue:=128) { ;;;
		MouseGetPos(,, &hwnd)
		this.ToggleWindowTransparency(TransparencyValue, hwnd)	
	}

	IncreaseWindowTransparency(ByValue:=32, hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		DetectHiddenWindows(true)
		Transparency := WinGetTransparent("ahk_id " . hwnd)
		if (Transparency = "")
			Transparency := 255
		Transparency := Transparency + ByValue
		if (Transparency > 255 || Transparency < 0) 
			Transparency := 255
		this.ShowInfo(Transparency)
		WinSetTransparent(Transparency, "ahk_id " . hwnd)
	}

	IncreaseHoveredWindowTransparency(ByValue:=32) { ;;;
		MouseGetPos(,, &hwnd)
		this.IncreaseWindowTransparency(ByValue, hwnd)	
	}

	DecreaseWindowTransparency(ByValue:=32, hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
		if (this.IsWindowBlacklisted(hwnd, A_ThisFunc)) {
			this.ShowInfo(this.getFunctionDisabledMessage(A_ThisFunc, hwnd))
			return
		}
		DetectHiddenWindows(true)
		Transparency := WinGetTransparent("ahk_id " . hwnd)
		if (Transparency = "")
			Transparency := 255
		Transparency := Transparency - ByValue
		if (Transparency > 255 || Transparency < ByValue) 
			Transparency := ByValue
		this.ShowInfo(Transparency)
		WinSetTransparent(Transparency, "ahk_id " . hwnd)
	}

	DecreaseHoveredWindowTransparency(ByValue:=32) { ;;;
		MouseGetPos(,, &hwnd)
		this.DecreaseWindowTransparency(ByValue, hwnd)	
	}

	SetWindowBorderColor(color:=-1, hwnd:=0) { ;;;
		if (hwnd=0)
			hwnd := WinGetID("A")
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
		vPName := WinGetProcessName("ahk_id " hwnd)
		return vPName " (" windowClass ")"
	}
}

class WindowFlags {
  static HWND_TOPMOST := -1

  ; SetWindowPos flags (SWP_*)
  static SWP_ASYNCWINDOWPOS := 0x4000 ; If the calling thread and the thread that owns the window are attached to different input queues, the system posts the request to the thread that owns the window. This prevents the calling thread from blocking its execution while other threads process the request.
  static SWP_DEFERERASE := 0x2000 ; Prevents generation of the WM_SYNCPAINT message.
  static SWP_DRAWFRAME := 0x0020 ; Draws a frame (defined in the window's class description) around the window.
  static SWP_FRAMECHANGED := 0x0020 ; Applies new frame styles set using the SetWindowLong function. Sends a WM_NCCALCSIZE message to the window, even if the window's size is not being changed. If this flag is not specified, WM_NCCALCSIZE is sent only when the window's size is being changed.
  static SWP_HIDEWINDOW := 0x0080 ; Hides the window.
  static SWP_NOACTIVATE := 0x0010 ; Does not activate the window. If this flag is not set, the window is activated and moved to the top of either the topmost or non-topmost group (depending on the setting of the hWndInsertAfter parameter).
  static SWP_NOCOPYBITS := 0x0100 ; Discards the entire contents of the client area. If this flag is not specified, the valid contents of the client area are saved and copied back into the client area after the window is sized or repositioned.
  static SWP_NOMOVE := 0x0002 ; Retains the current position (ignores X and Y parameters).
  static SWP_NOOWNERZORDER := 0x0200 ; Does not change the owner window's position in the Z order.
  static SWP_NOREDRAW := 0x0008 ; Does not redraw changes. If this flag is set, no repainting of any kind occurs. This applies to the client area, the nonclient area (including the title bar and scroll bars), and any part of the parent window uncovered as a result of the window being moved. When this flag is set, the application must explicitly invalidate or redraw any parts of the window and parent window that need redrawing.
  static SWP_NOREPOSITION := 0x0200 ; Same as the SWP_NOOWNERZORDER flag.
  static SWP_NOSENDCHANGING := 0x0400 ; Prevents the window from receiving the WM_WINDOWPOSCHANGING message.
  static SWP_NOSIZE := 0x0001 ; Retains the current size (ignores the cx and cy parameters).
  static SWP_NOZORDER := 0x0004 ; Retains the current Z order (ignores the hWndInsertAfter parameter).
  static SWP_SHOWWINDOW := 0x0040 ; Displays the window. 

  ; Window styles (WS_*)
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

  ; Extended window styles (WS_EX_*)
  static WS_EX_TOOLWINDOW := 0x80
  static WS_EX_LAYERED := 0x08000000

  static GA_ROOT := 2
  static WM_GETMINMAXINFO := 0x0024
  static WM_NCHITTEST := 0x0084
  static SM_CXMINTRACK := 34
  static SM_CYMINTRACK := 35

  ; DWM window attributes (DWMWA_*)
  static DWMWA_TRANSITIONS_FORCEDISABLED := 3
  static DWMWA_EXTENDED_FRAME_BOUNDS := 9
  static DWMWA_CLOAK := 13
  static DWMWA_CLOAKED := 14
  static DWMWA_WINDOW_CORNER_PREFERENCE := 33
  static DWMWA_BORDER_COLOR := 34

  ; DWM window corner preference (DWMWCP_*)
  static DWMWCP_DEFAULT := 0
  static DWMWCP_DONOTROUND := 1
  static DWMWCP_ROUND := 2
  static DWMWCP_ROUNDSMALL := 3

  static DWM_COLOR_DEFAULT := 0xFFFFFFFF
}

class RedrawWindowFlags {
  static INVALIDATE := 0x0001
  static ERASE := 0x0004
  static ALLCHILDREN := 0x0080
  static UPDATENOW := 0x0100
}

class WinEventFlags {
  static OUTOFCONTEXT := 0x0000
}

class WinEventConstants {
  static EVENT_OBJECT_LOCATIONCHANGE := 0x800B
  static OBJID_WINDOW := 0
  static CHILDID_SELF := 0
}

class ShellHookCodes {
  static WINDOWCREATED := 1
  static WINDOWDESTROYED := 2
  static ACTIVATESHELLWINDOW := 3
  static WINDOWACTIVATED := 4
  static GETMINRECT := 5
  static REDRAW := 6
  static TASKMAN := 7
  static LANGUAGE := 8
  static SYSMENU := 9
  static ENDTASK := 10
  static ACCESSIBILITYSTATE := 11
  static APPCOMMAND := 12
  static WINDOWREPLACED := 13
  static WINDOWREPLACING := 14
  static HIGHBIT := 15
  static FLASH := 16
  static RUDEAPPACTIVATED := 17

  static Names := Map(
    1, "WINDOW_CREATED",
    2, "WINDOW_DESTROYED",
    3, "ACTIVATE_SHELL_WINDOW",
    4, "WINDOW_ACTIVATED",
    5, "GET_MIN_RECT",
    6, "REDRAW",
    7, "TASK_MAN",
    8, "LANGUAGE",
    9, "SYS_MENU",
    10, "END_TASK",
    11, "ACCESSIBILITY_STATE",
    12, "APP_COMMAND",
    13, "WINDOW_REPLACED",
    14, "WINDOW_REPLACING",
    15, "HIGH_BIT",
    16, "FLASH",
    17, "RUDE_APP_ACTIVATED"
  )
}

class KeyboardInputFlags {
  static WM_INPUTLANGCHANGEREQUEST := 0x0050
  static INPUTLANGCHANGE_SYSCHARSET := 1
}

class VirtualDesktopMessages {
  static CHANGE_DESKTOP := 0x1400 + 30
}

class TouchInputFlags {
  static TOUCH_FEEDBACK_DEFAULT := 0x1
  static TOUCH_FEEDBACK_INDIRECT := 0x2
  static TOUCH_FEEDBACK_NONE := 0x3

  static TOUCH_MASK_NONE                := 0x00000000 ; Default - none of the optional fields are valid
  static TOUCH_MASK_CONTACTAREA         := 0x00000001 ; The rcContact field is valid
  static TOUCH_MASK_ORIENTATION         := 0x00000002 ; The orientation field is valid
  static TOUCH_MASK_PRESSURE            := 0x00000004 ; The pressure field is valid
  static TOUCH_MASK_ALL                 := 0x00000007
  static POINTER_FLAG_NONE              := 0x00000000 ; Default
  static POINTER_FLAG_NEW               := 0x00000001 ; New pointer
  static POINTER_FLAG_INRANGE           := 0x00000002 ; Pointer has not departed
  static POINTER_FLAG_INCONTACT         := 0x00000004 ; Pointer is in contact
  static POINTER_FLAG_FIRSTBUTTON       := 0x00000010 ; Primary action
  static POINTER_FLAG_SECONDBUTTON      := 0x00000020 ; Secondary action
  static POINTER_FLAG_THIRDBUTTON       := 0x00000040 ; Third button
  static POINTER_FLAG_FOURTHBUTTON      := 0x00000080 ; Fourth button
  static POINTER_FLAG_FIFTHBUTTON       := 0x00000100 ; Fifth button
  static POINTER_FLAG_PRIMARY           := 0x00002000 ; Pointer is primary
  static POINTER_FLAG_CONFIDENCE        := 0x00004000 ; Pointer is considered unlikely to be accidental
  static POINTER_FLAG_CANCELED          := 0x00008000 ; Pointer is departing in an abnormal manner
  static POINTER_FLAG_DOWN              := 0x00010000 ; Pointer transitioned to down state (made contact)
  static POINTER_FLAG_UPDATE            := 0x00020000 ; Pointer update
  static POINTER_FLAG_UP                := 0x00040000 ; Pointer transitioned from down state (broke contact)
  static POINTER_FLAG_WHEEL             := 0x00080000 ; Vertical wheel
  static POINTER_FLAG_HWHEEL            := 0x00100000 ; Horizontal wheel
  static POINTER_FLAG_CAPTURECHANGED    := 0x00200000 ; Lost capture
  static POINTER_FLAG_HASTRANSFORM      := 0x00400000 ; Input has a transform associated with it
  static POINTER_INPUT_TYPE_PT_POINTER  := 1 ; Generic pointer
  static POINTER_INPUT_TYPE_PT_TOUCH    := 2 ; Touch
  static POINTER_INPUT_TYPE_PT_PEN      := 3 ; Pen
  static POINTER_INPUT_TYPE_PT_MOUSE    := 4 ; Mouse
  static POINTER_INPUT_TYPE_PT_TOUCHPAD := 5 ; Touchpad if(WINVER >= 0x0603)

  static TOUCH_FLAG_NONE := 0x00000000
}

class Win32Sizes {
  static DWORD := 4
}

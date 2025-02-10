/*
add extra tray icon
Flipeador https://www.autohotkey.com/boards/viewtopic.php?style=19&p=206577&sid=02efb7ec0ef512729f88e5db3e7066bc#p206577
    Before reading what is commented here, read the comments in the NotifyIcon_Add and NotifyIcon_Delete functions to understand better (FUNCTIONS #2).
*/


; Below we assign 0xBFFE to the first icon (1001) and 0xBFFF to the second, here we register it to call a function when an event occurs in this icon
OnMessage(0xBFFE, "Tray_Icon_1")
OnMessage(0xBFFF, "Tray_Icon_2")

; Load a predefined icon. Read https://msdn.microsoft.com/en-us/library/windows/desktop/bb775703(v=vs.85).aspx
; 32518 = IDI_SHIELD
DllCall("Comctl32.dll\LoadIconWithScaleDown", "Ptr", 0, "Ptr", 32518, "Int", SysGet(49), "Int", SysGet(49), "PtrP", HICON)

; We add two icons
NotifyIcon_Add(1001, 0xBFFE, HICON, "Tray Icon #1")
NotifyIcon_Add(1002, 0xBFFF, HICON, "Tray Icon #2")

; We can (and we should if we do not use it for something else) destroy the icon once call to the function NotifyIcon_Add
DllCall("User32.dll\DestroyIcon", "Ptr", HICON)

; message to stop the script and observe the added icons
MsgBox

; on exit, we must eliminate the added icons.
NotifyIcon_Delete(1001)
NotifyIcon_Delete(1002)
ExitApp




; ======================================================================================================================================================
; ======= FUNCTIONS #1
; ======================================================================================================================================================
Tray_Icon_1(wParam, lParam, msg, hwnd)
{
    If (lParam == 0x0204)    ; https://msdn.microsoft.com/en-us/library/windows/desktop/ms646242(v=vs.85).aspx
        MsgBox % "Tray_Icon_1 WM_RBUTTONDOWN"
}

Tray_Icon_2(wParam, lParam, msg, hwnd)
{
    If (lParam == 0x0204)
        MsgBox % "Tray_Icon_2 WM_RBUTTONDOWN"
}




; ======================================================================================================================================================
; ======= FUNCTIONS #2
; ======================================================================================================================================================
/*
    This function adds an icon to the taskbar notification area.
    These are the parameters:
        ID: The application-defined identifier of the taskbar icon to identify which icon to operate on when Shell_NotifyIcon is invoked.
        CallbackMessage: An application-defined message identifier. The system uses this identifier to send notification messages to your script.
                         When an event occurs, your script will receive this message, you need to use OnMessage to tell AHK what function to call when receiving this message.
                         All OnMessage functions receive 4 parameters (wParam, lParam, msg, hwnd), the values of these parameters depend on the received message.
                         You can see what values will take the parameters in the link https://msdn.microsoft.com/en-us/library/windows/desktop/bb773352(v=vs.85).aspx (see uCallbackMessage).
                         This value must be greater than 0x400. It is best to choose a number greater than 4096 (0x1000).
        HICON: is an identifier to an icon. Once you have called the function by passing this identifier, you can delete it (the icon is copied).
        Tip: String that specifies the text for a standard tooltip (text displayed when positioning the cursor over the icon). It can have a maximum of 63 character.
*/
NotifyIcon_Add(ID, CallbackMessage, HICON, Tip)
{
    Static NIF_MESSAGE := 0x00000001
        , NIF_ICON    := 0x00000002
        , NIF_TIP     := 0x00000004
        , TIP_MAXCHAR := 64 - 1

    ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb773352(v=vs.85).aspx
    ; NOTIFYICONDATA structure
    Local cbSize := VarSetCapacity(NOTIFYICONDATA, A_PtrSize == 4 ? 956 : 976, 0)    ; 8*4 + 3*A_PtrSize + 16 + (256+64+64)*2 ?
    NumPut(cbSize, &NOTIFYICONDATA, "UInt")    ; NOTIFYICONDATA.cbSize
    NumPut(A_ScriptHwnd, &NOTIFYICONDATA + A_PtrSize, "Ptr")    ; NOTIFYICONDATA.hWnd
    NumPut(ID, &NOTIFYICONDATA + A_PtrSize*2, "UInt")    ; NOTIFYICONDATA.uID
    NumPut(NIF_MESSAGE|NIF_ICON|NIF_TIP, &NOTIFYICONDATA + A_PtrSize*2 + 4, "UInt")    ; NOTIFYICONDATA.Flags
    NumPut(CallbackMessage, &NOTIFYICONDATA + A_PtrSize*2 + 4*2, "UInt")    ; NOTIFYICONDATA.uCallbackMessage
    NumPut(HICON, &NOTIFYICONDATA + A_PtrSize*2 + 4*2 + A_PtrSize, "Ptr")    ; NOTIFYICONDATA.hIcon
    StrPut(SubStr(Tip, 1, TIP_MAXCHAR), &NOTIFYICONDATA + A_PtrSize*2 + 4*2 + A_PtrSize*2, "UTF-16")

    Return DllCall("Shell32.dll\Shell_NotifyIconW", "UInt", 0, "UPtr", &NOTIFYICONDATA)
}

/*
    This function deletes an icon from the taskbar notification area.
    These are the parameters:
        ID: The identifier specified in NotifyIcon_Add().
    Remarks:
        If you do not delete the icons when your script exits, they will remain in the taskbar notification area.
*/
NotifyIcon_Delete(ID)
{
    Local cbSize := VarSetCapacity(NOTIFYICONDATA, A_PtrSize == 4 ? 956 : 976, 0)
    NumPut(cbSize, &NOTIFYICONDATA, "UInt")    ; NOTIFYICONDATA.cbSize
    NumPut(A_ScriptHwnd, &NOTIFYICONDATA + A_PtrSize, "Ptr")    ; NOTIFYICONDATA.hWnd
    NumPut(ID, &NOTIFYICONDATA + A_PtrSize*2, "UInt")    ; NOTIFYICONDATA.uID
    Return DllCall("Shell32.dll\Shell_NotifyIconW", "UInt", 2, "UPtr", &NOTIFYICONDATA)
}

SysGet(n) ; thanks ... ahk v1 ... ...
{
    SysGet o, % n
    Return o
}
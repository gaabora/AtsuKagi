#Requires AutoHotkey v2.0
#SingleInstance Off

if (A_Args.Length != 3)
  ExitApp(2)

windowHwnd := Integer(A_Args[1])
offscreenLeft := Integer(A_Args[2])
offscreenTop := Integer(A_Args[3])
SWP_NOSIZE := 0x0001
SWP_NOZORDER := 0x0004
SWP_NOACTIVATE := 0x0010
SWP_NOOWNERZORDER := 0x0200
SWP_NOSENDCHANGING := 0x0400
flags := SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOSENDCHANGING
succeeded := windowHwnd && DllCall("IsWindow", "Ptr", windowHwnd) && DllCall("SetWindowPos", "Ptr", windowHwnd, "Ptr", 0, "Int", offscreenLeft, "Int", offscreenTop, "Int", 0, "Int", 0, "UInt", flags)
ExitApp(succeeded ? 0 : 1)

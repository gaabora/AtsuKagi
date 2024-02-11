@echo off
setlocal enabledelayedexpansion

if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    set "AHK=tools\ahk\AutoHotkeyU32_UIA.exe"
) else (
    set "AHK=tools\ahk\AutoHotkeyU64_UIA.exe"
)


"%~dp0%AHK%" "%~dp0AtsuiKagi.ahk"

endlocal

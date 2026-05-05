/**
 * HotkeyRecorder - Low-level keyboard hook recorder for capturing hotkeys
 * 
 * Ports v1 Hotkey library logic (from tmp/Hotkey-master/Hotkey.ahk) to AHK v2
 * Captures keyboard, mouse, and joystick input at the system level
 * 
 * Usage:
 *   recorder := HotkeyRecorder()
 *   recorder.OnKeyRecorded := (raw, display) => MsgBox(display)
 *   recorder.StartRecording({keyboard: true, mouse: true, lrModifiers: true})
 *   ; ... wait for keys ...
 *   recorder.StopRecording()
 */

class HotkeyRecorder {
    
    ; ============================================================================
    ; STATIC LOOKUPS
    ; ============================================================================
    
    static MODIFIER_VK_MAP := Map(
        "vkA4", "LAlt",      "vkA5", "RAlt",
        "vkA2", "LCtrl",     "vkA3", "RCtrl",
        "vkA0", "LShift",    "vkA1", "RShift",
        "vk5B", "LWin",      "vk5C", "RWin"
    )
    
    static SYMBOL_VK_MAP := Map(
        "vkBB", "=",     "vkBC", ",",     "vkBD", "-",     "vkBE", ".",     "vkBF", "/",
        "vkC0", "``",    "vkBA", ";",     "vkDB", "[",     "vkDC", "\",     "vkDD", "]",
        "vkDE", "'"
    )
    
    static PREFIX_MAP := Map(
        "LAlt", "<!",      "RAlt", ">!",
        "LCtrl", "<^",     "RCtrl", ">^",
        "LShift", "<+",    "RShift", ">+",
        "LWin", "<#",      "RWin", ">#"
    )
    
    static WH_KEYBOARD_LL := 13
    static WH_MOUSE_LL := 14
    static WM_KEYDOWN := 0x100
    static WM_KEYUP := 0x101
    static WM_SYSKEYDOWN := 0x104
    static WM_SYSKEYUP := 0x105
    static WM_LBUTTONDOWN := 0x201
    static WM_LBUTTONUP := 0x202
    static WM_RBUTTONDOWN := 0x204
    static WM_RBUTTONUP := 0x205
    static WM_MBUTTONDOWN := 0x207
    static WM_MBUTTONUP := 0x208
    static WM_MOUSEWHEEL := 0x20A
    
    static KBDLLHOOKSTRUCT_SIZE := 16
    static MSLLHOOKSTRUCT_SIZE := 20
    
    ; ============================================================================
    ; INSTANCE VARIABLES
    ; ============================================================================
    
    IsRecording := false
    OnKeyRecorded := unset  ; Callback: func(rawHotkey, displayString)
    
    __New() {
        this.hookHandle := 0
        this.mouseHookHandle := 0
        
        ; State machine for modifier tracking
        this.modifierState := Map()
        this.currentRaw := ""
        this.currentDisplay := ""
        this.lastKeyName := ""
        
        ; Options
        this.options := Map(
            "keyboard", true,
            "mouse", false,
            "joystick", false,
            "lrModifiers", true,
            "wildcard", false,
            "passthrough", false,
            "markOnly", false
        )
        
        ; Callback storage (to keep alive)
        this.keyboardCallback := CallbackCreate(this._LowLevelKeyboardProc.Bind(this), "F", 3)
        this.mouseCallback := CallbackCreate(this._LowLevelMouseProc.Bind(this), "F", 3)
    }
    
    ; ============================================================================
    ; PUBLIC API
    ; ============================================================================
    
    StartRecording(optionsParam := unset) {
        if (this.IsRecording) {
            return false
        }
        
        ; Merge options
        if (optionsParam is Map) {
            for key, value in optionsParam {
                if (this.options.Has(key)) {
                    this.options.Set(key, value)
                }
            }
        }
        
        this.IsRecording := true
        this.currentRaw := ""
        this.currentDisplay := ""
        this.lastKeyName := ""
        this.modifierState := Map()
        
        ; Install keyboard hook
        if (this.options.Get("keyboard")) {
            hModule := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
            this.hookHandle := DllCall("SetWindowsHookExW", 
                "Int", HotkeyRecorder.WH_KEYBOARD_LL,
                "Ptr", this.keyboardCallback,
                "Ptr", hModule,
                "UInt", 0,
                "Ptr", 0
            )
            if (!this.hookHandle) {
                this.IsRecording := false
                return false
            }
        }
        
        ; Install mouse hook if enabled
        if (this.options.Get("mouse")) {
            hModule := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
            this.mouseHookHandle := DllCall("SetWindowsHookExW", 
                "Int", HotkeyRecorder.WH_MOUSE_LL,
                "Ptr", this.mouseCallback,
                "Ptr", hModule,
                "UInt", 0,
                "Ptr", 0
            )
            if (!this.mouseHookHandle && !this.hookHandle) {
                this.IsRecording := false
                return false
            }
        }
        
        return true
    }
    
    StopRecording() {
        if (!this.IsRecording) {
            return false
        }
        
        ; Uninstall hooks
        if (this.hookHandle) {
            DllCall("UnhookWindowsHookEx", "Ptr", this.hookHandle)
            this.hookHandle := 0
        }
        if (this.mouseHookHandle) {
            DllCall("UnhookWindowsHookEx", "Ptr", this.mouseHookHandle)
            this.mouseHookHandle := 0
        }
        
        this.IsRecording := false
        
        return true
    }
    
    GetResult() {
        return Map(
            "raw", this.currentRaw,
            "display", this.currentDisplay
        )
    }
    
    ; ============================================================================
    ; HOOK CALLBACKS (called by Windows)
    ; ============================================================================
    
    _LowLevelKeyboardProc(nCode, wParam, lParam) {
        if (!this.IsRecording || !this.options.Get("keyboard")) {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
        }
        
        if (nCode >= 0) {
            ; Extract VK and SC from KBDLLHOOKSTRUCT
            vkCode := Format("vk{:X}", NumGet(lParam, 0, "UInt"))
            scanCode := Format("sc{:X}", NumGet(lParam, 4, "UInt"))
            
            ; Process key immediately (synchronously)
            isKeyDown := (wParam = HotkeyRecorder.WM_KEYDOWN || wParam = HotkeyRecorder.WM_SYSKEYDOWN)
            this._ProcessKeyboardEvent({
                vk: vkCode,
                sc: scanCode,
                isDown: isKeyDown
            })

            ; Let the event continue through the hook chain.
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
        }
        
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
    
    _LowLevelMouseProc(nCode, wParam, lParam) {
        if (!this.IsRecording || !this.options.Get("mouse")) {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
        }
        
        if (nCode >= 0) {
            ; Process mouse event immediately (synchronously)
            isMouseDown := (wParam = HotkeyRecorder.WM_LBUTTONDOWN 
                         || wParam = HotkeyRecorder.WM_RBUTTONDOWN 
                         || wParam = HotkeyRecorder.WM_MBUTTONDOWN)
            
            mouseButton := ""
            if (wParam = HotkeyRecorder.WM_LBUTTONDOWN || wParam = HotkeyRecorder.WM_LBUTTONUP) {
                mouseButton := "LButton"
            } else if (wParam = HotkeyRecorder.WM_RBUTTONDOWN || wParam = HotkeyRecorder.WM_RBUTTONUP) {
                mouseButton := "RButton"
            } else if (wParam = HotkeyRecorder.WM_MBUTTONDOWN || wParam = HotkeyRecorder.WM_MBUTTONUP) {
                mouseButton := "MButton"
            } else if (wParam = HotkeyRecorder.WM_MOUSEWHEEL) {
                mouseData := NumGet(lParam, 8, "UInt")
                delta := (mouseData >> 16) & 0xFFFF
                if delta >= 0x8000
                    delta -= 0x10000
                mouseButton := (delta > 0) ? "WheelUp" : "WheelDown"
                isMouseDown := true
            }
            
            if (mouseButton) {
                this._ProcessMouseEvent({
                    button: mouseButton,
                    isDown: isMouseDown
                })
            }

            ; Let the event continue through the hook chain.
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
        }
        
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
    
    ; ============================================================================
    ; EVENT PROCESSING (synchronous - called directly from hook)
    ; ============================================================================
    
    _ProcessKeyboardEvent(event) {
        vk := event.vk
        sc := event.sc
        isDown := event.isDown
        
        isModifier := HotkeyRecorder.MODIFIER_VK_MAP.Has(vk)
        
        if (isDown) {
            if (isModifier) {
                ; Track modifier state
                modName := HotkeyRecorder.MODIFIER_VK_MAP.Get(vk)
                this.modifierState.Set(modName, true)
                
                ; Update display
                this._UpdateDisplay()
            } else {
                ; Non-modifier key pressed
                keyName := this._VkToKeyName(vk, sc)
                if (keyName) {
                    ; Build full hotkey: prefix + keyName
                    prefix := this._BuildPrefix()
                    this.currentRaw := prefix . keyName
                    this.currentDisplay := this._ToDisplayString(this.currentRaw)
                    this.lastKeyName := keyName
                    
                    ; Invoke callback
                    this._InvokeCallback()
                }
            }
        } else {
            ; Key up
            if (isModifier) {
                modName := HotkeyRecorder.MODIFIER_VK_MAP.Get(vk)
                if (this.modifierState.Has(modName))
                    this.modifierState.Delete(modName)
                
                ; If only modifiers were pressed and now all are released, allow modifiers-only
                if (this.options.Get("markOnly") && this.lastKeyName = "") {
                    prefix := this._BuildPrefix()
                    if (prefix) {
                        this.currentRaw := prefix
                        this.currentDisplay := this._ToDisplayString(this.currentRaw)
                        this._InvokeCallback()
                    }
                }
            }
        }
    }
    
    _ProcessMouseEvent(event) {
        button := event.button
        isDown := event.isDown
        
        if (isDown) {
            ; Get current modifier prefix
            prefix := this._BuildPrefix()
            this.currentRaw := prefix . button
            this.currentDisplay := this._ToDisplayString(this.currentRaw)
            this.lastKeyName := button
            
            this._InvokeCallback()
        }
    }
    
    ; ============================================================================
    ; HELPER METHODS
    ; ============================================================================
    
    _VkToKeyName(vk, sc) {
        ; Check for symbol keys (layout-independent via scan code behavior)
        if (HotkeyRecorder.SYMBOL_VK_MAP.Has(vk)) {
            return HotkeyRecorder.SYMBOL_VK_MAP.Get(vk)
        }
        
        ; Use GetKeyName for standard keys (handles A-Z, function keys, navigation, etc.)
        keyName := GetKeyName(vk)
        
        if (!keyName) {
            ; Fallback: try scan code format
            return sc
        }
        
        ; Uppercase single-letter keys
        if (StrLen(keyName) = 1) {
            return Format("{:U}", keyName)
        }
        
        return keyName
    }
    
    _BuildPrefix() {
        prefix := ""
        
        ; Build prefix from currently pressed modifiers
        ; Use left/right distinction if enabled
        if (this.options.Get("lrModifiers")) {
            if (this.modifierState.Has("LCtrl"))
                prefix .= "<^"
            if (this.modifierState.Has("RCtrl"))
                prefix .= ">^"
            if (this.modifierState.Has("LAlt"))
                prefix .= "<!"
            if (this.modifierState.Has("RAlt"))
                prefix .= ">!"
            if (this.modifierState.Has("LShift"))
                prefix .= "<+"
            if (this.modifierState.Has("RShift"))
                prefix .= ">+"
            if (this.modifierState.Has("LWin"))
                prefix .= "<#"
            if (this.modifierState.Has("RWin"))
                prefix .= ">#"
        } else {
            ; Collapse L/R modifiers to generic notation
            if (this.modifierState.Has("LCtrl") || this.modifierState.Has("RCtrl"))
                prefix .= "^"
            if (this.modifierState.Has("LAlt") || this.modifierState.Has("RAlt"))
                prefix .= "!"
            if (this.modifierState.Has("LShift") || this.modifierState.Has("RShift"))
                prefix .= "+"
            if (this.modifierState.Has("LWin") || this.modifierState.Has("RWin"))
                prefix .= "#"
        }
        
        return prefix
    }
    
    _ToDisplayString(rawHotkey) {
        if (!rawHotkey) {
            return ""
        }
        
        result := ""
        i := 1
        len := StrLen(rawHotkey)
        
        ; Parse prefixes
        while (i <= len) {
            oneChar := SubStr(rawHotkey, i, 1)
            
            if (oneChar = "<" && i < len) {
                nextChar := SubStr(rawHotkey, i + 1, 1)
                if (nextChar = "^") {
                    result .= "LCtrl + "
                    i += 2
                } else if (nextChar = "!") {
                    result .= "LAlt + "
                    i += 2
                } else if (nextChar = "+") {
                    result .= "LShift + "
                    i += 2
                } else if (nextChar = "#") {
                    result .= "LWin + "
                    i += 2
                } else {
                    i += 1
                }
            } else if (oneChar = ">" && i < len) {
                nextChar := SubStr(rawHotkey, i + 1, 1)
                if (nextChar = "^") {
                    result .= "RCtrl + "
                    i += 2
                } else if (nextChar = "!") {
                    result .= "RAlt + "
                    i += 2
                } else if (nextChar = "+") {
                    result .= "RShift + "
                    i += 2
                } else if (nextChar = "#") {
                    result .= "RWin + "
                    i += 2
                } else {
                    i += 1
                }
            } else if (oneChar = "^") {
                result .= "Ctrl + "
                i += 1
            } else if (oneChar = "!") {
                result .= "Alt + "
                i += 1
            } else if (oneChar = "+") {
                result .= "Shift + "
                i += 1
            } else if (oneChar = "#") {
                result .= "Win + "
                i += 1
            } else if (oneChar = "*") {
                result .= "(Wildcard) "
                i += 1
            } else if (oneChar = "~") {
                result .= "(Passthrough) "
                i += 1
            } else {
                break
            }
        }
        
        ; Get remaining key name
        keyPart := SubStr(rawHotkey, i)
        if (keyPart) {
            ; Clean up vkXX/scXX format
            if (SubStr(keyPart, 1, 2) = "vk") {
                vkCode := SubStr(keyPart, 1, 4)
                if (HotkeyRecorder.SYMBOL_VK_MAP.Has(vkCode)) {
                    keyPart := HotkeyRecorder.SYMBOL_VK_MAP.Get(vkCode)
                } else {
                    keyName := GetKeyName(vkCode)
                    keyPart := keyName ? keyName : keyPart
                }
            }
            
            ; Remove trailing " + " if no key part
            if (!keyPart || keyPart = "") {
                result := RegExReplace(result, " \+ $", "")
            } else {
                result .= keyPart
            }
        } else {
            result := RegExReplace(result, " \+ $", "")
        }
        
        return result
    }
    
    _UpdateDisplay() {
        ; Show current modifier state as display
        prefix := this._BuildPrefix()
        if (prefix) {
            this.currentRaw := prefix
            this.currentDisplay := this._ToDisplayString(this.currentRaw)
            this._InvokeCallback()
        }
    }
    
    _InvokeCallback() {
        try
            callback := this.OnKeyRecorded
        catch
            return

        if (!callback is Func)
            return

        try {
            if (callback.IsVariadic || callback.MaxParams >= 2)
                callback.Call(this.currentRaw, this.currentDisplay)
            else if (callback.MaxParams = 1)
                callback.Call(this.currentRaw)
            else
                callback.Call()
        }
    }
}

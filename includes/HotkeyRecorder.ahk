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
        this.processingTimer := unset
        
        ; State machine for modifier tracking
        this.modifierState := Map()
        this.currentRaw := ""
        this.currentDisplay := ""
        this.lastKeyName := ""
        
        ; Options
        this.options := Map(
            "keyboard", true,
            "mouse", true,
            "joystick", false,
            "lrModifiers", true,
            "wildcard", false,
            "passthrough", false,
            "markOnly", false
        )
        
        ; Event queue for async processing (similar to v1 pattern)
        this.eventQueue := Array()
        this.processingTimerId := 0
        
        ; Callback storage (to keep alive)
        this.keyboardCallback := CallbackCreate(this._LowLevelKeyboardProc.Bind(this), "F", 3)
        this.mouseCallback := CallbackCreate(this._LowLevelMouseProc.Bind(this), "F", 3)
    }
    
    ; ============================================================================
    ; PUBLIC API
    ; ============================================================================
    
    StartRecording(optionsParam := unset) {
        if this.IsRecording {
            return false
        }
        
        ; Merge options
        if optionsParam is Map {
            for key, value in optionsParam {
                if this.options.Has(key) {
                    this.options[key] := value
                }
            }
        }
        
        this.IsRecording := true
        this.currentRaw := ""
        this.currentDisplay := ""
        this.lastKeyName := ""
        this.modifierState := Map()
        this.eventQueue := Array()
        
        ; Install keyboard hook
        if this.options["keyboard"] {
            hModule := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
            this.hookHandle := DllCall("SetWindowsHookExW", 
                "Int", HotkeyRecorder.WH_KEYBOARD_LL,
                "Ptr", this.keyboardCallback,
                "Ptr", hModule,
                "UInt", 0,
                "Ptr"
            )
            if !this.hookHandle {
                return false
            }
        }
        
        ; Install mouse hook if enabled
        if this.options["mouse"] {
            hModule := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
            this.mouseHookHandle := DllCall("SetWindowsHookExW", 
                "Int", HotkeyRecorder.WH_MOUSE_LL,
                "Ptr", this.mouseCallback,
                "Ptr", hModule,
                "UInt", 0,
                "Ptr"
            )
        }
        
        return true
    }
    
    StopRecording() {
        if !this.IsRecording {
            return false
        }
        
        ; Uninstall hooks
        if this.hookHandle {
            DllCall("UnhookWindowsHookEx", "Ptr", this.hookHandle)
            this.hookHandle := 0
        }
        if this.mouseHookHandle {
            DllCall("UnhookWindowsHookEx", "Ptr", this.mouseHookHandle)
            this.mouseHookHandle := 0
        }
        
        ; Stop processing timer
        if this.processingTimerId {
            SetTimer(this.processingTimerId, 0)
            this.processingTimerId := 0
        }
        
        this.IsRecording := false
        this.eventQueue := Array()
        
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
        if !this.IsRecording || !this.options["keyboard"] {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "UInt", lParam)
        }
        
        if nCode >= 0 {
            ; Extract VK and SC from KBDLLHOOKSTRUCT
            vkCode := Format("vk{:X}", NumGet(lParam, 0, "UInt"))
            scanCode := Format("sc{:X}", NumGet(lParam, 4, "UInt"))
            flags := NumGet(lParam, 8, "UInt")
            
            ; Queue the event for processing
            isKeyDown := (wParam = HotkeyRecorder.WM_KEYDOWN || wParam = HotkeyRecorder.WM_SYSKEYDOWN)
            this.eventQueue.Push({
                type: "keyboard",
                vk: vkCode,
                sc: scanCode,
                isDown: isKeyDown
            })
            
            ; Start/restart processing timer
            if !this.processingTimerId {
                this.processingTimerId := SetTimer(this._ProcessEventQueue.Bind(this), 10)
            }
            
            ; Block the key from going to other applications
            return 1
        }
        
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "UInt", lParam)
    }
    
    _LowLevelMouseProc(nCode, wParam, lParam) {
        if !this.IsRecording || !this.options["mouse"] {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "UInt", lParam)
        }
        
        if nCode >= 0 {
            ; Queue mouse event
            isMouseDown := (wParam = HotkeyRecorder.WM_LBUTTONDOWN 
                         || wParam = HotkeyRecorder.WM_RBUTTONDOWN 
                         || wParam = HotkeyRecorder.WM_MBUTTONDOWN)
            
            mouseButton := ""
            if wParam = HotkeyRecorder.WM_LBUTTONDOWN || wParam = HotkeyRecorder.WM_LBUTTONUP {
                mouseButton := "LButton"
            } else if wParam = HotkeyRecorder.WM_RBUTTONDOWN || wParam = HotkeyRecorder.WM_RBUTTONUP {
                mouseButton := "RButton"
            } else if wParam = HotkeyRecorder.WM_MBUTTONDOWN || wParam = HotkeyRecorder.WM_MBUTTONUP {
                mouseButton := "MButton"
            } else if wParam = HotkeyRecorder.WM_MOUSEWHEEL {
                delta := NumGet(lParam, 12, "Int")
                mouseButton := (delta > 0) ? "WheelUp" : "WheelDown"
                isMouseDown := true
            }
            
            if mouseButton {
                this.eventQueue.Push({
                    type: "mouse",
                    button: mouseButton,
                    isDown: isMouseDown
                })
                
                if !this.processingTimerId {
                    this.processingTimerId := SetTimer(this._ProcessEventQueue.Bind(this), 10)
                }
            }
            
            return 1
        }
        
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "UInt", lParam)
    }
    
    ; ============================================================================
    ; EVENT PROCESSING (async queue processor)
    ; ============================================================================
    
    _ProcessEventQueue() {
        while this.eventQueue.Length > 0 {
            event := this.eventQueue.RemoveAt(1)
            
            if event["type"] = "keyboard" {
                this._ProcessKeyboardEvent(event)
            } else if event["type"] = "mouse" {
                this._ProcessMouseEvent(event)
            }
        }
        
        ; Stop timer if queue is empty
        if this.eventQueue.Length = 0 && this.processingTimerId {
            SetTimer(this.processingTimerId, 0)
            this.processingTimerId := 0
        }
    }
    
    _ProcessKeyboardEvent(event) {
        vk := event["vk"]
        sc := event["sc"]
        isDown := event["isDown"]
        
        isModifier := HotkeyRecorder.MODIFIER_VK_MAP.Has(vk)
        
        if isDown {
            if isModifier {
                ; Track modifier state
                modName := HotkeyRecorder.MODIFIER_VK_MAP[vk]
                this.modifierState[modName] := true
                
                ; Update display
                this._UpdateDisplay()
            } else {
                ; Non-modifier key pressed
                keyName := this._VkToKeyName(vk, sc)
                if keyName {
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
            if isModifier {
                modName := HotkeyRecorder.MODIFIER_VK_MAP[vk]
                this.modifierState.Delete(modName)
                
                ; If only modifiers were pressed and now all are released, allow modifiers-only
                if this.options["markOnly"] && this.lastKeyName = "" {
                    prefix := this._BuildPrefix()
                    if prefix {
                        this.currentRaw := prefix
                        this.currentDisplay := this._ToDisplayString(this.currentRaw)
                        this._InvokeCallback()
                    }
                }
            }
        }
    }
    
    _ProcessMouseEvent(event) {
        button := event["button"]
        isDown := event["isDown"]
        
        if isDown {
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
        if HotkeyRecorder.SYMBOL_VK_MAP.Has(vk) {
            return HotkeyRecorder.SYMBOL_VK_MAP[vk]
        }
        
        ; Use GetKeyName for standard keys (handles A-Z, function keys, navigation, etc.)
        keyName := GetKeyName(vk)
        
        if !keyName {
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
        if this.options["lrModifiers"] {
            if this.modifierState.Has("LCtrl") {
                prefix .= "<^"
            }
            if this.modifierState.Has("RCtrl") {
                prefix .= ">^"
            }
            if this.modifierState.Has("LAlt") {
                prefix .= "<!"
            }
            if this.modifierState.Has("RAlt") {
                prefix .= ">!"
            }
            if this.modifierState.Has("LShift") {
                prefix .= "<+"
            }
            if this.modifierState.Has("RShift") {
                prefix .= ">+"
            }
            if this.modifierState.Has("LWin") {
                prefix .= "<#"
            }
            if this.modifierState.Has("RWin") {
                prefix .= ">#"
            }
        } else {
            ; Collapse L/R modifiers to generic notation
            if this.modifierState.Has("LCtrl") || this.modifierState.Has("RCtrl") {
                prefix .= "^"
            }
            if this.modifierState.Has("LAlt") || this.modifierState.Has("RAlt") {
                prefix .= "!"
            }
            if this.modifierState.Has("LShift") || this.modifierState.Has("RShift") {
                prefix .= "+"
            }
            if this.modifierState.Has("LWin") || this.modifierState.Has("RWin") {
                prefix .= "#"
            }
        }
        
        return prefix
    }
    
    _ToDisplayString(rawHotkey) {
        if !rawHotkey {
            return ""
        }
        
        result := ""
        i := 1
        len := StrLen(rawHotkey)
        
        ; Parse prefixes
        while i <= len {
            twoChar := SubStr(rawHotkey, i, 2)
            oneChar := SubStr(rawHotkey, i, 1)
            
            if HotkeyRecorder.PREFIX_MAP.Has(twoChar) {
                ; This shouldn't happen (prefixes are single-char notation)
                i += 1
            } else if oneChar = "<" && i < len {
                ; Left-side modifier
                nextChar := SubStr(rawHotkey, i + 1, 1)
                if nextChar = "^" {
                    result .= "LCtrl + "
                    i += 2
                } else if nextChar = "!" {
                    result .= "LAlt + "
                    i += 2
                } else if nextChar = "+" {
                    result .= "LShift + "
                    i += 2
                } else if nextChar = "#" {
                    result .= "LWin + "
                    i += 2
                } else {
                    i += 1
                }
            } else if oneChar = ">" && i < len {
                ; Right-side modifier
                nextChar := SubStr(rawHotkey, i + 1, 1)
                if nextChar = "^" {
                    result .= "RCtrl + "
                    i += 2
                } else if nextChar = "!" {
                    result .= "RAlt + "
                    i += 2
                } else if nextChar = "+" {
                    result .= "RShift + "
                    i += 2
                } else if nextChar = "#" {
                    result .= "RWin + "
                    i += 2
                } else {
                    i += 1
                }
            } else if oneChar = "^" {
                ; Generic Ctrl (no L/R distinction in raw)
                result .= "Ctrl + "
                i += 1
            } else if oneChar = "!" {
                ; Generic Alt
                result .= "Alt + "
                i += 1
            } else if oneChar = "+" {
                ; Generic Shift
                result .= "Shift + "
                i += 1
            } else if oneChar = "#" {
                ; Generic Win
                result .= "Win + "
                i += 1
            } else if oneChar = "*" {
                ; Wildcard
                result .= "(Wildcard) "
                i += 1
            } else if oneChar = "~" {
                ; Passthrough
                result .= "(Passthrough) "
                i += 1
            } else {
                break
            }
        }
        
        ; Get remaining key name
        keyPart := SubStr(rawHotkey, i)
        if keyPart {
            ; Clean up vkXX/scXX format
            if SubStr(keyPart, 1, 2) = "vk" {
                vkCode := SubStr(keyPart, 1, 4)
                if HotkeyRecorder.SYMBOL_VK_MAP.Has(vkCode) {
                    keyPart := HotkeyRecorder.SYMBOL_VK_MAP[vkCode]
                } else {
                    keyName := GetKeyName(vkCode)
                    keyPart := keyName ? keyName : keyPart
                }
            }
            
            ; Remove trailing " + " if no key part
            if !keyPart || keyPart = "" {
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
        if prefix {
            this.currentRaw := prefix
            this.currentDisplay := this._ToDisplayString(this.currentRaw)
            this._InvokeCallback()
        }
    }
    
    _InvokeCallback() {
        if this.HasOwnProp("OnKeyRecorded") && IsObject(this.OnKeyRecorded) {
            this.OnKeyRecorded(this.currentRaw, this.currentDisplay)
        }
    }
}

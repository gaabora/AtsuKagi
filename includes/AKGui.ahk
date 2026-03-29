class AKGui {
  static PREFERRED_APP_MODE := { Default: 0, AllowDark: 1, ForceDark: 2, ForceLight: 3, Max: 4 }

  _settingsGui := 0

  __New(App) {
    this.App := App
    if (this.IsDarkTheme()) {
      this.SetDarkThemeMode(AKGui.PREFERRED_APP_MODE.ForceDark)
    }
  }
  
  IsDarkTheme() {
    if (this.App.Config.GENERAL.DarkTheme = -1) {
      return NOT RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    } else {
      return this.App.Config.GENERAL.DarkTheme
    }
  }

  GetAccentColor() {
    ; return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent", "AccentColorMenu")
    return RegRead("HKCU\Software\Microsoft\Windows\DWM", "AccentColor")
  }

  SetDarkThemeMode(appMode) {
    uxthemePtr := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
    SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxthemePtr, "Ptr", 135, "Ptr")
    FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxthemePtr, "Ptr", 136, "Ptr")
    DllCall(SetPreferredAppMode, "int", appMode)
    DllCall(FlushMenuThemes)
  }

  ; ── Settings Window ────────────────────────────────────────────────────────
  ShowSettings() {
    ; If already open, just focus it
    if (this._settingsGui != 0) {
      try {
        WinActivate("ahk_id " this._settingsGui.Hwnd)
        return
      } catch {
        this._settingsGui := 0
      }
    }

    cfg := this.App.Config
    isDark := this.IsDarkTheme()

    g := Gui("+Resize -MaximizeBox", this.App.ScriptName " — Settings")
    g.SetFont("s10", "Segoe UI")
    this._settingsGui := g

    if (isDark) {
      g.BackColor := "1E1E1E"
      g.SetFont("cWhite")
    }

    ; ── Tabs ──────────────────────────────────────────────────────────────────
    tabs := g.AddTab3("w500 h420", ["General", "Plugins", "Hotkeys"])

    ; ══════════════════════════════════════════════════════════════════════════
    ; TAB 1: General
    ; ══════════════════════════════════════════════════════════════════════════
    tabs.UseTab(1)

    g.AddText("xm+15 ym+40 Section", "Welcome Message:")
    g.AddEdit("vWelcomeMessage w300 xs+150 yp-3", cfg.GENERAL.WelcomeMessage)

    g.AddText("xs ys+35 Section", "Dark Theme:")
    ddlItems := ["Auto (follow system)", "Disabled", "Enabled"]
    darkVal := cfg.GENERAL.DarkTheme
    ddlChoice := (darkVal = -1) ? 1 : (darkVal = 0) ? 2 : 3
    g.AddDropDownList("vDarkTheme w300 xs+150 yp-3 Choose" ddlChoice, ddlItems)

    g.AddText("xs ys+35 Section", "Tooltip Timeout (ms):")
    g.AddEdit("vToolTipTimeoutMs w300 xs+150 yp-3 Number", cfg.GENERAL.ToolTipTimeoutMs)

    g.AddText("xs ys+35 Section", "Window Transparency:")
    g.AddEdit("vWindowTransparencyValue w300 xs+150 yp-3 Number", cfg.GENERAL.WindowTransparencyValue)

    g.AddText("xs ys+35 Section", "On-Top Border Color:")
    g.AddEdit("vWindowOnTopBorderColor w300 xs+150 yp-3", cfg.GENERAL.WindowOnTopBorderColor)

    g.AddText("xs ys+35 Section", "Startup Sound:")
    g.AddEdit("vStartupSound w300 xs+150 yp-3", cfg.GENERAL.StartupSound)

    g.AddText("xs ys+35 Section", "Notification Sound:")
    g.AddEdit("vNotificationSound w300 xs+150 yp-3", cfg.GENERAL.NotificationSound)

    g.AddText("xs ys+35 Section", "Reload Hotkey:")
    g.AddEdit("vReloadAppHotkey w300 xs+150 yp-3", cfg.GENERAL.ReloadAppHotkey)

    g.AddText("xs ys+35 Section", "Suspend Hotkey:")
    g.AddEdit("vSuspendAppHotkey w300 xs+150 yp-3", cfg.GENERAL.SuspendAppHotkey)

    g.AddText("xs ys+35 Section", "Swap Mouse XButtons:")
    g.AddCheckbox("vSwapMouseXButtons xs+150 yp" (cfg.GENERAL.SwapMouseXButtons ? " Checked" : ""), "")

    ; ══════════════════════════════════════════════════════════════════════════
    ; TAB 2: Plugins
    ; ══════════════════════════════════════════════════════════════════════════
    tabs.UseTab(2)

    g.AddText("xm+15 ym+40 Section", "Enable or disable plugins (requires restart):")

    availablePlugins := this.App._getAvailablePlugins()
    disabledPlugins := this.App._getDisabledPlugins()
    this._pluginCheckboxes := Map()

    yOff := 25
    for pluginName in availablePlugins {
      isEnabled := !ArrayContains(disabledPlugins, pluginName)
      chk := g.AddCheckbox("vPlugin_" pluginName " xs yp+" yOff, pluginName)
      chk.Value := isEnabled
      this._pluginCheckboxes[pluginName] := chk
      yOff := 25
    }

    ; ══════════════════════════════════════════════════════════════════════════
    ; TAB 3: Hotkeys (read-only list for MVP)
    ; ══════════════════════════════════════════════════════════════════════════
    tabs.UseTab(3)

    g.AddText("xm+15 ym+40", "Current hotkey assignments (edit config.ini for changes):")

    lv := g.AddListView("xm+15 w480 h350 ReadOnly", ["Hotkey", "Action"])
    if (cfg.Has("HOTKEYS")) {
      for k, v in cfg.HOTKEYS {
        lv.Add(, k, v)
      }
    }
    lv.ModifyCol(1, 120)
    lv.ModifyCol(2, 340)

    ; ── Buttons (outside tabs) ────────────────────────────────────────────────
    tabs.UseTab(0)

    g.AddButton("xm+260 y+20 w110 Default", "Save && Reload").OnEvent("Click", (*) => this._saveSettings())
    g.AddButton("x+10 w110", "Cancel").OnEvent("Click", (*) => this._closeSettings())

    g.OnEvent("Close", (*) => this._closeSettings())
    g.Show("AutoSize")
  }

  _saveSettings() {
    g := this._settingsGui
    if (g = 0)
      return

    saved := g.Submit(false) ; get values without hiding
    cfg := this.App.Config

    ; ── General fields ────────────────────────────────────────────────────────
    cfg.GENERAL.WelcomeMessage := saved.WelcomeMessage
    cfg.GENERAL.ToolTipTimeoutMs := saved.ToolTipTimeoutMs
    cfg.GENERAL.WindowTransparencyValue := saved.WindowTransparencyValue
    cfg.GENERAL.WindowOnTopBorderColor := saved.WindowOnTopBorderColor
    cfg.GENERAL.StartupSound := saved.StartupSound
    cfg.GENERAL.NotificationSound := saved.NotificationSound
    cfg.GENERAL.ReloadAppHotkey := saved.ReloadAppHotkey
    cfg.GENERAL.SuspendAppHotkey := saved.SuspendAppHotkey
    cfg.GENERAL.SwapMouseXButtons := saved.SwapMouseXButtons

    ; Map dropdown back to config value
    switch saved.DarkTheme {
      case "Auto (follow system)": cfg.GENERAL.DarkTheme := -1
      case "Disabled":             cfg.GENERAL.DarkTheme := 0
      case "Enabled":              cfg.GENERAL.DarkTheme := 1
    }

    ; ── Plugins ───────────────────────────────────────────────────────────────
    disabledList := []
    for pluginName, chk in this._pluginCheckboxes {
      if (!chk.Value)
        disabledList.Push(pluginName)
    }
    cfg.GENERAL.DisabledPlugins := Join(disabledList, ",")

    ; Force write & reload
    cfg.Save()
    this._closeSettings()
    this.App.ReloadApp()
  }

  _closeSettings() {
    if (this._settingsGui != 0) {
      this._settingsGui.Destroy()
      this._settingsGui := 0
    }
  }
}

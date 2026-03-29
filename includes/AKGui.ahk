; ── Global functions for Neutron JS → AHK callbacks ──────────────────────────
SettingsSave(neutron) {
  neutron._akGui._saveSettings()
}

SettingsCancel(neutron) {
  neutron._akGui._closeSettings()
}

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

  ; ── Settings Window (Neutron / HTML-based) ─────────────────────────────────
  ShowSettings() {
    ; If already open, just focus it
    if (this._settingsGui != 0) {
      try {
        WinActivate("ahk_id " this._settingsGui.hWnd)
        return
      } catch {
        this._settingsGui := 0
      }
    }

    nw := NeutronWindow()
    nw.Load("includes/ui/settings.html")

    ; Store references so global callback functions can reach us
    nw._app := this.App
    nw._akGui := this
    this._settingsGui := nw

    ; Populate form from current config
    this._populateSettingsPage(nw)

    ; Set window title text inside the HTML title bar
    try nw.doc.getElementById("titleText").innerText := this.App.ScriptName " — Settings"

    nw.OnEvent("Close", (neutron) => (this._settingsGui := 0))
    nw.Show("w820 h560", this.App.ScriptName " — Settings")
  }

  _populateSettingsPage(nw) {
    doc := nw.doc
    cfg := this.App.Config

    ; ── General fields ────────────────────────────────────────────────────────
    doc.getElementById("WelcomeMessage").value       := cfg.GENERAL.WelcomeMessage
    doc.getElementById("DarkTheme").value            := "" cfg.GENERAL.DarkTheme
    doc.getElementById("ToolTipTimeoutMs").value     := cfg.GENERAL.ToolTipTimeoutMs
    doc.getElementById("WindowTransparencyValue").value := cfg.GENERAL.WindowTransparencyValue
    doc.getElementById("WindowOnTopBorderColor").value  := cfg.GENERAL.WindowOnTopBorderColor
    doc.getElementById("StartupSound").value         := cfg.GENERAL.StartupSound
    doc.getElementById("NotificationSound").value    := cfg.GENERAL.NotificationSound
    doc.getElementById("ReloadAppHotkey").value      := cfg.GENERAL.ReloadAppHotkey
    doc.getElementById("SuspendAppHotkey").value     := cfg.GENERAL.SuspendAppHotkey
    doc.getElementById("SwapMouseXButtons").checked  := (cfg.GENERAL.SwapMouseXButtons = 1)

    ; Update transparency slider label & fill
    doc.getElementById("WindowTransparencyLabel").innerText := cfg.GENERAL.WindowTransparencyValue
    pct := Round((cfg.GENERAL.WindowTransparencyValue / 255) * 100)
    doc.getElementById("WindowTransparencyValue").style.background := "linear-gradient(90deg, var(--color-primary-adaptive, #0078D7) " pct "%, #999 " (pct + 0.1) "%)"

    ; ── Plugins ───────────────────────────────────────────────────────────────
    availablePlugins := this.App._getAvailablePlugins()
    disabledPlugins  := this.App._getDisabledPlugins()
    html := ""
    for pluginName in availablePlugins {
      isEnabled := !ArrayContains(disabledPlugins, pluginName)
      checked := isEnabled ? " checked" : ""
      html .= '<div class="plugin-item">'
      html .= '<input class="app-checkbox" type="checkbox" id="plugin_' pluginName '"' checked ' />'
      html .= '<label for="plugin_' pluginName '">' pluginName '</label>'
      html .= '</div>'
    }
    doc.getElementById("plugins-list").innerHTML := html

    ; ── Hotkeys ───────────────────────────────────────────────────────────────
    if (cfg.Has("HOTKEYS")) {
      html := ""
      for k, v in cfg.HOTKEYS {
        escapedK := NeutronWindow.EscapeHTML(k)
        escapedV := NeutronWindow.EscapeHTML(v)
        html .= "<tr><td>" escapedK "</td><td>" escapedV "</td></tr>"
      }
      doc.getElementById("hotkeys-tbody").innerHTML := html
    }

    ; ── Theme ─────────────────────────────────────────────────────────────────
    if (this.IsDarkTheme()) {
      doc.documentElement.setAttribute("data-theme", "dark")
      doc.body.classList.add("dark-theme")
    } else {
      doc.documentElement.setAttribute("data-theme", "light")
    }
  }

  _saveSettings() {
    nw := this._settingsGui
    if (nw = 0)
      return

    doc := nw.doc
    cfg := this.App.Config

    ; ── Read General fields from DOM ──────────────────────────────────────────
    cfg.GENERAL.WelcomeMessage       := doc.getElementById("WelcomeMessage").value
    cfg.GENERAL.DarkTheme            := doc.getElementById("DarkTheme").value
    cfg.GENERAL.ToolTipTimeoutMs     := doc.getElementById("ToolTipTimeoutMs").value
    cfg.GENERAL.WindowTransparencyValue := doc.getElementById("WindowTransparencyValue").value
    cfg.GENERAL.WindowOnTopBorderColor  := doc.getElementById("WindowOnTopBorderColor").value
    cfg.GENERAL.StartupSound         := doc.getElementById("StartupSound").value
    cfg.GENERAL.NotificationSound    := doc.getElementById("NotificationSound").value
    cfg.GENERAL.ReloadAppHotkey      := doc.getElementById("ReloadAppHotkey").value
    cfg.GENERAL.SuspendAppHotkey     := doc.getElementById("SuspendAppHotkey").value
    cfg.GENERAL.SwapMouseXButtons    := doc.getElementById("SwapMouseXButtons").checked ? 1 : 0

    ; ── Collect disabled plugins ──────────────────────────────────────────────
    disabledList := []
    availablePlugins := this.App._getAvailablePlugins()
    for pluginName in availablePlugins {
      chk := doc.getElementById("plugin_" pluginName)
      if (chk && !chk.checked)
        disabledList.Push(pluginName)
    }
    cfg.GENERAL.DisabledPlugins := Join(disabledList, ",")

    ; ── Persist & reload ──────────────────────────────────────────────────────
    cfg.Save()
    this._closeSettings()
    this.App.ReloadApp()
  }

  _closeSettings() {
    if (this._settingsGui != 0) {
      nw := this._settingsGui
      this._settingsGui := 0
      try nw.Destroy()
    }
  }
}

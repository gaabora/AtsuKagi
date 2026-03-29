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

  ; ── Settings Window (WebViewGui / HTML-based) ──────────────────────────────
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

    nw := WebViewGui("+Resize -Caption",,, {DefaultWidth: 820, DefaultHeight: 560})
    nw.Title := this.App.ScriptName " — Settings"
    this._settingsGui := nw

    ; Register JS → AHK callbacks
    nw.AddCallbackToScript("SettingsSave", (wv, *) => this._saveSettings())
    nw.AddCallbackToScript("SettingsCancel", (wv, *) => this._closeSettings())

    ; Populate form after page finishes loading
    nw.DOMContentLoaded((ICoreWebView2, Args) => this._populateSettingsPage(nw))

    nw.OnEvent("Close", (*) => (this._settingsGui := 0))
    nw.Navigate("includes/ui/settings.html")
    nw.Show("w820 h560")
  }

  _populateSettingsPage(nw) {
    cfg := this.App.Config

    ; Build a single JavaScript block to populate all form fields
    js := ""

    ; ── General fields ────────────────────────────────────────────────────────
    js .= "document.getElementById('WelcomeMessage').value = '"       WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WelcomeMessage) "';`n"
    js .= "document.getElementById('DarkTheme').value = '"            WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.DarkTheme) "';`n"
    js .= "document.getElementById('ToolTipTimeoutMs').value = '"     WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.ToolTipTimeoutMs) "';`n"
    js .= "document.getElementById('WindowTransparencyValue').value = '" WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WindowTransparencyValue) "';`n"
    js .= "document.getElementById('WindowOnTopBorderColor').value = '"  WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WindowOnTopBorderColor) "';`n"
    js .= "document.getElementById('StartupSound').value = '"         WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.StartupSound) "';`n"
    js .= "document.getElementById('NotificationSound').value = '"    WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.NotificationSound) "';`n"
    js .= "document.getElementById('ReloadAppHotkey').value = '"      WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.ReloadAppHotkey) "';`n"
    js .= "document.getElementById('SuspendAppHotkey').value = '"     WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.SuspendAppHotkey) "';`n"
    js .= "document.getElementById('SwapMouseXButtons').checked = "   (cfg.GENERAL.SwapMouseXButtons = 1 ? "true" : "false") ";`n"

    ; Update transparency slider label & fill
    js .= "document.getElementById('WindowTransparencyLabel').innerText = '" WebViewCtrl.EscapeJavaScript("" cfg.GENERAL.WindowTransparencyValue) "';`n"
    pct := Round((cfg.GENERAL.WindowTransparencyValue / 255) * 100)
    js .= "document.getElementById('WindowTransparencyValue').style.background = 'linear-gradient(90deg, var(--color-primary-adaptive, #0078D7) " pct "%, #999 " (pct + 0.1) "%)';`n"

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
    js .= "document.getElementById('plugins-list').innerHTML = '" WebViewCtrl.EscapeJavaScript(html) "';`n"

    ; ── Hotkeys ───────────────────────────────────────────────────────────────
    if (cfg.Has("HOTKEYS")) {
      html := ""
      for k, v in cfg.HOTKEYS {
        escapedK := WebViewCtrl.EscapeHtml(k)
        escapedV := WebViewCtrl.EscapeHtml(v)
        html .= "<tr><td>" escapedK "</td><td>" escapedV "</td></tr>"
      }
      js .= "document.getElementById('hotkeys-tbody').innerHTML = '" WebViewCtrl.EscapeJavaScript(html) "';`n"
    }

    ; ── Theme ─────────────────────────────────────────────────────────────────
    if (this.IsDarkTheme()) {
      js .= "document.documentElement.setAttribute('data-theme', 'dark');`n"
      js .= "document.body.classList.add('dark-theme');`n"
    } else {
      js .= "document.documentElement.setAttribute('data-theme', 'light');`n"
    }

    ; ── Title text ────────────────────────────────────────────────────────────
    js .= "document.getElementById('titleText').innerText = '" WebViewCtrl.EscapeJavaScript(this.App.ScriptName " — Settings") "';`n"

    ; Slider live-update (re-attach after populate)
    js .= "if(typeof updateSlider==='function') updateSlider();`n"

    nw.ExecuteScriptAsync(js)
  }

  _saveSettings() {
    nw := this._settingsGui
    if (nw = 0)
      return

    cfg := this.App.Config

    ; ── Read General fields from DOM via synchronous JS execution ─────────────
    cfg.GENERAL.WelcomeMessage       := nw.ExecuteScript("document.getElementById('WelcomeMessage').value")
    cfg.GENERAL.DarkTheme            := nw.ExecuteScript("document.getElementById('DarkTheme').value")
    cfg.GENERAL.ToolTipTimeoutMs     := nw.ExecuteScript("document.getElementById('ToolTipTimeoutMs').value")
    cfg.GENERAL.WindowTransparencyValue := nw.ExecuteScript("document.getElementById('WindowTransparencyValue').value")
    cfg.GENERAL.WindowOnTopBorderColor  := nw.ExecuteScript("document.getElementById('WindowOnTopBorderColor').value")
    cfg.GENERAL.StartupSound         := nw.ExecuteScript("document.getElementById('StartupSound').value")
    cfg.GENERAL.NotificationSound    := nw.ExecuteScript("document.getElementById('NotificationSound').value")
    cfg.GENERAL.ReloadAppHotkey      := nw.ExecuteScript("document.getElementById('ReloadAppHotkey').value")
    cfg.GENERAL.SuspendAppHotkey     := nw.ExecuteScript("document.getElementById('SuspendAppHotkey').value")
    cfg.GENERAL.SwapMouseXButtons    := nw.ExecuteScript("document.getElementById('SwapMouseXButtons').checked") = "true" ? 1 : 0

    ; ── Collect disabled plugins ──────────────────────────────────────────────
    disabledList := []
    availablePlugins := this.App._getAvailablePlugins()
    for pluginName in availablePlugins {
      checked := nw.ExecuteScript("document.getElementById('plugin_" pluginName "').checked")
      if (checked != "true")
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


/**
 * SettingsDom: Caches DOM element lookups and provides accessors.
 */
class SettingsDom {
  constructor() {
    this.sections = new Map();
    this.navItems = new Map();
    this.fields = new Map();
    this.cache();
  }

  cache() {
    this.sections.clear();
    this.navItems.clear();
    this.fields.clear();

    document.querySelectorAll('.settings-section').forEach(el => {
      const id = el.id;
      if (!id) return console.error('Found settings section without id:', el);
      const sectionName = id.replace('section-', '');
      this.sections.set(sectionName, el);
    });

    document.querySelectorAll('.nav-item').forEach((el, idx) => {
      const dataSection = el.getAttribute('data-section');
      if (dataSection) this.navItems.set(dataSection, el);
    });

    const fieldIds = [
      'WelcomeMessage', 'DarkTheme', 'DebugLevel', 'ToolTipTimeoutMs', 'WindowTransparencyValue',
      'WindowOnTopBorderColor', 'StartupSound', 'NotificationSound',
      'ReloadAppHotkey', 'SuspendAppHotkey', 'SwapMouseXButtons',
      'ReloadAppHotkeyDisplay', 'SuspendAppHotkeyDisplay',
      'WindowTransparencyLabel', 'BorderColorSwatch',
      'plugins-list', 'hotkeys-tbody', 'logs-content', 'problems-content',
      'titleText'
    ];

    fieldIds.forEach(id => {
      const el = document.getElementById(id);
      if (el) this.fields.set(id, el);
    });
  }
  getSection(name) { return this.sections.get(name); }
  getNavItem(name) { return this.navItems.get(name); }
  getField(id) { return this.fields.get(id); }
  getAllNavItems() { return Array.from(this.navItems.values()); }
  getAllSections() { return Array.from(this.sections.values()); }
  getPluginCheckboxes() { return document.querySelectorAll('#plugins-list input[type="checkbox"][id^="plugin_"]'); }
}





// Initialize on page load
(function initialize() {
  // Host bridge stub (replace with actual bridge in prod)
  const hostBridge = window.hostBridge || {};

  // LogsController instance
  const logsContentEl = document.getElementById('logs-content');
  window.logsController = new LogsController(hostBridge);
  if (logsContentEl) window.logsController.mount(logsContentEl);

  window.settingsPage = new SettingsPage();
  // Attach logsController to settingsPage and SettingsForm if present
  if (window.settingsPage && window.settingsPage.form) {
    window.settingsPage.form.logsController = window.logsController;
  }
  window.SettingsPageBridge = {
    applyState: (state) => window.settingsPage.applyState(state),
    refresh: () => window.settingsPage.refreshUI()
  };
})();

window.chrome.webview.addEventListener('message', ahkWebMessage);
function ahkWebMessage(Msg) {
    console.log(Msg.data);
}

function ahkButtonClick(ele) {
    if (ele.Id != null || "") {
        var eleInfo = ele.Id;
    }
    else if (ele.Name != null || "") {
        var eleInfo = ele.Name;
    }
    else if (ele.innerText != null || "") {
        var eleInfo = ele.innerText;
    }
    else {
        var eleInfo = ele.outerHTML;
    }
    ahk.ButtonClick.Func(eleInfo);
}
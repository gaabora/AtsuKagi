
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

    document.querySelectorAll('[id]').forEach((el) => {
      this.fields.set(el.id, el);
    });
  }
  getSection(name) { return this.sections.get(name); }
  getNavItem(name) { return this.navItems.get(name); }
  getField(id) {
    return this.fields.get(id) || document.getElementById(id);
  }
  getAllNavItems() { return Array.from(this.navItems.values()); }
  getAllSections() { return Array.from(this.sections.values()); }
  getPluginCheckboxes() { return document.querySelectorAll('#plugins-list input[type="checkbox"][id^="plugin_"]'); }
}





// Initialize on page load
(function initialize() {
  window.settingsPage = new SettingsPage(window.settingsDevHostBridge);
  window.SettingsPageBridge = {
    applyState: (state) => window.settingsPage.applyState(state),
    refresh: () => window.settingsPage.refreshUI(),
    appendLogs: (entries) => {
      if (window.settingsPage && window.settingsPage.logs) {
        window.settingsPage.logs.appendLogs(entries);
      }
    }
  };
})();


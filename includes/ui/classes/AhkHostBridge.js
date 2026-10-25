class AhkHostBridge {
  constructor() {
    this.host = this._resolveHost();
  }

  _resolveHost() {
    try {
      if (window.chrome && window.chrome.webview && window.chrome.webview.hostObjects) {
        return window.chrome.webview.hostObjects.sync;
      }
    } catch (error) {
      console.error('Error accessing host objects:', error);
    }
    return null;
  }

  _checkHostFunction(funcName) { if (!this.host || typeof this.host[funcName] !== 'function') throw new Error(`${funcName} is not available on host object`); }

  _parseHostResult(result) {
    if (result == null) return { ok: false, error: 'Empty host response' };
    if (typeof result === 'string') {
      const txt = result.trim();
      if (!txt) return { ok: false, error: 'Empty host response' };
      try {
        return JSON.parse(txt);
      } catch (error) {
        return { ok: false, error: txt };
      }
    }
    if (typeof result === 'object') {
      return result;
    }
    return { ok: !!result };
  }



  saveGeneralSetting(key, value) {
    this._checkHostFunction('SaveGeneralSetting');
    return this._parseHostResult(this.host.SaveGeneralSetting(`${key || ''}`, JSON.stringify(value)));
  }

  savePluginSetting(pluginId, key, value) {
    this._checkHostFunction('SavePluginSetting');
    return this._parseHostResult(this.host.SavePluginSetting(`${pluginId || ''}`, `${key || ''}`, JSON.stringify(value)));
  }

  getAutomations() {
    this._checkHostFunction('GetAutomations');
    return this._parseHostResult(this.host.GetAutomations());
  }

  saveAutomations(automationData) {
    this._checkHostFunction('SaveAutomations');
    return this._parseHostResult(this.host.SaveAutomations(JSON.stringify(automationData)));
  }

  runAutomation(automationId) {
    this._checkHostFunction('RunAutomation');
    return this._parseHostResult(this.host.RunAutomation(`${automationId || ''}`));
  }

  testAutomationAction(automationId) {
    this._checkHostFunction('TestAutomationAction');
    return this._parseHostResult(this.host.TestAutomationAction(`${automationId || ''}`));
  }

  enableAutomation(automationId) {
    this._checkHostFunction('EnableAutomation');
    return this._parseHostResult(this.host.EnableAutomation(`${automationId || ''}`));
  }

  disableAutomation(automationId) {
    this._checkHostFunction('DisableAutomation');
    return this._parseHostResult(this.host.DisableAutomation(`${automationId || ''}`));
  }

  toggleAutomation(automationId) {
    this._checkHostFunction('ToggleAutomation');
    return this._parseHostResult(this.host.ToggleAutomation(`${automationId || ''}`));
  }

  showLowBatteryOsd() {
    this._checkHostFunction('ShowLowBatteryOsd');
    return this._parseHostResult(this.host.ShowLowBatteryOsd());
  }

  showTimeUntilSleep() {
    this._checkHostFunction('ShowTimeUntilSleep');
    return this._parseHostResult(this.host.ShowTimeUntilSleep());
  }

  saveHotkey(oldHotKey, hotKey, action, allowRiskyHotkeys = false) {
    this._checkHostFunction('SaveHotkey');
    return this._parseHostResult(this.host.SaveHotkey(`${oldHotKey || ''}`, `${hotKey || ''}`, `${action || ''}`, allowRiskyHotkeys ? 1 : 0));
  }

  removeHotkey(hotKey) {
    this._checkHostFunction('RemoveHotkey');
    return this._parseHostResult(this.host.RemoveHotkey(`${hotKey || ''}`));
  }

  addHotkey(hotKey, action, allowRiskyHotkeys = false) {
    this._checkHostFunction('AddHotkey');
    return this._parseHostResult(this.host.AddHotkey(`${hotKey || ''}`, `${action || ''}`, allowRiskyHotkeys ? 1 : 0));
  }

  togglePlugin(pluginId, enabled) {
    this._checkHostFunction('TogglePlugin');
    return this._parseHostResult(this.host.TogglePlugin(`${pluginId || ''}`, enabled ? 1 : 0));
  }

  setPluginDebugLevel(pluginId, level) {
    this._checkHostFunction('SetPluginDebugLevel');
    return this._parseHostResult(this.host.SetPluginDebugLevel(`${pluginId || ''}`, JSON.stringify(Number(level))));
  }

  clearLogs() {
    this._checkHostFunction('ClearLogs');
    this.host.ClearLogs();
  }

  setLogPageActive(active) {
    this._checkHostFunction('SetLogPageActive');
    this.host.SetLogPageActive(active ? 1 : 0);
  }

  closeSettings() {
    this._checkHostFunction('CloseSettings');
    this.host.CloseSettings();
  }

  browseForFile(currentPath = '') {
    this._checkHostFunction('BrowseForFile');
    return this.host.BrowseForFile(currentPath);
  }

  openDevTools() {
    this._checkHostFunction('OpenDevTools');
    return !!this.host.OpenDevTools();
  }

  minimize() {
    if (this.host && this.host.gui && typeof this.host.gui.Minimize === 'function') {
      this.host.gui.Minimize();
    }
  }
}

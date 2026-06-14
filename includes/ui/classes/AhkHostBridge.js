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

  saveHotkey(index, hotKey, action, allowRiskyHotkeys = false) {
    this._checkHostFunction('SaveHotkey');
    return this._parseHostResult(this.host.SaveHotkey(Number(index) || 0, `${hotKey || ''}`, `${action || ''}`, allowRiskyHotkeys ? 1 : 0));
  }

  removeHotkey(index) {
    this._checkHostFunction('RemoveHotkey');
    return this._parseHostResult(this.host.RemoveHotkey(Number(index) || 0));
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

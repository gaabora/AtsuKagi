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

  saveSettings(payloadObject) {
    this._checkHostFunction('SaveSettingsJson');
    const obj = payloadObject || {};
    this.host.SaveSettingsJson(JSON.stringify(obj));
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

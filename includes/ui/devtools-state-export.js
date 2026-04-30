/* DevTools helpers: export full AHK->UI state as one-line runnable command. */
(function () {
  function _clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function _getState() {
    if (!window.settingsPage) {
      throw new Error('settingsPage is not available');
    }
    if (window.settingsPage._lastAppliedState) {
      return _clone(window.settingsPage._lastAppliedState);
    }
    throw new Error('No AHK state snapshot captured yet. Reopen settings from AHK first.');
  }

  function _applyState(state) {
    if (!window.SettingsPageBridge || typeof window.SettingsPageBridge.applyState !== 'function') {
      throw new Error('SettingsPageBridge.applyState is not available');
    }
    window.SettingsPageBridge.applyState(state);
    return true;
  }

  window.expAhk = function () {
    const state = _getState();
    const serialized = JSON.stringify(state);
    const command = 'impAhk(' + JSON.stringify(serialized) + ')';
    console.log(command);
    return command;
  };

  window.impAhk = function (payload) {
    try {
      let state = payload;
      if (typeof payload === 'string') {
        state = JSON.parse(payload);
      }
      return _applyState(state);
    } catch (err) {
      console.error('impAhk failed: ' + err.message);
      return false;
    }
  };
})();

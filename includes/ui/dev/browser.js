class BrowserMockBridge {
  constructor(scenario) {
    this.scenario = scenario;
    this.storageKey = `haribol.ui-dev.data.v1.${scenario}`;
    this.data = this.readStorage(localStorage, this.storageKey) || window.createSettingsDevData(scenario);
    this.availableActions = ['PreventSleep', 'DismissMatchingWindows', 'ShowLowBatteryOsd', 'ShowTimeUntilSleep', 'StartFakeScreensaver', 'StopFakeScreensaver'];
    this.logId = 0;
  }

  readStorage(storage, key) {
    try { return JSON.parse(storage.getItem(key) || 'null'); }
    catch (error) { console.warn('Could not read browser preview data', error); return null; }
  }

  persist() {
    try { localStorage.setItem(this.storageKey, JSON.stringify(this.data)); }
    catch (error) { return { ok: false, error: `Could not save browser data: ${error.message}` }; }
    return { ok: true };
  }

  getAutomations() {
    return structuredClone({
      ok: true, schemaVersion: 1, automations: this.data.automations, availableActions: this.availableActions,
      runtime: { ...this.data.runtime, enabledAutomations: this.data.automations.filter((automation) => automation.enabled).length }
    });
  }

  saveAutomations(payload) {
    if (this.scenario === 'save-error') return { ok: false, error: 'Example save failure. Your changes were not saved.' };
    const previous = this.data.automations;
    this.data.automations = structuredClone(payload.automations);
    const result = this.persist();
    if (!result.ok) this.data.automations = previous;
    return result;
  }

  setEnabled(automationId, enabled) {
    const collection = structuredClone(this.data.automations);
    const automation = collection.find((entry) => entry.id === automationId);
    if (!automation) return { ok: false, error: 'Automation not found' };
    automation.enabled = enabled;
    return this.saveAutomations({ automations: collection });
  }

  enableAutomation(automationId) { return this.setEnabled(automationId, true); }
  disableAutomation(automationId) { return this.setEnabled(automationId, false); }
  toggleAutomation(automationId) {
    const automation = this.data.automations.find((entry) => entry.id === automationId);
    return this.setEnabled(automationId, !automation?.enabled);
  }

  simulate(label) {
    console.info(`[Browser preview] ${label}. No system action was run.`);
    window.SettingsPageBridge?.appendLogs([{ id: ++this.logId, level: 3, time: new Date().toLocaleTimeString(), text: `[Browser preview] ${label}` }]);
    return { ok: true };
  }

  runAutomation(automationId) { return this.simulate(`Run ${automationId}`); }
  testAutomationAction(automationId) { return this.simulate(`Test action ${automationId}`); }
  showLowBatteryOsd() { return this.simulate('Show battery OSD'); }
  showTimeUntilSleep() { return this.simulate('Show sleep countdown'); }
  clearLogs() { return { ok: true }; }
  setLogPageActive() { return { ok: true }; }
  closeSettings() { return this.simulate('Close settings'); }
  minimize() { return this.simulate('Minimize settings'); }
  openDevTools() { alert('Open browser developer tools with F12.'); return true; }
  browseForFile(currentPath) { return currentPath; }

  savePluginSetting(pluginId, key, value) {
    const page = this.data.state.plugins.pages.find((entry) => entry.id === pluginId);
    const field = page?.sections.flatMap((section) => section.fields).find((entry) => entry.key === key);
    if (!field) return { ok: false, error: 'Preview field not found' };
    const previous = field.value;
    const previousRunning = this.data.runtime.running;
    field.value = value;
    if (key === 'SchedulerEnabled') this.data.runtime.running = Boolean(value);
    const result = this.persist();
    if (!result.ok) {
      field.value = previous;
      this.data.runtime.running = previousRunning;
    }
    if (result.ok && key === 'SchedulerEnabled') {
      window.settingsPage.automations.load();
    }
    return result;
  }

  togglePlugin(pluginId, enabled) {
    this.data.state.plugins.disabled = enabled ? [] : [pluginId];
    return this.persist();
  }

  setPluginDebugLevel(pluginId, level) {
    this.data.state.plugins.debugLevels[pluginId] = level;
    return this.persist();
  }
}

(() => {
  const params = new URLSearchParams(location.search);
  const scenarios = ['normal', 'empty', 'long', 'invalid', 'save-error'];
  const scenario = scenarios.includes(params.get('scenario')) ? params.get('scenario') : 'normal';
  const bridge = new BrowserMockBridge(scenario);
  const sessionKey = `haribol.ui-dev.session.v1.${scenario}`;
  let sessionSavingEnabled = true;
  window.settingsDevHostBridge = bridge;

  const saveSession = () => {
    const page = window.settingsPage;
    if (!page || !sessionSavingEnabled) return;
    const content = document.querySelector('.settings-content');
    try {
      sessionStorage.setItem(sessionKey, JSON.stringify({
        section: page._currentSection, draft: page.automations.draft, editorMode: page.automations.editorMode,
        timetable: page.automations.timetable, scrollTop: content?.scrollTop || 0
      }));
    } catch (error) { console.warn('Could not save browser preview draft', error); }
  };

  document.addEventListener('DOMContentLoaded', () => {
    const saved = bridge.readStorage(sessionStorage, sessionKey);
    const page = window.settingsPage;
    page.applyState({ ...bridge.data.state, theme: params.get('theme') === 'dark' ? 'dark' : 'light', openPage: saved?.section || params.get('page') || 'plugin-Automations' });
    if (saved?.draft) {
      page.automations._openEditor(saved.draft, saved.editorMode || 'edit');
      page.automations.timetable = saved.timetable || null;
      page.automations.render();
    }
    requestAnimationFrame(() => { document.querySelector('.settings-content').scrollTop = saved?.scrollTop || 0; });

    const toolbar = document.createElement('div');
    toolbar.style.cssText = 'display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:8px 12px;background:#fff3cd;color:#332700;font:13px sans-serif;';
    toolbar.innerHTML = `<strong>Browser preview</strong><span>Mock data only</span><label>Example <select>${scenarios.map((entry) => `<option ${entry === scenario ? 'selected' : ''}>${entry}</option>`).join('')}</select></label><label>Dark theme <input type="checkbox" ${params.get('theme') === 'dark' ? 'checked' : ''}></label><button type="button">Reset example</button>`;
    document.querySelector('.settings-content').prepend(toolbar);
    toolbar.querySelector('select').addEventListener('change', (event) => {
      params.set('scenario', event.target.value);
      location.search = params.toString();
    });
    toolbar.querySelector('input').addEventListener('change', (event) => {
      params.set('theme', event.target.checked ? 'dark' : 'light');
      location.search = params.toString();
    });
    toolbar.querySelector('button').addEventListener('click', () => {
      sessionSavingEnabled = false;
      localStorage.removeItem(bridge.storageKey);
      sessionStorage.removeItem(sessionKey);
      location.reload();
    });

    for (const eventName of ['input', 'change', 'click']) document.addEventListener(eventName, () => queueMicrotask(saveSession));
    window.addEventListener('beforeunload', saveSession);

    const events = new EventSource('/__dev/events');
    let serverRevision = null;
    events.addEventListener('ready', (event) => {
      if (serverRevision && serverRevision !== event.data) location.reload();
      serverRevision = event.data;
    });
    events.addEventListener('reload', () => { saveSession(); location.reload(); });
  });
})();

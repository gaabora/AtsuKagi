class SettingsPage {
  constructor() {
    this.dom = new SettingsDom();
    this.hostBridge = new AhkHostBridge();
    this.form = new SettingsForm(this.dom);
    this.colorPicker = new ColorPickerController(this.dom);
    this.hotkeyRecorder = new HotkeyRecorderController(this.dom, (actionName, hotkeyRaw, replaceRaw) => this._applyActionHotkey(actionName, hotkeyRaw, replaceRaw));
    this.logs = new LogsController(this.hostBridge, (settingRef) => this._goToSetting(settingRef));
    this._isApplyingState = false;
    this._fieldSaveTimers = new Map();
    this._currentSection = null;
    this.init();
  }

  init() {
    this._bindActions();
    this._bindNavigation();
    this._bindFilePickers();
    this._bindColorPickerDialog();
    this._bindHotkeyRecorderDialog();
    this._bindSliderRefresh();
    this._bindDevToolsButton();
    this._bindAtomicAutoSave();
    this._bindPluginFieldReset();
    this._bindActionHotkeyRemoval();
    this._bindHotkeyBadgeReset();
    this._mountLogsController();
  }

  _mountLogsController() {
    const container = document.getElementById('logs-content');
    const toolbar = document.getElementById('logs-toolbar');
    if (container) {
      this.logs.mount(container);
    }
    if (toolbar) {
      this.logs.buildToolbar(toolbar);
    }
    this.form.logsController = this.logs;
  }

  _bindActions() {
    // Toolbar buttons
    const saveBtn = document.querySelector('[data-action="save-settings"]');
    const cancelBtn = document.querySelector('[data-action="close-settings"]');
    const minimizeBtn = document.querySelector('[data-action="minimize-window"]');

    if (saveBtn) {
      saveBtn.addEventListener('click', () => this._saveSettings());
    }
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => this.hostBridge.closeSettings());
    }
    if (minimizeBtn) {
      minimizeBtn.addEventListener('click', () => this.hostBridge.minimize());
    }
  }

  _bindAtomicAutoSave() {
    const contentRoot = document.querySelector('.settings-content');
    if (!contentRoot) return;

    const trackCurrentValue = (el) => {
      if (!(el instanceof HTMLInputElement || el instanceof HTMLSelectElement || el instanceof HTMLTextAreaElement)) return;
      if (el.type === 'checkbox') {
        el.dataset.prevValue = el.checked ? '1' : '0';
      } else {
        el.dataset.prevValue = `${el.value ?? ''}`;
      }
    };

    contentRoot.addEventListener('focusin', (ev) => {
      const target = ev.target;
      if (!target) return;
      trackCurrentValue(target);
    });

    const onChange = (ev) => {
      if (this._isApplyingState) return;
      const target = ev.target;
      if (!target) return;
      if (!(target instanceof HTMLInputElement || target instanceof HTMLSelectElement || target instanceof HTMLTextAreaElement))
        return;

      const pluginCheckbox = target.matches('#plugins-list input[type="checkbox"][id^="plugin_"]');
      if (pluginCheckbox) {
        this._schedulePluginToggleSave(target);
        return;
      }

      if (target.classList.contains('general-field')) {
        this._scheduleGeneralFieldSave(target);
        return;
      }

      if (target.classList.contains('plugin-field')) {
        this._schedulePluginFieldSave(target);
      }
    };

    contentRoot.addEventListener('change', onChange);
  }

  _scheduleFieldSave(saveKey, callback, delayMs = 350) {
    if (this._fieldSaveTimers.has(saveKey)) {
      clearTimeout(this._fieldSaveTimers.get(saveKey));
    }
    const timer = setTimeout(() => {
      this._fieldSaveTimers.delete(saveKey);
      callback();
    }, delayMs);
    this._fieldSaveTimers.set(saveKey, timer);
  }

  _readFieldValue(el) {
    if (!el) return '';
    if (el.type === 'checkbox') return !!el.checked;
    return `${el.value ?? ''}`;
  }

  _readPreviousFieldValue(el) {
    if (!el) return '';
    if (Object.prototype.hasOwnProperty.call(el.dataset, 'prevValue')) {
      if (el.type === 'checkbox') return el.dataset.prevValue === '1';
      return el.dataset.prevValue;
    }
    if (el.type === 'checkbox') return !el.checked;
    return '';
  }

  _writeFieldValue(el, value) {
    if (!el) return;
    if (el.type === 'checkbox') {
      el.checked = !!value;
      el.dataset.prevValue = el.checked ? '1' : '0';
      return;
    }
    el.value = `${value ?? ''}`;
    el.dataset.prevValue = `${el.value ?? ''}`;
  }

  _scheduleGeneralFieldSave(target) {
    const key = `${target.getAttribute('data-key') || ''}`.trim();
    if (!key) return;

    const value = this._readFieldValue(target);
    const previousValue = this._readPreviousFieldValue(target);

    this._scheduleFieldSave(`general:${key}`, () => {
      const result = this.hostBridge.saveGeneralSetting(key, value);
      if (!result?.ok) {
        this._writeFieldValue(target, previousValue);
        console.error('Failed to save general setting', { key, error: result?.error || 'Unknown error' });
        return;
      }
      this._writeFieldValue(target, value);
    });
  }

  _schedulePluginFieldSave(target) {
    const pluginId = `${target.getAttribute('data-plugin-id') || ''}`.trim();
    const key = `${target.getAttribute('data-key') || ''}`.trim();
    if (!pluginId || !key) return;

    const value = this._readFieldValue(target);
    const previousValue = this._readPreviousFieldValue(target);

    this._scheduleFieldSave(`plugin:${pluginId}:${key}`, () => {
      const result = this.hostBridge.savePluginSetting(pluginId, key, value);
      if (!result?.ok) {
        this._writeFieldValue(target, previousValue);
        console.error('Failed to save plugin setting', { pluginId, key, error: result?.error || 'Unknown error' });
        return;
      }
      this._writeFieldValue(target, value);
    });
  }

  _schedulePluginToggleSave(target) {
    const id = `${target.id || ''}`;
    const pluginId = id.startsWith('plugin_') ? id.slice('plugin_'.length) : '';
    if (!pluginId) return;

    const enabled = !!target.checked;
    const previousValue = this._readPreviousFieldValue(target);

    this._scheduleFieldSave(`plugin-toggle:${pluginId}`, () => {
      const result = this.hostBridge.togglePlugin(pluginId, enabled);
      if (!result?.ok) {
        this._writeFieldValue(target, previousValue);
        console.error('Failed to toggle plugin', { pluginId, error: result?.error || 'Unknown error' });
        return;
      }
      this._writeFieldValue(target, enabled);
    });
  }

  _bindNavigation() {
    const navRoot = document.querySelector('.settings-nav');
    if (navRoot) {
      navRoot.addEventListener('click', (e) => {
        const item = e.target.closest('.nav-item');
        if (!item) return;
        const sectionName = item.getAttribute('data-section') || item.getAttribute('onclick')?.match(/'([\w-]+)'/)?.[1];
        if (sectionName) {
          this._showSection(sectionName, item);
        }
      });
    }
  }

  _showSection(name, navEl) {
    // Deactivate previous section
    if (this._currentSection === 'logs') {
      this.logs.onPageInactive();
    }

    document.querySelectorAll('.settings-content .settings-section').forEach(section => {
      section.classList.remove('active');
    });

    document.querySelectorAll('.settings-nav .nav-item').forEach(item => {
      item.classList.remove('active');
    });

    const target = document.getElementById(`section-${name}`);
    if (target) {
      target.classList.add('active');
    }
    if (navEl) {
      navEl.classList.add('active');
    }

    // Activate new section
    this._currentSection = name;
    if (name === 'logs') {
      this.logs.onPageActive();
    }
  }

  _bindFilePickers() {
    this._wireFilePicker('StartupSound', 'browseStartupSound', 'StartupSoundFile');
    this._wireFilePicker('NotificationSound', 'browseNotificationSound', 'NotificationSoundFile');
  }

  _wireFilePicker(textInputId, browseBtnId, fileInputId) {
    const txt = document.getElementById(textInputId);
    const btn = document.getElementById(browseBtnId);
    const picker = document.getElementById(fileInputId);
    if (!txt || !btn || !picker) return;
    if (btn.dataset.boundFilePicker === '1') return;
    btn.dataset.boundFilePicker = '1';

    btn.addEventListener('click', () => {
      const selected = this.hostBridge.browseForFile(txt.value || '');
      if (selected) {
        txt.value = selected;
        txt.title = selected;
        txt.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });

    picker.addEventListener('change', () => {
      if (picker.files && picker.files.length > 0) {
        txt.value = picker.files[0].name;
        txt.title = picker.files[0].name;
        txt.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });
  }

  _bindColorPickerDialog() {
    const applyBtn = document.getElementById('applyColorPicker');
    const cancelBtn = document.getElementById('cancelColorPicker');

    // Delegate: listen for clicks on any color picker button
    if (!this._isColorPickerDelegated) {
      this._isColorPickerDelegated = true;
      document.addEventListener('click', (ev) => {
        const trigger = ev.target.closest('[data-color-input-id], [data-color-selector]');
        if (!trigger) return;
        
        // New unified style: data-color-input-id and data-color-swatch-id
        if (trigger.dataset.colorInputId) {
          const inputId = trigger.getAttribute('data-color-input-id');
          const swatchId = trigger.getAttribute('data-color-swatch-id');
          const input = inputId ? document.getElementById(inputId) : null;
          const swatch = swatchId ? document.getElementById(swatchId) : null;
          
          this.colorPicker.targetInput = input;
          this.colorPicker.targetSwatch = swatch;
          this.colorPicker.syncFromTarget();
        } else if (trigger.dataset.colorSelector) {
          // Legacy plugin style: data-color-selector
          this.colorPicker.beginForTrigger(trigger);
        }
      });
    }

    if (applyBtn && applyBtn.dataset.boundColorApply !== '1') {
      applyBtn.dataset.boundColorApply = '1';
      applyBtn.addEventListener('click', () => {
        this.colorPicker.apply();
        if (cancelBtn) cancelBtn.click();
      });
    }
  }

  _bindHotkeyRecorderDialog() {
    const applyBtn = document.getElementById('apply-hotkey-record');

    if (applyBtn) {
      applyBtn.addEventListener('click', () => {
        this.hotkeyRecorder.apply();
      });
    }

  }


  _bindSliderRefresh() {
    const slider = this.dom.getField('WindowTransparencyValue');
    if (slider) {
      if (slider.dataset.boundTransparencySlider === '1') return;
      slider.dataset.boundTransparencySlider = '1';
      slider.addEventListener('input', () => this.form._updateTransparencyUI());
      slider.addEventListener('change', () => this.form._updateTransparencyUI());
    }
  }

  _bindDevToolsButton() {
    const openDevToolsBtn = document.getElementById('open-dev-tools');
    if (!openDevToolsBtn) return;
    if (openDevToolsBtn.dataset.boundDevTools === '1') return;
    openDevToolsBtn.dataset.boundDevTools = '1';

    openDevToolsBtn.addEventListener('click', () => {
      this.hostBridge.openDevTools();
    });
  }

  _bindDynamicGeneralControls() {
    this._bindFilePickers();
    this._bindColorPickerDialog();
    this._bindSliderRefresh();
    this._bindDevToolsButton();
  }

  _findHotkeyIndexByRaw(hotkeyRaw) {
    const raw = `${hotkeyRaw || ''}`.trim();
    if (!raw) return -1;
    return this.form._hotkeyEntries.findIndex((entry) => `${entry.hotKey || ''}`.trim() === raw);
  }

  _bindActionHotkeyRemoval() {
    document.addEventListener('click', (ev) => {
      const removeBtn = ev.target.closest('[data-action-hotkey-remove]');
      if (!removeBtn) return;
      ev.preventDefault();
      ev.stopPropagation();

      const raw = `${removeBtn.getAttribute('data-action-hotkey-remove') || ''}`.trim();
      if (!raw) return;
      const actionItem = removeBtn.closest('.plugin-action-item');
      const actionName = `${actionItem?.getAttribute('data-action-name') || ''}`.trim();

      const idx = this._findHotkeyIndexByRaw(raw);
      if (idx === -1) {
        console.warn('Hotkey not found in local entries, skipping atomic remove', { raw });
        return;
      }

      const result = this.hostBridge.removeHotkey(idx);
      if (!result?.ok) {
        console.error('Failed to remove hotkey', { raw, error: result?.error });
        return;
      }

      this.form.removeHotkeyByRaw(raw);
      this._refreshActionHotkeys(actionName);
      this.form._renderHotkeys(this.form._hotkeyEntries);
    });
  }

  _bindHotkeyBadgeReset() {
    document.addEventListener('click', (ev) => {
      const resetBtn = ev.target.closest('[data-hotkey-reset-field]');
      if (!resetBtn) return;
      ev.preventDefault();
      ev.stopPropagation();

      const fieldId = `${resetBtn.getAttribute('data-hotkey-reset-field') || ''}`.trim();
      const def = `${resetBtn.getAttribute('data-default') || ''}`;
      if (!fieldId) return;

      const field = document.getElementById(fieldId);
      if (!field) return;

      field.value = def;
      field.dispatchEvent(new Event('input', { bubbles: true }));
      field.dispatchEvent(new Event('change', { bubbles: true }));
      this.hotkeyRecorder.updatePreview(fieldId);
      // change event with bubbles:true is caught by atomic autosave handler
    });
  }

  _bindPluginFieldReset() {
    document.addEventListener('click', (ev) => {
      const resetBtn = ev.target.closest('[data-reset-field]');
      if (!resetBtn) return;
      ev.preventDefault();
      ev.stopPropagation();

      const section = resetBtn.closest('.settings-section[id^="section-plugin-"]');
      const sectionId = `${section?.id || ''}`;
      const pluginId = sectionId.startsWith('section-plugin-') ? sectionId.slice('section-plugin-'.length) : '';
      const key = `${resetBtn.getAttribute('data-reset-field') || ''}`.trim();
      const def = `${resetBtn.getAttribute('data-default') || ''}`;
      if (!pluginId || !key) return;

      const selector = `.plugin-field[data-plugin-id="${CSS.escape(pluginId)}"][data-key="${CSS.escape(key)}"]`;
      const field = section ? section.querySelector(selector) : document.querySelector(selector);
      if (!field) return;

      if (field.type === 'checkbox') {
        field.checked = (def === '1' || def === 'true');
      } else {
        field.value = def;
      }

      field.dispatchEvent(new Event('input', { bubbles: true }));
      field.dispatchEvent(new Event('change', { bubbles: true }));

      if (field.classList.contains('plugin-field-hotkey') && field.id) {
        this.hotkeyRecorder.updatePreview(field.id);
      }
    });
  }

  _applyActionHotkey(actionName, hotkeyRaw, replaceRaw) {
    const newRaw = `${hotkeyRaw || ''}`.trim();
    const replaceWith = `${replaceRaw || ''}`.trim();
    if (!newRaw) return;

    let result;
    if (replaceWith) {
      const idx = this._findHotkeyIndexByRaw(replaceWith);
      if (idx !== -1) {
        result = this.hostBridge.saveHotkey(idx, newRaw, actionName);
      } else {
        result = this.hostBridge.addHotkey(newRaw, actionName);
      }
    } else {
      const existingIdx = this.form._hotkeyEntries.findIndex(
        (e) => this.form._extractActionName(e.action) === actionName
      );
      if (existingIdx !== -1) {
        result = this.hostBridge.saveHotkey(existingIdx, newRaw, actionName);
      } else {
        result = this.hostBridge.addHotkey(newRaw, actionName);
      }
    }

    if (!result?.ok) {
      console.error('Failed to save action hotkey', { actionName, hotkeyRaw: newRaw, error: result?.error });
      return;
    }

    this.form.assignActionHotkey(actionName, newRaw, replaceWith);
    this._refreshActionHotkeys(actionName);
    this.form._renderHotkeys(this.form._hotkeyEntries);
  }

  _refreshActionHotkeys(actionName) {
    const wanted = `${actionName || ''}`.trim();
    if (!wanted) return;
    document.querySelectorAll(`.plugin-action-item[data-action-name="${CSS.escape(wanted)}"]`).forEach((item) => {
      const pluginId = `${item.getAttribute('data-plugin-id') || ''}`;
      const hotkeys = this.form.getHotkeysForAction(wanted);
      const host = item.querySelector('.plugin-action-hotkeys');
      if (!host) return;

      if (!hotkeys.length) {
        host.innerHTML = `<button type="button" class="app-btn plugin-hotkey-badge plugin-hotkey-badge-empty" data-hotkey-action="${this.form._escapeHtml(wanted)}" data-win-toggle="modal" data-win-target="#HotkeyRecorderDialog">Assign hotkey</button>`;
        return;
      }

      host.innerHTML = hotkeys.map((hk) => this.form._renderActionHotkeyBadge(pluginId, wanted, hk)).join('');
    });
  }

  _saveSettings() {
    const invalidField = document.querySelector('.settings-content :invalid');
    if (invalidField) {
      if (typeof invalidField.reportValidity === 'function') {
        invalidField.reportValidity();
      }
      if (typeof invalidField.focus === 'function') {
        invalidField.focus();
      }
      return;
    }

    const payloadObject = this.form.serializeObject();
    this.hostBridge.saveSettings(payloadObject);
  }

  refreshUI() {
    this.form.refreshUI(this.colorPicker, this.hotkeyRecorder);
  }

  /**
   * Apply state from AHK
   */
  applyState(state) {
    this._isApplyingState = true;
    const t0 = performance.now();
    const prevState = this._lastAppliedState || null;
    const changes = this.form.applyState(state, prevState);
    const t1 = performance.now();
    // Keep exact incoming AHK payload for DevTools export/import replay.
    this._lastAppliedState = state ? JSON.parse(JSON.stringify(state)) : null;

    if (changes.generalSchemaChanged || changes.pluginPagesSchemaChanged) {
      this._bindDynamicGeneralControls();
    }
    if (changes.generalSchemaChanged || changes.generalValuesChanged || changes.pluginPagesSchemaChanged || changes.pluginFieldValuesChanged || changes.hotkeysChanged) {
      this.refreshUI();
    }
    const t2 = performance.now();

    if (this._isVerboseUiDebug(state)) {
      console.debug('[SettingsUI] applyState timings', {
        totalMs: Math.round((t2 - t0) * 100) / 100,
        formApplyMs: Math.round((t1 - t0) * 100) / 100,
        postApplyMs: Math.round((t2 - t1) * 100) / 100,
        changes,
        rowOperations: changes.rowOperations
      });
    }

    const openPage = `${state?.openPage || ''}`.trim();
    if (openPage) {
      const navEl = this.dom.getNavItem(openPage) || document.querySelector(`.settings-nav .nav-item[data-section="${CSS.escape(openPage)}"]`);
      this._showSection(openPage, navEl);
    }

    if (Array.isArray(state?.logLevelFilter) && state.logLevelFilter.length > 0) {
      this.logs.setLevelFilter(state.logLevelFilter);
    }

    this._isApplyingState = false;
  }

  _isVerboseUiDebug(state) {
    try {
      const sections = state?.generalPage?.sections || [];
      for (const section of sections) {
        for (const field of (section?.fields || [])) {
          if (`${field?.key || ''}` === 'DebugLevel') {
            const level = Number(field?.value ?? field?.default ?? 0);
            return Number.isFinite(level) && level >= 4;
          }
        }
      }
    } catch (error) {
      return false;
    }
    return false;
  }

  _goToSetting(settingRef) {
    const { page, section, key, index } = settingRef || {};
    if (!page) return;

    // Navigate to the page
    this._showSection(page);

    // Find and scroll to the field
    let targetEl = null;
    const hotkeyIndex = Number(index);
    if (page === 'hotkeys' && Number.isInteger(hotkeyIndex) && hotkeyIndex >= 0) {
      // For hotkeys, find the row at index
      const tbody = this.dom.getField('hotkeys-tbody');
      if (tbody) {
        const rows = tbody.querySelectorAll('tr');
        if (rows[hotkeyIndex]) {
          targetEl = rows[hotkeyIndex];
        }
      }
    } else {
      // For general/plugin pages, find the field
      const selector = key ? `[data-key="${CSS.escape(key)}"]` : null;
      if (selector) {
        const sectionEl = this.dom.getSection(page);
        if (sectionEl) {
          targetEl = sectionEl.querySelector(selector);
        }
      }
    }

    if (targetEl) {
      targetEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
      // Add highlight class
      targetEl.classList.add('setting-highlight');
      // Remove after 2s
      setTimeout(() => targetEl.classList.remove('setting-highlight'), 2000);
    }
  }
}

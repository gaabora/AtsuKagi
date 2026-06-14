class SettingsPage {
  constructor() {
    this.dom = new SettingsDom();
    this.hostBridge = new AhkHostBridge();
    this.form = new SettingsForm(this.dom);
    this.colorPicker = new ColorPickerController(this.dom);
    this.hotkeyRecorder = new HotkeyRecorderController(this.dom, (actionName, hotkeyRaw, replaceRaw, allowRiskyHotkeys, fullActionHandler) => this._applyActionHotkey(actionName, hotkeyRaw, replaceRaw, allowRiskyHotkeys, fullActionHandler));
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
    const cancelBtn = document.querySelector('[data-action="close-settings"]');
    const minimizeBtn = document.querySelector('[data-action="minimize-window"]');

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

      if (target.classList.contains('plugin-debug-level')) {
        this._schedulePluginDebugLevelSave(target);
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
      if (key === 'DebugLevel') this._refreshPluginGlobalDebugLabels(value);
    });
  }

  _refreshPluginGlobalDebugLabels(value) {
    const level = Number(value);
    const labels = ['Error', 'Warning', 'Notice', 'Info', 'Debug', 'Trace'];
    const label = labels[level] || 'Unknown';
    document.querySelectorAll('.plugin-debug-level option[value="-1"]').forEach((option) => {
      option.textContent = `Use global (${level} - ${label})`;
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
      const state = target.closest('.plugin-item')?.querySelector('.plugin-state');
      if (state) state.textContent = enabled ? 'Enabled' : 'Disabled';
    });
  }

  _schedulePluginDebugLevelSave(target) {
    const pluginId = `${target.getAttribute('data-plugin-id') || ''}`.trim();
    if (!pluginId) return;

    const level = Number(target.value);
    const previousValue = this._readPreviousFieldValue(target);

    this._scheduleFieldSave(`plugin-debug:${pluginId}`, () => {
      const result = this.hostBridge.setPluginDebugLevel(pluginId, level);
      if (!result?.ok) {
        this._writeFieldValue(target, previousValue);
        console.error('Failed to save plugin debug level', { pluginId, error: result?.error || 'Unknown error' });
        return;
      }
      this._writeFieldValue(target, level);
    });
  }

  _bindNavigation() {
    const navRoot = document.querySelector('.settings-nav');
    if (navRoot) {
      navRoot.addEventListener('click', (e) => {
        const item = e.target.closest('.nav-item');
        if (!item) return;
        if (item.tagName === 'A') {
          e.preventDefault();
        }
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

    const pageShell = document.querySelector('.settings-page-shell');
    const settingsContent = document.querySelector('.settings-content');
    const isLogsSection = name === 'logs';
    if (pageShell) {
      pageShell.classList.toggle('logs-layout', isLogsSection);
    }
    if (settingsContent) {
      settingsContent.classList.toggle('logs-layout', isLogsSection);
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

  _bindOnce(el, key, event, handler) {
    if (!el || el.dataset[key] === '1') return false;
    el.dataset[key] = '1';
    el.addEventListener(event, handler);
    return true;
  }

  _wireFilePicker(textInputId, browseBtnId, fileInputId) {
    const txt = document.getElementById(textInputId);
    const btn = document.getElementById(browseBtnId);
    const picker = document.getElementById(fileInputId);
    if (!txt || !btn || !picker) return;

    this._bindOnce(btn, 'boundFilePicker', 'click', () => {
      const selected = this.hostBridge.browseForFile(txt.value || '');
      if (selected) {
        txt.value = selected;
        txt.title = selected;
        txt.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });

    this._bindOnce(picker, 'boundFilePickerChange', 'change', () => {
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
        const trigger = ev.target.closest('[data-color-input-id]');
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
        }

        // Open dialog for dynamically rendered buttons (windows-ui.min.js
        // only binds data-win-toggle="modal" at page load)
        const dialog = document.querySelector('#ColorPickerDialog');
        if (dialog && !dialog.classList.contains('show')) {
          dialog.classList.add('show');
        }
      });
    }

    this._bindOnce(applyBtn, 'boundColorApply', 'click', () => {
      this.colorPicker.apply();
      if (cancelBtn) cancelBtn.click();
    });
  }

  _bindHotkeyRecorderDialog() {
    const applyBtn = document.getElementById('saveHotkey');
    const cancelBtn = document.getElementById('canceHotkey');
    const removeBtn = document.getElementById('removeHotkey');
    const resetBtn = document.getElementById('resetHotkey');

    this._bindOnce(applyBtn, 'boundHotkeyApply', 'click', () => {
      const ok = this.hotkeyRecorder.apply();
      if (ok && cancelBtn) cancelBtn.click();
    });

    this._bindOnce(cancelBtn, 'boundHotkeyCancel', 'click', () => {
      this.hotkeyRecorder.cancel();
    });

    this._bindOnce(removeBtn, 'boundHotkeyRemove', 'click', () => {
        this.hotkeyRecorder.remove();

        if (this.hotkeyRecorder.actionTarget) {
          const actionName = `${this.hotkeyRecorder.actionTarget.actionName || ''}`.trim();
          const replaceRaw = `${this.hotkeyRecorder.actionTarget.replaceHotkeyRaw || ''}`.trim();

          let idx = -1;
          if (replaceRaw) {
            idx = this._findHotkeyIndexByRaw(replaceRaw);
          }
          if (idx === -1) {
            idx = this.form._hotkeyEntries.findIndex(
              (e) => this.form._extractActionName(e.action) === actionName
            );
          }

          if (idx !== -1) {
            const removedRaw = `${this.form._hotkeyEntries[idx]?.hotKey || ''}`.trim();
            const result = this.hostBridge.removeHotkey(idx);
            if (result?.ok) {
              if (removedRaw) this.form.removeHotkeyByRaw(removedRaw);
              this._refreshActionHotkeys(actionName);
              this.form._renderHotkeys(this.form._hotkeyEntries);
              if (cancelBtn) cancelBtn.click();
            }
          }
          return;
        }

        const input = this.hotkeyRecorder.targetElement
          || (this.hotkeyRecorder.targetId ? this.dom.getField(this.hotkeyRecorder.targetId) : null);
        if (!input) return;
        input.value = '';
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        if (this.hotkeyRecorder.targetId) this.hotkeyRecorder.updatePreview(this.hotkeyRecorder.targetId);
        if (cancelBtn) cancelBtn.click();
    });

    this._bindOnce(resetBtn, 'boundHotkeyReset', 'click', () => {
      this.hotkeyRecorder.reset();
    });

  }


  _bindSliderRefresh() {
    if (this._sliderRefreshBound) return;
    this._sliderRefreshBound = true;

    const clampRangeValue = (rangeEl, rawValue, commit = false) => {
      if (!(rangeEl instanceof HTMLInputElement) || rangeEl.type !== 'range') return null;

      let value = Number(rawValue);
      if (!Number.isFinite(value)) {
        value = Number(rangeEl.value);
      }
      if (!Number.isFinite(value)) return null;

      const min = rangeEl.min !== '' ? Number(rangeEl.min) : NaN;
      const max = rangeEl.max !== '' ? Number(rangeEl.max) : NaN;
      const step = rangeEl.step !== '' ? Number(rangeEl.step) : NaN;

      if (Number.isFinite(min)) value = Math.max(value, min);
      if (Number.isFinite(max)) value = Math.min(value, max);

      if (commit && Number.isFinite(step) && step > 0) {
        const base = Number.isFinite(min) ? min : 0;
        const steps = Math.round((value - base) / step);
        value = base + steps * step;
        if (Number.isFinite(min)) value = Math.max(value, min);
        if (Number.isFinite(max)) value = Math.min(value, max);
      }

      return value;
    };

    const formatValue = (value, stepText) => {
      const step = Number(stepText);
      if (!Number.isFinite(value)) return '';
      if (!Number.isFinite(step) || step <= 0 || Number.isInteger(step)) {
        return `${Math.round(value)}`;
      }

      const stepStr = `${step}`;
      const dot = stepStr.indexOf('.');
      const precision = dot >= 0 ? (stepStr.length - dot - 1) : 0;
      return value.toFixed(Math.min(Math.max(precision, 0), 6));
    };

    const syncFromRange = (rangeEl, skipNumberUpdate = false) => {
      if (!(rangeEl instanceof HTMLInputElement) || rangeEl.type !== 'range') return;

      const numberId = `${rangeEl.getAttribute('data-range-number-id') || ''}`;
      const numberEl = numberId ? document.getElementById(numberId) : null;

      const value = clampRangeValue(rangeEl, rangeEl.value, false);
      if (!Number.isFinite(value)) return;

      const normalized = formatValue(value, rangeEl.step);
      if (!skipNumberUpdate && numberEl instanceof HTMLInputElement) {
        numberEl.value = normalized;
      }

      if (rangeEl.id === 'WindowTransparencyValue') {
        this.form._updateTransparencyUI();
      }
    };

    document.addEventListener('input', (ev) => {
      const target = ev.target;

      if (target instanceof HTMLInputElement && target.type === 'range' && target.hasAttribute('data-range-number-id')) {
        syncFromRange(target);
        return;
      }

      if (!(target instanceof HTMLInputElement) || target.type !== 'number') return;
      if (!target.hasAttribute('data-range-source-id')) return;

      const rangeId = `${target.getAttribute('data-range-source-id') || ''}`;
      const rangeEl = rangeId ? document.getElementById(rangeId) : null;
      if (!(rangeEl instanceof HTMLInputElement) || rangeEl.type !== 'range') return;

      const value = clampRangeValue(rangeEl, target.value, false);
      if (!Number.isFinite(value)) return;

      const normalized = formatValue(value, rangeEl.step);
      rangeEl.value = normalized;
      syncFromRange(rangeEl, true);

      rangeEl.dispatchEvent(new Event('input', { bubbles: true }));
    });

    document.addEventListener('change', (ev) => {
      const target = ev.target;

      if (target instanceof HTMLInputElement && target.type === 'range' && target.hasAttribute('data-range-number-id')) {
        syncFromRange(target);
        return;
      }

      if (!(target instanceof HTMLInputElement) || target.type !== 'number') return;
      if (!target.hasAttribute('data-range-source-id')) return;

      const rangeId = `${target.getAttribute('data-range-source-id') || ''}`;
      const rangeEl = rangeId ? document.getElementById(rangeId) : null;
      if (!(rangeEl instanceof HTMLInputElement) || rangeEl.type !== 'range') return;

      const value = clampRangeValue(rangeEl, target.value, true);
      if (!Number.isFinite(value)) {
        syncFromRange(rangeEl);
        return;
      }

      const normalized = formatValue(value, rangeEl.step);
      target.value = normalized;
      rangeEl.value = normalized;
      syncFromRange(rangeEl);

      rangeEl.dispatchEvent(new Event('input', { bubbles: true }));
      rangeEl.dispatchEvent(new Event('change', { bubbles: true }));
    });

    // Sync all range inputs (both general and plugin scope)
    document.querySelectorAll('input[type="range"][data-range-number-id]').forEach((rangeEl) => {
      if (rangeEl instanceof HTMLInputElement) {
        syncFromRange(rangeEl);
      }
    });
  }

  _bindDevToolsButton() {
    const openDevToolsBtn = document.getElementById('openDevTools');
    this._bindOnce(openDevToolsBtn, 'boundDevTools', 'click', () => {
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

  _applyActionHotkey(actionName, hotkeyRaw, replaceRaw, allowRiskyHotkeys = false, fullActionHandler = '') {
    const newRaw = `${hotkeyRaw || ''}`.trim();
    const replaceWith = `${replaceRaw || ''}`.trim();
    const handlerToSave = `${fullActionHandler || actionName || ''}`.trim();
    if (!newRaw) return { ok: false, error: 'Hotkey cannot be empty' };

    let result;
    if (replaceWith) {
      const idx = this._findHotkeyIndexByRaw(replaceWith);
      if (idx !== -1) {
        result = this.hostBridge.saveHotkey(idx, newRaw, handlerToSave, allowRiskyHotkeys);
      } else {
        result = this.hostBridge.addHotkey(newRaw, handlerToSave, allowRiskyHotkeys);
      }
    } else {
      const existingIdx = this.form._hotkeyEntries.findIndex(
        (e) => this.form._extractActionName(e.action) === actionName
      );
      if (existingIdx !== -1) {
        result = this.hostBridge.saveHotkey(existingIdx, newRaw, handlerToSave, allowRiskyHotkeys);
      } else {
        result = this.hostBridge.addHotkey(newRaw, handlerToSave, allowRiskyHotkeys);
      }
    }

    if (!result?.ok) {
      const problemList = Array.isArray(result?.problems)
        ? result.problems.filter((msg) => `${msg || ''}`.trim() !== '')
        : [];
      const errorText = problemList.length
        ? problemList.join('; ')
        : `${result?.error || 'Failed to save hotkey'}`;
      console.error('Failed to save action hotkey', { actionName, hotkeyRaw: newRaw, error: errorText });
      return { ok: false, error: errorText, problems: problemList };
    }

    this.form.assignActionHotkey(actionName, newRaw, replaceWith, fullActionHandler);
    this._refreshActionHotkeys(actionName);
    this.form._renderHotkeys(this.form._hotkeyEntries);
    return { ok: true };
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
        host.innerHTML = this.form._renderActionHotkeyBadge(pluginId, wanted, '');
        return;
      }

      host.innerHTML = hotkeys.map((hk) => this.form._renderActionHotkeyBadge(pluginId, wanted, hk)).join('');
    });
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
    this._applyUIScaling(state);

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

  _isVerboseUiDebug(state) { //FIXME: wth is this, why not use apps debug level
    try {
      const sections = state?.generalPage?.sections || [];
      for (const section of sections) {
        for (const field of (section?.fields || [])) {
          if (`${field?.key || ''}` === 'DebugLevel') {
             //FIXME: magic numbers 0,4 - can be made more explicit with enum or constant export from AHK
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

  _applyUIScaling(state) {
    try {
      const generalPage = state?.generalPage;
      if (!generalPage) return;
      
      const sections = generalPage.sections || [];
      for (const section of sections) {
        const fields = section.fields || [];
        for (const field of fields) {
          if (field.key === 'UIScalingPercent') {
            const percent = Number(field.value) || 100;
            const scale = percent / 100;
            document.documentElement.style.setProperty('--ui-scale', scale);
            return;
          }
        }
      }
    } catch (error) {
      console.error('Failed to apply UI scaling:', error);
    }
  }
}

class SettingsPage {
  constructor() {
    this.dom = new SettingsDom();
    this.hostBridge = new AhkHostBridge();
    this.form = new SettingsForm(this.dom);
    this.colorPicker = new ColorPickerController(this.dom);
    this.hotkeyRecorder = new HotkeyRecorderController(this.dom, (actionName, hotkeyRaw, replaceRaw) => this._applyActionHotkey(actionName, hotkeyRaw, replaceRaw));
    this._isApplyingState = false;
    this._autoSaveTimer = 0;
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
    this._bindAutoSave();
    this._bindActionHotkeyRemoval();
    this._bindHotkeyBadgeReset();
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

  _bindAutoSave() {
    const contentRoot = document.querySelector('.settings-content');
    if (!contentRoot) return;

    const onChange = (ev) => {
      if (this._isApplyingState) return;
      const target = ev.target;
      if (!target) return;
      if (!(target instanceof HTMLInputElement || target instanceof HTMLSelectElement || target instanceof HTMLTextAreaElement))
        return;
      this._scheduleAutoSave();
    };

    contentRoot.addEventListener('change', onChange);
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
      }
    });

    picker.addEventListener('change', () => {
      if (picker.files && picker.files.length > 0) {
        txt.value = picker.files[0].name;
        txt.title = picker.files[0].name;
      }
    });
  }

  _bindColorPickerDialog() {
    const toggleBtn = document.getElementById('toggleBorderColorPicker');
    const applyBtn = document.getElementById('applyColorPicker');
    const cancelBtn = document.getElementById('cancelColorPicker');

    if (toggleBtn && toggleBtn.dataset.boundColorToggle !== '1') {
      toggleBtn.dataset.boundColorToggle = '1';
      toggleBtn.addEventListener('click', () => this.colorPicker.syncFromForm());
    }
    if (!this._isColorSelectorDelegated) {
      this._isColorSelectorDelegated = true;
      document.addEventListener('click', (ev) => {
        const trigger = ev.target.closest('[data-color-selector]');
        if (!trigger) return;
        this.colorPicker.beginForTrigger(trigger);
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
    const applyBtn = document.getElementById('applyHotkeyRecord');

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
    const openDevToolsBtn = document.getElementById('openDevTools');
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

      this.form.removeHotkeyByRaw(raw);
      this._refreshActionHotkeys(actionName);
      this.form._renderHotkeys(this.form._hotkeyEntries);
      this._scheduleAutoSave();
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
      field.dispatchEvent(new Event('input'));
      field.dispatchEvent(new Event('change'));
      this.hotkeyRecorder.updatePreview(fieldId);
      this._scheduleAutoSave();
    });
  }

  _applyActionHotkey(actionName, hotkeyRaw, replaceRaw) {
    this.form.assignActionHotkey(actionName, hotkeyRaw, replaceRaw);
    this._refreshActionHotkeys(actionName);
    this.form._renderHotkeys(this.form._hotkeyEntries);
    this._scheduleAutoSave();
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

  _scheduleAutoSave() {
    if (this._autoSaveTimer) {
      clearTimeout(this._autoSaveTimer);
    }
    this._autoSaveTimer = setTimeout(() => {
      this._autoSaveTimer = 0;
      this._saveSettings();
    }, 350);
  }

  _saveSettings() {
    const payloadObject = this.form.serializeObject();
    console.log('Saving settings...', { payloadObject });
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
    // Keep exact incoming AHK payload for DevTools export/import replay.
    this._lastAppliedState = state ? JSON.parse(JSON.stringify(state)) : null;
    this.form.applyState(state);
    this._bindDynamicGeneralControls();
    this.refreshUI();
    this._isApplyingState = false;
  }
}


/**
 * SettingsForm: Manages form state and serialization.
 */
class SettingsForm {
  constructor(dom) {
    this.dom = dom;
    this._hotkeyEntries = [];
    this._defaultActionHotkeys = new Map();
    this.logsController = null;
    this.renderer = new SettingsFormRenderer(this);
    this.pluginPagesRenderer = new SettingsFormPluginPagesRenderer(this);
    this.actionsRenderer = new SettingsFormActionsRenderer(this);
  }

  /**
   * Serialize form state into save payload.
   */
  serializeObject() {
    const general = this._readGeneralFields();

    const disabledPlugins = [];
    this.dom.getPluginCheckboxes().forEach(cb => {
      if (!cb.checked) {
        disabledPlugins.push(cb.id.substring(7));
      }
    });

    const pluginConfigs = {};
    document.querySelectorAll('.plugin-field[data-plugin-id][data-key]').forEach((el) => {
      const pluginId = el.getAttribute('data-plugin-id') || '';
      const key = el.getAttribute('data-key') || '';
      if (!pluginId || !key) return;

      if (!pluginConfigs[pluginId]) {
        pluginConfigs[pluginId] = {};
      }

      let value = '';
      if (el.type === 'checkbox') {
        value = !!el.checked;
      } else {
        value = el.value || '';
      }
      pluginConfigs[pluginId][key] = value;
    });

    return {
      general,
      disabledPlugins,
      pluginConfigs,
      hotkeys: [...this._hotkeyEntries]
    };
  }

  /**
   * Apply incoming state from AHK to form DOM.
   */
  applyState(state, prevState = null) {
    if (!state) return {
      generalSchemaChanged: false,
      generalValuesChanged: false,
      pluginListChanged: false,
      pluginPagesSchemaChanged: false,
      pluginFieldValuesChanged: false,
      hotkeysChanged: false,
      logsChanged: false,
      themeChanged: false,
      titleChanged: false,
      rowOperations: { adds: 0, replaces: 0, removes: 0 }
    };

    // Initialize counters for row-level operations during this apply cycle
    this._rowOpsAdds = 0;
    this._rowOpsReplaces = 0;
    this._rowOpsRemoves = 0;

    const currentSig = SettingsFormSerializer.buildStateSignatures(state);
    const previousSig = SettingsFormSerializer.buildStateSignatures(prevState || null);

    const generalSchemaChanged = currentSig.generalSchema !== previousSig.generalSchema;
    const generalValuesChanged = currentSig.generalValues !== previousSig.generalValues;
    const pluginListChanged = currentSig.pluginList !== previousSig.pluginList;
    const pluginPagesSchemaChanged = currentSig.pluginPagesSchema !== previousSig.pluginPagesSchema;
    const pluginFieldValuesChanged = currentSig.pluginFieldValues !== previousSig.pluginFieldValues;
    const hotkeysChanged = currentSig.hotkeys !== previousSig.hotkeys;
    const hasLogs = Array.isArray(state.logs);
    const prevLogs = Array.isArray(prevState?.logs) ? prevState.logs : null;
    const currentLogs = hasLogs ? state.logs : [];
    const prevLast = prevLogs && prevLogs.length ? Number(prevLogs[prevLogs.length - 1]?.id ?? -1) : -1;
    const currentLast = currentLogs.length ? Number(currentLogs[currentLogs.length - 1]?.id ?? -1) : -1;
    const logsChanged = hasLogs && (
      !prevLogs ||
      currentLogs.length !== prevLogs.length ||
      currentLast !== prevLast
    );
    const themeChanged = currentSig.theme !== previousSig.theme;
    const titleChanged = currentSig.title !== previousSig.title;

    try {
      if (state.generalPage && generalSchemaChanged) {
        this.renderGeneralPage(state.generalPage);
        if (this.dom && typeof this.dom.cache === 'function') {
          this.dom.cache();
        }
      }
      if (state.generalPage && (generalSchemaChanged || generalValuesChanged)) {
        this._applyGeneralFieldValues(state.generalPage);
      }
    } catch (error) {
      console.error('General settings render failed', error);
    }

    try {
      this._defaultActionHotkeys = new Map();
      const defaults = state?.defaultActionHotkeys;
      if (defaults && typeof defaults === 'object') {
        Object.keys(defaults).forEach((actionName) => {
          const key = `${actionName || ''}`.trim();
          if (!key) return;
          const raw = defaults[actionName];
          const arr = Array.isArray(raw) ? raw.map((hk) => `${hk || ''}`.trim()).filter(Boolean) : [];
          this._defaultActionHotkeys.set(key, arr);
        });
      }

      if (hotkeysChanged) {
        this._hotkeyEntries = Array.isArray(state.hotkeys)
          ? state.hotkeys
              .map((hk) => ({ hotKey: `${hk?.hotKey || ''}`, action: `${hk?.action || ''}` }))
              .filter((hk) => hk.hotKey && hk.action)
          : [];
      }
    } catch (error) {
      console.error('Hotkeys state parse failed', error);
      this._hotkeyEntries = [];
    }

    try {
      if (state.plugins) {
        if (pluginListChanged) {
          this._renderPlugins(state.plugins);
        }
        if (pluginPagesSchemaChanged) {
          if (state.plugins.pages) {
            this._renderPluginSettingsPages(state.plugins.pages);
          }
        } else if (pluginFieldValuesChanged && state.plugins.pages) {
          this._applyPluginFieldValues(state.plugins.pages);
        }
      }
    } catch (error) {
      console.error('Plugin settings render failed', error);
    }

    try {
      if (hotkeysChanged && state.hotkeys) {
        this._renderHotkeys(state.hotkeys);
        if (!pluginPagesSchemaChanged) {
          this._syncPluginActionHotkeys();
        }
      }
    } catch (error) {
      console.error('Hotkeys table render failed', error);
    }

    try {
      if (logsChanged && this.logsController) {
        this.logsController.setLogs(state.logs);
      }
    } catch (error) {
      console.error('Logs render failed', error);
    }

    try {
      if (themeChanged) {
        if (state.theme === 'dark') {
          document.documentElement.setAttribute('data-theme', 'dark');
          document.body.classList.add('dark-theme');
        } else if (state.theme === 'light') {
          document.documentElement.setAttribute('data-theme', 'light');
          document.body.classList.remove('dark-theme');
        }
      }
    } catch (error) {
      console.error('Theme apply failed', error);
    }

    try {
      if (titleChanged && state.title) {
        const titleEl = this.dom.getField('titleText');
        if (titleEl) titleEl.innerText = state.title;
      }
    } catch (error) {
      console.error('Title apply failed', error);
    }

    const rowOperations = {
      adds: this._rowOpsAdds || 0,
      replaces: this._rowOpsReplaces || 0,
      removes: this._rowOpsRemoves || 0
    };

    return {
      generalSchemaChanged,
      generalValuesChanged,
      pluginListChanged,
      pluginPagesSchemaChanged,
      pluginFieldValuesChanged,
      hotkeysChanged,
      logsChanged,
      themeChanged,
      titleChanged,
      rowOperations
    };
  }

  _readGeneralFields() {
    const general = {};
    document.querySelectorAll('.general-field[data-key][data-type]').forEach((el) => {
      const key = `${el.getAttribute('data-key') || ''}`.trim();
      const valueType = `${el.getAttribute('data-type') || 'string'}`.trim();
      if (!key) return;

      let value;
      if (el.type === 'checkbox') {
        value = !!el.checked;
      } else {
        value = `${el.value ?? ''}`;
      }

      if (valueType === 'boolean') {
        general[key] = !!value;
      } else {
        general[key] = value;
      }
    });
    return general;
  }

  _applyGeneralFieldValues(generalPage) {
    if (!Array.isArray(generalPage?.sections)) return;

    generalPage.sections.forEach((section) => {
      (section?.fields || []).forEach((field) => {
        const key = `${field?.key || ''}`.trim();
        if (!key) return;
        const value = field && Object.prototype.hasOwnProperty.call(field, 'value') ? field.value : '';
        const target = document.querySelector(`.general-field[data-key="${CSS.escape(key)}"]`);
        if (!target) return;

        if (target.type === 'checkbox') {
          target.checked = (value === true || value === 1 || value === '1' || value === 'true');
        } else {
          target.value = `${value ?? ''}`;
        }
      });
    });
  }

  _applyPluginFieldValues(pages) {
    (pages || []).forEach((page) => {
      const pageId = `${page?.id || ''}`;
      if (!pageId) return;

      (page?.sections || []).forEach((section) => {
        (section?.fields || []).forEach((field) => {
          const key = `${field?.key || ''}`.trim();
          if (!key) return;

          const value = field && Object.prototype.hasOwnProperty.call(field, 'value') ? field.value : '';
          const selector = `.plugin-field[data-plugin-id="${CSS.escape(pageId)}"][data-key="${CSS.escape(key)}"]`;
          const target = document.querySelector(selector);
          if (!target) return;

          if (target.type === 'checkbox') {
            target.checked = (value === true || value === 1 || value === '1' || value === 'true');
          } else {
            target.value = `${value ?? ''}`;
          }

          target.dispatchEvent(new Event('input'));
          target.dispatchEvent(new Event('change'));
        });
      });
    });
  }

  renderGeneralPage(page) {
    this.renderer.renderGeneralPage(page);
  }

  _renderField(field, scope = 'general', pluginId = null) {
    return this.renderer.renderField(field, scope, pluginId);
  }

  _getGeneralPathBrowseMeta(key) {
    if (key === 'StartupSound') {
      return { buttonId: 'browseStartupSound', fileInputId: 'StartupSoundFile' };
    }
    if (key === 'NotificationSound') {
      return { buttonId: 'browseNotificationSound', fileInputId: 'NotificationSoundFile' };
    }
    return null;
  }

  _getGeneralSelectOptions(field) {
    if (Array.isArray(field?.options) && field.options.length) {
      return field.options;
    }

    return [{ value: `${field?.value ?? field?.default ?? ''}`, label: `${field?.value ?? field?.default ?? ''}` }];
  }

  _renderPlugins(plugins) {
    const pluginsEl = this.dom.getField('plugins-list');
    if (!pluginsEl) return;

    let html = '';
    const disabled = plugins.disabled || [];

    plugins.available?.forEach(pluginName => {
      const isChecked = !disabled.includes(pluginName);
      const checked = isChecked ? ' checked' : '';
      html += `<div class="plugin-item"><input class="app-checkbox" type="checkbox" id="plugin_${pluginName}"${checked} /><label for="plugin_${pluginName}">${this._escapeHtml(pluginName)}</label></div>`;
    });

    pluginsEl.innerHTML = html;
  }

  _renderHotkeys(hotkeys) {
    const tbody = this.dom.getField('hotkeys-tbody');
    if (!tbody) return;

    let html = '';
    hotkeys.forEach(hk => {
      html += `<tr><td>${this._escapeHtml(hk.hotKey || '')}</td><td>${this._escapeHtml(hk.action || '')}</td></tr>`;
    });

    tbody.innerHTML = html;
  }

  _escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  _renderPluginSettingsPages(pages) {
    this.pluginPagesRenderer.renderPluginSettingsPages(pages);
  }

  _pluginFieldSignature(field) {
    if (!field) return '';
    return SettingsFormSerializer.signature({
      key: `${field?.key || ''}`,
      pluginId: `${field?.pluginId || ''}`,
      label: `${field?.label || ''}`,
      description: `${field?.description || ''}`,
      type: `${field?.type || ''}`,
      control: `${field?.control || ''}`,
      default: `${field?.default ?? ''}`,
      value: `${field?.value ?? ''}`,
      scope: `${field?.scope || ''}`,
      validation: field?.validation || {},
      options: field?.options || []
    });
  }

  _renderPluginActionsSummary(pluginId, actions) {
    return this.actionsRenderer.renderPluginActionsSummary(pluginId, actions);
  }

  _renderActionHotkeyBadge(pluginId, actionName, hotkeyRaw) {
    return this.actionsRenderer.renderActionHotkeyBadge(pluginId, actionName, hotkeyRaw);
  }

  _syncPluginActionHotkeys() {
    this.actionsRenderer.syncPluginActionHotkeys();
  }

  _extractActionName(actionText) {
    const txt = `${actionText || ''}`.trim();
    if (!txt) return '';
    const idx = txt.indexOf('(');
    return (idx === -1 ? txt : txt.slice(0, idx)).trim();
  }

  getHotkeysForAction(actionName) {
    const wanted = `${actionName || ''}`.trim();
    if (!wanted) return [];
    return this._hotkeyEntries
      // .filter((entry) => this._extractActionName(entry.action) === wanted)
      .filter((entry) => entry.action.includes(wanted))
      .map((entry) => entry.hotKey)
      .filter(Boolean);
  }

  getFullActionHandlerForHotkey(hotkeyRaw) {
    const wanted = `${hotkeyRaw || ''}`.trim();
    if (!wanted) return '';
    const entry = this._hotkeyEntries.find((e) => `${e.hotKey || ''}`.trim() === wanted);
    return entry ? `${entry.action || ''}`.trim() : '';
  }

  getDefaultHotkeyForAction(actionName) {
    const wanted = `${actionName || ''}`.trim();
    if (!wanted || !this._defaultActionHotkeys.has(wanted)) return '';
    const values = this._defaultActionHotkeys.get(wanted);
    return Array.isArray(values) && values.length ? `${values[0] || ''}`.trim() : '';
  }

  assignActionHotkey(actionName, newHotkeyRaw, replaceHotkeyRaw = '', fullActionHandler = '') {
    const wanted = `${actionName || ''}`.trim();
    const newRaw = `${newHotkeyRaw || ''}`.trim();
    const replaceRaw = `${replaceHotkeyRaw || ''}`.trim();
    const handlerToStore = `${fullActionHandler || wanted || ''}`.trim();
    if (!wanted || !newRaw) return;

    this._hotkeyEntries = this._hotkeyEntries.filter((entry) => `${entry.hotKey || ''}`.trim() !== newRaw);

    if (replaceRaw) {
      let replaced = false;
      this._hotkeyEntries = this._hotkeyEntries.map((entry) => {
        if (`${entry.hotKey || ''}`.trim() === replaceRaw) {
          replaced = true;
          return { hotKey: newRaw, action: handlerToStore };
        }
        return entry;
      });
      if (!replaced) {
        this._hotkeyEntries.push({ hotKey: newRaw, action: handlerToStore });
      }
      return;
    }

    const existingForAction = this._hotkeyEntries.find((entry) => this._extractActionName(entry.action) === wanted);
    if (existingForAction) {
      existingForAction.hotKey = newRaw;
      return;
    }

    this._hotkeyEntries.push({ hotKey: newRaw, action: wanted });
  }

  removeHotkeyByRaw(hotkeyRaw) {
    const raw = `${hotkeyRaw || ''}`.trim();
    if (!raw) return;
    this._hotkeyEntries = this._hotkeyEntries.filter((entry) => `${entry.hotKey || ''}`.trim() !== raw);
  }

  _renderPluginField(field) {
    // Plugin fields now use the unified _renderField with scope='plugin'
    return this._renderField(field, 'plugin', field?.pluginId);
  }

  _resetPluginFields(pluginId) {
    const section = document.getElementById(`section-plugin-${pluginId}`);
    if (!section) return;

    section.querySelectorAll('[data-reset-field]').forEach(btn => {
      btn.click();
    });
    section.querySelectorAll('[data-hotkey-reset-field]').forEach((btn) => {
      btn.click();
    });
  }

  /**
   * Refresh derived UI: slider label, color swatch, hotkey displays.
   */
  refreshUI(colorController, hotkeyController) {
    this._updateTransparencyUI();
    if (colorController) {
      colorController.syncFromForm();
      colorController.updatePluginSwatches();
    }
    if (hotkeyController) {
      hotkeyController.updatePreview('ReloadAppHotkey');
      hotkeyController.updatePreview('SuspendAppHotkey');
      hotkeyController.updatePluginPreviews();
    }
  }

  _updateTransparencyUI() {
    const slider = this.dom.getField('WindowTransparencyValue');
    const label = this.dom.getField('WindowTransparencyLabel');
    if (!slider || !label) return;

    if (label instanceof HTMLInputElement || label instanceof HTMLTextAreaElement) {
      label.value = slider.value;
    } else {
      label.textContent = slider.value;
    }
    const pct = (slider.value / 255) * 100;
    slider.style.background = `linear-gradient(90deg, var(--color-primary-adaptive, #0078D7) ${pct}%, #999 ${pct + 0.1}%)`;
  }
}



/**
 * SettingsForm: Manages form state and serialization.
 */
class SettingsForm {
  constructor(dom) {
    this.dom = dom;
    this._hotkeyEntries = [];
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

  static encodePluginConfigLines(pluginConfigs) {
    const lines = [];
    Object.keys(pluginConfigs || {}).forEach((pluginId) => {
      const cfg = pluginConfigs[pluginId] || {};
      Object.keys(cfg).forEach((key) => {
        const rawValue = cfg[key];
        const value = typeof rawValue === 'boolean' ? (rawValue ? '1' : '0') : `${rawValue ?? ''}`;
        lines.push(`${SettingsForm.escapeLinePart(pluginId)}\t${SettingsForm.escapeLinePart(key)}\t${SettingsForm.escapeLinePart(value)}`);
      });
    });
    return lines.join('\n');
  }

  static encodeGeneralLines(general) {
    const lines = [];
    Object.keys(general || {}).forEach((key) => {
      const rawValue = general[key];
      const value = typeof rawValue === 'boolean' ? (rawValue ? '1' : '0') : `${rawValue ?? ''}`;
      lines.push(`${SettingsForm.escapeLinePart(key)}\t${SettingsForm.escapeLinePart(value)}`);
    });
    return lines.join('\n');
  }

  static encodeHotkeysLines(hotkeys) {
    const lines = [];
    (hotkeys || []).forEach((entry) => {
      const hotKey = `${entry?.hotKey || ''}`;
      const action = `${entry?.action || ''}`;
      if (!hotKey || !action) return;
      lines.push(`${SettingsForm.escapeLinePart(hotKey)}\t${SettingsForm.escapeLinePart(action)}`);
    });
    return lines.join('\n');
  }

  static escapeLinePart(value) {
    return `${value ?? ''}`
      .replace(/\\/g, '\\\\')
      .replace(/\r/g, '\\r')
      .replace(/\n/g, '\\n')
      .replace(/\t/g, '\\t');
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
      problemsChanged: false,
      themeChanged: false,
      titleChanged: false,
      rowOperations: { adds: 0, replaces: 0, removes: 0 }
    };

    // Initialize counters for row-level operations during this apply cycle
    this._rowOpsAdds = 0;
    this._rowOpsReplaces = 0;
    this._rowOpsRemoves = 0;

    const currentSig = this._buildStateSignatures(state);
    const previousSig = this._buildStateSignatures(prevState || null);

    const generalSchemaChanged = currentSig.generalSchema !== previousSig.generalSchema;
    const generalValuesChanged = currentSig.generalValues !== previousSig.generalValues;
    const pluginListChanged = currentSig.pluginList !== previousSig.pluginList;
    const pluginPagesSchemaChanged = currentSig.pluginPagesSchema !== previousSig.pluginPagesSchema;
    const pluginFieldValuesChanged = currentSig.pluginFieldValues !== previousSig.pluginFieldValues;
    const hotkeysChanged = currentSig.hotkeys !== previousSig.hotkeys;
    const logsChanged = currentSig.logsText !== previousSig.logsText;
    const problemsChanged = currentSig.problemsText !== previousSig.problemsText;
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
      if (logsChanged) {
        const logsEl = this.dom.getField('logs-content');
        if (logsEl) logsEl.textContent = state.logsText || 'No logs yet.';
      }

      if (problemsChanged) {
        const problemsEl = this.dom.getField('problems-content');
        if (problemsEl) problemsEl.textContent = state.problemsText || 'No problems detected.';
      }
    } catch (error) {
      console.error('Logs/problems render failed', error);
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
      problemsChanged,
      themeChanged,
      titleChanged,
      rowOperations
    };
  }

  _buildStateSignatures(state) {
    if (!state) {
      return {
        generalSchema: '',
        generalValues: '',
        pluginList: '',
        pluginPagesSchema: '',
        pluginFieldValues: '',
        hotkeys: '',
        logsText: '',
        problemsText: '',
        theme: '',
        title: ''
      };
    }

    return {
      generalSchema: this._signature(this._stripGeneralValues(state.generalPage)),
      generalValues: this._signature(this._extractGeneralValues(state.generalPage)),
      pluginList: this._signature({
        available: state?.plugins?.available || [],
        disabled: state?.plugins?.disabled || []
      }),
      pluginPagesSchema: this._signature(this._stripPluginPageValues(state?.plugins?.pages || [])),
      pluginFieldValues: this._signature(this._extractPluginFieldValues(state?.plugins?.pages || [])),
      hotkeys: this._signature(state.hotkeys || []),
      logsText: `${state.logsText ?? ''}`,
      problemsText: `${state.problemsText ?? ''}`,
      theme: `${state.theme ?? ''}`,
      title: `${state.title ?? ''}`
    };
  }

  _signature(value) {
    return JSON.stringify(this._toStableValue(value));
  }

  _toStableValue(value) {
    if (Array.isArray(value)) {
      return value.map((item) => this._toStableValue(item));
    }
    if (!value || typeof value !== 'object') {
      return value;
    }

    const out = {};
    Object.keys(value).sort().forEach((key) => {
      out[key] = this._toStableValue(value[key]);
    });
    return out;
  }

  _stripGeneralValues(page) {
    if (!page) return null;
    return {
      id: page.id || '',
      title: page.title || '',
      description: page.description || '',
      icon: page.icon || '',
      navOrder: page.navOrder || 0,
      enableDynamicRender: !!page.enableDynamicRender,
      sections: (page.sections || []).map((section) => ({
        id: section?.id || '',
        title: section?.title || '',
        fields: (section?.fields || []).map((field) => ({
          key: field?.key || '',
          pluginId: field?.pluginId || '',
          label: field?.label || '',
          description: field?.description || '',
          type: field?.type || '',
          control: field?.control || '',
          default: field?.default ?? '',
          scope: field?.scope || '',
          validation: field?.validation || {},
          options: field?.options || []
        }))
      }))
    };
  }

  _extractGeneralValues(page) {
    const out = {};
    if (!Array.isArray(page?.sections)) return out;
    page.sections.forEach((section) => {
      (section?.fields || []).forEach((field) => {
        const key = `${field?.key || ''}`.trim();
        if (!key) return;
        out[key] = field && Object.prototype.hasOwnProperty.call(field, 'value') ? field.value : '';
      });
    });
    return out;
  }

  _stripPluginPageValues(pages) {
    return (pages || []).map((page) => ({
      id: page?.id || '',
      title: page?.title || '',
      description: page?.description || '',
      icon: page?.icon || '',
      enabled: !!page?.enabled,
      navOrder: page?.navOrder || 0,
      sections: (page?.sections || []).map((section) => ({
        id: section?.id || '',
        title: section?.title || '',
        fields: (section?.fields || []).map((field) => ({
          key: field?.key || '',
          pluginId: field?.pluginId || '',
          label: field?.label || '',
          description: field?.description || '',
          type: field?.type || '',
          control: field?.control || '',
          default: field?.default ?? '',
          scope: field?.scope || '',
          validation: field?.validation || {},
          options: field?.options || []
        }))
      })),
      actions: page?.actions || []
    }));
  }

  _extractPluginFieldValues(pages) {
    const out = {};
    (pages || []).forEach((page) => {
      const pageId = `${page?.id || ''}`;
      if (!pageId) return;
      out[pageId] = {};
      (page?.sections || []).forEach((section) => {
        (section?.fields || []).forEach((field) => {
          const key = `${field?.key || ''}`.trim();
          if (!key) return;
          out[pageId][key] = field && Object.prototype.hasOwnProperty.call(field, 'value') ? field.value : '';
        });
      });
    });
    return out;
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
    const container = document.getElementById('section-general');
    if (!container || !Array.isArray(page?.sections)) return;

    let html = '';
    page.sections.forEach((section) => {
      html += `<div class="setting-group"><h2>${this._escapeHtml(section?.title || section?.id || 'General')}</h2>`;
      (section?.fields || []).forEach((field) => {
        html += this._renderField(field || {}, 'general');
      });
      html += '</div>';
    });

    container.innerHTML = html;
  }

  _renderField(field, scope = 'general', pluginId = null) {
    const key = `${field?.key || ''}`;
    const label = `${field?.label || key}`;
    const description = `${field?.description || ''}`;
    const control = `${field?.control || 'text'}`;
    const value = field?.value ?? '';
    const defaultValue = field?.default ?? '';
    const type = `${field?.type || 'string'}`;
    const min = field?.validation?.min;
    const max = field?.validation?.max;
    const isGeneral = scope === 'general';
    const fieldClass = isGeneral ? 'general-field' : 'plugin-field';
    const fieldAttrs = isGeneral
      ? `data-key="${this._escapeHtml(key)}" data-type="${this._escapeHtml(type)}"`
      : `data-plugin-id="${this._escapeHtml(pluginId || '')}" data-key="${this._escapeHtml(key)}"`;
    const inputIdBase = isGeneral
      ? key
      : `${pluginId || 'plugin'}_${key}`.replace(/[^A-Za-z0-9_\-]/g, '_');

    let controlHtml = '';

    switch (control) {
      case 'switch': {
        const checked = (value === true || value === 1 || value === '1' || value === 'true') ? ' checked' : '';
        controlHtml = `
          <label class="app-switch">
            <input type="checkbox" class="${fieldClass}" id="${this._escapeHtml(inputIdBase)}" ${fieldAttrs}${checked} />
            <div class="app-switch-view"></div>
            <span class="app-switch-label" data-on="On" data-off="Off"></span>
          </label>
        `;
        break;
      }
      case 'hotkey': {
        const readable = AK_HumanizeAhkHotkey(`${value || ''}`) || 'Assign hotkey';
        const hotkeyFieldId = isGeneral ? key : `pluginHotkey_${pluginId || 'plugin'}_${key}`.replace(/[^A-Za-z0-9_\-]/g, '_');
        const hotkeyBadgeClass = isGeneral ? 'hotkey-badge-large' : 'hotkey-badge-medium';
        controlHtml = `
          <div class="field-with-actions">
            <input type="hidden" class="${fieldClass}" id="${this._escapeHtml(hotkeyFieldId)}" ${fieldAttrs} value="${this._escapeHtml(`${value || ''}`)}" />
            <button type="button" class="app-btn hotkey-badge ${hotkeyBadgeClass}" data-hotkey-target="${this._escapeHtml(hotkeyFieldId)}" data-hotkey-display-for="${this._escapeHtml(hotkeyFieldId)}" data-win-toggle="modal" data-win-target="#HotkeyRecorderDialog">
              <span class="hotkey-badge-label">${this._escapeHtml(readable)}</span>
            </button>
          </div>
        `;
        break;
      }
      case 'color': {
        const colorInputId = `colorInput_${scope}_${pluginId || 'general'}_${key}`.replace(/[^A-Za-z0-9_]/g, '_');
        const colorBtnId = `colorPickBtn_${scope}_${pluginId || 'general'}_${key}`.replace(/[^A-Za-z0-9_]/g, '_');
        const colorSwatchId = `colorSwatch_${scope}_${pluginId || 'general'}_${key}`.replace(/[^A-Za-z0-9_]/g, '_');
        controlHtml = `
          <div class="field-with-actions">
            <input class="app-input-text ${fieldClass}" type="text" id="${this._escapeHtml(colorInputId)}" ${fieldAttrs} data-color-swatch-id="${this._escapeHtml(colorSwatchId)}" value="${this._escapeHtml(`${value || ''}`)}" placeholder="${this._escapeHtml(`${defaultValue || ''}`)}" />
            <div class="field-actions">
              <button id="${this._escapeHtml(colorBtnId)}" type="button" class="app-btn app-btn-subtle field-btn" data-color-input-id="${this._escapeHtml(colorInputId)}" data-color-swatch-id="${this._escapeHtml(colorSwatchId)}" data-win-toggle="modal" data-win-target="#ColorPickerDialog">
                <span id="${this._escapeHtml(colorSwatchId)}" class="color-swatch-small" aria-hidden="true"></span>
                <span>Pick</span>
              </button>
            </div>
          </div>
        `;
        break;
      }
      case 'path': {
        const browseMeta = isGeneral ? this._getGeneralPathBrowseMeta(key) : null;
        const pickerHtml = browseMeta
          ? `<input type="file" id="${this._escapeHtml(browseMeta.fileInputId)}" accept="audio/*,.wav,.mp3,.ogg,.flac" hidden />`
          : '';
        const browseBtnHtml = browseMeta
          ? `<button id="${this._escapeHtml(browseMeta.buttonId)}" type="button" class="app-btn app-btn-subtle field-btn"><span>Browse</span></button>`
          : '';
        controlHtml = `
          <div class="field-with-actions">
            <input class="app-input-text ${fieldClass}" type="text" id="${this._escapeHtml(inputIdBase)}" ${fieldAttrs} value="${this._escapeHtml(`${value || ''}`)}" />
            <div class="field-actions">${browseBtnHtml}</div>
          </div>
          ${pickerHtml}
        `;
        break;
      }
      case 'range': {
        const minAttr = Number.isFinite(Number(min)) ? ` min="${Number(min)}"` : ' min="0"';
        const maxAttr = Number.isFinite(Number(max)) ? ` max="${Number(max)}"` : ' max="255"';
        const sliderValue = `${value ?? defaultValue ?? 128}`;
        const rangeLabelId = isGeneral && key === 'WindowTransparencyValue'
          ? 'WindowTransparencyLabel'
          : `RangeLabel_${inputIdBase}`;
        controlHtml = `
          <div class="app-range-slider">
            <input type="range" class="${fieldClass}" id="${this._escapeHtml(inputIdBase)}" ${fieldAttrs}${minAttr}${maxAttr} step="1" value="${this._escapeHtml(sliderValue)}" />
            <span id="${this._escapeHtml(rangeLabelId)}">${this._escapeHtml(sliderValue)}</span>
          </div>
        `;
        break;
      }
      case 'number': {
        const minAttr = Number.isFinite(Number(min)) ? ` min="${Number(min)}"` : '';
        const maxAttr = Number.isFinite(Number(max)) ? ` max="${Number(max)}"` : '';
        controlHtml = `
          <input class="app-input-text ${fieldClass}" type="number" id="${this._escapeHtml(inputIdBase)}" ${fieldAttrs} value="${this._escapeHtml(`${value || ''}`)}"${minAttr}${maxAttr} />
        `;
        break;
      }
      case 'select': {
        const options = isGeneral
          ? this._getGeneralSelectOptions(field)
          : (Array.isArray(field?.options) && field.options.length
            ? field.options
            : [{ value: `${field?.value ?? field?.default ?? ''}`, label: `${field?.value ?? field?.default ?? ''}` }]);
        const selected = `${value ?? defaultValue ?? ''}`;
        const optionsHtml = options.map((opt) => {
          const v = `${opt?.value ?? ''}`;
          const text = `${opt?.label ?? v}`;
          const isSelected = v === selected ? ' selected' : '';
          return `<option value="${this._escapeHtml(v)}"${isSelected}>${this._escapeHtml(text)}</option>`;
        }).join('');
        controlHtml = `
          <div class="app-select-menu">
            <select class="${fieldClass}" id="${this._escapeHtml(inputIdBase)}" ${fieldAttrs}>${optionsHtml}</select>
          </div>
        `;
        break;
      }
      default: {
        controlHtml = `
          <input class="app-input-text ${fieldClass}" type="text" id="${this._escapeHtml(inputIdBase)}" ${fieldAttrs} value="${this._escapeHtml(`${value || ''}`)}" />
        `;
      }
    }

    const maybeDevTools = scope === 'general' && key === 'DebugLevel'
      ? '<div class="field-actions"><button type="button" id="openDevTools" class="app-btn app-btn-subtle field-btn"><span>Open DevTools</span></button></div>'
      : '';

    if (scope === 'plugin') {
      const pluginFieldKey = `${key}`;
      const pluginFieldSig = this._pluginFieldSignature(field);
      return `
        <div class="setting-row plugin-setting-row" data-plugin-field-key="${this._escapeHtml(pluginFieldKey)}" data-plugin-field-sig="${this._escapeHtml(pluginFieldSig)}">
          <div class="plugin-field-meta">
            <label class="field-label">${this._escapeHtml(label)}</label>
            ${description ? `<p class="field-description">${this._escapeHtml(description)}</p>` : ''}
          </div>
          <div class="app-input-container">
            ${controlHtml}
          </div>
        </div>
      `;
    } else {
      return `
        <div class="setting-row">
          <div class="general-field-meta">
            <label class="field-label" for="${this._escapeHtml(inputIdBase)}">${this._escapeHtml(label)}</label>
            ${description ? `<p class="field-description">${this._escapeHtml(description)}</p>` : ''}
          </div>
          <div class="app-input-container">
            ${maybeDevTools ? `<div class="field-with-actions">${controlHtml}${maybeDevTools}</div>` : controlHtml}
          </div>
        </div>
      `;
    }
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
    const nav = document.querySelector('.settings-nav');
    const content = document.querySelector('.settings-content');
    if (!nav || !content) return;

    const sortedPages = [...(pages || [])].filter((page) => page && page.id).sort((a, b) => {
      const ao = Number.isFinite(Number(a?.navOrder)) ? Number(a.navOrder) : 100;
      const bo = Number.isFinite(Number(b?.navOrder)) ? Number(b.navOrder) : 100;
      if (ao !== bo) return ao - bo;
      return String(a?.title || a?.id || '').localeCompare(String(b?.title || b?.id || ''));
    });

    const wantedPageIds = new Set(sortedPages.map((page) => `${page.id}`));

    // Remove obsolete dynamic nav items and sections.
    nav.querySelectorAll('[data-dynamic-plugin="1"]').forEach((el) => {
      const sectionName = `${el.getAttribute('data-section') || ''}`;
      const pageId = sectionName.startsWith('plugin-') ? sectionName.slice(7) : '';
      if (!wantedPageIds.has(pageId)) {
        el.remove();
      }
    });
    content.querySelectorAll('[data-dynamic-plugin="1"]').forEach((el) => {
      const id = `${el.id || ''}`;
      const pageId = id.startsWith('section-plugin-') ? id.slice('section-plugin-'.length) : '';
      if (!wantedPageIds.has(pageId)) {
        el.remove();
      }
    });

    // Find insertion point: after "Plugins" but before "Hotkeys"
    const pluginsBtn = nav.querySelector('[data-section="plugins"]');
    const hotkeysBtn = nav.querySelector('[data-section="hotkeys"]');

    // Keep nav order stable by inserting in reverse before Hotkeys.
    for (let i = sortedPages.length - 1; i >= 0; i -= 1) {
      const page = sortedPages[i];
      const pageId = `${page.id}`;
      const navSelector = `[data-dynamic-plugin="1"][data-section="plugin-${CSS.escape(pageId)}"]`;
      let navItem = nav.querySelector(navSelector);
      if (!navItem) {
        navItem = document.createElement('button');
        navItem.className = 'nav-item';
        navItem.setAttribute('data-section', `plugin-${pageId}`);
        navItem.setAttribute('data-dynamic-plugin', '1');
      }

      const navSig = this._signature({ id: pageId, title: page.title || page.id || '', icon: page.icon || 'icons10-puzzle' });
      if (navItem.dataset.navSig !== navSig) {
        navItem.innerHTML = `<i class="${this._escapeHtml(page.icon || 'icons10-puzzle')}"></i><span>${this._escapeHtml(page.title || page.id)}</span>`;
        navItem.dataset.navSig = navSig;
      }

      if (pluginsBtn && hotkeysBtn) {
        pluginsBtn.parentNode.insertBefore(navItem, hotkeysBtn);
      } else if (pluginsBtn) {
        pluginsBtn.parentNode.appendChild(navItem);
      }
    }

    sortedPages.forEach(page => {
      const pageId = `${page.id}`;
      const sectionId = `section-plugin-${pageId}`;
      let section = document.getElementById(sectionId);
      if (!section) {
        section = document.createElement('div');
        section.id = sectionId;
        section.className = 'settings-section';
        section.setAttribute('data-dynamic-plugin', '1');
      }

      this._upsertPluginPage(section, page);

      content.appendChild(section);
    });

    if (!this._isPluginResetAllBound) {
      this._isPluginResetAllBound = true;
      document.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-plugin-reset-all]');
        if (!btn) return;
        e.preventDefault();
        const pluginId = btn.getAttribute('data-plugin-reset-all');
        this._resetPluginFields(pluginId);
      });
    }
  }

  _upsertPluginPage(section, page) {
    if (!section || !page) return;

    const pageId = `${page.id || ''}`;
    if (!pageId) return;

    const shell = this._ensurePluginPageShell(section);
    const headerSig = this._signature({
      id: pageId,
      title: page.title || page.id || '',
      description: page.description || '',
      enabled: !!page.enabled
    });
    const sectionsOrderSig = this._signature((page.sections || []).map((sec, idx) => ({
      id: `${sec?.id || sec?.title || `section-${idx}`}`,
      title: `${sec?.title || sec?.id || ''}`
    })));
    const actionsSig = this._signature(page.actions || []);

    if (shell.header.dataset.sig !== headerSig) {
      shell.header.innerHTML = this._renderPluginHeaderHtml(page);
      shell.header.dataset.sig = headerSig;
    }

    if (shell.sections.dataset.orderSig !== sectionsOrderSig) {
      shell.sections.dataset.orderSig = sectionsOrderSig;
    }
    this._reconcilePluginSections(shell.sections, page);

    if (shell.actions.dataset.sig !== actionsSig) {
      shell.actions.innerHTML = (page.actions && page.actions.length > 0)
        ? this._renderPluginActionsSummary(pageId, page.actions)
        : '';
      shell.actions.dataset.sig = actionsSig;
    }

    const resetSig = pageId;
    if (shell.footer.dataset.sig !== resetSig) {
      shell.footer.innerHTML = `
        <div class="setting-group">
          <button type="button" class="app-btn app-btn-subtle" data-plugin-reset-all="${this._escapeHtml(pageId)}">Reset All</button>
        </div>
      `;
      shell.footer.dataset.sig = resetSig;
    }
  }

  _ensurePluginPageShell(section) {
    let header = section.querySelector(':scope > [data-plugin-slot="header"]');
    let sections = section.querySelector(':scope > [data-plugin-slot="sections"]');
    let actions = section.querySelector(':scope > [data-plugin-slot="actions"]');
    let footer = section.querySelector(':scope > [data-plugin-slot="footer"]');

    if (!header) {
      header = document.createElement('div');
      header.setAttribute('data-plugin-slot', 'header');
      section.appendChild(header);
    }
    if (!sections) {
      sections = document.createElement('div');
      sections.setAttribute('data-plugin-slot', 'sections');
      section.appendChild(sections);
    }
    if (!actions) {
      actions = document.createElement('div');
      actions.setAttribute('data-plugin-slot', 'actions');
      section.appendChild(actions);
    }
    if (!footer) {
      footer = document.createElement('div');
      footer.setAttribute('data-plugin-slot', 'footer');
      section.appendChild(footer);
    }

    return { header, sections, actions, footer };
  }

  _renderPluginHeaderHtml(page) {
    return `
      <div class="setting-group">
        <div class="plugin-page-header">
          <div class="plugin-header-info">
            <h2>${this._escapeHtml(page.title || page.id)}</h2>
            <p class="subtitle">${this._escapeHtml(page.description || '')}</p>
            ${!page.enabled ? '<div class="plugin-disabled-badge">Plugin is disabled</div>' : ''}
          </div>
        </div>
      </div>
    `;
  }

  _reconcilePluginSections(container, page) {
    if (!container) return;

    const sections = page?.sections || [];
    const wantedIds = new Set();

    sections.forEach((sec, idx) => {
      const secId = `${sec?.id || sec?.title || `section-${idx}`}`;
      wantedIds.add(secId);
    });

    container.querySelectorAll(':scope > .setting-group[data-plugin-section-id]').forEach((el) => {
      const id = `${el.getAttribute('data-plugin-section-id') || ''}`;
      if (!wantedIds.has(id)) {
        el.remove();
      }
    });

    sections.forEach((sec, idx) => {
      const secId = `${sec?.id || sec?.title || `section-${idx}`}`;
      const selector = `:scope > .setting-group[data-plugin-section-id="${CSS.escape(secId)}"]`;
      let secEl = container.querySelector(selector);
      if (!secEl) {
        secEl = document.createElement('div');
        secEl.className = 'setting-group';
        secEl.setAttribute('data-plugin-section-id', secId);
      }

      let titleEl = secEl.querySelector(':scope > h3[data-role="section-title"]');
      if (!titleEl) {
        titleEl = document.createElement('h3');
        titleEl.setAttribute('data-role', 'section-title');
        secEl.appendChild(titleEl);
      }
      const titleText = `${sec?.title || sec?.id || ''}`;
      if (titleEl.textContent !== titleText) {
        titleEl.textContent = titleText;
      }

      let fieldsHost = secEl.querySelector(':scope > [data-role="section-fields"]');
      if (!fieldsHost) {
        fieldsHost = document.createElement('div');
        fieldsHost.setAttribute('data-role', 'section-fields');
        secEl.appendChild(fieldsHost);
      }

      this._reconcilePluginFieldRows(fieldsHost, sec?.fields || [], page.id);

      container.appendChild(secEl);
    });
  }

  _pluginFieldSignature(field) {
    if (!field) return '';
    return this._signature({
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

  _reconcilePluginFieldRows(fieldsHost, fields, pageId) {
    const wantedKeys = new Set();
    (fields || []).forEach((field, idx) => {
      const key = `${field?.key || `field-${idx}`}`;
      wantedKeys.add(key);
    });

    fieldsHost.querySelectorAll(':scope > .plugin-setting-row[data-plugin-field-key]').forEach((row) => {
      const key = `${row.getAttribute('data-plugin-field-key') || ''}`;
      if (!wantedKeys.has(key)) {
        row.remove();
        this._rowOpsRemoves = (this._rowOpsRemoves || 0) + 1;
      }
    });

    (fields || []).forEach((field, idx) => {
      const key = `${field?.key || `field-${idx}`}`;
      const selector = `:scope > .plugin-setting-row[data-plugin-field-key="${CSS.escape(key)}"]`;
      let row = fieldsHost.querySelector(selector);
      const nextSig = this._pluginFieldSignature(field);

      if (!row) {
        row = this._createElementFromHtml(this._renderField(field, 'plugin', pageId));
        this._rowOpsAdds = (this._rowOpsAdds || 0) + 1;
      } else {
        const currentSig = `${row.getAttribute('data-plugin-field-sig') || ''}`;
        if (currentSig !== nextSig) {
          const replacement = this._createElementFromHtml(this._renderField(field, 'plugin', pageId));
          row.replaceWith(replacement);
          row = replacement;
          this._rowOpsReplaces = (this._rowOpsReplaces || 0) + 1;
        }
      }

      fieldsHost.appendChild(row);
    });
  }

  _createElementFromHtml(html) {
    const tpl = document.createElement('template');
    tpl.innerHTML = `${html || ''}`.trim();
    return tpl.content.firstElementChild;
  }

  _renderPluginActionsSummary(pluginId, actions) {
    const grouped = new Map();
    (actions || []).forEach((action) => {
      const category = action.category || 'Actions';
      if (!grouped.has(category)) grouped.set(category, []);
      grouped.get(category).push(action);
    });

    let html = '<div class="setting-group plugin-actions-summary"><h3>Actions</h3>';
    grouped.forEach((items, category) => {
      html += `<div class="plugin-action-category"><div class="plugin-action-category-title">${this._escapeHtml(category)}</div>`;
      items.forEach((item) => {
        const actionName = `${item?.action || ''}`;
        const hotkeys = this.getHotkeysForAction(actionName);
        const hotkeysHtml = hotkeys.length
          ? hotkeys.map((hk) => this._renderActionHotkeyBadge(pluginId, actionName, hk)).join('')
          : this._renderActionHotkeyBadge(pluginId, actionName, '')
        ;
        html += `
          <div class="plugin-action-item" data-plugin-id="${this._escapeHtml(pluginId || '')}" data-action-name="${this._escapeHtml(actionName)}">
            <div class="plugin-action-head">
              <div class="plugin-action-name">${this._escapeHtml(item.label || item.action || '')}</div>
              <div class="plugin-action-description">${this._escapeHtml(item.description || '')}</div>
            </div>
            <div class="plugin-action-hotkeys">${hotkeysHtml}</div>
          </div>
        `;
      });
      html += '</div>';
    });
    html += '</div>';

    return html;
  }

  _renderActionHotkeyBadge(pluginId, actionName, hotkeyRaw) {
    const readable = AK_HumanizeAhkHotkey(hotkeyRaw);
    return `
      <button
        type="button"
        class="app-btn plugin-hotkey-badge"
        data-hotkey-action="${this._escapeHtml(actionName)}"
        data-hotkey-current="${this._escapeHtml(hotkeyRaw)}"
        data-plugin-id="${this._escapeHtml(pluginId || '')}"
        data-win-toggle="modal"
        data-win-target="#HotkeyRecorderDialog"
      >
        <span class="plugin-hotkey-badge-label">${this._escapeHtml(readable || hotkeyRaw) || 'assign'}</span>
        ${hotkeyRaw ? `<span class="hotkey-badge-remove" data-hotkey-remove="${this._escapeHtml(hotkeyRaw)}">&times;</span>` : ''}
      </button>
    `;
  }

  _syncPluginActionHotkeys() {
    document.querySelectorAll('.plugin-action-item').forEach((item) => {
      const pluginId = `${item.getAttribute('data-plugin-id') || ''}`;
      const actionName = `${item.getAttribute('data-action-name') || ''}`;
      const host = item.querySelector('.plugin-action-hotkeys');
      if (!host || !actionName) return;

      const hotkeys = this.getHotkeysForAction(actionName);
      if (!hotkeys.length) {
        host.innerHTML = this._renderActionHotkeyBadge(pluginId, actionName, '');
        return;
      }
      host.innerHTML = hotkeys.map((hk) => this._renderActionHotkeyBadge(pluginId, actionName, hk)).join('');
    });
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
      .filter((entry) => this._extractActionName(entry.action) === wanted)
      .map((entry) => entry.hotKey)
      .filter(Boolean);
  }

  assignActionHotkey(actionName, newHotkeyRaw, replaceHotkeyRaw = '') {
    const wanted = `${actionName || ''}`.trim();
    const newRaw = `${newHotkeyRaw || ''}`.trim();
    const replaceRaw = `${replaceHotkeyRaw || ''}`.trim();
    if (!wanted || !newRaw) return;

    this._hotkeyEntries = this._hotkeyEntries.filter((entry) => `${entry.hotKey || ''}`.trim() !== newRaw);

    if (replaceRaw) {
      let replaced = false;
      this._hotkeyEntries = this._hotkeyEntries.map((entry) => {
        if (`${entry.hotKey || ''}`.trim() === replaceRaw) {
          replaced = true;
          return { hotKey: newRaw, action: entry.action || wanted };
        }
        return entry;
      });
      if (!replaced) {
        this._hotkeyEntries.push({ hotKey: newRaw, action: wanted });
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

    label.textContent = slider.value;
    const pct = (slider.value / 255) * 100;
    slider.style.background = `linear-gradient(90deg, var(--color-primary-adaptive, #0078D7) ${pct}%, #999 ${pct + 0.1}%)`;
  }
}


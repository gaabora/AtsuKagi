
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
    const welcomeMsg = this.getFieldValue('WelcomeMessage');
    const darkTheme = this.getFieldValue('DarkTheme');
    const debugLevel = this.getFieldValue('DebugLevel');
    const tooltipMs = this.getFieldValue('ToolTipTimeoutMs');
    const transparency = this.getFieldValue('WindowTransparencyValue');
    const borderColor = this.getFieldValue('WindowOnTopBorderColor');
    const startupSound = this.getFieldValue('StartupSound');
    const notificationSound = this.getFieldValue('NotificationSound');
    const reloadHotkey = this.getFieldValue('ReloadAppHotkey');
    const suspendHotkey = this.getFieldValue('SuspendAppHotkey');

    const isSwapped = this.getFieldChecked('SwapMouseXButtons') ? 'true' : 'false';

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
      general: {
        WelcomeMessage: welcomeMsg,
        DarkTheme: darkTheme,
        DebugLevel: debugLevel,
        ToolTipTimeoutMs: tooltipMs,
        WindowTransparencyValue: transparency,
        WindowOnTopBorderColor: borderColor,
        StartupSound: startupSound,
        NotificationSound: notificationSound,
        ReloadAppHotkey: reloadHotkey,
        SuspendAppHotkey: suspendHotkey,
        SwapMouseXButtons: this.getFieldChecked('SwapMouseXButtons')
      },
      disabledPlugins,
      pluginConfigs,
      hotkeys: [...this._hotkeyEntries]
    };
  }

  serializeLegacy(payloadObject) {
    const obj = payloadObject || this.serializeObject();
    const gen = obj.general || {};
    const disabled = Array.isArray(obj.disabledPlugins) ? obj.disabledPlugins : [];
    const pluginConfigEncoded = SettingsForm.encodePluginConfigLines(obj.pluginConfigs || {});

    return [
      gen.WelcomeMessage || '',
      gen.DarkTheme || '',
      gen.DebugLevel || '',
      gen.ToolTipTimeoutMs || '',
      gen.WindowTransparencyValue || '',
      gen.WindowOnTopBorderColor || '',
      gen.StartupSound || '',
      gen.NotificationSound || '',
      gen.ReloadAppHotkey || '',
      gen.SuspendAppHotkey || '',
      gen.SwapMouseXButtons ? 'true' : 'false',
      disabled.join(','),
      pluginConfigEncoded
    ];
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

  serialize() {
    const payloadObject = this.serializeObject();
    return this.serializeLegacy(payloadObject);
  }

  getFieldValue(id) {
    const el = this.dom.getField(id);
    return el ? (el.value || '') : '';
  }

  getFieldChecked(id) {
    const el = this.dom.getField(id);
    return !!(el && el.checked);
  }

  setFieldValue(id, value) {
    const el = this.dom.getField(id);
    if (el) el.value = value;
  }

  setFieldChecked(id, checked) {
    const el = this.dom.getField(id);
    if (el) el.checked = checked;
  }

  /**
   * Apply incoming state from AHK to form DOM.
   */
  applyState(state) {
    if (!state) return;

    const gen = state.general || {};
    this.setFieldValue('WelcomeMessage', gen.WelcomeMessage || '');
    this.setFieldValue('DarkTheme', gen.DarkTheme || '-1');
    this.setFieldValue('DebugLevel', gen.DebugLevel || '0');
    this.setFieldValue('ToolTipTimeoutMs', gen.ToolTipTimeoutMs || '');
    this.setFieldValue('WindowTransparencyValue', gen.WindowTransparencyValue || '128');
    this.setFieldValue('WindowOnTopBorderColor', gen.WindowOnTopBorderColor || '');
    this.setFieldValue('StartupSound', gen.StartupSound || '');
    this.setFieldValue('NotificationSound', gen.NotificationSound || '');
    this.setFieldValue('ReloadAppHotkey', gen.ReloadAppHotkey || '');
    this.setFieldValue('SuspendAppHotkey', gen.SuspendAppHotkey || '');
    this.setFieldChecked('SwapMouseXButtons', gen.SwapMouseXButtons === true || gen.SwapMouseXButtons === 1 || gen.SwapMouseXButtons === '1');

    this._hotkeyEntries = Array.isArray(state.hotkeys)
      ? state.hotkeys
          .map((hk) => ({ hotKey: `${hk?.hotKey || ''}`, action: `${hk?.action || ''}` }))
          .filter((hk) => hk.hotKey && hk.action)
      : [];

    if (state.plugins) {
      this._renderPlugins(state.plugins);
      if (state.plugins.pages) {
        this._renderPluginSettingsPages(state.plugins.pages);
      }
    }

    if (state.hotkeys) {
      this._renderHotkeys(state.hotkeys);
    }

    if (state.logsText !== undefined) {
      const logsEl = this.dom.getField('logs-content');
      if (logsEl) logsEl.textContent = state.logsText || 'No logs yet.';
    }

    if (state.problemsText !== undefined) {
      const problemsEl = this.dom.getField('problems-content');
      if (problemsEl) problemsEl.textContent = state.problemsText || 'No problems detected.';
    }

    if (state.theme === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
      document.body.classList.add('dark-theme');
    } else if (state.theme === 'light') {
      document.documentElement.setAttribute('data-theme', 'light');
      document.body.classList.remove('dark-theme');
    }

    if (state.title) {
      const titleEl = this.dom.getField('titleText');
      if (titleEl) titleEl.innerText = state.title;
    }
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

    const sortedPages = [...(pages || [])].sort((a, b) => {
      const ao = Number.isFinite(Number(a?.navOrder)) ? Number(a.navOrder) : 100;
      const bo = Number.isFinite(Number(b?.navOrder)) ? Number(b.navOrder) : 100;
      if (ao !== bo) return ao - bo;
      return String(a?.title || a?.id || '').localeCompare(String(b?.title || b?.id || ''));
    });

    // Re-render safety: remove previously generated plugin pages/nav to avoid duplicates.
    nav.querySelectorAll('[data-dynamic-plugin="1"]').forEach((el) => el.remove());
    content.querySelectorAll('[data-dynamic-plugin="1"]').forEach((el) => el.remove());

    // Find insertion point: after "Plugins" but before "Hotkeys"
    const pluginsBtn = nav.querySelector('[data-section="plugins"]');
    const hotkeysBtn = nav.querySelector('[data-section="hotkeys"]');

    sortedPages.forEach(page => {
      if (!page || !page.id) return; //FIXME: find where empty coming from and fix at source instead of silently skipping here.
      // Create nav item
      const navItem = document.createElement('button');
      navItem.className = 'nav-item';
      navItem.setAttribute('data-section', `plugin-${page.id}`);
      navItem.setAttribute('data-dynamic-plugin', '1');
      navItem.innerHTML = `<i class="${this._escapeHtml(page.icon || 'icons10-puzzle')}"></i><span>${this._escapeHtml(page.title || page.id)}</span>`;
      
      // Insert nav item after Plugins and before Hotkeys
      if (pluginsBtn && hotkeysBtn) {
        pluginsBtn.parentNode.insertBefore(navItem, hotkeysBtn);
      } else if (pluginsBtn) {
        pluginsBtn.parentNode.appendChild(navItem);
      }

      // Create content section
      const section = document.createElement('div');
      section.id = `section-plugin-${page.id}`;
      section.className = 'settings-section';
      section.setAttribute('data-dynamic-plugin', '1');
      
      // Build section HTML
      let sectionHtml = `
        <div class="setting-group">
          <div class="plugin-page-header">
            <div class="plugin-header-info">
              <h2>${this._escapeHtml(page.title || page.id)}</h2>
              <p class="subtitle">${this._escapeHtml(page.description || '')}</p>
              ${!page.enabled ? '<div class="plugin-disabled-badge">Plugin is disabled</div>' : ''}
            </div>
          </div>
      `;

      // Add settings groups (sections)
      if (page.sections && page.sections.length > 0) {
        page.sections.forEach(sec => {
          sectionHtml += `<div class="setting-group"><h3>${this._escapeHtml(sec.title || sec.id)}</h3>`;
          
          if (sec.fields && sec.fields.length > 0) {
            sec.fields.forEach(field => {
              sectionHtml += this._renderPluginField(field);
            });
          }
          
          sectionHtml += '</div>';
        });
      }

      // Add actions summary block grouped by category.
      if (page.actions && page.actions.length > 0) {
        sectionHtml += this._renderPluginActionsSummary(page.id, page.actions);
      }

      // Add Reset All button
      sectionHtml += `
        <div class="setting-group">
          <button type="button" class="app-btn app-btn-subtle" data-plugin-reset-all="${page.id}">Reset All</button>
        </div>
      `;

      sectionHtml += '</div>';
      section.innerHTML = sectionHtml;

      // Insert section into content
      content.appendChild(section);

      // Bind per-field reset buttons for this section.
      section.querySelectorAll('[data-reset-field]').forEach((btn) => {
        btn.addEventListener('click', (e) => {
          e.preventDefault();
          const key = btn.getAttribute('data-reset-field');
          const def = btn.getAttribute('data-default') || '';
          const field = section.querySelector(`.plugin-field[data-plugin-id="${page.id}"][data-key="${key}"]`);
          if (!field) return;
          if (field.type === 'checkbox') {
            field.checked = (def === '1' || def === 'true');
          } else {
            field.value = def;
          }
          if (field.classList.contains('plugin-field-hotkey')) {
            const display = document.querySelector(`[data-plugin-hotkey-display="${page.id}::${key}"]`);
            if (display) {
              display.value = def ? this._humanizeHotkey(def) : '';
            }
          }
          field.dispatchEvent(new Event('input'));
          field.dispatchEvent(new Event('change'));
        });
      });
    });

    // Bind Reset All buttons
    document.querySelectorAll('[data-plugin-reset-all]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const pluginId = btn.getAttribute('data-plugin-reset-all');
        this._resetPluginFields(pluginId);
      });
    });
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
          ? `<div class="plugin-action-hotkeys">${hotkeys.map((hk) => this._renderActionHotkeyBadge(pluginId, actionName, hk)).join('')}</div>`
          : `<div class="plugin-action-hotkeys">${this._renderActionHotkeyBadge(pluginId, actionName, '')}</div>`;
        html += `
          <div class="plugin-action-item" data-plugin-id="${this._escapeHtml(pluginId || '')}" data-action-name="${this._escapeHtml(actionName)}">
            <div class="plugin-action-head">
              <div class="plugin-action-name">${this._escapeHtml(item.label || item.action || '')}</div>
              ${hotkeysHtml}
            </div>
            <div class="plugin-action-description">${this._escapeHtml(item.description || '')}</div>
          </div>
        `;
      });
      html += '</div>';
    });
    html += '</div>';

    return html;
  }

  _renderActionHotkeyBadge(pluginId, actionName, hotkeyRaw) {
    const readable = this._humanizeHotkey(hotkeyRaw);
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
    const key = field.key || '';
    const label = field.label || key;
    const description = field.description || '';
    const control = field.control || 'text';
    const value = field.value || '';
    const defaultValue = field.default || '';
    const pluginId = field.pluginId || '';

    let controlHtml = '';
    
    switch (control) {
      case 'switch':
        const checked = (value === true || value === 1 || value === '1' || value === 'true') ? 'checked' : '';
        controlHtml = `<label class="app-switch"><input type="checkbox" class="plugin-field" data-plugin-id="${this._escapeHtml(pluginId)}" data-key="${this._escapeHtml(key)}"${checked} /><div class="app-switch-view"></div><span class="app-switch-label" data-on="On" data-off="Off"></span></label>`;
        break;
      
      case 'hotkey':
        const hotkeyFieldId = `pluginHotkey_${pluginId}_${key}`.replace(/[^A-Za-z0-9_\-]/g, '_');
        const readable = this._humanizeHotkey(value);
        controlHtml = `
          <div class="field-with-actions">
            <input type="hidden" id="${this._escapeHtml(hotkeyFieldId)}" class="plugin-field plugin-field-hotkey" data-plugin-id="${this._escapeHtml(pluginId)}" data-key="${this._escapeHtml(key)}" value="${this._escapeHtml(value)}" />
            <button type="button" class="app-btn hotkey-badge hotkey-badge-medium" data-hotkey-target="${this._escapeHtml(hotkeyFieldId)}" data-hotkey-display-for="${this._escapeHtml(hotkeyFieldId)}" data-win-toggle="modal" data-win-target="#HotkeyRecorderDialog">
              <span class="hotkey-badge-label">${this._escapeHtml(readable || 'Assign hotkey')}</span>
              <span class="hotkey-badge-remove" data-hotkey-reset-field="${this._escapeHtml(hotkeyFieldId)}" data-default="${this._escapeHtml(defaultValue)}">&times;</span>
            </button>
          </div>
        `;
        break;
      
      case 'color':
        const colorKey = `${pluginId}::${key}`;
        controlHtml = `
          <div class="field-with-actions">
            <input type="text" class="app-input-text plugin-field plugin-color-input" data-plugin-id="${this._escapeHtml(pluginId)}" data-key="${this._escapeHtml(key)}" data-plugin-color-key="${this._escapeHtml(colorKey)}" value="${this._escapeHtml(value)}" placeholder="${this._escapeHtml(defaultValue)}" />
            <div class="field-actions">
              <button type="button" class="app-btn app-btn-subtle field-btn" data-color-selector=".plugin-color-input[data-plugin-id=&quot;${this._escapeHtml(pluginId)}&quot;][data-key=&quot;${this._escapeHtml(key)}&quot;]" data-win-toggle="modal" data-win-target="#ColorPickerDialog">
                <span class="color-swatch-small" data-plugin-color-swatch="${this._escapeHtml(colorKey)}" aria-hidden="true"></span>
                <span>Pick</span>
              </button>
              <button type="button" class="app-btn app-btn-subtle field-btn" data-reset-field="${this._escapeHtml(key)}" data-default="${this._escapeHtml(defaultValue)}">Reset</button>
            </div>
          </div>
        `;
        break;
      
      default: // text, string, etc.
        controlHtml = `
          <div class="field-with-actions">
            <input type="text" class="app-input-text plugin-field" data-plugin-id="${this._escapeHtml(pluginId)}" data-key="${this._escapeHtml(key)}" value="${this._escapeHtml(value)}" />
            <div class="field-actions">
              <button type="button" class="app-btn app-btn-subtle field-btn" data-reset-field="${this._escapeHtml(key)}" data-default="${this._escapeHtml(defaultValue)}">Reset</button>
            </div>
          </div>
        `;
    }

    return `
      <div class="setting-row plugin-setting-row">
        <div class="plugin-field-meta">
          <label class="field-label">${this._escapeHtml(label)}</label>
          ${description ? `<p class="field-description">${this._escapeHtml(description)}</p>` : ''}
        </div>
        <div class="app-input-container">
          ${controlHtml}
        </div>
      </div>
    `;
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

  _humanizeHotkey(hk) {
    if (!hk) return '';
    let input = hk;
    const labels = [];

    if (input.indexOf('*') !== -1) {
      labels.push('Wildcard');
      input = input.replace(/\*/g, '');
    }
    if (input.indexOf('~') !== -1) {
      labels.push('Passthrough');
      input = input.replace(/~/g, '');
    }
    if (input.indexOf('^') !== -1) {
      labels.push('Ctrl');
      input = input.replace(/\^/g, '');
    }
    if (input.indexOf('!') !== -1) {
      labels.push('Alt');
      input = input.replace(/!/g, '');
    }
    if (input.indexOf('+') !== -1) {
      labels.push('Shift');
      input = input.replace(/\+/g, '');
    }
    if (input.indexOf('#') !== -1) {
      labels.push('Win');
      input = input.replace(/#/g, '');
    }

    const key = input.trim();
    if (key) labels.push(key);
    return labels.join(' + ');
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



/**
 * AhkHostBridge: Isolates WebView2 host-object access.
 */
class AhkHostBridge {
  constructor() {
    this.host = this._resolveHost();
  }

  _resolveHost() {
    try {
      if (window.chrome && window.chrome.webview && window.chrome.webview.hostObjects) {
        return window.chrome.webview.hostObjects.sync;
      }
    } catch (_) {}
    return null;
  }

  saveSettings(payloadObject, legacyPayload) {
    if (!this.host) return;

    if (typeof this.host.SettingsSaveV2 === 'function') {
      const obj = payloadObject || {};
      const generalEncoded = SettingsForm.encodeGeneralLines(obj.general || {});
      const disabledCsv = Array.isArray(obj.disabledPlugins) ? obj.disabledPlugins.join(',') : '';
      const pluginEncoded = SettingsForm.encodePluginConfigLines(obj.pluginConfigs || {});
      const hotkeysEncoded = SettingsForm.encodeHotkeysLines(obj.hotkeys || []);
      this.host.SettingsSaveV2(generalEncoded, disabledCsv, pluginEncoded, hotkeysEncoded);
      return;
    }

    if (typeof this.host.SettingsSave !== 'function') return;
    const payload = legacyPayload || [];
    const [welcomeMsg, darkTheme, debugLevel, tooltipMs, transparency, borderColor, startupSound, notificationSound, reloadHotkey, suspendHotkey, swapXButtons, disabledPlugins, pluginConfigEncoded] = payload;
    this.host.SettingsSave(welcomeMsg, darkTheme, debugLevel, tooltipMs, transparency, borderColor, startupSound, notificationSound, reloadHotkey, suspendHotkey, swapXButtons, disabledPlugins, pluginConfigEncoded || '');
  }

  cancel() {
    if (this.host && typeof this.host.SettingsCancel === 'function') {
      this.host.SettingsCancel();
    }
  }

  browseForFile(currentPath = '') {
    if (!this.host || typeof this.host.BrowseForFile !== 'function') return '';
    return this.host.BrowseForFile(currentPath);
  }

  openDevTools() {
    if (!this.host || typeof this.host.OpenDevTools !== 'function') return false;
    return !!this.host.OpenDevTools();
  }

  minimize() {
    if (this.host && this.host.gui && typeof this.host.gui.Minimize === 'function') {
      this.host.gui.Minimize();
    }
  }
}

/**
 * SettingsDom: Caches DOM element lookups and provides accessors.
 */
class SettingsDom {
  constructor() {
    this.sections = new Map();
    this.navItems = new Map();
    this.fields = new Map();
    this.cache();
  }

  cache() {
    // Cache all section elements
    document.querySelectorAll('.settings-section').forEach(el => {
      const id = el.id;
      if (id) {
        const sectionName = id.replace('section-', '');
        this.sections.set(sectionName, el);
      }
    });

    // Cache all nav items
    document.querySelectorAll('.nav-item').forEach((el, idx) => {
      const dataSection = el.getAttribute('data-section');
      if (dataSection) {
        this.navItems.set(dataSection, el);
      }
    });

    // Cache common form fields
    const fieldIds = [
      'WelcomeMessage', 'DarkTheme', 'DebugLevel', 'ToolTipTimeoutMs', 'WindowTransparencyValue',
      'WindowOnTopBorderColor', 'StartupSound', 'NotificationSound',
      'ReloadAppHotkey', 'SuspendAppHotkey', 'SwapMouseXButtons',
      'ReloadAppHotkeyDisplay', 'SuspendAppHotkeyDisplay',
      'WindowTransparencyLabel', 'BorderColorSwatch',
      'plugins-list', 'hotkeys-tbody', 'logs-content', 'problems-content',
      'titleText'
    ];

    fieldIds.forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        this.fields.set(id, el);
      }
    });
  }

  getSection(name) {
    return this.sections.get(name);
  }

  getNavItem(name) {
    return this.navItems.get(name);
  }

  getField(id) {
    return this.fields.get(id);
  }

  getAllNavItems() {
    return Array.from(this.navItems.values());
  }

  getAllSections() {
    return Array.from(this.sections.values());
  }

  getPluginCheckboxes() {
    return document.querySelectorAll('#plugins-list input[type="checkbox"][id^="plugin_"]');
  }
}

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
    if (el) {
      el.value = value;
    }
  }

  setFieldChecked(id, checked) {
    const el = this.dom.getField(id);
    if (el) {
      el.checked = checked;
    }
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

    // Render plugin list
    if (state.plugins) {
      this._renderPlugins(state.plugins);
      // Phase 1+: Render plugin settings pages
      if (state.plugins.pages) {
        this._renderPluginSettingsPages(state.plugins.pages);
      }
    }

    // Render hotkeys table
    if (state.hotkeys) {
      this._renderHotkeys(state.hotkeys);
    }

    // Set logs and problems text
    if (state.logsText !== undefined) {
      const logsEl = this.dom.getField('logs-content');
      if (logsEl) {
        logsEl.textContent = state.logsText || 'No logs yet.';
      }
    }
    if (state.problemsText !== undefined) {
      const problemsEl = this.dom.getField('problems-content');
      if (problemsEl) {
        problemsEl.textContent = state.problemsText || 'No problems detected.';
      }
    }

    // Apply theme if present
    if (state.theme === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
      document.body.classList.add('dark-theme');
    } else if (state.theme === 'light') {
      document.documentElement.setAttribute('data-theme', 'light');
      document.body.classList.remove('dark-theme');
    }

    // Set title if present
    if (state.title) {
      const titleEl = this.dom.getField('titleText');
      if (titleEl) {
        titleEl.innerText = state.title;
      }
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

  // Phase 1+: Render plugin settings pages dynamically
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
          : `<div class="plugin-action-hotkeys"><button type="button" class="app-btn plugin-hotkey-badge plugin-hotkey-badge-empty" data-hotkey-action="${this._escapeHtml(actionName)}" data-win-toggle="modal" data-win-target="#HotkeyRecorderDialog">Assign hotkey</button></div>`;
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
        <span class="plugin-hotkey-badge-label">${this._escapeHtml(readable || hotkeyRaw)}</span>
        <span class="plugin-hotkey-badge-remove" data-action-hotkey-remove="${this._escapeHtml(hotkeyRaw)}">&times;</span>
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

  // Render a single plugin field
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

  // Reset plugin fields to defaults
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


/**
 * ColorPickerController: Manages the LCH color picker dialog.
 */
class ColorPickerController {
  constructor(dom) {
    this.dom = dom;
    this.colorWheel = null;
    this.targetInput = null;
    this.targetSwatch = null;
    this.dialogHex = document.getElementById('DialogColorHex');
    this.dialogRgb = document.getElementById('DialogColorRgb');
    this.dialogLch = document.getElementById('DialogColorLch');
    this.dialogPreview = document.getElementById('DialogColorPreview');
    this.smallSwatch = this.dom.getField('BorderColorSwatch');
    this.colorInput = this.dom.getField('WindowOnTopBorderColor');
    this.init();
  }

  init() {
    if (!window.LchColorWheel) {
      return;
    }

    const container = document.getElementById('my-color-picker-container');
    if (!container) return;

    this.colorWheel = new LchColorWheel({
      appendTo: container,
      wheelDiameter: 300,
      wheelThickness: 30,
      handleDiameter: 22,
      drawsRgbValidityBoundary: false,
      onChange: () => this._onWheelChange()
    });

    if (this.dialogHex) {
      this.dialogHex.addEventListener('input', () => this._onDialogHexInput());
      this.dialogHex.addEventListener('change', () => this._onDialogHexChange());
    }

    if (this.colorInput) {
      this.colorInput.addEventListener('change', () => this.syncFromForm());
      this.colorInput.addEventListener('input', () => this.syncFromForm());
    }

    document.addEventListener('input', (ev) => {
      const input = ev.target.closest('.plugin-color-input');
      if (!input) return;
      this._updatePluginSwatchForInput(input);
    });

    document.addEventListener('change', (ev) => {
      const input = ev.target.closest('.plugin-color-input');
      if (!input) return;
      this._updatePluginSwatchForInput(input);
    });

    this.syncFromForm();
  }

  beginForTrigger(trigger) {
    const selector = trigger?.getAttribute('data-color-selector') || '';
    const input = selector ? document.querySelector(selector) : this.colorInput;
    this.targetInput = input || this.colorInput;
    this.targetSwatch = this._resolveSwatch(this.targetInput);
    this.syncFromTarget();
  }

  _onWheelChange() {
    const hex = this._toAhkHex(this.colorWheel.rgb[0], this.colorWheel.rgb[1], this.colorWheel.rgb[2]);
    if (this.dialogHex) this.dialogHex.value = hex;
    if (this.dialogRgb) {
      this.dialogRgb.value = this.colorWheel.rgb.map(v => Math.round(v)).join(', ');
    }
    if (this.dialogLch) {
      this.dialogLch.value = this.colorWheel.lch.map(v => Math.round(v * 10) / 10).join(', ');
    }
    if (this.dialogPreview) {
      this.dialogPreview.style.background = this._toCssColor(hex);
    }
  }

  _onDialogHexInput() {
    if (this.dialogPreview) {
      this.dialogPreview.style.background = this._toCssColor(this.dialogHex.value);
    }
  }

  _onDialogHexChange() {
    const parsed = this._parseAhkHexColor(this.dialogHex.value);
    if (!parsed) return;
    if (this.colorWheel) {
      this.colorWheel.rgb = parsed;
      this.colorWheel.redraw();
    }
  }

  syncFromForm() {
    this.targetInput = this.colorInput;
    this.targetSwatch = this.smallSwatch;
    this.syncFromTarget();
  }

  syncFromTarget() {
    const activeInput = this.targetInput || this.colorInput;
    const parsed = this._parseAhkHexColor(activeInput?.value || '');
    if (this.dialogHex) {
      this.dialogHex.value = activeInput?.value || '';
    }
    if (parsed) {
      if (this.colorWheel) {
        this.colorWheel.rgb = parsed;
        this.colorWheel.redraw();
      }
      if (this.dialogPreview) {
        this.dialogPreview.style.background = this._toCssColor(activeInput?.value || '');
      }
    } else if (this.dialogPreview) {
      this.dialogPreview.style.background = '#ffffff';
    }
    if (activeInput === this.colorInput) {
      this._updateMainSwatch(activeInput?.value || '');
    } else {
      this._updatePluginSwatch(this.targetSwatch, activeInput?.value || '');
    }
  }

  _updateMainSwatch(hexLike) {
    if (this.smallSwatch) {
      this.smallSwatch.style.background = this._toCssColor(hexLike);
    }
  }

  apply() {
    if (!this.dialogHex) return;
    const hex6 = this._normalizeHex6(this.dialogHex.value);
    const activeInput = this.targetInput || this.colorInput;
    if (hex6 && activeInput) {
      activeInput.value = '0x' + hex6;
      activeInput.dispatchEvent(new Event('input'));
      activeInput.dispatchEvent(new Event('change'));
      if (activeInput === this.colorInput) {
        this._updateMainSwatch(activeInput.value);
      } else {
        this._updatePluginSwatch(this.targetSwatch, activeInput.value);
      }
    }
  }

  updatePluginSwatches() {
    document.querySelectorAll('.plugin-color-input').forEach((input) => {
      this._updatePluginSwatchForInput(input);
    });
  }

  _updatePluginSwatchForInput(input) {
    if (!input) return;
    const key = input.getAttribute('data-plugin-color-key');
    if (!key) return;
    const swatch = document.querySelector(`[data-plugin-color-swatch="${key}"]`);
    this._updatePluginSwatch(swatch, input.value || '');
  }

  _resolveSwatch(input) {
    if (!input || input === this.colorInput) return this.smallSwatch;
    const key = input.getAttribute('data-plugin-color-key');
    if (!key) return null;
    return document.querySelector(`[data-plugin-color-swatch="${key}"]`);
  }

  _updatePluginSwatch(swatch, hexLike) {
    if (swatch) {
      swatch.style.background = this._toCssColor(hexLike);
    }
  }

  _normalizeHex6(value) {
    let txt = (value || '').trim();
    if (txt.length >= 2) {
      const first = txt.charAt(0);
      const last = txt.charAt(txt.length - 1);
      if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
        txt = txt.slice(1, -1).trim();
      }
    }
    if (txt.charAt(0) === '#') txt = txt.slice(1);
    const m = /^(?:0[xX])?([0-9A-Fa-f]{6})$/.exec(txt);
    return m ? m[1].toUpperCase() : '';
  }

  _parseAhkHexColor(value) {
    const hex = this._normalizeHex6(value);
    if (!hex) return null;
    return [
      parseInt(hex.slice(0, 2), 16),
      parseInt(hex.slice(2, 4), 16),
      parseInt(hex.slice(4, 6), 16)
    ];
  }

  _toCssColor(value) {
    const hex = this._normalizeHex6(value);
    return hex ? ('#' + hex) : '#ffffff';
  }

  _toAhkHex(r, g, b) {
    const toHex = (v) => {
      const h = Math.max(0, Math.min(255, v | 0)).toString(16).toUpperCase();
      return h.length === 1 ? '0' + h : h;
    };
    return '0x' + toHex(r) + toHex(g) + toHex(b);
  }
}

/**
 * HotkeyRecorderController: Manages hotkey recording modal.
 */
class HotkeyRecorderController {
  constructor(dom, onActionHotkeyApplied = null) {
    this.dom = dom;
    this.onActionHotkeyApplied = onActionHotkeyApplied;
    this.recording = false;
    this.targetId = '';
    this.targetElement = null;
    this.targetDisplayElement = null;
    this.pendingRaw = '';
    this.actionTarget = null;
    this.init();
  }

  init() {
    document.addEventListener('click', (ev) => {
      const btn = ev.target.closest('[data-hotkey-target], [data-hotkey-selector], [data-hotkey-action]');
      if (!btn) return;
      this._onRecordButtonClick(btn);
    });

    document.addEventListener('keydown', (ev) => this._onRecordKey(ev), { capture: true });
  }

  _onRecordButtonClick(btn) {
    const dialog = document.getElementById('HotkeyRecorderDialog');
    if (dialog) {
      dialog.classList.add('active');
      dialog.style.display = 'flex';
    }

    const actionName = `${btn.getAttribute('data-hotkey-action') || ''}`.trim();
    if (actionName) {
      this.targetId = '';
      this.targetElement = null;
      this.targetDisplayElement = null;
      this.actionTarget = {
        actionName,
        replaceHotkeyRaw: `${btn.getAttribute('data-hotkey-current') || ''}`.trim()
      };
      this.pendingRaw = this.actionTarget.replaceHotkeyRaw;

      const optWildcard = document.getElementById('hotkeyOptWildcard');
      const optPassthrough = document.getElementById('hotkeyOptPassthrough');
      if (optWildcard) {
        optWildcard.checked = this.pendingRaw.indexOf('*') !== -1;
      }
      if (optPassthrough) {
        optPassthrough.checked = this.pendingRaw.indexOf('~') !== -1;
      }

      const statusEl = document.getElementById('hotkeyRecordStatus');
      const valueEl = document.getElementById('hotkeyRecordReadable');
      if (statusEl) {
        statusEl.textContent = 'Recording... press a key combination.';
      }
      if (valueEl) {
        valueEl.textContent = this.pendingRaw ? this._humanizeAhkHotkey(this.pendingRaw) : '(listening...)';
      }

      this._stopRecording();
      this.recording = true;
      return;
    }

    const targetId = btn.getAttribute('data-hotkey-target');
    const selector = btn.getAttribute('data-hotkey-selector');
    const input = selector ? document.querySelector(selector) : this.dom.getField(targetId);
    if (!input) return;

    this.actionTarget = null;
    this.targetId = targetId;
    this.targetElement = input;
    this.targetDisplayElement = this._resolveDisplayElement(input);
    this.pendingRaw = input.value || '';

    const optWildcard = document.getElementById('hotkeyOptWildcard');
    const optPassthrough = document.getElementById('hotkeyOptPassthrough');
    if (optWildcard) {
      optWildcard.checked = this.pendingRaw.indexOf('*') !== -1;
    }
    if (optPassthrough) {
      optPassthrough.checked = this.pendingRaw.indexOf('~') !== -1;
    }

    const statusEl = document.getElementById('hotkeyRecordStatus');
    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (statusEl) {
      statusEl.textContent = 'Recording... press a key combination.';
    }
    if (valueEl) {
      valueEl.textContent = this.pendingRaw ? this._humanizeAhkHotkey(this.pendingRaw) : '(listening...)';
    }

    this._stopRecording();
    this.recording = true;
  }

  _onRecordKey(ev) {
    if (!this.recording) return;

    const optWildcard = document.getElementById('hotkeyOptWildcard');
    const optPassthrough = document.getElementById('hotkeyOptPassthrough');

    ev.preventDefault();
    ev.stopPropagation();

    const raw = this._toAhkHotkey(ev, optWildcard?.checked || false, optPassthrough?.checked || false);
    if (!raw) return;

    this.pendingRaw = raw;

    const statusEl = document.getElementById('hotkeyRecordStatus');
    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (statusEl) {
      statusEl.textContent = 'Captured. Press Apply to use it or keep pressing keys to change.';
    }
    if (valueEl) {
      valueEl.textContent = this._humanizeAhkHotkey(raw);
    }
  }

  _stopRecording() {
    this.recording = false;
  }

  apply() {
    if (this.actionTarget && this.pendingRaw) {
      if (typeof this.onActionHotkeyApplied === 'function') {
        this.onActionHotkeyApplied(this.actionTarget.actionName, this.pendingRaw, this.actionTarget.replaceHotkeyRaw || '');
      }
      this._stopRecording();
      return;
    }

    const input = this.targetElement || this.dom.getField(this.targetId);
    if (!input || !this.pendingRaw) return;

    input.value = this.pendingRaw;
    input.dispatchEvent(new Event('input'));
    input.dispatchEvent(new Event('change'));
    this._stopRecording();
    if (this.targetId) {
      this.updatePreview(this.targetId);
    } else {
      this._updateElementPreview(input, this.targetDisplayElement);
    }
  }

  updatePreview(inputId) {
    const input = this.dom.getField(inputId);
    const display = this._resolveDisplayElement(input) || this.dom.getField(inputId + 'Display');
    if (!input) return;

    const txt = (input.value || '').trim();
    const readable = txt ? this._humanizeAhkHotkey(txt) : '';
    this._setDisplayText(display, readable);
  }

  updatePluginPreviews() {
    document.querySelectorAll('.plugin-field-hotkey').forEach((input) => {
      this._updateElementPreview(input, this._resolveDisplayElement(input));
    });
  }

  _resolveDisplayElement(input) {
    if (!input) return null;
    const displayKey = input.getAttribute('data-display-for-plugin-hotkey');
    if (displayKey)
      return document.querySelector(`[data-plugin-hotkey-display="${displayKey}"]`);

    const id = input.id || '';
    if (!id) return null;
    return document.querySelector(`[data-hotkey-display-for="${id}"]`);
  }

  _setDisplayText(display, readable) {
    if (!display) return;
    const text = readable || 'Assign hotkey';
    if (display instanceof HTMLInputElement || display instanceof HTMLTextAreaElement) {
      display.value = readable || '';
      return;
    }

    const label = display.querySelector('.hotkey-badge-label');
    if (label) {
      label.textContent = text;
    } else {
      display.textContent = text;
    }
    display.classList.toggle('is-empty', !readable);
  }

  _updateElementPreview(input, display) {
    if (!input || !display) return;
    const txt = (input.value || '').trim();
    this._setDisplayText(display, txt ? this._humanizeAhkHotkey(txt) : '');
  }

  _toAhkHotkey(ev, wildcard, passthrough) {
    const key = ev.key;
    if (!key) return '';
    if (key === 'Control' || key === 'Shift' || key === 'Alt' || key === 'Meta') return '';

    let prefix = '';
    if (wildcard) prefix += '*';
    if (passthrough) prefix += '~';
    if (ev.ctrlKey) prefix += '^';
    if (ev.altKey) prefix += '!';
    if (ev.shiftKey) prefix += '+';
    if (ev.metaKey) prefix += '#';

    const keyMap = {
      ' ': 'Space',
      'Escape': 'Esc',
      'ArrowUp': 'Up',
      'ArrowDown': 'Down',
      'ArrowLeft': 'Left',
      'ArrowRight': 'Right',
      'Backspace': 'Backspace',
      'Delete': 'Delete',
      'Insert': 'Insert',
      'Home': 'Home',
      'End': 'End',
      'PageUp': 'PgUp',
      'PageDown': 'PgDn',
      'Enter': 'Enter',
      'Tab': 'Tab'
    };

    let keyName = keyMap[key] || key;
    if (keyName.length === 1) keyName = keyName.toUpperCase();
    return prefix + keyName;
  }

  _humanizeAhkHotkey(hk) {
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
}

/**
 * SettingsPage: Composition root and public bridge.
 */
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
    const cancelBtn = document.querySelector('[data-action="cancel-settings"]');
    const minimizeBtn = document.querySelector('[data-action="minimize-window"]');

    if (saveBtn) {
      saveBtn.addEventListener('click', () => this._saveSettings());
    }
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => this.hostBridge.cancel());
    }
    if (minimizeBtn) {
      minimizeBtn.addEventListener('click', () => this.hostBridge.minimize());
    }

    // Fallback for inline onclick (Phase 2 will remove these)
    window.ahk = {
      SettingsSave: () => this._saveSettings(),
      SettingsCancel: () => this.hostBridge.cancel(),
      BrowseForFile: (path) => this.hostBridge.browseForFile(path),
      gui: {
        Minimize: () => this.hostBridge.minimize()
      }
    };

    window.SettingsUiBridge = {
      refreshFromConfig: () => this.refreshUI()
    };
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

    // Fallback for inline onclick
    window.showSection = (name, navEl) => this._showSection(name, navEl);
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

    if (toggleBtn) {
      toggleBtn.addEventListener('click', () => this.colorPicker.syncFromForm());
    }
    document.addEventListener('click', (ev) => {
      const trigger = ev.target.closest('[data-color-selector]');
      if (!trigger) return;
      this.colorPicker.beginForTrigger(trigger);
    });
    if (applyBtn) {
      applyBtn.addEventListener('click', () => {
        this.colorPicker.apply();
        if (cancelBtn) cancelBtn.click();
      });
    }
  }

  _bindHotkeyRecorderDialog() {
    const applyBtn = document.getElementById('applyHotkeyRecord');
    const cancelBtn = document.getElementById('cancelHotkeyRecord');

    if (applyBtn) {
      applyBtn.addEventListener('click', () => {
        this.hotkeyRecorder.apply();
        this._closeDialog('HotkeyRecorderDialog');
      });
    }
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => this._closeDialog('HotkeyRecorderDialog'));
    }
  }

  _closeDialog(dialogId) {
    const dialog = document.getElementById(dialogId);
    if (!dialog) return;
    dialog.classList.remove('active');
    dialog.style.display = '';
  }

  _bindSliderRefresh() {
    const slider = this.dom.getField('WindowTransparencyValue');
    if (slider) {
      slider.addEventListener('input', () => this.form._updateTransparencyUI());
      slider.addEventListener('change', () => this.form._updateTransparencyUI());
    }
  }

  _bindDevToolsButton() {
    const openDevToolsBtn = document.getElementById('openDevTools');
    if (!openDevToolsBtn) return;

    openDevToolsBtn.addEventListener('click', () => {
      this.hostBridge.openDevTools();
    });
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
    const legacyPayload = this.form.serializeLegacy(payloadObject);
    this.hostBridge.saveSettings(payloadObject, legacyPayload);
  }

  refreshUI() {
    this.form.refreshUI(this.colorPicker, this.hotkeyRecorder);
  }

  /**
   * Apply state from AHK (Phase 3).
   */
  applyState(state) {
    this._isApplyingState = true;
    this.form.applyState(state);
    this.refreshUI();
    this._isApplyingState = false;
  }
}

// Initialize on page load
(function initialize() {
  window.settingsPage = new SettingsPage();
  window.SettingsPageBridge = {
    applyState: (state) => window.settingsPage.applyState(state),
    refresh: () => window.settingsPage.refreshUI()
  };

  // Refresh after a small delay to ensure DOM is ready
  if (window.SettingsUiBridge && typeof window.SettingsUiBridge.refreshFromConfig === 'function') {
    window.SettingsUiBridge.refreshFromConfig();
  }
})();

window.chrome.webview.addEventListener('message', ahkWebMessage);
function ahkWebMessage(Msg) {
    console.log(Msg.data);
}

function ahkButtonClick(ele) {
    if (ele.Id != null || "") {
        var eleInfo = ele.Id;
    }
    else if (ele.Name != null || "") {
        var eleInfo = ele.Name;
    }
    else if (ele.innerText != null || "") {
        var eleInfo = ele.innerText;
    }
    else {
        var eleInfo = ele.outerHTML;
    }
    ahk.ButtonClick.Func(eleInfo);
}
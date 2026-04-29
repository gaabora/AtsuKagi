
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

  saveSettings(payload) {
    if (!this.host || typeof this.host.SettingsSave !== 'function') return;
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
  }

  /**
   * Serialize form state into save payload.
   */
  serialize() {
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

    const pluginLines = [];
    document.querySelectorAll('.plugin-field[data-plugin-id][data-key]').forEach((el) => {
      const pluginId = el.getAttribute('data-plugin-id') || '';
      const key = el.getAttribute('data-key') || '';
      if (!pluginId || !key) return;

      let value = '';
      if (el.type === 'checkbox') {
        value = el.checked ? '1' : '0';
      } else {
        value = el.value || '';
      }
      pluginLines.push(`${pluginId}\t${key}\t${value}`);
    });

    return [
      welcomeMsg, darkTheme, debugLevel, tooltipMs, transparency, borderColor,
      startupSound, notificationSound, reloadHotkey, suspendHotkey, isSwapped,
      disabledPlugins.join(','), pluginLines.join('\n')
    ];
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
        sectionHtml += this._renderPluginActionsSummary(page.actions);
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

      // Bind nav click handler
      navItem.addEventListener('click', (e) => {
        e.preventDefault();
        document.querySelectorAll('.settings-nav .nav-item').forEach((item) => item.classList.remove('active'));
        document.querySelectorAll('.settings-content .settings-section').forEach((s) => s.classList.remove('active'));
        navItem.classList.add('active');
        section.classList.add('active');
      });

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

  _renderPluginActionsSummary(actions) {
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
        const hotkeys = Array.isArray(item.hotkeys) ? item.hotkeys : [];
        const hotkeysHtml = hotkeys.length
          ? `<div class="plugin-action-hotkeys">${hotkeys.map((hk) => `<span class="plugin-hotkey-chip">${this._escapeHtml(hk)}</span>`).join('')}</div>`
          : `<div class="plugin-action-hotkeys plugin-action-hotkeys-empty">No hotkey assigned</div>`;
        html += `
          <div class="plugin-action-item">
            <div class="plugin-action-name">${this._escapeHtml(item.label || item.action || '')}</div>
            <div class="plugin-action-description">${this._escapeHtml(item.description || '')}</div>
            ${hotkeysHtml}
          </div>
        `;
      });
      html += '</div>';
    });
    html += '</div>';

    return html;
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
        const hotkeyDisplayKey = `${pluginId}::${key}`;
        controlHtml = `
          <div class="field-with-actions">
            <input type="hidden" class="plugin-field plugin-field-hotkey" data-plugin-id="${this._escapeHtml(pluginId)}" data-key="${this._escapeHtml(key)}" data-display-for-plugin-hotkey="${this._escapeHtml(hotkeyDisplayKey)}" value="${this._escapeHtml(value)}" />
            <input type="text" class="app-input-text hotkey-display-input" readonly value="${this._escapeHtml(value)}" data-plugin-hotkey-display="${this._escapeHtml(hotkeyDisplayKey)}" placeholder="Press Record" />
            <div class="field-actions">
              <button type="button" class="app-btn app-btn-subtle field-btn" data-hotkey-selector=".plugin-field-hotkey[data-plugin-id=&quot;${this._escapeHtml(pluginId)}&quot;][data-key=&quot;${this._escapeHtml(key)}&quot;]" data-win-toggle="modal" data-win-target="#HotkeyRecorderDialog">Record</button>
              <button type="button" class="app-btn app-btn-subtle field-btn" data-reset-field="${this._escapeHtml(key)}" data-default="${this._escapeHtml(defaultValue)}">Reset</button>
            </div>
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
      <div class="setting-row">
        <label class="field-label">${this._escapeHtml(label)}</label>
        ${description ? `<p class="field-description">${this._escapeHtml(description)}</p>` : ''}
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
  constructor(dom) {
    this.dom = dom;
    this.recording = false;
    this.targetId = '';
    this.targetElement = null;
    this.targetDisplayElement = null;
    this.pendingRaw = '';
    this.init();
  }

  init() {
    document.addEventListener('click', (ev) => {
      const btn = ev.target.closest('[data-hotkey-target], [data-hotkey-selector]');
      if (!btn) return;
      this._onRecordButtonClick(btn);
    });

    document.addEventListener('keydown', (ev) => this._onRecordKey(ev), { capture: true });
  }

  _onRecordButtonClick(btn) {
    const targetId = btn.getAttribute('data-hotkey-target');
    const selector = btn.getAttribute('data-hotkey-selector');
    const input = selector ? document.querySelector(selector) : this.dom.getField(targetId);
    if (!input) return;

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
    const display = this.dom.getField(inputId + 'Display');
    if (!input) return;

    const txt = (input.value || '').trim();
    const readable = txt ? this._humanizeAhkHotkey(txt) : '';
    if (display) display.value = readable;
  }

  updatePluginPreviews() {
    document.querySelectorAll('.plugin-field-hotkey').forEach((input) => {
      this._updateElementPreview(input, this._resolveDisplayElement(input));
    });
  }

  _resolveDisplayElement(input) {
    if (!input) return null;
    const displayKey = input.getAttribute('data-display-for-plugin-hotkey');
    if (!displayKey) return null;
    return document.querySelector(`[data-plugin-hotkey-display="${displayKey}"]`);
  }

  _updateElementPreview(input, display) {
    if (!input || !display) return;
    const txt = (input.value || '').trim();
    display.value = txt ? this._humanizeAhkHotkey(txt) : '';
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
    this.hotkeyRecorder = new HotkeyRecorderController(this.dom);
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

  _bindNavigation() {
    this.dom.getAllNavItems().forEach(item => {
      item.addEventListener('click', (e) => {
        const sectionName = item.getAttribute('data-section') || item.getAttribute('onclick')?.match(/'(\w+)'/)?.[1];
        if (sectionName) {
          this._showSection(sectionName, item);
        }
      });
    });

    // Fallback for inline onclick
    window.showSection = (name, navEl) => this._showSection(name, navEl);
  }

  _showSection(name, navEl) {
    this.dom.getAllSections().forEach(section => {
      section.classList.remove('active');
    });

    this.dom.getAllNavItems().forEach(item => {
      item.classList.remove('active');
    });

    const target = this.dom.getSection(name);
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
        if (cancelBtn) cancelBtn.click();
      });
    }
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

  _saveSettings() {
    const payload = this.form.serialize();
    this.hostBridge.saveSettings(payload);
  }

  refreshUI() {
    this.form.refreshUI(this.colorPicker, this.hotkeyRecorder);
  }

  /**
   * Apply state from AHK (Phase 3).
   */
  applyState(state) {
    this.form.applyState(state);
    this.refreshUI();
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
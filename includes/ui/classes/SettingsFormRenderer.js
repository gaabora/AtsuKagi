class SettingsFormRenderer {
  constructor(form) {
    this.form = form;
  }

  renderGeneralPage(page) {
    const container = document.getElementById('section-general');
    if (!container || !Array.isArray(page?.sections)) return;

    let html = '';
    page.sections.forEach((section) => {
      html += `<div class="setting-group"><h2>${this.form._escapeHtml(section?.title || section?.id || 'General')}</h2>`;
      (section?.fields || []).forEach((field) => {
        html += this.renderField(field || {}, 'general');
      });
      html += '</div>';
    });

    container.innerHTML = html;
  }

  renderField(field, scope = 'general', pluginId = null) {
    const key = `${field?.key || ''}`;
    const label = `${field?.label || key}`;
    const description = `${field?.description || ''}`;
    const control = `${field?.control || 'text'}`.trim().toLowerCase();
    const value = field?.value ?? '';
    const defaultValue = field?.default ?? '';
    const type = `${field?.type || 'string'}`;
    const min = field?.validation?.min;
    const max = field?.validation?.max;
    const step = field?.validation?.step ?? field?.step;
    const requiredAttr = field?.validation?.required ? ' required' : '';
    const isGeneral = scope === 'general';
    const fieldClass = isGeneral ? 'general-field' : 'plugin-field';
    const fieldAttrs = isGeneral
      ? `data-key="${this.form._escapeHtml(key)}" data-type="${this.form._escapeHtml(type)}"`
      : `data-plugin-id="${this.form._escapeHtml(pluginId || '')}" data-key="${this.form._escapeHtml(key)}"`;
    const rawInputIdBase = isGeneral
      ? key
      : `${pluginId || 'plugin'}_${key}`;
    const inputIdBase = `${rawInputIdBase}`.replace(/[^A-Za-z0-9_\-]/g, '_') || 'setting_field';

    let controlHtml = '';

    switch (control) {
      case 'switch': {
        const checked = (value === true || value === 1 || value === '1' || value === 'true') ? ' checked' : '';
        controlHtml = `
          <label class="app-switch">
            <input type="checkbox" class="${fieldClass}" id="${this.form._escapeHtml(inputIdBase)}" ${fieldAttrs}${checked} />
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
        const defaultHotkey = `${defaultValue || ''}`;
        controlHtml = `
          <div class="field-with-actions">
            <input type="hidden" class="${fieldClass}" id="${this.form._escapeHtml(hotkeyFieldId)}" ${fieldAttrs} value="${this.form._escapeHtml(`${value || ''}`)}" />
            <button type="button" class="app-btn hotkey-badge ${hotkeyBadgeClass}" data-hotkey-target="${this.form._escapeHtml(hotkeyFieldId)}" data-hotkey-display-for="${this.form._escapeHtml(hotkeyFieldId)}" data-hotkey-default="${this.form._escapeHtml(defaultHotkey)}" data-win-toggle="modal" data-win-target="#HotkeyRecorderDialog">
              <span class="hotkey-badge-label">${this.form._escapeHtml(readable)}</span>
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
            <input class="app-input-text ${fieldClass}" type="text" id="${this.form._escapeHtml(colorInputId)}" ${fieldAttrs}${requiredAttr} data-color-swatch-id="${this.form._escapeHtml(colorSwatchId)}" value="${this.form._escapeHtml(`${value || ''}`)}" placeholder="${this.form._escapeHtml(`${defaultValue || ''}`)}" />
            <div class="field-actions">
              <button id="${this.form._escapeHtml(colorBtnId)}" type="button" class="app-btn app-btn-subtle field-btn" data-color-input-id="${this.form._escapeHtml(colorInputId)}" data-color-swatch-id="${this.form._escapeHtml(colorSwatchId)}" data-win-toggle="modal" data-win-target="#ColorPickerDialog">
                <span id="${this.form._escapeHtml(colorSwatchId)}" class="color-swatch-small" aria-hidden="true"></span>
                <span>Pick</span>
              </button>
            </div>
          </div>
        `;
        break;
      }
      case 'path': {
        const browseMeta = isGeneral ? this.form._getGeneralPathBrowseMeta(key) : null;
        const pickerHtml = browseMeta
          ? `<input type="file" id="${this.form._escapeHtml(browseMeta.fileInputId)}" accept="audio/*,.wav,.mp3,.ogg,.flac" hidden />`
          : '';
        const browseBtnHtml = browseMeta
          ? `<button id="${this.form._escapeHtml(browseMeta.buttonId)}" type="button" class="app-btn app-btn-subtle field-btn"><span>Browse</span></button>`
          : '';
        controlHtml = `
          <div class="field-with-actions">
            <input class="app-input-text ${fieldClass}" type="text" id="${this.form._escapeHtml(inputIdBase)}" ${fieldAttrs}${requiredAttr} value="${this.form._escapeHtml(`${value || ''}`)}" />
            <div class="field-actions">${browseBtnHtml}</div>
          </div>
          ${pickerHtml}
        `;
        break;
      }
      case 'range': {
        const minNum = Number(min);
        const maxNum = Number(max);
        const stepNum = Number(step);
        const hasMin = Number.isFinite(minNum);
        const hasMax = Number.isFinite(maxNum);
        const hasStep = Number.isFinite(stepNum) && stepNum > 0;

        const minAttr = hasMin ? ` min="${minNum}"` : ' min="0"';
        const maxAttr = hasMax ? ` max="${maxNum}"` : '';
        const stepAttr = hasStep ? ` step="${stepNum}"` : ' step="1"';

        // Parse initial value safely: handle empty strings, non-numeric, and proper numeric values
        const valueStr = `${value ?? ''}`.trim();
        const defaultStr = `${defaultValue ?? ''}`.trim();
        const valueNum = valueStr ? Number(valueStr) : NaN;
        const defaultNum = defaultStr ? Number(defaultStr) : NaN;

        let sliderNum;
        if (Number.isFinite(valueNum)) {
          sliderNum = valueNum;
        } else if (Number.isFinite(defaultNum)) {
          sliderNum = defaultNum;
        } else if (hasMin) {
          sliderNum = minNum;
        } else {
          sliderNum = 128;
        }

        // Clamp to min/max
        if (hasMin) sliderNum = Math.max(sliderNum, minNum);
        if (hasMax) sliderNum = Math.min(sliderNum, maxNum);

        const sliderValue = `${sliderNum}`;
        const numberInputId = isGeneral && key === 'WindowTransparencyValue'
          ? 'WindowTransparencyLabel'
          : `RangeInput_${inputIdBase}`;
        controlHtml = `
          <div class="app-range-slider">
            <input type="range" class="${fieldClass}" id="${this.form._escapeHtml(inputIdBase)}" ${fieldAttrs}${minAttr}${maxAttr}${stepAttr} value="${this.form._escapeHtml(sliderValue)}" data-range-number-id="${this.form._escapeHtml(numberInputId)}" />
            <input type="number" class="app-input-text app-range-number" id="${this.form._escapeHtml(numberInputId)}"${minAttr}${maxAttr}${stepAttr} value="${this.form._escapeHtml(sliderValue)}" data-range-source-id="${this.form._escapeHtml(inputIdBase)}" />
          </div>
        `;
        break;
      }
      case 'number': {
        const minAttr = Number.isFinite(Number(min)) ? ` min="${Number(min)}"` : '';
        const maxAttr = Number.isFinite(Number(max)) ? ` max="${Number(max)}"` : '';
        controlHtml = `
          <input class="app-input-text ${fieldClass}" type="number" id="${this.form._escapeHtml(inputIdBase)}" ${fieldAttrs}${requiredAttr} value="${this.form._escapeHtml(`${value || ''}`)}"${minAttr}${maxAttr} />
        `;
        break;
      }
      case 'select': {
        const options = isGeneral
          ? this.form._getGeneralSelectOptions(field)
          : (Array.isArray(field?.options) && field.options.length
            ? field.options
            : [{ value: `${field?.value ?? field?.default ?? ''}`, label: `${field?.value ?? field?.default ?? ''}` }]);
        const selected = `${value ?? defaultValue ?? ''}`;
        const optionsHtml = options.map((opt) => {
          const v = `${opt?.value ?? ''}`;
          const text = `${opt?.label ?? v}`;
          const isSelected = v === selected ? ' selected' : '';
          return `<option value="${this.form._escapeHtml(v)}"${isSelected}>${this.form._escapeHtml(text)}</option>`;
        }).join('');
        controlHtml = `
          <div class="app-select-menu">
            <select class="${fieldClass}" id="${this.form._escapeHtml(inputIdBase)}" ${fieldAttrs}${requiredAttr}>${optionsHtml}</select>
          </div>
        `;
        break;
      }
      default: {
        controlHtml = `
          <input class="app-input-text ${fieldClass}" type="text" id="${this.form._escapeHtml(inputIdBase)}" ${fieldAttrs}${requiredAttr} value="${this.form._escapeHtml(`${value || ''}`)}" />
        `;
      }
    }

    if (scope === 'plugin') {
      const pluginFieldKey = `${key}`;
      const pluginFieldSig = this.form._pluginFieldSignature(field);
      return `
        <div class="setting-row plugin-setting-row" data-plugin-field-key="${this.form._escapeHtml(pluginFieldKey)}" data-plugin-field-sig="${this.form._escapeHtml(pluginFieldSig)}">
          <div class="plugin-field-meta">
            <label class="field-label">${this.form._escapeHtml(label)}</label>
            ${description ? `<p class="field-description">${this.form._escapeHtml(description)}</p>` : ''}
          </div>
          <div class="app-input-container">
            ${controlHtml}
          </div>
        </div>
      `;
    }

    return `
      <div class="setting-row">
        <div class="general-field-meta">
          <label class="field-label" for="${this.form._escapeHtml(inputIdBase)}">${this.form._escapeHtml(label)}</label>
          ${description ? `<p class="field-description">${this.form._escapeHtml(description)}</p>` : ''}
        </div>
        <div class="app-input-container">
          ${controlHtml}
        </div>
      </div>
    `;
  }
}

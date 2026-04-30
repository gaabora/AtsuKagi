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

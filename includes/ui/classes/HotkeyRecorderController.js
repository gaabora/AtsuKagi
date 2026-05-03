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
      dialog.classList.add('show');
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
        valueEl.textContent = this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(listening...)';
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
      valueEl.textContent = this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(listening...)';
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
      valueEl.textContent = AK_HumanizeAhkHotkey(raw);
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
    const readable = txt ? AK_HumanizeAhkHotkey(txt) : '';
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
    this._setDisplayText(display, txt ? AK_HumanizeAhkHotkey(txt) : '');
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

}
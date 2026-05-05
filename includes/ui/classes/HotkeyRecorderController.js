/**
 * HotkeyRecorderController: Manages hotkey recording modal.
 * Delegates key recording to AHK-level low-level keyboard hook.
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

    // Global receiver for AHK hotkey updates (installed when recording starts)
    window._onAhkHotkeyRecorded = (data) => this._onAhkHotkeyUpdate(data);
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

      this._initializeRecorderUI();
      this._startAhkRecording();
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

    this._initializeRecorderUI();
    this._startAhkRecording();
  }

  _initializeRecorderUI() {
    const statusEl = document.getElementById('hotkeyRecordStatus');
    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (statusEl) {
      statusEl.textContent = 'Recording... press a key combination.';
    }
    if (valueEl) {
      valueEl.textContent = this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(listening...)';
    }
  }

  _startAhkRecording() {
    // Note: wildcard and passthrough will be applied by JS at apply-time, not by AHK recorder
    const options = {
      keyboard: true,
      mouse: true,
      lrModifiers: true,
      markOnly: false
    };

    try {
      const result = window.chrome.webview.hostObjects.sync.StartHotkeyRecording(JSON.stringify(options));
      const parsed = (typeof result === 'string') ? JSON.parse(result) : result;
      this.recording = !!parsed?.success;
    } catch (error) {
      console.error('Failed to start AHK hotkey recording', error);
      this.recording = false;
    }
  }

  _onAhkHotkeyUpdate(data) {
    if (!this.recording) return;

    const { raw, display } = data;
    if (!raw) return;

    // Store the raw hotkey
    this.pendingRaw = raw;

    // Update UI
    const statusEl = document.getElementById('hotkeyRecordStatus');
    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (statusEl) {
      statusEl.textContent = 'Captured. Press Apply to use it or keep pressing keys to change.';
    }
    if (valueEl) {
      valueEl.textContent = display;
    }
  }

  _stopAhkRecording() {
    try {
      window.chrome.webview.hostObjects.sync.StopHotkeyRecording();
    } catch (error) {
      console.error('Failed to stop AHK hotkey recording', error);
    }
    this.recording = false;
  }

  apply() {
    // Apply wildcard and passthrough modifiers if enabled (done at JS level, not AHK)
    let finalHotkey = this.pendingRaw;
    const optWildcard = document.getElementById('hotkeyOptWildcard')?.checked || false;
    const optPassthrough = document.getElementById('hotkeyOptPassthrough')?.checked || false;

    // Add prefixes if not already present
    if (optWildcard && !finalHotkey.startsWith('*')) {
      finalHotkey = '*' + finalHotkey;
    }
    if (optPassthrough && !finalHotkey.startsWith('~')) {
      finalHotkey = '~' + finalHotkey;
    }

    if (this.actionTarget && finalHotkey) {
      if (typeof this.onActionHotkeyApplied === 'function') {
        this.onActionHotkeyApplied(this.actionTarget.actionName, finalHotkey, this.actionTarget.replaceHotkeyRaw || '');
      }
      this._stopAhkRecording();
      return;
    }

    const input = this.targetElement || this.dom.getField(this.targetId);
    if (!input || !finalHotkey) return;

    input.value = finalHotkey;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    this._stopAhkRecording();
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

  cancel() {
    this._stopAhkRecording();
  }

  close() {
    this._stopAhkRecording();
  }

}
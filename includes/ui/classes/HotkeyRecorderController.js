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
    this._manualKeyCatalog = this._buildManualKeyCatalog();
    this._manualModifierIdsGeneric = ['hotkeyManualModCtrl', 'hotkeyManualModAlt', 'hotkeyManualModShift', 'hotkeyManualModWin'];
    this._manualModifierIdsLr = [
      'hotkeyManualModLCtrl', 'hotkeyManualModRCtrl',
      'hotkeyManualModLAlt', 'hotkeyManualModRAlt',
      'hotkeyManualModLShift', 'hotkeyManualModRShift',
      'hotkeyManualModLWin', 'hotkeyManualModRWin'
    ];
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

    this._bindAdvancedControls();
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

      const label = this._humanizeLabel(actionName);
      this._setDialogTitle(`Assign ${label}`);

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

    const targetLabel = this._resolveTargetTitle(btn, input, targetId);
    this._setDialogTitle(`Assign ${targetLabel}`);

    this._initializeRecorderUI();
    this._startAhkRecording();
  }

  _setDialogTitle(titleText) {
    const title = document.getElementById('hotkeyDialogTitle');
    if (title) {
      title.textContent = titleText || 'Assign Hotkey';
    }
  }

  _resolveTargetTitle(btn, input, targetId) {
    const direct = `${btn?.getAttribute('data-hotkey-label') || ''}`.trim();
    if (direct) return direct;

    const rowLabel = `${input?.closest('.setting-row')?.querySelector('.field-label')?.textContent || ''}`.trim();
    if (rowLabel) return rowLabel;

    const dataKey = `${input?.getAttribute('data-key') || ''}`.trim();
    if (dataKey) return this._humanizeLabel(dataKey);

    const inputId = `${targetId || input?.id || ''}`.trim();
    if (inputId) return this._humanizeLabel(inputId);

    return 'Hotkey';
  }

  _humanizeLabel(value) {
    const text = `${value || ''}`.trim();
    if (!text) return '';

    return text
      .replace(/[_-]+/g, ' ')
      .replace(/([a-z\d])([A-Z])/g, '$1 $2')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/\b\w/g, (ch) => ch.toUpperCase());
  }

  _initializeRecorderUI() {
    const optWildcard = document.getElementById('hotkeyOptWildcard');
    const optPassthrough = document.getElementById('hotkeyOptPassthrough');
    if (optWildcard) {
      optWildcard.checked = this.pendingRaw.indexOf('*') !== -1;
    }
    if (optPassthrough) {
      optPassthrough.checked = this.pendingRaw.indexOf('~') !== -1;
    }

    const advancedDetails = document.getElementById('hotkeyAdvancedDetails');
    if (advancedDetails) {
      advancedDetails.open = false;
    }

    const manualFilter = document.getElementById('hotkeyManualKeyFilter');
    if (manualFilter) {
      manualFilter.value = '';
    }

    this._syncManualModifierMode();
    this._renderManualKeyList();
    this._setManualControlsFromRaw(this.pendingRaw);
    this._updateManualPreview();

    const statusEl = document.getElementById('hotkeyRecordStatus');
    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (statusEl) {
      statusEl.textContent = 'Recording... press a key combination.';
    }
    if (valueEl) {
      valueEl.textContent = this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(listening...)';
    }
  }

  _bindAdvancedControls() {
    const bindOnce = (el, marker, eventName, handler) => {
      if (!el || el.dataset[marker] === '1') return;
      el.dataset[marker] = '1';
      el.addEventListener(eventName, handler);
    };

    const optionIds = ['hotkeyOptMouseCapture', 'hotkeyOptGamepadCapture', 'hotkeyOptModifiersOnly', 'hotkeyOptLrModifiers'];
    optionIds.forEach((id) => {
      const el = document.getElementById(id);
      bindOnce(el, `bound${id}`, 'change', () => {
        if (id === 'hotkeyOptLrModifiers') {
          this._syncManualModifierMode();
          this._setManualControlsFromRaw(this.pendingRaw);
          this._updateManualPreview();
        }
        this._restartRecordingIfActive();
      });
    });

    const manualFilter = document.getElementById('hotkeyManualKeyFilter');
    bindOnce(manualFilter, 'boundHotkeyManualFilter', 'input', () => {
      this._renderManualKeyList();
      this._updateManualPreview();
    });

    const keyList = document.getElementById('hotkeyManualKeyList');
    bindOnce(keyList, 'boundHotkeyManualKeyChange', 'change', () => this._updateManualPreview());
    bindOnce(keyList, 'boundHotkeyManualKeyDblClick', 'dblclick', () => this._applyManualHotkey());

    const applyManualBtn = document.getElementById('apply-manual-hotkey');
    bindOnce(applyManualBtn, 'boundHotkeyManualApply', 'click', () => this._applyManualHotkey());

    this._manualModifierIdsGeneric.concat(this._manualModifierIdsLr).forEach((id) => {
      const el = document.getElementById(id);
      bindOnce(el, `bound${id}`, 'change', () => this._updateManualPreview());
    });
  }

  _restartRecordingIfActive() {
    if (!this.recording) return;
    this._startAhkRecording();
  }

  _startAhkRecording() {
    this._stopAhkRecording();

    const optLrModifiers = document.getElementById('hotkeyOptLrModifiers');
    const optMouseCapture = document.getElementById('hotkeyOptMouseCapture');
    const optGamepadCapture = document.getElementById('hotkeyOptGamepadCapture');
    const optModifiersOnly = document.getElementById('hotkeyOptModifiersOnly');

    // Note: wildcard and passthrough will be applied by JS at apply-time, not by AHK recorder
    const options = {
      keyboard: true,
      mouse: optMouseCapture ? !!optMouseCapture.checked : true,
      joystick: optGamepadCapture ? !!optGamepadCapture.checked : true,
      lrModifiers: optLrModifiers ? !!optLrModifiers.checked : true,
      markOnly: optModifiersOnly ? !!optModifiersOnly.checked : false
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

    this._setCapturedDisplay(raw, display, 'Captured. Press Apply to use it or keep pressing keys to change.');
  }

  _setCapturedDisplay(raw, display, statusText) {
    this.pendingRaw = `${raw || ''}`.trim();

    const statusEl = document.getElementById('hotkeyRecordStatus');
    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (statusEl) {
      statusEl.textContent = statusText || 'Captured.';
    }
    if (valueEl) {
      valueEl.textContent = display || (this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(none)');
    }

    this._setManualControlsFromRaw(this.pendingRaw);
    this._updateManualPreview();
  }

  _stopAhkRecording() {
    try {
      window.chrome.webview.hostObjects.sync.StopHotkeyRecording();
    } catch (error) {
      console.error('Failed to stop AHK hotkey recording', error);
    }
    this.recording = false;
  }

  _buildManualKeyCatalog() {
    const catalog = [];
    const add = (value, label = value) => {
      const item = {
        value,
        label,
        search: `${value} ${label}`.toLowerCase()
      };
      catalog.push(item);
    };

    for (let i = 65; i <= 90; i += 1) {
      const ch = String.fromCharCode(i);
      add(ch, ch);
    }
    for (let i = 0; i <= 9; i += 1) {
      add(`${i}`, `${i}`);
    }
    for (let i = 1; i <= 24; i += 1) {
      add(`F${i}`, `F${i}`);
    }

    [
      ['Esc', 'Escape'], ['Tab', 'Tab'], ['Enter', 'Enter'], ['Space', 'Space'],
      ['Backspace', 'Backspace'], ['Delete', 'Delete'], ['Insert', 'Insert'],
      ['Home', 'Home'], ['End', 'End'], ['PgUp', 'Page Up'], ['PgDn', 'Page Down'],
      ['Up', 'Arrow Up'], ['Down', 'Arrow Down'], ['Left', 'Arrow Left'], ['Right', 'Arrow Right'],
      ['CapsLock', 'Caps Lock'], ['NumLock', 'Num Lock'], ['ScrollLock', 'Scroll Lock'],
      ['PrintScreen', 'Print Screen'], ['Pause', 'Pause'], ['AppsKey', 'Context Menu'],
      ['Numpad0', 'Numpad 0'], ['Numpad1', 'Numpad 1'], ['Numpad2', 'Numpad 2'],
      ['Numpad3', 'Numpad 3'], ['Numpad4', 'Numpad 4'], ['Numpad5', 'Numpad 5'],
      ['Numpad6', 'Numpad 6'], ['Numpad7', 'Numpad 7'], ['Numpad8', 'Numpad 8'],
      ['Numpad9', 'Numpad 9'], ['NumpadDot', 'Numpad .'], ['NumpadAdd', 'Numpad +'],
      ['NumpadSub', 'Numpad -'], ['NumpadMult', 'Numpad *'], ['NumpadDiv', 'Numpad /'],
      ['NumpadEnter', 'Numpad Enter'], ['Volume_Mute', 'Volume Mute'],
      ['Volume_Down', 'Volume Down'], ['Volume_Up', 'Volume Up'],
      ['Media_Play_Pause', 'Media Play/Pause'], ['Media_Next', 'Media Next'],
      ['Media_Prev', 'Media Previous'], ['Media_Stop', 'Media Stop'],
      ['LButton', 'Mouse Left'], ['RButton', 'Mouse Right'], ['MButton', 'Mouse Middle'],
      ['WheelUp', 'Mouse Wheel Up'], ['WheelDown', 'Mouse Wheel Down']
    ].forEach(([value, label]) => add(value, label));

    return catalog;
  }

  _renderManualKeyList() {
    const list = document.getElementById('hotkeyManualKeyList');
    if (!list) return;

    const filterInput = document.getElementById('hotkeyManualKeyFilter');
    const needle = `${filterInput?.value || ''}`.trim().toLowerCase();
    const previousValue = `${list.value || ''}`.trim();

    const filtered = this._manualKeyCatalog.filter((item) => {
      if (!needle) return true;
      return item.search.includes(needle);
    });

    list.innerHTML = '';
    filtered.forEach((item) => {
      const opt = document.createElement('option');
      opt.value = item.value;
      opt.textContent = item.label;
      list.appendChild(opt);
    });

    if (previousValue) {
      this._setManualKeySelection(previousValue);
    }
  }

  _setManualKeySelection(keyValue) {
    const list = document.getElementById('hotkeyManualKeyList');
    if (!list) return;

    const value = `${keyValue || ''}`.trim();
    if (!value) {
      list.value = '';
      return;
    }

    const existing = Array.from(list.options).find((opt) => `${opt.value}` === value);
    if (!existing) {
      const opt = document.createElement('option');
      opt.value = value;
      const pretty = typeof AK_HumanizeAhkKeyName === 'function' ? AK_HumanizeAhkKeyName(value) : value;
      opt.textContent = `${pretty} [custom]`;
      opt.dataset.custom = '1';
      list.appendChild(opt);
    }

    list.value = value;
  }

  _syncManualModifierMode() {
    const lrEnabled = document.getElementById('hotkeyOptLrModifiers')?.checked || false;
    const genericBox = document.getElementById('hotkeyManualModsGeneric');
    const lrBox = document.getElementById('hotkeyManualModsLr');
    if (genericBox) {
      genericBox.hidden = lrEnabled;
    }
    if (lrBox) {
      lrBox.hidden = !lrEnabled;
    }
  }

  _clearManualModifiers() {
    this._manualModifierIdsGeneric.concat(this._manualModifierIdsLr).forEach((id) => {
      const cb = document.getElementById(id);
      if (cb) cb.checked = false;
    });
  }

  _parseHotkey(rawHotkey) {
    let input = `${rawHotkey || ''}`.trim();
    input = input.replace(/\*/g, '').replace(/~/g, '');

    const modifiers = [];
    let i = 0;

    while (i < input.length) {
      const two = input.slice(i, i + 2);
      const one = input[i];
      if (['<^', '>^', '<!', '>!', '<+', '>+', '<#', '>#'].includes(two)) {
        modifiers.push(two);
        i += 2;
        continue;
      }
      if (['^', '!', '+', '#'].includes(one)) {
        modifiers.push(one);
        i += 1;
        continue;
      }
      break;
    }

    return {
      modifiers,
      key: input.slice(i).trim()
    };
  }

  _setManualControlsFromRaw(rawHotkey) {
    this._clearManualModifiers();

    const parsed = this._parseHotkey(rawHotkey);
    const lrEnabled = document.getElementById('hotkeyOptLrModifiers')?.checked || false;

    const tokenToIdLr = {
      '<^': 'hotkeyManualModLCtrl',
      '>^': 'hotkeyManualModRCtrl',
      '<!': 'hotkeyManualModLAlt',
      '>!': 'hotkeyManualModRAlt',
      '<+': 'hotkeyManualModLShift',
      '>+': 'hotkeyManualModRShift',
      '<#': 'hotkeyManualModLWin',
      '>#': 'hotkeyManualModRWin',
      '^': 'hotkeyManualModLCtrl',
      '!': 'hotkeyManualModLAlt',
      '+': 'hotkeyManualModLShift',
      '#': 'hotkeyManualModLWin'
    };
    const tokenToIdGeneric = {
      '<^': 'hotkeyManualModCtrl',
      '>^': 'hotkeyManualModCtrl',
      '<!': 'hotkeyManualModAlt',
      '>!': 'hotkeyManualModAlt',
      '<+': 'hotkeyManualModShift',
      '>+': 'hotkeyManualModShift',
      '<#': 'hotkeyManualModWin',
      '>#': 'hotkeyManualModWin',
      '^': 'hotkeyManualModCtrl',
      '!': 'hotkeyManualModAlt',
      '+': 'hotkeyManualModShift',
      '#': 'hotkeyManualModWin'
    };

    parsed.modifiers.forEach((token) => {
      const id = lrEnabled ? tokenToIdLr[token] : tokenToIdGeneric[token];
      if (!id) return;
      const cb = document.getElementById(id);
      if (cb) cb.checked = true;
    });

    this._setManualKeySelection(parsed.key);
  }

  _collectManualModifiers() {
    const lrEnabled = document.getElementById('hotkeyOptLrModifiers')?.checked || false;
    const tokenById = lrEnabled
      ? {
        hotkeyManualModLCtrl: '<^', hotkeyManualModRCtrl: '>^',
        hotkeyManualModLAlt: '<!', hotkeyManualModRAlt: '>!',
        hotkeyManualModLShift: '<+', hotkeyManualModRShift: '>+',
        hotkeyManualModLWin: '<#', hotkeyManualModRWin: '>#'
      }
      : {
        hotkeyManualModCtrl: '^', hotkeyManualModAlt: '!',
        hotkeyManualModShift: '+', hotkeyManualModWin: '#'
      };

    const order = lrEnabled ? this._manualModifierIdsLr : this._manualModifierIdsGeneric;
    const parts = [];
    order.forEach((id) => {
      const cb = document.getElementById(id);
      if (cb?.checked) {
        parts.push(tokenById[id]);
      }
    });
    return parts.join('');
  }

  _composeManualRaw() {
    const modifiers = this._collectManualModifiers();
    const keyList = document.getElementById('hotkeyManualKeyList');
    const key = `${keyList?.value || ''}`.trim();
    const modifiersOnly = document.getElementById('hotkeyOptModifiersOnly')?.checked || false;

    if (!key) {
      return modifiersOnly ? modifiers : '';
    }
    return `${modifiers}${key}`;
  }

  _updateManualPreview() {
    const preview = document.getElementById('hotkeyManualPreview');
    if (!preview) return;

    const raw = this._composeManualRaw();
    preview.textContent = raw ? AK_HumanizeAhkHotkey(raw) : '(pick modifiers and key)';
  }

  _applyManualHotkey() {
    const raw = this._composeManualRaw();
    if (!raw) {
      const statusEl = document.getElementById('hotkeyRecordStatus');
      if (statusEl) {
        statusEl.textContent = 'Manual mode: choose a key (or enable Modifiers-only and choose modifiers).';
      }
      return;
    }

    this._setCapturedDisplay(
      raw,
      AK_HumanizeAhkHotkey(raw),
      'Composed manually. Press Apply to save or keep editing.'
    );
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
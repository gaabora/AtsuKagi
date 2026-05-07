/**
 * HotkeyRecorderController: Manages hotkey recording modal.
 * Delegates key recording to AHK-level low-level keyboard hook.
 */
class HotkeyRecorderController {

  // --- Modifier token maps (shared between parse and compose) ---

  static MOD_TOKENS_GENERIC = {
    '^': 'Ctrl', '!': 'Alt', '+': 'Shift', '#': 'Win',
    '<^': 'Ctrl', '>^': 'Ctrl', '<!': 'Alt', '>!': 'Alt',
    '<+': 'Shift', '>+': 'Shift', '<#': 'Win', '>#': 'Win'
  };

  static MOD_TOKENS_LR = {
    '^': 'LCtrl', '!': 'LAlt', '+': 'LShift', '#': 'LWin',
    '<^': 'LCtrl', '>^': 'RCtrl', '<!': 'LAlt', '>!': 'RAlt',
    '<+': 'LShift', '>+': 'RShift', '<#': 'LWin', '>#': 'RWin'
  };

  static MOD_TO_TOKEN_GENERIC = { 'Ctrl': '^', 'Alt': '!', 'Shift': '+', 'Win': '#' };

  static MOD_TO_TOKEN_LR = {
    'LCtrl': '<^', 'RCtrl': '>^', 'LAlt': '<!', 'RAlt': '>!',
    'LShift': '<+', 'RShift': '>+', 'LWin': '<#', 'RWin': '>#'
  };

  static RISKY_KEYS = new Set(['ESC', 'ENTER', 'LBUTTON', 'RBUTTON']);

  static KEY_CATALOG_SPECIAL = [
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
  ];

  constructor(dom, onActionHotkeyApplied = null) {
    this.dom = dom;
    this.onActionHotkeyApplied = onActionHotkeyApplied;
    this.recording = false;
    this.targetId = '';
    this.targetElement = null;
    this.targetDisplayElement = null;
    this.pendingRaw = '';
    this.actionTarget = null;
    this._activeTab = 'auto';
    this._recordSeconds = 5;
    this._recordDeadline = 0;
    this._recordTickTimer = null;
    this._recordStopTimer = null;
    this._autoWindowCaptured = false;
    this._customComboStep = 0;
    this._pendingPrefixKey = '';
    this._manualKeyCatalog = this._buildManualKeyCatalog();
    this.init();
  }

  // --- Helpers ---

  _str(v) { return `${v || ''}`.trim(); }

  _el(id) { return document.getElementById(id); }

  _checked(id) { return this._el(id)?.checked || false; }

  _lrEnabled() { return this._checked('hotkeyOptLrModifiers'); }

  _humanize(raw) { return raw ? AK_HumanizeAhkHotkey(raw) : '(none)'; }

  // --- Init ---

  init() {
    document.addEventListener('click', (ev) => {
      const btn = ev.target.closest('[data-hotkey-target], [data-hotkey-selector], [data-hotkey-action]');
      if (btn) this._onRecordButtonClick(btn);
    });

    window._onAhkHotkeyRecorded = (data) => this._onAhkHotkeyUpdate(data);
    this._bindControls();
  }

  // --- Dialog open ---

  _onRecordButtonClick(btn) {
    const dialog = this._el('HotkeyRecorderDialog');
    if (dialog) {
      dialog.classList.add('active', 'show');
      dialog.style.display = 'flex';
    }

    const actionName = this._str(btn.getAttribute('data-hotkey-action'));
    if (actionName) {
      this.targetId = '';
      this.targetElement = null;
      this.targetDisplayElement = null;
      this.actionTarget = {
        actionName,
        fullActionHandler: this._str(btn.getAttribute('data-hotkey-action-full')) || actionName,
        replaceHotkeyRaw: this._str(btn.getAttribute('data-hotkey-current'))
      };
      this.pendingRaw = this.actionTarget.replaceHotkeyRaw;
      this._setDialogTitle(`Assign ${this._humanizeLabel(actionName)}`);
      this._initializeRecorderUI();
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
    this._setDialogTitle(`Assign ${this._resolveTargetTitle(btn, input, targetId)}`);
    this._initializeRecorderUI();
  }

  _setDialogTitle(text) {
    const el = this._el('hotkeyDialogTitle');
    if (el) el.textContent = text || 'Assign Hotkey';
  }

  _resolveTargetTitle(btn, input, targetId) {
    return this._str(btn?.getAttribute('data-hotkey-label'))
      || this._str(input?.closest('.setting-row')?.querySelector('.field-label')?.textContent)
      || this._humanizeLabel(this._str(input?.getAttribute('data-key')))
      || this._humanizeLabel(this._str(targetId || input?.id))
      || 'Hotkey';
  }

  _humanizeLabel(value) {
    const text = this._str(value);
    if (!text) return '';
    return text
      .replace(/[_-]+/g, ' ')
      .replace(/([a-z\d])([A-Z])/g, '$1 $2')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/\b\w/g, (ch) => ch.toUpperCase());
  }

  // --- Recording timer management ---

  _clearRecordTimers() {
    if (this._recordTickTimer) { clearInterval(this._recordTickTimer); this._recordTickTimer = null; }
    if (this._recordStopTimer) { clearTimeout(this._recordStopTimer); this._recordStopTimer = null; }
    this._recordDeadline = 0;
  }

  _getRecordSecondsLeft() {
    if (!this._recordDeadline) return 0;
    return Math.max(0, Math.ceil((this._recordDeadline - Date.now()) / 1000));
  }

  // --- UI state setters ---

  _setRecorderStatus(text, isError = false) {
    const el = this._el('hotkeyRecordHint');
    if (!el) return;
    el.textContent = text || '';
    el.classList.toggle('is-error', !!isError);
  }

  _setSaveEnabled(enabled) {
    const btn = this._el('saveHotkey');
    if (btn) btn.disabled = !enabled;
  }

  _setRecordButtonState() {
    const btn = this._el('hotkeyRecordButton');
    if (!btn) return;
    const seconds = this._getRecordSecondsLeft();
    if (this.recording) {
      btn.textContent = `Stop in ${seconds} second${seconds !== 1 ? 's' : ''}`;
      btn.classList.add('app-btn-danger');
      btn.classList.remove('app-btn-primary');
    } else {
      btn.textContent = 'Record';
      btn.classList.add('app-btn-primary');
      btn.classList.remove('app-btn-danger');
    }
  }

  _setReadableDisplay(raw) {
    const el = this._el('hotkeyRecordReadable');
    if (el) el.textContent = this._humanize(raw);
  }

  // --- Recording lifecycle ---

  _stopRecordingWindow() {
    const wasRecording = this.recording;
    const captured = this._autoWindowCaptured;
    this._stopAhkRecording();
    this._customComboStep = 0;
    this._pendingPrefixKey = '';
    this._clearRecordTimers();
    this._setSaveEnabled(true);
    this._setRecordButtonState();

    this._autoWindowCaptured = false;
    if (!wasRecording && !captured) {
      this._setRecorderStatus('Press Record to capture a hotkey');
    }
  }

  _startRecordingWindow() {
    if (this.recording) { this._stopRecordingWindow(); return; }

    this._clearRecordTimers();
    this._startAhkRecording();

    if (!this.recording) {
      this._setRecorderStatus('Failed to start recording. Try restarting the app.', true);
      this._setRecordButtonState();
      return;
    }

    this._setSaveEnabled(false);
    this._autoWindowCaptured = false;
    this._customComboStep = 0;
    this._pendingPrefixKey = '';
    this._recordDeadline = Date.now() + (this._recordSeconds * 1000);
    this._setRecorderStatus('Recording started. Press your hotkey now.');
    this._setRecordButtonState();

    this._recordTickTimer = setInterval(() => {
      if (!this.recording) { this._clearRecordTimers(); }
      this._setRecordButtonState();
    }, 250);

    this._recordStopTimer = setTimeout(() => this._stopRecordingWindow(), this._recordSeconds * 1000);
  }

  _startAhkRecording() {
    if (this._activeTab === 'manual') { this.recording = false; return; }
    this._stopAhkRecording(false);

    const options = {
      keyboard: true,
      mouse: this._checkedOr('hotkeyOptMouseCapture', true),
      joystick: this._checkedOr('hotkeyOptGamepadCapture', true),
      lrModifiers: this._checkedOr('hotkeyOptLrModifiers', false),
      markOnly: this._checkedOr('hotkeyOptModifiersOnly', false)
    };

    try {
      const result = window.chrome.webview.hostObjects.sync.StartHotkeyRecording(JSON.stringify(options));
      const parsed = (typeof result === 'string') ? JSON.parse(result) : result;
      this.recording = !!parsed?.success;
    } catch (e) {
      console.error('Failed to start AHK hotkey recording', e);
      this.recording = false;
    }
    this._setRecordButtonState();
  }

  _stopAhkRecording(clearAutoWindow = true) {
    try { window.chrome.webview.hostObjects.sync.StopHotkeyRecording(); }
    catch (e) { console.error('Failed to stop AHK hotkey recording', e); }
    this.recording = false;
    if (clearAutoWindow) {
      this._clearRecordTimers();
      this._setSaveEnabled(true);
      this._setRecordButtonState();
    }
  }

  _restartRecordingIfActive() {
    if (!this.recording) return;
    this._startAhkRecording();
    this._setRecordButtonState();
    this._setSaveEnabled(!this.recording);
  }

  // --- AHK hotkey callback ---

  _onAhkHotkeyUpdate(data) {
    if (!this.recording) return;
    const { raw, display } = data;
    if (!raw) return;

    if (this._checked('hotkeyOptUseCustomModifier')) {
      this._handleCustomComboCapture(raw);
      return;
    }

    this._autoWindowCaptured = true;
    const seconds = this._getRecordSecondsLeft();
    const status = (this._activeTab === 'auto' && seconds > 0)
      ? `Captured. ${seconds}s left in recording window.`
      : 'Captured. Press Apply to use it or Record to retry.';
    this._setCapturedDisplay(raw, display, status);
  }

  _handleCustomComboCapture(raw) {
    const key = this._extractBaseKey(raw);
    if (!key) return;

    if (this._customComboStep === 0) {
      this._pendingPrefixKey = key;
      this._customComboStep = 1;
      this._recordDeadline = Date.now() + (this._recordSeconds * 1000);
      this._setRecorderStatus(`Custom Modifier captured: ${AK_HumanizeAhkKeyName(key)}. Now press the another key.`);
      const el = this._el('hotkeyRecordReadable');
      if (el) el.textContent = `${AK_HumanizeAhkKeyName(key)} & ...`;
      return;
    }

    if (key.toLowerCase() === this._pendingPrefixKey.toLowerCase()) {
      this._setRecorderStatus('Second key must differ from the modifier key. Press a different key.', true);
      return;
    }

    const composed = `${this._pendingPrefixKey} & ${key}`;
    this._customComboStep = 0;
    this._pendingPrefixKey = '';
    this._setCapturedDisplay(composed, AK_HumanizeAhkHotkey(composed), 'Custom combination captured. Press Apply to use it or Record to retry.');
    this._stopRecordingWindow();
  }

  _setCapturedDisplay(raw, display, statusText) {
    this.pendingRaw = this._str(raw);
    this._setRecorderStatus(statusText || 'Hotkey captured. Press Apply to save, or Record to capture again.');
    const el = this._el('hotkeyRecordReadable');
    if (el) el.textContent = display || this._humanize(this.pendingRaw);
    this._setManualControlsFromRaw(this.pendingRaw);
    // Don't call _updateManualPreview() here — it would recompose and potentially corrupt pendingRaw
  }

  // --- Recorder UI initialization ---

  _initializeRecorderUI() {
    this._clearRecordTimers();
    this._stopAhkRecording(false);
    this._autoWindowCaptured = false;

    const setChecked = (id, val) => { const el = this._el(id); if (el) el.checked = val; };
    setChecked('hotkeyOptWildcard', this.pendingRaw.includes('*'));
    setChecked('hotkeyOptPassthrough', this.pendingRaw.includes('~'));
    setChecked('hotkeyOptAllowRisky', false);

    this._setRecorderTab('auto', false);

    const clearFilter = (id) => { const el = this._el(id); if (el) el.value = ''; };
    clearFilter('hotkeyManualKeyFilter');
    clearFilter('hotkeyManualPrefixKeyFilter');

    this._syncManualModifierMode();
    this._renderKeyList('hotkeyManualKeyList', 'hotkeyManualKeyFilter');
    this._renderKeyList('hotkeyManualPrefixKeyList', 'hotkeyManualPrefixKeyFilter');
    this._setManualControlsFromRaw(this.pendingRaw);
    this._updateManualPreview();
    this._setReadableDisplay(this.pendingRaw);
    this._setRecorderStatus('Ready to record. Press Record to capture a hotkey');
    this._setSaveEnabled(true);
    this._setRecordButtonState();
    this._updateKeySelectionVisibility();
  }

  // --- Tab management ---

  _setRecorderTab(tabName, manageRecording = true) {
    const wanted = (tabName === 'manual') ? 'manual' : 'auto';
    this._activeTab = wanted;

    document.querySelectorAll('[data-hotkey-tab]').forEach((btn) => {
      const active = btn.getAttribute('data-hotkey-tab') === wanted;
      btn.classList.toggle('is-active', active);
      btn.setAttribute('aria-selected', active ? 'true' : 'false');
    });
    document.querySelectorAll('[data-hotkey-tab-panel]').forEach((panel) => {
      const active = panel.getAttribute('data-hotkey-tab-panel') === wanted;
      panel.classList.toggle('is-active', active);
      panel.hidden = !active;
    });

    if (manageRecording) this._stopRecordingWindow();
    else this._setRecordButtonState();
  }

  // --- Control binding ---

  _checkedOr(id, fallback) {
    const el = this._el(id);
    return el ? el.checked : fallback;
  }

  _bindControls() {
    const bound = new Set();
    const on = (el, event, handler) => {
      if (!el) return;
      const key = `${el.id || el.className}_${event}`;
      if (bound.has(key)) return;
      bound.add(key);
      el.addEventListener(event, handler);
    };

    // Option checkboxes
    const optionHandlers = {
      hotkeyOptLrModifiers: () => { this._syncManualModifierMode(); this._setManualControlsFromRaw(this.pendingRaw); this._updateManualPreview(); },
      hotkeyOptModifiersOnly: () => { this._updateKeySelectionVisibility(); this._updateManualPreview(); },
      hotkeyOptUseCustomModifier: () => { this._updateModifiersVisibility(); this._updatePrefixKeyVisibility(); this._updateManualPreview(); }
    };
    ['hotkeyOptMouseCapture', 'hotkeyOptGamepadCapture', 'hotkeyOptModifiersOnly', 'hotkeyOptLrModifiers', 'hotkeyOptUseCustomModifier'].forEach((id) => {
      on(this._el(id), 'change', () => { optionHandlers[id]?.(); this._restartRecordingIfActive(); });
    });

    // Filters and lists
    on(this._el('hotkeyManualKeyFilter'), 'input', () => { this._renderKeyList('hotkeyManualKeyList', 'hotkeyManualKeyFilter'); this._updateManualPreview(); });
    on(this._el('hotkeyManualKeyList'), 'change', () => this._updateManualPreview());
    on(this._el('hotkeyManualKeyList'), 'dblclick', () => this._applyManualHotkey());
    on(this._el('hotkeyManualPrefixKeyFilter'), 'input', () => { this._renderKeyList('hotkeyManualPrefixKeyList', 'hotkeyManualPrefixKeyFilter'); this._updateManualPreview(); });
    on(this._el('hotkeyManualPrefixKeyList'), 'change', () => this._updateManualPreview());
    on(this._el('hotkeyRecordButton'), 'click', () => this._startRecordingWindow());

    // Modifier buttons
    document.querySelectorAll('.hotkey-mod-btn').forEach((btn) => {
      on(btn, 'click', (ev) => { ev.preventDefault(); btn.classList.toggle('active'); this._updateManualPreview(); });
    });

    // Tab buttons
    document.querySelectorAll('[data-hotkey-tab]').forEach((btn) => {
      on(btn, 'click', () => this._setRecorderTab(this._str(btn.getAttribute('data-hotkey-tab')) || 'auto', true));
    });
  }

  // --- Manual key catalog and list rendering ---

  _buildManualKeyCatalog() {
    const catalog = [];
    const add = (value, label) => catalog.push({ value, label, search: `${value} ${label}`.toLowerCase() });

    for (let i = 65; i <= 90; i++) { const ch = String.fromCharCode(i); add(ch, ch); }
    for (let i = 0; i <= 9; i++) add(`${i}`, `${i}`);
    for (let i = 1; i <= 24; i++) add(`F${i}`, `F${i}`);
    HotkeyRecorderController.KEY_CATALOG_SPECIAL.forEach(([v, l]) => add(v, l));

    return catalog;
  }

  _renderKeyList(listId, filterId) {
    const list = this._el(listId);
    if (!list) return;

    const needle = this._str(this._el(filterId)?.value).toLowerCase();
    const prev = this._str(list.value);
    const filtered = needle
      ? this._manualKeyCatalog.filter((item) => item.search.includes(needle))
      : this._manualKeyCatalog;

    list.innerHTML = '';
    for (const item of filtered) {
      const opt = document.createElement('option');
      opt.value = item.value;
      opt.textContent = item.label;
      list.appendChild(opt);
    }

    if (prev) this._ensureListSelection(list, prev);
  }

  _ensureListSelection(list, value) {
    if (!value) { list.value = ''; return; }
    if (!Array.from(list.options).some((o) => o.value === value)) {
      const opt = document.createElement('option');
      opt.value = value;
      const pretty = typeof AK_HumanizeAhkKeyName === 'function' ? AK_HumanizeAhkKeyName(value) : value;
      opt.textContent = `${pretty} [custom]`;
      opt.dataset.custom = '1';
      list.appendChild(opt);
    }
    list.value = value;
  }

  // --- Manual mode: modifiers and composition ---

  _updateKeySelectionVisibility() {
    const el = this._el('hotkeyKeySelection');
    debugger
    if (el) el.hidden = this._checked('hotkeyOptModifiersOnly');
  }

  _updateModifiersVisibility() {
    const els = [this._el('hotkeyManualModsGeneric'), this._el('hotkeyManualModsLr')].filter(Boolean);
    if (els.length === 0) return;
    const isVisible = !this._checked('hotkeyOptUseCustomModifier');
    if (isVisible) {
      this._syncManualModifierMode();
    } else {
      els.forEach((el) => { el.hidden = !isVisible; el.classList.toggle('hidden', !isVisible); });
    }
  }

  _updatePrefixKeyVisibility() {
    const el = this._el('hotkeyPrefixKeySection');
    if (!el) return;
    const isVisible = this._checked('hotkeyOptUseCustomModifier');
    el.hidden = !isVisible;
    el.classList.toggle('hidden', !isVisible);
  }

  _syncManualModifierMode() {
    const lr = this._lrEnabled();
    const generic = this._el('hotkeyManualModsGeneric');
    const lrBox = this._el('hotkeyManualModsLr');
    if (generic) { generic.classList.toggle('hidden', lr); generic.hidden = lr; }
    if (lrBox) { lrBox.classList.toggle('hidden', !lr); lrBox.hidden = !lr; }
  }

  _clearManualModifiers() {
    document.querySelectorAll('.hotkey-mod-btn').forEach((btn) => btn.classList.remove('active'));
  }

  _setManualControlsFromRaw(rawHotkey) {
    this._clearManualModifiers();
    const parsed = this._parseHotkey(rawHotkey);
    const lr = this._lrEnabled();

    const customCombo = this._el('hotkeyOptUseCustomModifier');
    if (customCombo) customCombo.checked = !!parsed.prefixKey;
    this._updatePrefixKeyVisibility();

    const tokenMap = lr ? HotkeyRecorderController.MOD_TOKENS_LR : HotkeyRecorderController.MOD_TOKENS_GENERIC;
    if (!parsed.prefixKey) {
      for (const token of parsed.modifiers) {
        const modName = tokenMap[token];
        if (!modName) continue;
        const btn = document.querySelector(`.hotkey-mod-btn[data-mod="${modName}"]`);
        if (btn) btn.classList.add('active');
      }
    }

    this._ensureListSelection(this._el('hotkeyManualKeyList'), parsed.key);
    this._ensureListSelection(this._el('hotkeyManualPrefixKeyList'), parsed.prefixKey);
  }

  _collectManualModifiers() {
    const lr = this._lrEnabled();
    const modToToken = lr ? HotkeyRecorderController.MOD_TO_TOKEN_LR : HotkeyRecorderController.MOD_TO_TOKEN_GENERIC;
    const box = this._el(lr ? 'hotkeyManualModsLr' : 'hotkeyManualModsGeneric');
    if (!box) return '';

    const parts = [];
    box.querySelectorAll('.hotkey-mod-btn.active').forEach((btn) => {
      const token = modToToken[btn.getAttribute('data-mod')];
      if (token) parts.push(token);
    });
    return parts.join('');
  }

  _composeManualRaw() {
    if (this._checked('hotkeyOptUseCustomModifier')) {
      const prefix = this._str(this._el('hotkeyManualPrefixKeyList')?.value);
      const key = this._str(this._el('hotkeyManualKeyList')?.value);
      if (prefix && key && prefix.toLowerCase() === key.toLowerCase()) return '';
      return (prefix && key) ? `${prefix} & ${key}` : '';
    }

    const mods = this._collectManualModifiers();
    const key = this._str(this._el('hotkeyManualKeyList')?.value);
    if (!key) return this._checked('hotkeyOptModifiersOnly') ? mods : '';
    return `${mods}${key}`;
  }

  _updateManualPreview() {
    this.pendingRaw = this._composeManualRaw();
    this._setReadableDisplay(this.pendingRaw);
  }

  _applyManualHotkey() {
    const raw = this._composeManualRaw();
    if (!raw) return;
    this._setCapturedDisplay(raw, AK_HumanizeAhkHotkey(raw), 'Composed manually. Press Apply to save or keep editing.');
  }

  // --- Hotkey parsing ---

  _parseHotkey(rawHotkey) {
    let input = this._str(rawHotkey).replace(/[*~$]/g, '');
    const modifiers = [];
    let i = 0;

    while (i < input.length) {
      const two = input.slice(i, i + 2);
      if (['<^', '>^', '<!', '>!', '<+', '>+', '<#', '>#'].includes(two)) {
        modifiers.push(two); i += 2; continue;
      }
      if ('^!+#'.includes(input[i])) {
        modifiers.push(input[i]); i += 1; continue;
      }
      break;
    }

    const remaining = input.slice(i).trim();
    const parts = remaining.split(/\s*&\s*/).filter(Boolean);
    return {
      modifiers,
      key: parts.length >= 2 ? parts.slice(1).join(' & ') : remaining,
      prefixKey: parts.length >= 2 ? parts[0] : ''
    };
  }

  _extractBaseKey(rawHotkey) {
    return this._str(this._parseHotkey(rawHotkey)?.key);
  }

  // --- Apply ---

  apply() {
    if (this.recording) {
      this._setRecorderStatus('Recording is active. Wait for countdown to finish or press Stop.', true);
      return false;
    }

    let finalHotkey = this.pendingRaw;
    if (this._checked('hotkeyOptWildcard') && !finalHotkey.startsWith('*')) finalHotkey = '*' + finalHotkey;
    if (this._checked('hotkeyOptPassthrough') && !finalHotkey.startsWith('~')) finalHotkey = '~' + finalHotkey;
    finalHotkey = this._str(finalHotkey);

    if (!finalHotkey) {
      this._setRecorderStatus('No hotkey selected. Record or compose one first.', true);
      return false;
    }

    const allowRisky = this._checked('hotkeyOptAllowRisky');
    const baseKey = this._extractBaseKey(finalHotkey);
    if (!allowRisky && HotkeyRecorderController.RISKY_KEYS.has(baseKey.toUpperCase())) {
      this._setRecorderStatus('This hotkey is risky (Esc, Enter, Mouse Left/Right). Enable "Allow risky hotkeys" to use it.', true);
      return false;
    }

    if (this.actionTarget) return this._applyToAction(finalHotkey, allowRisky);
    return this._applyToField(finalHotkey);
  }

  _applyToAction(finalHotkey, allowRisky) {
    this._stopAhkRecording();
    if (typeof this.onActionHotkeyApplied !== 'function') {
      this._setRecorderStatus('Unable to save action hotkey: callback is missing.', true);
      return false;
    }

    const { actionName, replaceHotkeyRaw, fullActionHandler } = this.actionTarget;
    const result = this.onActionHotkeyApplied(actionName, finalHotkey, replaceHotkeyRaw || '', allowRisky, fullActionHandler || actionName)
      || { ok: false, error: 'Failed to save hotkey' };

    if (!result?.ok) {
      this._setRecorderStatus(result?.error || 'Failed to save hotkey.', true);
      return false;
    }
    return true;
  }

  _applyToField(finalHotkey) {
    const input = this.targetElement || this.dom.getField(this.targetId);
    if (!input) {
      this._setRecorderStatus('Target field was not found.', true);
      return false;
    }

    input.value = finalHotkey;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    this._stopAhkRecording();

    if (this.targetId) this.updatePreview(this.targetId);
    else this._updateElementPreview(input, this.targetDisplayElement);
    return true;
  }

  // --- Preview helpers ---

  updatePreview(inputId) {
    const input = this.dom.getField(inputId);
    if (!input) return;
    const display = this._resolveDisplayElement(input) || this.dom.getField(inputId + 'Display');
    const txt = (input.value || '').trim();
    this._setDisplayText(display, txt ? AK_HumanizeAhkHotkey(txt) : '');
  }

  updatePluginPreviews() {
    document.querySelectorAll('.plugin-field-hotkey').forEach((input) => {
      this._updateElementPreview(input, this._resolveDisplayElement(input));
    });
  }

  _resolveDisplayElement(input) {
    if (!input) return null;
    const displayKey = input.getAttribute('data-display-for-plugin-hotkey');
    if (displayKey) return document.querySelector(`[data-plugin-hotkey-display="${displayKey}"]`);
    const id = input.id || '';
    return id ? document.querySelector(`[data-hotkey-display-for="${id}"]`) : null;
  }

  _setDisplayText(display, readable) {
    if (!display) return;
    const text = readable || 'Assign hotkey';
    if (display instanceof HTMLInputElement || display instanceof HTMLTextAreaElement) {
      display.value = readable || '';
      return;
    }
    const label = display.querySelector('.hotkey-badge-label');
    if (label) label.textContent = text;
    else display.textContent = text;
    display.classList.toggle('is-empty', !readable);
  }

  _updateElementPreview(input, display) {
    if (!input || !display) return;
    const txt = (input.value || '').trim();
    this._setDisplayText(display, txt ? AK_HumanizeAhkHotkey(txt) : '');
  }

  // --- Close/Cancel ---

  cancel() { this._stopAhkRecording(); }
  close() { this._stopAhkRecording(); }
}
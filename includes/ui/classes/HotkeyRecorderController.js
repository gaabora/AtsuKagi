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
    this._activeTab = 'auto';
    this._autoRecordSeconds = 5;
    this._autoRecordDeadline = 0;
    this._autoRecordTickTimer = null;
    this._autoRecordStopTimer = null;
    this._autoWindowCaptured = false;
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

  _clearAutoRecordTimers() {
    if (this._autoRecordTickTimer) {
      clearInterval(this._autoRecordTickTimer);
      this._autoRecordTickTimer = null;
    }
    if (this._autoRecordStopTimer) {
      clearTimeout(this._autoRecordStopTimer);
      this._autoRecordStopTimer = null;
    }
    this._autoRecordDeadline = 0;
  }

  _getAutoRecordSecondsLeft() {
    if (!this._autoRecordDeadline) return 0;
    return Math.max(0, Math.ceil((this._autoRecordDeadline - Date.now()) / 1000));
  }

  _setRecorderStatus(text, isError = false) {
    const statusEl = document.getElementById('hotkeyRecordStatus');
    if (!statusEl) return;
    statusEl.textContent = text || '';
    statusEl.classList.toggle('is-error', !!isError);
  }

  _setAutoHint(text) {
    const hintEl = document.getElementById('hotkeyAutoRecordHint');
    if (hintEl) {
      hintEl.textContent = text || '';
    }
  }

  _setApplyEnabled(enabled) {
    const applyBtn = document.getElementById('apply-hotkey-record');
    if (applyBtn) {
      applyBtn.disabled = !enabled;
    }
  }

  _setAutoRecordButtonState() {
    const btn = document.getElementById('hotkeyAutoRecordButton');
    if (!btn) return;
    const seconds = this._getAutoRecordSecondsLeft();
    const text = (this.recording && this._activeTab === 'auto')
      ? `Stop (${Math.max(1, seconds)}s)`
      : `Record (${this._autoRecordSeconds}s)`;
    const labelNode = btn.querySelector('span');
    if (labelNode) {
      labelNode.textContent = text;
    } else {
      btn.textContent = text;
    }
    btn.classList.toggle('is-recording', this.recording && this._activeTab === 'auto');
  }

  _stopAutoRecordingWindow(reason = 'timeout') {
    const wasRecording = this.recording;
    const capturedInWindow = this._autoWindowCaptured;
    this._stopAhkRecording();
    this._clearAutoRecordTimers();
    this._setApplyEnabled(true);
    this._setAutoRecordButtonState();

    if (!wasRecording) {
      this._autoWindowCaptured = false;
      this._setRecorderStatus('Auto mode: press Record to capture a hotkey (5 seconds).');
      this._setAutoHint('Press Record to listen for 5 seconds.');
      return;
    }

    if (reason === 'manual-stop') {
      this._setRecorderStatus(capturedInWindow
        ? 'Recording stopped. Press Apply to save, or Record to try again.'
        : 'Recording stopped with no new capture. Press Record to try again.');
      this._setAutoHint('Press Record to start another 5-second capture window.');
      this._autoWindowCaptured = false;
      return;
    }

    this._setRecorderStatus(capturedInWindow
      ? 'Capture window ended. Press Apply to save, or Record to try again.'
      : 'No hotkey captured in 5 seconds. Press Record to try again.');
    this._setAutoHint('Press Record to start another 5-second capture window.');
    this._autoWindowCaptured = false;
  }

  _startAutoRecordingWindow() {
    if (this._activeTab !== 'auto') {
      this._setRecorderStatus('Switch to Auto tab to start timed recording.', true);
      return;
    }

    if (this.recording) {
      this._stopAutoRecordingWindow('manual-stop');
      return;
    }

    this._clearAutoRecordTimers();
    this._startAhkRecording();

    if (!this.recording) {
      this._setRecorderStatus('Failed to start recording. Check host bridge.', true);
      this._setAutoHint('Recording failed. Try again.');
      this._setAutoRecordButtonState();
      return;
    }

    this._setApplyEnabled(false);
    this._autoWindowCaptured = false;
    this._autoRecordDeadline = Date.now() + (this._autoRecordSeconds * 1000);
    this._setRecorderStatus(`Recording... ${this._autoRecordSeconds}s left.`);
    this._setAutoHint('Press keys now. Recording stops automatically after 5 seconds.');
    this._setAutoRecordButtonState();

    this._autoRecordTickTimer = setInterval(() => {
      if (!this.recording) {
        this._clearAutoRecordTimers();
        this._setAutoRecordButtonState();
        return;
      }

      const seconds = this._getAutoRecordSecondsLeft();
      if (seconds <= 0) return;
      this._setRecorderStatus(this._autoWindowCaptured
        ? `Captured. ${seconds}s left in recording window.`
        : `Recording... ${seconds}s left.`);
      this._setAutoRecordButtonState();
    }, 250);

    this._autoRecordStopTimer = setTimeout(() => {
      this._stopAutoRecordingWindow('timeout');
    }, this._autoRecordSeconds * 1000);
  }

  _initializeRecorderUI() {
    this._clearAutoRecordTimers();
    this._stopAhkRecording(false);
    this._autoWindowCaptured = false;

    const optWildcard = document.getElementById('hotkeyOptWildcard');
    const optPassthrough = document.getElementById('hotkeyOptPassthrough');
    const optAllowRisky = document.getElementById('hotkeyOptAllowRisky');
    if (optWildcard) {
      optWildcard.checked = this.pendingRaw.indexOf('*') !== -1;
    }
    if (optPassthrough) {
      optPassthrough.checked = this.pendingRaw.indexOf('~') !== -1;
    }
    if (optAllowRisky) {
      optAllowRisky.checked = false;
    }

    this._setRecorderTab('auto', false);

    const manualFilter = document.getElementById('hotkeyManualKeyFilter');
    if (manualFilter) {
      manualFilter.value = '';
    }

    this._syncManualModifierMode();
    this._renderManualKeyList();
    this._setManualControlsFromRaw(this.pendingRaw);
    this._updateManualPreview();

    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (valueEl) {
      valueEl.textContent = this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(none)';
    }

    this._setRecorderStatus('Auto mode: press Record to capture a hotkey (5 seconds).');
    this._setAutoHint('Listening for input...');
    this._setApplyEnabled(true);
    this._setAutoRecordButtonState();
    this._updateKeySelectionVisibility();
    this._updateAdvancedOptionsVisibility();
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
        if (id === 'hotkeyOptModifiersOnly') {
          this._updateKeySelectionVisibility();
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

    const recordBtn = document.getElementById('hotkeyAutoRecordButton');
    bindOnce(recordBtn, 'boundHotkeyAutoRecord', 'click', () => this._startAutoRecordingWindow());

    // Bind modifier buttons
    document.querySelectorAll('.hotkey-mod-btn').forEach((btn, idx) => {
      bindOnce(btn, `boundModBtn${idx}`, 'click', (ev) => {
        ev.preventDefault();
        btn.classList.toggle('active');
        this._updateManualPreview();
      });
    });

    // Tab switching
    document.querySelectorAll('[data-hotkey-tab]').forEach((tabBtn, idx) => {
      bindOnce(tabBtn, `boundHotkeyTab${idx}`, 'click', () => {
        const tabName = `${tabBtn.getAttribute('data-hotkey-tab') || 'auto'}`.trim();
        this._setRecorderTab(tabName, true);
        this._updateAdvancedOptionsVisibility();
      });
    });
  }

  _setRecorderTab(tabName, manageRecording = true) {
    const wanted = (tabName === 'manual') ? 'manual' : 'auto';
    this._activeTab = wanted;

    document.querySelectorAll('[data-hotkey-tab]').forEach((tabBtn) => {
      const isActive = `${tabBtn.getAttribute('data-hotkey-tab') || ''}` === wanted;
      tabBtn.classList.toggle('is-active', isActive);
      tabBtn.setAttribute('aria-selected', isActive ? 'true' : 'false');
    });

    document.querySelectorAll('[data-hotkey-tab-panel]').forEach((panel) => {
      const isActive = `${panel.getAttribute('data-hotkey-tab-panel') || ''}` === wanted;
      panel.classList.toggle('is-active', isActive);
      panel.hidden = !isActive;
    });

    if (!manageRecording) {
      this._setAutoRecordButtonState();
      return;
    }

    if (wanted === 'manual') {
      this._stopAutoRecordingWindow('manual-stop');
      this._setRecorderStatus('Manual mode selected. Build a hotkey below.');
      return;
    }

    if (this.recording) {
      const seconds = this._getAutoRecordSecondsLeft();
      this._setRecorderStatus(`Recording... ${Math.max(1, seconds)}s left.`);
      this._setAutoHint('Press keys now. Recording stops automatically after 5 seconds.');
      this._setApplyEnabled(false);
    } else {
      this._setRecorderStatus('Auto mode: press Record to capture a hotkey (5 seconds).');
      this._setAutoHint('Listening for input...');
      this._setApplyEnabled(true);
    }
    this._setAutoRecordButtonState();
    this._updateAdvancedOptionsVisibility();
  }

  _updateAdvancedOptionsVisibility() {
    const autoSection = document.getElementById('hotkeyAdvancedAuto');
    const manualSection = document.getElementById('hotkeyAdvancedManual');
    if (autoSection) autoSection.hidden = this._activeTab !== 'auto';
    if (manualSection) manualSection.hidden = this._activeTab !== 'manual';
  }

  _updateKeySelectionVisibility() {
    const keySelection = document.getElementById('hotkeyKeySelection');
    const modifiersOnly = document.getElementById('hotkeyOptModifiersOnly')?.checked || false;
    if (keySelection) {
      keySelection.hidden = modifiersOnly;
    }
  }

  _restartRecordingIfActive() {
    if (!this.recording) return;
    this._startAhkRecording();
    if (this.recording && this._activeTab === 'auto') {
      const seconds = this._getAutoRecordSecondsLeft();
      this._setRecorderStatus(`Recording... ${Math.max(1, seconds)}s left.`);
      this._setAutoRecordButtonState();
    }
  }

  _startAhkRecording() {
    if (this._activeTab === 'manual') {
      this.recording = false;
      return;
    }

    this._stopAhkRecording(false);

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
      this._setAutoRecordButtonState();
    } catch (error) {
      console.error('Failed to start AHK hotkey recording', error);
      this.recording = false;
      this._setAutoRecordButtonState();
    }
  }

  _onAhkHotkeyUpdate(data) {
    if (!this.recording) return;

    const { raw, display } = data;
    if (!raw) return;

    this._autoWindowCaptured = true;

    const seconds = this._getAutoRecordSecondsLeft();
    const statusText = (this._activeTab === 'auto' && seconds > 0)
      ? `Captured. ${seconds}s left in recording window.`
      : 'Captured. Press Apply to use it or Record to retry.';

    this._setCapturedDisplay(raw, display, statusText);
  }

  _setCapturedDisplay(raw, display, statusText) {
    this.pendingRaw = `${raw || ''}`.trim();

    const valueEl = document.getElementById('hotkeyRecordReadable');
    this._setRecorderStatus(statusText || 'Captured.');
    if (valueEl) {
      valueEl.textContent = display || (this.pendingRaw ? AK_HumanizeAhkHotkey(this.pendingRaw) : '(none)');
    }

    this._setManualControlsFromRaw(this.pendingRaw);
    this._updateManualPreview();
  }

  _stopAhkRecording(clearAutoWindow = true) {
    try {
      window.chrome.webview.hostObjects.sync.StopHotkeyRecording();
    } catch (error) {
      console.error('Failed to stop AHK hotkey recording', error);
    }
    this.recording = false;
    if (clearAutoWindow) {
      this._clearAutoRecordTimers();
      this._setApplyEnabled(true);
      this._setAutoRecordButtonState();
    }
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
      genericBox.classList.toggle('hidden', lrEnabled);
      genericBox.hidden = lrEnabled;
    }
    if (lrBox) {
      lrBox.classList.toggle('hidden', !lrEnabled);
      lrBox.hidden = !lrEnabled;
    }
  }

  _clearManualModifiers() {
    document.querySelectorAll('.hotkey-mod-btn').forEach((btn) => {
      btn.classList.remove('active');
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

    const tokenToModLr = {
      '<^': 'LCtrl', '>^': 'RCtrl',
      '<!': 'LAlt', '>!': 'RAlt',
      '<+': 'LShift', '>+': 'RShift',
      '<#': 'LWin', '>#': 'RWin',
      '^': 'LCtrl', '!': 'LAlt',
      '+': 'LShift', '#': 'LWin'
    };

    const tokenToModGeneric = {
      '<^': 'Ctrl', '>^': 'Ctrl',
      '<!': 'Alt', '>!': 'Alt',
      '<+': 'Shift', '>+': 'Shift',
      '<#': 'Win', '>#': 'Win',
      '^': 'Ctrl', '!': 'Alt',
      '+': 'Shift', '#': 'Win'
    };

    const tokenToMod = lrEnabled ? tokenToModLr : tokenToModGeneric;

    parsed.modifiers.forEach((token) => {
      const modName = tokenToMod[token];
      if (!modName) return;
      const btn = document.querySelector(`.hotkey-mod-btn[data-mod="${modName}"]`);
      if (btn) btn.classList.add('active');
    });

    this._setManualKeySelection(parsed.key);
  }

  _collectManualModifiers() {
    const lrEnabled = document.getElementById('hotkeyOptLrModifiers')?.checked || false;

    const modToTokenLr = {
      'LCtrl': '<^', 'RCtrl': '>^',
      'LAlt': '<!', 'RAlt': '>!',
      'LShift': '<+', 'RShift': '>+',
      'LWin': '<#', 'RWin': '>#'
    };

    const modToTokenGeneric = {
      'Ctrl': '^', 'Alt': '!',
      'Shift': '+', 'Win': '#'
    };

    const modToToken = lrEnabled ? modToTokenLr : modToTokenGeneric;
    const parts = [];

    const relevantBox = lrEnabled
      ? document.getElementById('hotkeyManualModsLr')
      : document.getElementById('hotkeyManualModsGeneric');

    if (relevantBox) {
      relevantBox.querySelectorAll('.hotkey-mod-btn.active').forEach((btn) => {
        const modName = btn.getAttribute('data-mod');
        const token = modToToken[modName];
        if (token) parts.push(token);
      });
    }

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
    const raw = this._composeManualRaw();
    this.pendingRaw = raw;

    const valueEl = document.getElementById('hotkeyRecordReadable');
    if (valueEl) {
      valueEl.textContent = raw ? AK_HumanizeAhkHotkey(raw) : '(none)';
    }
  }

  _extractBaseHotkeyKey(rawHotkey) {
    const parsed = this._parseHotkey(rawHotkey);
    return `${parsed?.key || ''}`.trim();
  }

  _isRiskyBaseKey(keyName) {
    const key = `${keyName || ''}`.trim().toUpperCase();
    if (!key) return false;

    const riskyKeys = new Set([
      'ESC',
      'ENTER',
      'LBUTTON',
      'RBUTTON'
    ]);

    return riskyKeys.has(key);
  }

  _applyManualHotkey() {
    const raw = this._composeManualRaw();
    if (!raw) {
      this._setRecorderStatus('Manual mode: choose a key (or enable Modifiers-only and choose modifiers).', true);
      return;
    }

    this._setCapturedDisplay(
      raw,
      AK_HumanizeAhkHotkey(raw),
      'Composed manually. Press Apply to save or keep editing.'
    );
  }

  apply() {
    if (this.recording) {
      this._setRecorderStatus('Recording is active. Wait for countdown to finish or press Stop.', true);
      return false;
    }

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

    finalHotkey = `${finalHotkey || ''}`.trim();
    if (!finalHotkey) {
      this._setRecorderStatus('No hotkey selected. Record or compose one first.', true);
      return false;
    }

    const allowRiskyHotkeys = document.getElementById('hotkeyOptAllowRisky')?.checked || false;
    const baseKey = this._extractBaseHotkeyKey(finalHotkey);
    if (!allowRiskyHotkeys && this._isRiskyBaseKey(baseKey)) {
      this._setRecorderStatus('This hotkey is risky (Esc, Enter, Mouse Left/Right). Enable "Allow risky hotkeys" to use it.', true);
      return false;
    }

    if (this.actionTarget) {
      this._stopAhkRecording();
      if (typeof this.onActionHotkeyApplied !== 'function') {
        this._setRecorderStatus('Unable to save action hotkey: callback is missing.', true);
        return false;
      }

      const result = this.onActionHotkeyApplied(
        this.actionTarget.actionName,
        finalHotkey,
        this.actionTarget.replaceHotkeyRaw || '',
        allowRiskyHotkeys
      ) || { ok: false, error: 'Failed to save hotkey' };

      if (!result?.ok) {
        this._setRecorderStatus(result?.error || 'Failed to save hotkey.', true);
        return false;
      }

      return true;
    }

    const input = this.targetElement || this.dom.getField(this.targetId);
    if (!input) {
      this._setRecorderStatus('Target field was not found.', true);
      return false;
    }

    input.value = finalHotkey;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    this._stopAhkRecording();
    if (this.targetId) {
      this.updatePreview(this.targetId);
    } else {
      this._updateElementPreview(input, this.targetDisplayElement);
    }

    return true;
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
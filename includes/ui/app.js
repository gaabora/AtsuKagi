
function getAhkHost() {
    try {
    if (window.chrome && window.chrome.webview && window.chrome.webview.hostObjects)
        return window.chrome.webview.hostObjects.sync;
    } catch (_) {}
    return null;
}

const ahk = {
    SettingsSave: function () {
    var host = getAhkHost();
    if (!host || typeof host.SettingsSave !== 'function') return;

    function v(id) {
        var el = document.getElementById(id);
        return el ? (el.value || '') : '';
    }

    function checked(id) {
        var el = document.getElementById(id);
        return !!(el && el.checked);
    }

    var disabled = [];
    var pluginCheckboxes = document.querySelectorAll('#plugins-list input[type="checkbox"][id^="plugin_"]');
    for (var i = 0; i < pluginCheckboxes.length; i++) {
        var cb = pluginCheckboxes[i];
        if (!cb.checked)
        disabled.push(cb.id.substring(7));
    }

    host.SettingsSave(
        v('WelcomeMessage'),
        v('DarkTheme'),
        v('ToolTipTimeoutMs'),
        v('WindowTransparencyValue'),
        v('WindowOnTopBorderColor'),
        v('StartupSound'),
        v('NotificationSound'),
        v('ReloadAppHotkey'),
        v('SuspendAppHotkey'),
        checked('SwapMouseXButtons') ? 'true' : 'false',
        disabled.join(',')
    );
    },
    SettingsCancel: function () {
    var host = getAhkHost();
    if (host && typeof host.SettingsCancel === 'function')
        host.SettingsCancel();
    },
    BrowseForFile: function (currentPath) {
    var host = getAhkHost();
    if (!host || typeof host.BrowseForFile !== 'function')
        return '';
    return host.BrowseForFile(currentPath || '');
    },
    gui: {
    Minimize: function () {
        var host = getAhkHost();
        if (host && host.gui && typeof host.gui.Minimize === 'function')
        host.gui.Minimize();
    }
    }
};

var settingsUiState = {
    syncBorderColorPreview: function () {}
};

window.SettingsUiBridge = {
    refreshFromConfig: function () {
    updateSlider();
    settingsUiState.syncBorderColorPreview();
    updateHotkeyPreview('ReloadAppHotkey');
    updateHotkeyPreview('SuspendAppHotkey');
    }
};

function showSection(name, navEl) {
    var sections = document.querySelectorAll('.settings-section');
    for (var i = 0; i < sections.length; i++)
    sections[i].classList.remove('active');

    var navItems = document.querySelectorAll('.nav-item');
    for (var j = 0; j < navItems.length; j++)
    navItems[j].classList.remove('active');

    var target = document.getElementById('section-' + name);
    if (target) target.classList.add('active');
    if (navEl) navEl.classList.add('active');
}

function updateSlider() {
    var slider = document.getElementById('WindowTransparencyValue');
    var sliderLabel = document.getElementById('WindowTransparencyLabel');
    if (!slider || !sliderLabel) return;

    sliderLabel.textContent = slider.value;
    var pct = (slider.value / 255) * 100;
    slider.style.background = 'linear-gradient(90deg, var(--color-primary-adaptive, #0078D7) ' + pct + '%, #999 ' + (pct + 0.1) + '%)';
}

function wireFilePicker(textInputId, browseBtnId, fileInputId) {
    var txt = document.getElementById(textInputId);
    var btn = document.getElementById(browseBtnId);
    var picker = document.getElementById(fileInputId);
    if (!txt || !btn || !picker) return;

    btn.addEventListener('click', function () {
    var selected = ahk.BrowseForFile(txt.value || '');
    if (selected) {
        txt.value = selected;
        txt.title = selected;
    }
    });

    picker.addEventListener('change', function () {
    if (picker.files && picker.files.length > 0)
        txt.value = picker.files[0].name;
        txt.title = picker.files[0].name;
    });
}

function toAhkHex(r, g, b) {
    function toHex(v) {
    var h = Math.max(0, Math.min(255, v | 0)).toString(16).toUpperCase();
    return h.length === 1 ? '0' + h : h;
    }
    return '0x' + toHex(r) + toHex(g) + toHex(b);
}

function normalizeHex6(value) {
    var txt = (value || '').trim();
    if (txt.length >= 2) {
    var first = txt.charAt(0);
    var last = txt.charAt(txt.length - 1);
    if ((first === '"' && last === '"') || (first === "'" && last === "'"))
        txt = txt.slice(1, -1).trim();
    }
    if (txt.charAt(0) === '#')
    txt = txt.slice(1);
    var m = /^(?:0[xX])?([0-9A-Fa-f]{6})$/.exec(txt);
    return m ? m[1].toUpperCase() : '';
}

function parseAhkHexColor(value) {
    var hex = normalizeHex6(value);
    if (!hex) return null;
    return [
    parseInt(hex.slice(0, 2), 16),
    parseInt(hex.slice(2, 4), 16),
    parseInt(hex.slice(4, 6), 16)
    ];
}

function toCssColor(value) {
    var hex = normalizeHex6(value);
    return hex ? ('#' + hex) : '#ffffff';
}

function toAhkHotkey(ev, wildcard, passthrough) {
    var key = ev.key;
    if (!key) return '';
    if (key === 'Control' || key === 'Shift' || key === 'Alt' || key === 'Meta') return '';

    var prefix = '';
    if (wildcard) prefix += '*';
    if (passthrough) prefix += '~';
    if (ev.ctrlKey) prefix += '^';
    if (ev.altKey) prefix += '!';
    if (ev.shiftKey) prefix += '+';
    if (ev.metaKey) prefix += '#';

    var keyMap = {
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

    var keyName = keyMap[key] || key;
    if (keyName.length === 1) keyName = keyName.toUpperCase();
    return prefix + keyName;
}

function humanizeAhkHotkey(hk) {
    if (!hk) return '';
    var input = hk;
    var labels = [];

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

    var key = input.trim();
    if (key) labels.push(key);
    return labels.join(' + ');
}

function updateHotkeyPreview(inputId) {
    var input = document.getElementById(inputId);
    var display = document.getElementById(inputId + 'Display');
    if (!input) return;

    var txt = (input.value || '').trim();
    var readable = txt ? humanizeAhkHotkey(txt) : '';
    if (display) display.value = readable;
}

function initColorPickerDialog() {
    var colorInput = document.getElementById('WindowOnTopBorderColor');
    var toggleBtn = document.getElementById('toggleBorderColorPicker');
    var dialogHex = document.getElementById('DialogColorHex');
    var dialogRgb = document.getElementById('DialogColorRgb');
    var dialogLch = document.getElementById('DialogColorLch');
    var dialogPreview = document.getElementById('DialogColorPreview');
    var smallSwatch = document.getElementById('BorderColorSwatch');
    var applyBtn = document.getElementById('applyColorPicker');
    var cancelBtn = document.getElementById('cancelColorPicker');
    var container = document.getElementById('my-color-picker-container');
    if (!colorInput || !toggleBtn || !dialogHex || !applyBtn || !cancelBtn || !container)
    return;

    function setMainSwatch(hexLike) {
    if (smallSwatch)
        smallSwatch.style.background = toCssColor(hexLike);
    }

    function syncMainSwatchFromInput() {
    setMainSwatch(colorInput.value);
    }

    settingsUiState.syncBorderColorPreview = syncMainSwatchFromInput;

    if (!window.LchColorWheel) {
    toggleBtn.disabled = true;
    syncMainSwatchFromInput();
    return;
    }

    var colorWheel = new LchColorWheel({
    appendTo: container,
    wheelDiameter: 300,
    wheelThickness: 30,
    handleDiameter: 22,
    drawsRgbValidityBoundary: false,
    onChange: function () {
        var hex = toAhkHex(colorWheel.rgb[0], colorWheel.rgb[1], colorWheel.rgb[2]);
        dialogHex.value = hex;
        dialogRgb.value = colorWheel.rgb.map(function (v) { return Math.round(v); }).join(', ');
        dialogLch.value = colorWheel.lch.map(function (v) { return Math.round(v * 10) / 10; }).join(', ');
        if (dialogPreview)
        dialogPreview.style.background = toCssColor(hex);
    }
    });

    function syncFromInput() {
    var parsed = parseAhkHexColor(colorInput.value);
    if (parsed) {
        colorWheel.rgb = parsed;
        colorWheel.redraw();
        if (dialogPreview)
        dialogPreview.style.background = toCssColor(colorInput.value);
    } else if (dialogPreview) {
        dialogPreview.style.background = '#ffffff';
    }
    }

    toggleBtn.addEventListener('click', function () {
    syncFromInput();
    });

    dialogHex.addEventListener('input', function () {
    if (dialogPreview)
        dialogPreview.style.background = toCssColor(dialogHex.value);
    });

    dialogHex.addEventListener('change', function () {
    var parsed = parseAhkHexColor(dialogHex.value);
    if (!parsed) return;
    colorWheel.rgb = parsed;
    colorWheel.redraw();
    });

    applyBtn.addEventListener('click', function () {
    var hex6 = normalizeHex6(dialogHex.value);
    if (hex6)
        colorInput.value = '0x' + hex6;
    setMainSwatch(colorInput.value);
    cancelBtn.click();
    });

    colorInput.addEventListener('change', syncMainSwatchFromInput);
    colorInput.addEventListener('input', syncMainSwatchFromInput);
    syncMainSwatchFromInput();
}

function initHotkeyRecorderDialog() {
    var state = {
    targetId: '',
    pendingRaw: '',
    recording: false
    };

    var title = document.getElementById('hotkeyDialogTitle');
    var optWildcard = document.getElementById('hotkeyOptWildcard');
    var optPassthrough = document.getElementById('hotkeyOptPassthrough');
    var statusEl = document.getElementById('hotkeyRecordStatus');
    var valueEl = document.getElementById('hotkeyRecordReadable');
    var applyBtn = document.getElementById('applyHotkeyRecord');
    var cancelBtn = document.getElementById('cancelHotkeyRecord');
    if (!title || !optWildcard || !optPassthrough || !statusEl || !valueEl || !applyBtn || !cancelBtn)
    return;

    function stopRecording() {
    state.recording = false;
    document.removeEventListener('keydown', onRecordKey, true);
    }

    function onRecordKey(ev) {
    if (!state.recording) return;
    ev.preventDefault();
    ev.stopPropagation();
    var raw = toAhkHotkey(ev, optWildcard.checked, optPassthrough.checked);
    if (!raw) return;
    state.pendingRaw = raw;
    valueEl.textContent = humanizeAhkHotkey(raw);
    statusEl.textContent = 'Captured. Press Apply to use it or keep pressing keys to change.';
    }

    var recordButtons = document.querySelectorAll('[data-hotkey-target]');
    for (var i = 0; i < recordButtons.length; i++) {
    (function (btn) {
        btn.addEventListener('click', function () {
        var targetId = btn.getAttribute('data-hotkey-target');
        var input = document.getElementById(targetId);
        if (!input) return;

        state.targetId = targetId;
        state.pendingRaw = input.value || '';
        optWildcard.checked = state.pendingRaw.indexOf('*') !== -1;
        optPassthrough.checked = state.pendingRaw.indexOf('~') !== -1;
        title.textContent = 'Record Hotkey';
        valueEl.textContent = state.pendingRaw ? humanizeAhkHotkey(state.pendingRaw) : '(listening...)';
        statusEl.textContent = 'Recording... press a key combination.';
        stopRecording();
        state.recording = true;
        document.addEventListener('keydown', onRecordKey, true);
        });
    })(recordButtons[i]);
    }

    applyBtn.addEventListener('click', function () {
    if (!state.targetId || !state.pendingRaw) return;
    var input = document.getElementById(state.targetId);
    if (!input) return;

    input.value = state.pendingRaw;
    input.dispatchEvent(new Event('input'));
    stopRecording();
    cancelBtn.click();
    });

    cancelBtn.addEventListener('click', stopRecording);
}

(function initPage() {
    var slider = document.getElementById('WindowTransparencyValue');
    if (slider) {
    slider.oninput = updateSlider;
    slider.onchange = updateSlider;
    }
    updateSlider();

    wireFilePicker('StartupSound', 'browseStartupSound', 'StartupSoundFile');
    wireFilePicker('NotificationSound', 'browseNotificationSound', 'NotificationSoundFile');

    initColorPickerDialog();
    initHotkeyRecorderDialog();

    window.SettingsUiBridge.refreshFromConfig();
    setTimeout(function () {
    window.SettingsUiBridge.refreshFromConfig();
    }, 250);
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
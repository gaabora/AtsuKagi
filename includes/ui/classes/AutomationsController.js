class AutomationsController {
  constructor(hostBridge) {
    this.hostBridge = hostBridge;
    this.root = null;
    this.data = null;
    this.availableActions = [];
    this.draft = null;
    this.editorMode = '';
    this.message = '';
    this.messageKind = 'info';
    this.timetable = null;
    this.pointerPaint = null;
    this.pendingPageRequest = null;
    this.lastPageRequestToken = '';
  }

  applyState(state) {
    this.availableActions = this._collectAvailableActions(state);
    this._capturePageRequest(state?.pageRequest);
    const section = document.getElementById('section-plugin-Automations');
    if (!section) return;

    let root = section.querySelector(':scope > [data-automations-controller]');
    if (!root) {
      root = document.createElement('div');
      root.setAttribute('data-automations-controller', '1');
      const actionsSlot = section.querySelector(':scope > [data-plugin-slot="actions"]');
      section.insertBefore(root, actionsSlot || null);
      this.root = root;
      this._bindEvents();
      this.load();
      return;
    }
    this.root = root;
    if (this.data) {
      this.render();
      this._applyPageRequest();
    }
  }

  load() {
    if (!this.root) return;
    try {
      const result = this.hostBridge.getAutomations();
      if (!result?.ok) throw new Error(result?.error || 'Could not load automations');
      this.data = {
        schemaVersion: Number(result.schemaVersion || 1),
        automations: Array.isArray(result.automations) ? result.automations : [],
        runtime: result.runtime || {}
      };
      if (Array.isArray(result.availableActions)) this.availableActions = [...new Set(result.availableActions.map((action) => `${action}`.trim()).filter(Boolean))].sort((firstAction, secondAction) => firstAction.localeCompare(secondAction));
      if (result.loadError) this._setMessage(result.loadError, 'error');
      this.render();
      if (!result.loadError) this._applyPageRequest();
    } catch (error) {
      this.data = { schemaVersion: 1, automations: [], runtime: {} };
      this._setMessage(error.message || `${error}`, 'error');
      this.render();
    }
  }

  _capturePageRequest(request) {
    if (!request || request.kind !== 'automation') return;
    const token = `${request.token || ''}`;
    if (!token || token === this.lastPageRequestToken) return;
    this.pendingPageRequest = { token, mode: `${request.mode || ''}`, automationId: `${request.automationId || ''}` };
  }

  _applyPageRequest() {
    if (!this.data || !this.pendingPageRequest) return;
    const request = this.pendingPageRequest;
    this.pendingPageRequest = null;
    this.lastPageRequestToken = request.token;
    const automation = this.data.automations.find((entry) => entry.id === request.automationId);
    if (!automation) {
      this.draft = null;
      this.timetable = null;
      this._setMessage(`Automation was not found: ${request.automationId}`, 'error');
      this.render();
      return;
    }

    if (this.draft && this.draft.id !== request.automationId && !window.confirm('Close the current automation editor and discard its unsaved changes?')) return;
    if (request.mode === 'edit') {
      if (!this.draft || this.draft.id !== request.automationId) this._openEditor(automation, 'edit');
      else {
        this.timetable = null;
        this.render();
      }
      return;
    }
    if (request.mode === 'extend') {
      if (!this.draft || this.draft.id !== request.automationId) this._openEditor(automation, 'edit');
      this._openTimetable(-1, 'extend');
    }
  }

  render() {
    if (!this.root || !this.data) return;
    this.root.innerHTML = `
      <div class="automation-runner">
        ${this._renderStatus()}
        ${this._renderToolbar()}
        ${this.message ? `<div class="automation-message automation-message-${this._escape(this.messageKind)}">${this._escape(this.message)}</div>` : ''}
        ${this.draft ? this._renderEditor() : this._renderList()}
        ${this.timetable?.open ? this._renderTimetable() : ''}
      </div>
    `;
  }

  _renderStatus() {
    const runtime = this.data.runtime || {};
    const runningLabel = runtime.running ? 'Running' : 'Stopped';
    const nextDue = runtime.nextDue?.known ? `${runtime.nextDue.name} in ${this._formatDuration(runtime.nextDue.secondsUntil)}` : 'No known next run';
    const battery = runtime.battery || {};
    const batteryLabel = battery.hasBattery ? `${battery.percent}% ${battery.charging ? 'charging' : battery.powerSource || ''}` : 'No battery';
    return `
      <div class="setting-group automation-status-group">
        <h3>Automation runner</h3>
        <div class="automation-status-grid">
          <div><span>Scheduler</span><strong>${this._escape(runningLabel)}</strong></div>
          <div><span>Enabled</span><strong>${Number(runtime.enabledAutomations || 0)}</strong></div>
          <div><span>Next</span><strong>${this._escape(nextDue)}</strong></div>
          <div><span>Battery</span><strong>${this._escape(batteryLabel)}</strong></div>
        </div>
        <div class="automation-quick-actions">
          <button type="button" class="app-btn app-btn-default" data-automation-action="show-battery-osd">Show battery OSD</button>
          <button type="button" class="app-btn app-btn-default" data-automation-action="show-sleep-osd">Show sleep countdown</button>
        </div>
      </div>
    `;
  }

  _renderToolbar() {
    if (this.draft) {
      return `
        <div class="automation-toolbar">
          <button type="button" class="app-btn app-btn-primary" data-automation-action="save-editor">Save automation</button>
          <button type="button" class="app-btn app-btn-default" data-automation-action="cancel-editor">Cancel</button>
        </div>
      `;
    }
    return `
      <div class="automation-toolbar">
        <button type="button" class="app-btn app-btn-primary" data-automation-action="add">Add automation</button>
        <select class="app-input" data-automation-example aria-label="Automation example">
          <option value="keep-awake">Keep awake during work hours</option>
          <option value="dismiss-popup">Dismiss a matching popup</option>
          <option value="low-battery">Low battery warning</option>
          <option value="fake-screensaver">Start fake screensaver</option>
        </select>
        <button type="button" class="app-btn app-btn-default" data-automation-action="add-example">Add example</button>
      </div>
    `;
  }

  _renderList() {
    const automations = this.data.automations || [];
    if (automations.length === 0) {
      return '<div class="setting-group automation-empty">No automations yet. Add one or start from an example.</div>';
    }
    const rows = automations.map((automation) => this._renderAutomationRow(automation)).join('');
    return `
      <div class="setting-group automation-list-group">
        <div class="automation-table" role="table">
          <div class="automation-table-head" role="row">
            <span>On</span><span>Name</span><span>Trigger</span><span>Action</span><span>Last result</span><span>Next or state</span><span>Actions</span>
          </div>
          ${rows}
        </div>
      </div>
    `;
  }

  _renderAutomationRow(automation) {
    const runtime = this.data.runtime?.automations?.[automation.id] || {};
    const lastResult = runtime.lastResult || {};
    const lastLabel = lastResult.time ? `${lastResult.ok ? 'OK' : 'Failed'} ${this._formatTimestamp(lastResult.time)}` : 'Never';
    const stateLabel = runtime.running ? 'Running now' : runtime.nextDue?.known ? `In ${this._formatDuration(runtime.nextDue.secondsUntil)}` : runtime.conditionPassed ? 'Conditions pass' : 'Waiting';
    const validationErrors = Array.isArray(automation.validationErrors) ? automation.validationErrors : [];
    return `
      <div class="automation-row${validationErrors.length ? ' is-invalid' : ''}" role="row" data-automation-id="${this._escape(automation.id)}">
        <label class="automation-cell automation-enabled-cell" data-label="Enabled"><input type="checkbox" data-automation-toggle="${this._escape(automation.id)}" ${automation.enabled ? 'checked' : ''}></label>
        <div class="automation-cell" data-label="Name"><strong>${this._escape(automation.name)}</strong>${validationErrors.length ? `<small>${this._escape(validationErrors.join('; '))}</small>` : ''}</div>
        <div class="automation-cell" data-label="Trigger">${this._escape(this._triggerSummary(automation.triggers || []))}</div>
        <div class="automation-cell automation-action-text" data-label="Action">${this._escape(automation.action)}</div>
        <div class="automation-cell" data-label="Last result">${this._escape(lastLabel)}</div>
        <div class="automation-cell" data-label="Next or state">${this._escape(stateLabel)}</div>
        <div class="automation-cell automation-row-actions" data-label="Actions">
          <button type="button" data-automation-action="edit" data-id="${this._escape(automation.id)}">Edit</button>
          <button type="button" data-automation-action="duplicate" data-id="${this._escape(automation.id)}">Duplicate</button>
          <button type="button" data-automation-action="run" data-id="${this._escape(automation.id)}">Run</button>
          <button type="button" data-automation-action="test" data-id="${this._escape(automation.id)}">Test</button>
          <button type="button" data-automation-action="extend" data-id="${this._escape(automation.id)}">Extend</button>
          <button type="button" data-automation-action="delete" data-id="${this._escape(automation.id)}">Delete</button>
        </div>
      </div>
    `;
  }

  _renderEditor() {
    const errors = this._validateAutomation(this.draft);
    const preview = this._automationPreview(this.draft);
    const triggers = (this.draft.triggers || []).map((trigger, idx) => this._renderTrigger(trigger, idx)).join('');
    const conditions = (this.draft.conditions || []).map((condition) => this._renderCondition(condition, 0)).join('');
    const actionOptions = this.availableActions.map((action) => `<option value="${this._escape(`${action}()`)}"></option>`).join('');
    return `
      <div class="setting-group automation-editor" data-automation-editor>
        <div class="automation-editor-heading"><h3>${this.editorMode === 'add' ? 'New automation' : 'Edit automation'}</h3><span>${this._escape(this.draft.id)}</span></div>
        <div class="automation-form-grid">
          <label><span>Name</span><input class="app-input" data-draft-field="name" value="${this._escape(this.draft.name)}"></label>
          <label class="automation-check"><input type="checkbox" data-draft-field="enabled" ${this.draft.enabled ? 'checked' : ''}><span>Enabled</span></label>
        </div>

        <div class="automation-editor-section">
          <div class="automation-section-heading"><h4>Triggers</h4><div><button type="button" data-automation-action="add-schedule">Add schedule</button><button type="button" data-automation-action="add-interval">Add interval</button></div></div>
          <div class="automation-trigger-list">${triggers || '<p class="automation-muted">At least one trigger is required.</p>'}</div>
        </div>

        <div class="automation-editor-section">
          <div class="automation-section-heading"><h4>Conditions</h4><div><button type="button" data-automation-action="add-condition">Add condition</button><button type="button" data-automation-action="add-or">Add OR group</button><button type="button" data-automation-action="add-not">Add NOT</button></div></div>
          <p class="automation-muted">Top-level conditions use AND.</p>
          <div class="automation-condition-list">${conditions || '<p class="automation-muted">No conditions. The action can run whenever a trigger is due.</p>'}</div>
        </div>

        <div class="automation-editor-section">
          <h4>Action and options</h4>
          <label><span>Action string</span><input class="app-input" list="automation-action-suggestions" data-draft-field="action" value="${this._escape(this.draft.action)}"></label>
          <datalist id="automation-action-suggestions">${actionOptions}</datalist>
          <div class="automation-options-grid">
            ${this._renderOption('logRuns', 'Log runs')}
            ${this._renderOption('notifyOnError', 'Notify on error')}
            ${this._renderOption('catchUp', 'Catch up missed schedules')}
            ${this._renderOption('showInTray', 'Show in tray')}
            <label><span>Repeat behavior</span><select class="app-input" data-draft-option="conditionMode"><option value="each-trigger" ${this.draft.options.conditionMode === 'each-trigger' ? 'selected' : ''}>Each trigger</option><option value="on-enter" ${this.draft.options.conditionMode === 'on-enter' ? 'selected' : ''}>Only when conditions become true</option></select></label>
          </div>
        </div>

        <div class="automation-preview">
          <strong>Preview</strong>
          <p>${this._escape(preview)}</p>
          <p>${this._escape(this._nextRunPreview(this.draft))}</p>
          ${errors.length ? `<div class="automation-validation">${errors.map((errorText) => `<div>${this._escape(errorText)}</div>`).join('')}</div>` : '<div class="automation-validation is-valid">Ready to save.</div>'}
        </div>
      </div>
    `;
  }

  _renderTrigger(trigger, idx) {
    const isSchedule = trigger.type === 'schedule';
    const value = trigger.value ?? '';
    const preview = isSchedule ? this._cronPreview(`${value}`) : this._intervalPreview(value);
    return `
      <div class="automation-trigger" data-trigger-index="${idx}">
        <div class="automation-trigger-main">
          <label><span>Type</span><select class="app-input" data-trigger-field="type"><option value="schedule" ${isSchedule ? 'selected' : ''}>Schedule</option><option value="interval" ${!isSchedule ? 'selected' : ''}>Interval</option></select></label>
          <label><span>${isSchedule ? 'Cron expression' : 'Interval, ms'}</span><input class="app-input" data-trigger-field="value" type="${isSchedule ? 'text' : 'number'}" min="${isSchedule ? '' : '1000'}" max="${isSchedule ? '' : '59999'}" value="${this._escape(value)}"></label>
          ${isSchedule ? `<label><span>Expiry, optional</span><input class="app-input" data-trigger-field="expires" type="date" value="${this._escape(trigger.expires || '')}"></label>` : ''}
        </div>
        <div class="automation-trigger-preview">${this._escape(preview)}</div>
        <div class="automation-inline-actions">
          ${isSchedule ? `<button type="button" data-automation-action="timetable" data-trigger-index="${idx}">7x24 timetable</button>` : ''}
          <button type="button" data-automation-action="duplicate-trigger" data-trigger-index="${idx}">Duplicate</button>
          <button type="button" data-automation-action="delete-trigger" data-trigger-index="${idx}">Delete</button>
        </div>
      </div>
    `;
  }

  _renderCondition(condition, depth) {
    this._ensureConditionUiIds(condition);
    const conditionId = condition._uiId;
    if (condition.type === 'or') {
      const children = Array.isArray(condition.value) ? condition.value.map((child) => this._renderCondition(child, depth + 1)).join('') : '';
      return `<div class="automation-condition automation-condition-group" data-condition-id="${conditionId}" style="--condition-depth:${depth}"><div class="automation-condition-title"><strong>OR group</strong><div><button type="button" data-automation-action="add-condition-child" data-condition-id="${conditionId}">Add condition</button><button type="button" data-automation-action="wrap-condition-not" data-condition-id="${conditionId}">Wrap NOT</button><button type="button" data-automation-action="delete-condition" data-condition-id="${conditionId}">Delete</button></div></div>${children || '<p class="automation-muted">Add at least one condition.</p>'}</div>`;
    }
    if (condition.type === 'not') {
      const child = condition.value && typeof condition.value === 'object' ? this._renderCondition(condition.value, depth + 1) : '';
      return `<div class="automation-condition automation-condition-group" data-condition-id="${conditionId}" style="--condition-depth:${depth}"><div class="automation-condition-title"><strong>NOT</strong><button type="button" data-automation-action="delete-condition" data-condition-id="${conditionId}">Delete</button></div>${child}</div>`;
    }

    const typeOptions = this._conditionTypes().map((entry) => `<option value="${entry.value}" ${condition.type === entry.value ? 'selected' : ''}>${this._escape(entry.label)}</option>`).join('');
    const input = condition.type === 'charging'
      ? `<label class="automation-check"><input type="checkbox" data-condition-field="value" ${condition.value ? 'checked' : ''}><span>Required</span></label>`
      : condition.type === 'power-source'
        ? `<select class="app-input" data-condition-field="value"><option value="battery" ${condition.value === 'battery' ? 'selected' : ''}>Battery</option><option value="ac" ${condition.value === 'ac' ? 'selected' : ''}>AC power</option></select>`
        : `<input class="app-input" data-condition-field="value" type="${this._conditionUsesNumber(condition.type) ? 'number' : 'text'}" value="${this._escape(condition.value ?? '')}">`;
    return `<div class="automation-condition" data-condition-id="${conditionId}" style="--condition-depth:${depth}"><select class="app-input" data-condition-field="type">${typeOptions}</select>${input}<button type="button" data-automation-action="wrap-condition-not" data-condition-id="${conditionId}">NOT</button><button type="button" data-automation-action="delete-condition" data-condition-id="${conditionId}">Delete</button></div>`;
  }

  _renderOption(key, label) {
    return `<label class="automation-check"><input type="checkbox" data-draft-option="${this._escape(key)}" ${this.draft.options[key] ? 'checked' : ''}><span>${this._escape(label)}</span></label>`;
  }

  _renderTimetable() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const hourHeaders = Array.from({ length: 24 }, (unusedValue, hour) => `<button type="button" class="automation-time-header" data-time-hour="${hour}">${`${hour}`.padStart(2, '0')}</button>`).join('');
    const rows = dayNames.map((dayName, dayIdx) => {
      const cells = Array.from({ length: 24 }, (unusedValue, hour) => `<button type="button" class="automation-time-cell${this.timetable.selection[dayIdx][hour] ? ' is-active' : ''}" data-time-day="${dayIdx}" data-time-hour="${hour}" aria-label="${dayName} ${hour}:00"></button>`).join('');
      return `<button type="button" class="automation-time-day" data-time-day="${dayIdx}">${dayName}</button>${cells}`;
    }).join('');
    const expressions = this._selectionToCron(this.timetable.selection);
    return `
      <div class="automation-dialog-backdrop" data-automation-timetable>
        <div class="automation-timetable-dialog">
          <div class="automation-section-heading"><h3>${this.timetable.mode === 'extend' ? 'Extend schedule' : 'Weekly timetable'}</h3><button type="button" data-automation-action="close-timetable">Close</button></div>
          <p>Select hours. Drag cells to paint. Day and hour headers toggle a full row or column.</p>
          <div class="automation-timetable"><span></span>${hourHeaders}${rows}</div>
          <div class="automation-timetable-footer">
            <label><span>Expiry ${this.timetable.mode === 'extend' ? '(required)' : '(optional)'}</span><input class="app-input" type="date" data-timetable-expiry value="${this._escape(this.timetable.expiry || '')}"></label>
            <div><strong>Generated cron</strong><code>${this._escape(expressions.join(' | ') || 'Select at least one hour')}</code></div>
            <div class="automation-inline-actions"><button type="button" class="app-btn app-btn-primary" data-automation-action="apply-timetable">Apply</button><button type="button" class="app-btn app-btn-default" data-automation-action="clear-timetable">Clear</button></div>
          </div>
        </div>
      </div>
    `;
  }

  _bindEvents() {
    this.root.addEventListener('click', (event) => this._handleClick(event));
    this.root.addEventListener('input', (event) => this._handleInput(event));
    this.root.addEventListener('change', (event) => this._handleChange(event));
    this.root.addEventListener('pointerdown', (event) => this._handlePointerDown(event));
    this.root.addEventListener('pointerover', (event) => this._handlePointerOver(event));
    document.addEventListener('pointerup', () => { this.pointerPaint = null; });
  }

  _handleClick(event) {
    const dayHeader = event.target.closest('.automation-time-day[data-time-day]');
    if (dayHeader && this.timetable) {
      event.preventDefault();
      const dayIdx = Number(dayHeader.dataset.timeDay);
      const enabled = this.timetable.selection[dayIdx].some((cellEnabled) => !cellEnabled);
      this.timetable.selection[dayIdx].fill(enabled);
      this.render();
      return;
    }
    const hourHeader = event.target.closest('.automation-time-header[data-time-hour]');
    if (hourHeader && this.timetable) {
      event.preventDefault();
      const hour = Number(hourHeader.dataset.timeHour);
      const enabled = this.timetable.selection.some((day) => !day[hour]);
      this.timetable.selection.forEach((day) => { day[hour] = enabled; });
      this.render();
      return;
    }
    const actionButton = event.target.closest('[data-automation-action]');
    if (!actionButton || !this.root.contains(actionButton)) return;
    event.preventDefault();
    const action = actionButton.dataset.automationAction;
    const automationId = actionButton.dataset.id || '';
    const triggerIndex = Number(actionButton.dataset.triggerIndex);
    const conditionId = actionButton.dataset.conditionId || '';
    const actions = {
      add: () => this._openEditor(this._emptyAutomation(), 'add'),
      edit: () => this._editAutomation(automationId),
      duplicate: () => this._duplicateAutomation(automationId),
      run: () => this._runCommand('run', automationId),
      test: () => this._runCommand('test', automationId),
      extend: () => this._extendAutomation(automationId),
      delete: () => this._deleteAutomation(automationId),
      'add-example': () => this._addExample(),
      'save-editor': () => this._saveEditor(),
      'cancel-editor': () => this._closeEditor(),
      'add-schedule': () => this._addTrigger('schedule'),
      'add-interval': () => this._addTrigger('interval'),
      timetable: () => this._openTimetable(triggerIndex, 'edit'),
      'duplicate-trigger': () => this._duplicateTrigger(triggerIndex),
      'delete-trigger': () => this._deleteTrigger(triggerIndex),
      'add-condition': () => this._addTopCondition(this._newLeafCondition()),
      'add-or': () => this._addTopCondition(this._newOrCondition()),
      'add-not': () => this._addTopCondition(this._newNotCondition()),
      'add-condition-child': () => this._addConditionChild(conditionId),
      'wrap-condition-not': () => this._wrapConditionNot(conditionId),
      'delete-condition': () => this._deleteCondition(conditionId),
      'close-timetable': () => this._closeTimetable(),
      'apply-timetable': () => this._applyTimetable(),
      'clear-timetable': () => this._clearTimetable(),
      'show-battery-osd': () => this._showOsd('battery'),
      'show-sleep-osd': () => this._showOsd('sleep')
    };
    if (actions[action]) actions[action]();
  }

  _handleInput(event) {
    if (event.target.matches('[data-timetable-expiry]') && this.timetable) {
      this.timetable.expiry = event.target.value;
      return;
    }
    if (!this.draft) return;
    this._syncDraftInput(event.target);
    this._refreshEditorPreview(event.target);
  }

  _handleChange(event) {
    const toggle = event.target.closest('[data-automation-toggle]');
    if (toggle) {
      this._toggleAutomation(toggle.dataset.automationToggle, toggle.checked);
      return;
    }
    if (!this.draft) return;
    this._syncDraftInput(event.target);
    this.render();
  }

  _handlePointerDown(event) {
    const cell = event.target.closest('[data-time-day][data-time-hour]');
    if (!cell || !this.timetable) return;
    event.preventDefault();
    const dayIdx = Number(cell.dataset.timeDay);
    const hour = Number(cell.dataset.timeHour);
    const enabled = !this.timetable.selection[dayIdx][hour];
    this.pointerPaint = { enabled };
    this._paintTimetableCell(dayIdx, hour, enabled);
  }

  _handlePointerOver(event) {
    if (!this.pointerPaint || !this.timetable) return;
    const cell = event.target.closest('[data-time-day][data-time-hour]');
    if (!cell) return;
    this._paintTimetableCell(Number(cell.dataset.timeDay), Number(cell.dataset.timeHour), this.pointerPaint.enabled);
  }

  _syncDraftInput(target) {
    if (target.dataset.draftField) {
      this.draft[target.dataset.draftField] = target.type === 'checkbox' ? target.checked : target.value;
      return;
    }
    if (target.dataset.draftOption) {
      this.draft.options[target.dataset.draftOption] = target.type === 'checkbox' ? target.checked : target.value;
      return;
    }
    const triggerElement = target.closest('[data-trigger-index]');
    if (triggerElement && target.dataset.triggerField) {
      const trigger = this.draft.triggers[Number(triggerElement.dataset.triggerIndex)];
      const field = target.dataset.triggerField;
      trigger[field] = field === 'value' && trigger.type === 'interval' ? Number(target.value) : target.value;
      if (field === 'type') {
        trigger.value = target.value === 'interval' ? 1000 : '* * * * *';
        delete trigger.expires;
      }
      if (field === 'expires' && !target.value) delete trigger.expires;
      return;
    }
    const conditionElement = target.closest('[data-condition-id]');
    if (conditionElement && target.dataset.conditionField) {
      const condition = this._findCondition(conditionElement.dataset.conditionId)?.condition;
      if (!condition) return;
      if (target.dataset.conditionField === 'type') {
        condition.type = target.value;
        condition.value = this._defaultConditionValue(target.value);
      } else {
        condition.value = target.type === 'checkbox' ? target.checked : this._conditionUsesNumber(condition.type) ? Number(target.value) : target.value;
      }
    }
  }

  _refreshEditorPreview(target) {
    const triggerElement = target.closest('[data-trigger-index]');
    if (triggerElement) {
      const trigger = this.draft.triggers[Number(triggerElement.dataset.triggerIndex)];
      const previewElement = triggerElement.querySelector('.automation-trigger-preview');
      if (previewElement) previewElement.textContent = trigger.type === 'schedule' ? this._cronPreview(trigger.value) : this._intervalPreview(trigger.value);
    }
    const previewRoot = this.root.querySelector('.automation-preview');
    if (!previewRoot) return;
    const errors = this._validateAutomation(this.draft);
    previewRoot.innerHTML = `
      <strong>Preview</strong>
      <p>${this._escape(this._automationPreview(this.draft))}</p>
      <p>${this._escape(this._nextRunPreview(this.draft))}</p>
      ${errors.length ? `<div class="automation-validation">${errors.map((errorText) => `<div>${this._escape(errorText)}</div>`).join('')}</div>` : '<div class="automation-validation is-valid">Ready to save.</div>'}
    `;
  }

  _openEditor(automation, mode) {
    this.draft = this._clone(automation);
    this.draft.options = { catchUp: false, conditionMode: 'each-trigger', logRuns: true, notifyOnError: false, showInTray: false, ...(this.draft.options || {}) };
    this._ensureConditionUiIds(this.draft.conditions || []);
    this.editorMode = mode;
    this.timetable = null;
    this._clearMessage();
    this.render();
  }

  _editAutomation(automationId) {
    const automation = this.data.automations.find((entry) => entry.id === automationId);
    if (automation) this._openEditor(automation, 'edit');
  }

  _closeEditor() {
    this.draft = null;
    this.editorMode = '';
    this.timetable = null;
    this._clearMessage();
    this.render();
  }

  _saveEditor() {
    const errors = this._validateAutomation(this.draft);
    if (errors.length) {
      this._setMessage(errors.join(' '), 'error');
      this.render();
      return;
    }
    const persistedDraft = this._stripUiFields(this.draft);
    const automations = this.data.automations.map((automation) => automation.id === persistedDraft.id ? persistedDraft : automation);
    if (!automations.some((automation) => automation.id === persistedDraft.id)) automations.push(persistedDraft);
    this._saveCollection(automations, 'Automation saved.');
  }

  _duplicateAutomation(automationId) {
    const source = this.data.automations.find((entry) => entry.id === automationId);
    if (!source) return;
    const copy = this._clone(source);
    copy.id = this._newId();
    copy.name = `${copy.name} copy`;
    copy.enabled = false;
    delete copy.validationErrors;
    this._saveCollection([...this.data.automations, copy], 'Automation duplicated.');
  }

  _deleteAutomation(automationId) {
    const automation = this.data.automations.find((entry) => entry.id === automationId);
    if (!automation || !window.confirm(`Delete automation "${automation.name}"?`)) return;
    this._saveCollection(this.data.automations.filter((entry) => entry.id !== automationId), 'Automation deleted.');
  }

  _toggleAutomation(automationId, enabled) {
    try {
      const result = enabled ? this.hostBridge.enableAutomation(automationId) : this.hostBridge.disableAutomation(automationId);
      if (!result?.ok) throw new Error(result?.error || 'Could not change automation state');
      this._setMessage(enabled ? 'Automation enabled.' : 'Automation disabled.', 'success');
      this.load();
    } catch (error) {
      this._setMessage(error.message || `${error}`, 'error');
      this.load();
    }
  }

  _runCommand(command, automationId) {
    try {
      const result = command === 'test' ? this.hostBridge.testAutomationAction(automationId) : this.hostBridge.runAutomation(automationId);
      if (!result?.ok) throw new Error(result?.error || 'Automation action failed');
      this._setMessage(command === 'test' ? 'Action test completed.' : 'Automation run completed.', 'success');
      this.load();
    } catch (error) {
      this._setMessage(error.message || `${error}`, 'error');
      this.load();
    }
  }

  _showOsd(kind) {
    try {
      const result = kind === 'battery' ? this.hostBridge.showLowBatteryOsd() : this.hostBridge.showTimeUntilSleep();
      if (!result?.ok) throw new Error(result?.error || 'Could not show OSD');
      this._setMessage('OSD shown.', 'success');
    } catch (error) {
      this._setMessage(error.message || `${error}`, 'error');
    }
    this.render();
  }

  _saveCollection(automations, successMessage) {
    try {
      const payload = { schemaVersion: this.data.schemaVersion || 1, automations: automations.map((automation) => this._stripUiFields(automation)) };
      const result = this.hostBridge.saveAutomations(payload);
      if (!result?.ok) {
        const problemText = Array.isArray(result?.problems) ? result.problems.flatMap((problem) => problem.errors || []).join('; ') : '';
        throw new Error(problemText || result?.error || 'Could not save automations');
      }
      this.draft = null;
      this.editorMode = '';
      this.timetable = null;
      this._setMessage(successMessage, 'success');
      this.load();
    } catch (error) {
      this._setMessage(error.message || `${error}`, 'error');
      this.render();
    }
  }

  _addTrigger(type) {
    this.draft.triggers.push(type === 'interval' ? { type: 'interval', value: 1000 } : { type: 'schedule', value: '* * * * *' });
    this.render();
  }

  _duplicateTrigger(triggerIndex) {
    const trigger = this.draft.triggers[triggerIndex];
    if (trigger) this.draft.triggers.splice(triggerIndex + 1, 0, this._clone(trigger));
    this.render();
  }

  _deleteTrigger(triggerIndex) {
    this.draft.triggers.splice(triggerIndex, 1);
    this.render();
  }

  _addTopCondition(condition) {
    this._ensureConditionUiIds(condition);
    this.draft.conditions.push(condition);
    this.render();
  }

  _addConditionChild(conditionId) {
    const match = this._findCondition(conditionId);
    if (match?.condition?.type !== 'or') return;
    match.condition.value.push(this._newLeafCondition());
    this.render();
  }

  _wrapConditionNot(conditionId) {
    const match = this._findCondition(conditionId);
    if (!match) return;
    const wrapped = { type: 'not', value: match.condition, _uiId: this._newUiId() };
    if (match.parentArray) match.parentArray[match.index] = wrapped;
    else if (match.parentCondition?.type === 'not') match.parentCondition.value = wrapped;
    this.render();
  }

  _deleteCondition(conditionId) {
    const match = this._findCondition(conditionId);
    if (!match) return;
    if (match.parentArray) match.parentArray.splice(match.index, 1);
    else if (match.parentCondition?.type === 'not') match.parentCondition.value = this._newLeafCondition();
    this.render();
  }

  _findCondition(conditionId) {
    const visit = (condition, parentArray, index, parentCondition) => {
      if (condition?._uiId === conditionId) return { condition, parentArray, index, parentCondition };
      if (condition?.type === 'or' && Array.isArray(condition.value)) {
        for (let childIdx = 0; childIdx < condition.value.length; childIdx += 1) {
          const match = visit(condition.value[childIdx], condition.value, childIdx, condition);
          if (match) return match;
        }
      } else if (condition?.type === 'not' && condition.value && typeof condition.value === 'object') {
        return visit(condition.value, null, 0, condition);
      }
      return null;
    };
    for (let conditionIdx = 0; conditionIdx < this.draft.conditions.length; conditionIdx += 1) {
      const match = visit(this.draft.conditions[conditionIdx], this.draft.conditions, conditionIdx, null);
      if (match) return match;
    }
    return null;
  }

  _extendAutomation(automationId) {
    const automation = this.data.automations.find((entry) => entry.id === automationId);
    if (!automation) return;
    this._openEditor(automation, 'edit');
    this._openTimetable(-1, 'extend');
  }

  _openTimetable(triggerIndex, mode) {
    const selection = Array.from({ length: 7 }, () => Array(24).fill(false));
    let expiry = '';
    if (mode === 'edit' && triggerIndex >= 0) {
      const trigger = this.draft.triggers[triggerIndex];
      expiry = trigger?.expires || '';
      this._cronToSelection(trigger?.value || '', selection);
    }
    this.timetable = { open: true, mode, triggerIndex, selection, expiry };
    this.render();
  }

  _closeTimetable() {
    this.timetable = null;
    this.pointerPaint = null;
    this.render();
  }

  _clearTimetable() {
    this.timetable.selection = Array.from({ length: 7 }, () => Array(24).fill(false));
    this.render();
  }

  _paintTimetableCell(dayIdx, hour, enabled) {
    if (dayIdx < 0 || dayIdx > 6 || hour < 0 || hour > 23) return;
    this.timetable.selection[dayIdx][hour] = enabled;
    const cell = this.root.querySelector(`[data-time-day="${dayIdx}"][data-time-hour="${hour}"]`);
    cell?.classList.toggle('is-active', enabled);
    const code = this.root.querySelector('.automation-timetable-footer code');
    if (code) code.textContent = this._selectionToCron(this.timetable.selection).join(' | ') || 'Select at least one hour';
  }

  _applyTimetable() {
    const expressions = this._selectionToCron(this.timetable.selection);
    if (!expressions.length) {
      this._setMessage('Select at least one timetable cell.', 'error');
      this.render();
      return;
    }
    if (this.timetable.mode === 'extend' && !this._validDate(this.timetable.expiry)) {
      this._setMessage('A valid expiry date is required for Extend.', 'error');
      this.render();
      return;
    }
    if (this.timetable.mode === 'extend' && this.timetable.expiry < this._localDateText(new Date())) {
      this._setMessage('Extend expiry cannot be before today.', 'error');
      this.render();
      return;
    }
    const triggers = expressions.map((expression) => ({ type: 'schedule', value: expression, ...(this.timetable.expiry ? { expires: this.timetable.expiry } : {}) }));
    if (this.timetable.mode === 'extend') this.draft.triggers.push(...triggers);
    else this.draft.triggers.splice(this.timetable.triggerIndex, 1, ...triggers);
    this.timetable = null;
    this._setMessage('Timetable applied. Save the automation to keep it.', 'info');
    this.render();
  }

  _cronToSelection(expression, selection) {
    try {
      const parsed = this._parseCron(expression);
      if (parsed.fields[2].restricted || parsed.fields[3].restricted) return false;
      const days = parsed.fields[4].restricted ? [...parsed.fields[4].values] : [0, 1, 2, 3, 4, 5, 6];
      const dayToRow = { 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 0: 6 };
      days.forEach((dayValue) => parsed.fields[1].values.forEach((hour) => { selection[dayToRow[dayValue]][hour] = true; }));
      return true;
    } catch (error) {
      return false;
    }
  }

  _selectionToCron(selection) {
    const groups = new Map();
    selection.forEach((hours, dayIdx) => {
      const enabledHours = hours.map((enabled, hour) => enabled ? hour : -1).filter((hour) => hour >= 0);
      if (!enabledHours.length) return;
      const key = enabledHours.join(',');
      if (!groups.has(key)) groups.set(key, { hours: enabledHours, days: [] });
      groups.get(key).days.push(dayIdx);
    });
    return [...groups.values()].map((group) => `* ${this._compactNumbers(group.hours)} * * ${this._compactDays(group.days)}`);
  }

  _compactNumbers(values) {
    if (!values.length) return '*';
    const sortedValues = [...new Set(values)].sort((firstValue, secondValue) => firstValue - secondValue);
    if (sortedValues.length === 24 && sortedValues[0] === 0 && sortedValues[23] === 23) return '*';
    const parts = [];
    let rangeStart = sortedValues[0];
    let previousValue = sortedValues[0];
    for (let valueIdx = 1; valueIdx <= sortedValues.length; valueIdx += 1) {
      const currentValue = sortedValues[valueIdx];
      if (currentValue === previousValue + 1) {
        previousValue = currentValue;
        continue;
      }
      parts.push(rangeStart === previousValue ? `${rangeStart}` : `${rangeStart}-${previousValue}`);
      rangeStart = currentValue;
      previousValue = currentValue;
    }
    return parts.join(',');
  }

  _compactDays(dayRows) {
    if (dayRows.length === 7) return '*';
    const cronDays = dayRows.map((dayIdx) => [1, 2, 3, 4, 5, 6, 0][dayIdx]);
    const weekdayValues = cronDays.filter((dayValue) => dayValue !== 0);
    const weekdayText = this._compactNumbers(weekdayValues);
    if (!cronDays.includes(0)) return weekdayText;
    return weekdayValues.length ? `${weekdayText},0` : '0';
  }

  _addExample() {
    const select = this.root.querySelector('[data-automation-example]');
    const example = this._exampleAutomation(select?.value || 'keep-awake');
    this._openEditor(example, 'add');
  }

  _exampleAutomation(exampleId) {
    const base = this._emptyAutomation();
    base.enabled = false;
    if (exampleId === 'dismiss-popup') {
      base.name = 'Dismiss matching popup';
      base.triggers = [{ type: 'interval', value: 1000 }];
      base.conditions = [{ type: 'window-exists', value: 'ahk_class TRegCheckDlg' }];
      base.action = 'DismissMatchingWindows(ahk_class TRegCheckDlg, {Escape})';
    } else if (exampleId === 'low-battery') {
      base.name = 'Low battery warning';
      base.triggers = [{ type: 'interval', value: 30000 }];
      base.conditions = [{ type: 'power-source', value: 'battery' }, { type: 'battery-percent-at-most', value: 15 }];
      base.action = 'ShowLowBatteryOsd()';
      base.options.conditionMode = 'on-enter';
    } else if (exampleId === 'fake-screensaver') {
      base.name = 'Start fake screensaver at night';
      base.triggers = [{ type: 'schedule', value: '0 23 * * *' }];
      base.action = 'StartFakeScreensaver()';
    } else {
      base.name = 'Keep awake during work hours';
      base.triggers = [{ type: 'schedule', value: '* 8-17 * * 1-5' }];
      base.conditions = [{ type: 'idle', value: 10000 }];
      base.action = 'PreventSleep()';
    }
    return base;
  }

  _emptyAutomation() {
    return { id: this._newId(), name: '', enabled: false, triggers: [{ type: 'schedule', value: '* * * * *' }], conditions: [], action: '', options: { catchUp: false, conditionMode: 'each-trigger', logRuns: true, notifyOnError: false, showInTray: false } };
  }

  _newLeafCondition() {
    return { type: 'idle', value: 1000, _uiId: this._newUiId() };
  }

  _newOrCondition() {
    return { type: 'or', value: [this._newLeafCondition()], _uiId: this._newUiId() };
  }

  _newNotCondition() {
    return { type: 'not', value: this._newLeafCondition(), _uiId: this._newUiId() };
  }

  _conditionTypes() {
    return [
      { value: 'idle', label: 'Physical idle, ms' },
      { value: 'window-exists', label: 'Window exists' },
      { value: 'window-active', label: 'Window is active' },
      { value: 'window-topmost', label: 'Window is topmost' },
      { value: 'power-source', label: 'Power source' },
      { value: 'battery-percent-at-most', label: 'Battery percent at most' },
      { value: 'battery-minutes-at-most', label: 'Battery minutes at most' },
      { value: 'charging', label: 'Charging' }
    ];
  }

  _defaultConditionValue(type) {
    if (type === 'idle') return 1000;
    if (type === 'battery-percent-at-most') return 15;
    if (type === 'battery-minutes-at-most') return 15;
    if (type === 'power-source') return 'battery';
    if (type === 'charging') return true;
    return '';
  }

  _conditionUsesNumber(type) {
    return ['idle', 'battery-percent-at-most', 'battery-minutes-at-most'].includes(type);
  }

  _validateAutomation(automation) {
    const errors = [];
    if (!`${automation.id || ''}`.trim()) errors.push('ID cannot be empty.');
    if (!`${automation.name || ''}`.trim()) errors.push('Name cannot be empty.');
    if (!`${automation.action || ''}`.trim()) errors.push('Action cannot be empty.');
    else if (this.availableActions.length && !this.availableActions.includes(this._actionName(automation.action))) errors.push(`Unknown action: ${this._actionName(automation.action) || automation.action}.`);
    if (!Array.isArray(automation.triggers) || !automation.triggers.length) errors.push('At least one trigger is required.');
    (automation.triggers || []).forEach((trigger, idx) => {
      if (trigger.type === 'interval') {
        const interval = Number(trigger.value);
        if (!Number.isInteger(interval) || interval < 1000 || interval >= 60000) errors.push(`Trigger ${idx + 1}: interval must be 1000-59999 ms.`);
      } else if (trigger.type === 'schedule') {
        try { this._parseCron(`${trigger.value || ''}`); } catch (error) { errors.push(`Trigger ${idx + 1}: ${error.message}.`); }
        if (trigger.expires && !this._validDate(trigger.expires)) errors.push(`Trigger ${idx + 1}: expiry date is invalid.`);
      } else errors.push(`Trigger ${idx + 1}: unsupported type.`);
    });
    (automation.conditions || []).forEach((condition, idx) => this._validateCondition(condition, 1, `Condition ${idx + 1}`, errors));
    if (automation.options?.conditionMode === 'on-enter' && !(automation.conditions || []).length) errors.push('Only when conditions become true requires a condition.');
    const duplicates = this.data.automations.filter((entry) => entry.id === automation.id && entry !== automation);
    if (this.editorMode === 'add' && duplicates.length) errors.push('Automation ID must be unique.');
    return errors;
  }

  _validateCondition(condition, depth, path, errors) {
    if (!condition || typeof condition !== 'object') {
      errors.push(`${path} must be an object.`);
      return;
    }
    if (depth > 3) errors.push(`${path} exceeds nesting depth 3.`);
    if (condition.type === 'or') {
      if (!Array.isArray(condition.value) || !condition.value.length) errors.push(`${path} OR group needs a condition.`);
      (condition.value || []).forEach((child, idx) => this._validateCondition(child, depth + 1, `${path}.OR ${idx + 1}`, errors));
      return;
    }
    if (condition.type === 'not') {
      this._validateCondition(condition.value, depth + 1, `${path}.NOT`, errors);
      return;
    }
    const knownTypes = this._conditionTypes().map((entry) => entry.value);
    if (!knownTypes.includes(condition.type)) errors.push(`${path} has unsupported type.`);
    if (['window-exists', 'window-active', 'window-topmost'].includes(condition.type) && !`${condition.value || ''}`.trim()) errors.push(`${path} window selector cannot be empty.`);
    if (condition.type === 'power-source' && !['ac', 'battery'].includes(condition.value)) errors.push(`${path} power source must be AC or battery.`);
    const ranges = { idle: [0, 2147483647], 'battery-percent-at-most': [0, 100], 'battery-minutes-at-most': [0, 10080] };
    if (ranges[condition.type]) {
      const numericValue = Number(condition.value);
      const [minimum, maximum] = ranges[condition.type];
      if (!Number.isInteger(numericValue) || numericValue < minimum || numericValue > maximum) errors.push(`${path} value must be ${minimum}-${maximum}.`);
    }
  }

  _parseCron(expression) {
    const fields = `${expression || ''}`.trim().split(/\s+/);
    if (fields.length !== 5) throw new Error('cron schedule must contain five fields');
    return { expression, fields: [this._parseCronField(fields[0], 0, 59), this._parseCronField(fields[1], 0, 23), this._parseCronField(fields[2], 1, 31), this._parseCronField(fields[3], 1, 12), this._parseCronField(fields[4], 0, 7, true)] };
  }

  _parseCronField(text, minimum, maximum, normalizeSunday = false) {
    const values = new Set();
    `${text}`.split(',').forEach((itemText) => {
      const itemParts = itemText.trim().split('/');
      if (!itemParts[0] || itemParts.length > 2) throw new Error(`invalid cron item ${itemText}`);
      const step = itemParts.length === 2 ? Number(itemParts[1]) : 1;
      if (!Number.isInteger(step) || step <= 0) throw new Error(`invalid cron step ${itemText}`);
      let rangeStart;
      let rangeEnd;
      if (itemParts[0] === '*') {
        rangeStart = minimum;
        rangeEnd = maximum;
      } else if (itemParts[0].includes('-')) {
        const rangeParts = itemParts[0].split('-');
        if (rangeParts.length !== 2) throw new Error(`invalid cron range ${itemText}`);
        rangeStart = Number(rangeParts[0]);
        rangeEnd = Number(rangeParts[1]);
      } else {
        rangeStart = Number(itemParts[0]);
        rangeEnd = itemParts.length === 2 ? maximum : rangeStart;
      }
      if (!Number.isInteger(rangeStart) || !Number.isInteger(rangeEnd) || rangeStart < minimum || rangeEnd > maximum || rangeStart > rangeEnd) throw new Error(`cron value is outside ${minimum}-${maximum}`);
      for (let currentValue = rangeStart; currentValue <= rangeEnd; currentValue += step) values.add(normalizeSunday && currentValue === 7 ? 0 : currentValue);
    });
    return { values, restricted: text !== '*' };
  }

  _cronPreview(expression) {
    try {
      const parsed = this._parseCron(expression);
      const minuteText = parsed.fields[0].values.size === 60 ? 'Every minute' : `Minute ${this._compactNumbers([...parsed.fields[0].values])}`;
      const hourText = parsed.fields[1].values.size === 24 ? 'all day' : `at hour ${this._compactNumbers([...parsed.fields[1].values])}`;
      const dayOfMonthText = parsed.fields[2].restricted ? `day ${this._compactNumbers([...parsed.fields[2].values])} of month` : '';
      const weekdayText = parsed.fields[4].restricted ? this._weekdayNames(parsed.fields[4].values) : '';
      const dayText = dayOfMonthText && weekdayText ? `on ${dayOfMonthText} or ${weekdayText}` : dayOfMonthText ? `on ${dayOfMonthText}` : weekdayText ? `on ${weekdayText}` : 'every day';
      const monthText = parsed.fields[3].restricted ? ` in month ${this._compactNumbers([...parsed.fields[3].values])}` : '';
      return `${minuteText}, ${hourText}, ${dayText}${monthText}`;
    } catch (error) {
      return error.message;
    }
  }

  _nextRunPreview(automation) {
    let nextDate = null;
    (automation.triggers || []).forEach((trigger) => {
      if (trigger.type !== 'schedule') return;
      try {
        const candidate = this._findNextCron(this._parseCron(trigger.value));
        if (candidate && (!nextDate || candidate < nextDate) && (!trigger.expires || candidate <= new Date(`${trigger.expires}T23:59:59`))) nextDate = candidate;
      } catch (error) {
      }
    });
    const intervalValues = (automation.triggers || []).filter((trigger) => trigger.type === 'interval').map((trigger) => Number(trigger.value)).filter(Number.isFinite);
    if (!nextDate && intervalValues.length) return `Next interval check in about ${Math.min(...intervalValues)} ms.`;
    return nextDate ? `Next schedule match: ${nextDate.toLocaleString()}.` : 'Next run is not known.';
  }

  _findNextCron(parsed) {
    const candidate = new Date();
    candidate.setSeconds(0, 0);
    candidate.setMinutes(candidate.getMinutes() + 1);
    for (let minuteOffset = 0; minuteOffset < 527040; minuteOffset += 1) {
      const fields = parsed.fields;
      const baseMatches = fields[0].values.has(candidate.getMinutes()) && fields[1].values.has(candidate.getHours()) && fields[3].values.has(candidate.getMonth() + 1);
      const dayOfMonthMatches = fields[2].values.has(candidate.getDate());
      const weekdayMatches = fields[4].values.has(candidate.getDay());
      const dayMatches = fields[2].restricted && fields[4].restricted ? dayOfMonthMatches || weekdayMatches : dayOfMonthMatches && weekdayMatches;
      if (baseMatches && dayMatches) return new Date(candidate);
      candidate.setMinutes(candidate.getMinutes() + 1);
    }
    return null;
  }

  _automationPreview(automation) {
    const triggerText = this._triggerSummary(automation.triggers || []);
    const conditionText = this._conditionSummaryList(automation.conditions || []);
    return `${triggerText}${conditionText ? ` if ${conditionText}` : ''}, then ${automation.action || 'choose an action'}.`;
  }

  _triggerSummary(triggers) {
    if (!triggers.length) return 'No trigger';
    return triggers.map((trigger) => trigger.type === 'schedule' ? this._cronPreview(trigger.value) : this._intervalPreview(trigger.value)).join(' OR ');
  }

  _intervalPreview(value) {
    const interval = Number(value);
    return Number.isInteger(interval) && interval >= 1000 && interval < 60000 ? `Every ${interval} ms` : 'Interval must be 1000-59999 ms';
  }

  _conditionSummaryList(conditions) {
    return conditions.map((condition) => this._conditionSummary(condition)).join(' AND ');
  }

  _conditionSummary(condition) {
    if (condition.type === 'or') return `(${(condition.value || []).map((child) => this._conditionSummary(child)).join(' OR ')})`;
    if (condition.type === 'not') return `NOT ${this._conditionSummary(condition.value || {})}`;
    const labels = Object.fromEntries(this._conditionTypes().map((entry) => [entry.value, entry.label]));
    return `${labels[condition.type] || condition.type} ${condition.value}`;
  }

  _weekdayNames(values) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return [...values].sort((firstValue, secondValue) => firstValue - secondValue).map((dayValue) => names[dayValue]).join(', ');
  }

  _validDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(`${value || ''}`)) return false;
    const parsed = new Date(`${value}T00:00:00`);
    return !Number.isNaN(parsed.getTime()) && this._localDateText(parsed) === value;
  }

  _localDateText(date) {
    return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}-${`${date.getDate()}`.padStart(2, '0')}`;
  }

  _collectAvailableActions(state) {
    const actions = [];
    (state?.plugins?.pages || []).forEach((page) => (page.actions || []).forEach((action) => {
      const actionName = `${action.action || ''}`.trim();
      if (actionName && !actions.includes(actionName)) actions.push(actionName);
    }));
    return actions.sort((firstAction, secondAction) => firstAction.localeCompare(secondAction));
  }

  _actionName(actionString) {
    return `${actionString || ''}`.trim().match(/^([A-Za-z_][A-Za-z0-9_]*)\s*\(/)?.[1] || '';
  }

  _ensureConditionUiIds(value) {
    if (Array.isArray(value)) {
      value.forEach((condition) => this._ensureConditionUiIds(condition));
      return;
    }
    if (!value || typeof value !== 'object') return;
    if (!value._uiId) value._uiId = this._newUiId();
    if (value.type === 'or' && Array.isArray(value.value)) value.value.forEach((condition) => this._ensureConditionUiIds(condition));
    if (value.type === 'not') this._ensureConditionUiIds(value.value);
  }

  _stripUiFields(value) {
    if (Array.isArray(value)) return value.map((entry) => this._stripUiFields(entry));
    if (!value || typeof value !== 'object') return value;
    const result = {};
    Object.entries(value).forEach(([key, entry]) => {
      if (key !== '_uiId' && key !== 'validationErrors') result[key] = this._stripUiFields(entry);
    });
    return result;
  }

  _newId() {
    return `automation-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  }

  _newUiId() {
    return `condition-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  }

  _clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  _setMessage(message, kind = 'info') {
    this.message = `${message || ''}`;
    this.messageKind = kind;
  }

  _clearMessage() {
    this.message = '';
    this.messageKind = 'info';
  }

  _formatDuration(totalSeconds) {
    const safeSeconds = Math.max(0, Math.floor(Number(totalSeconds) || 0));
    const hours = Math.floor(safeSeconds / 3600);
    const minutes = Math.floor((safeSeconds % 3600) / 60);
    const seconds = safeSeconds % 60;
    return `${hours}:${`${minutes}`.padStart(2, '0')}:${`${seconds}`.padStart(2, '0')}`;
  }

  _formatTimestamp(timestamp) {
    const text = `${timestamp || ''}`;
    if (!/^\d{14}$/.test(text)) return text;
    return `${text.slice(0, 4)}-${text.slice(4, 6)}-${text.slice(6, 8)} ${text.slice(8, 10)}:${text.slice(10, 12)}:${text.slice(12, 14)}`;
  }

  _escape(value) {
    return `${value ?? ''}`.replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
  }
}

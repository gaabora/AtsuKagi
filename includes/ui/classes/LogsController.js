class LogsController {
  constructor(hostBridge) {
    this.hostBridge = hostBridge;
    this._logs = [];
    this._searchQuery = '';
    this._levelFilter = new Set([0, 1, 2, 3, 4]);
    this._showTime = false;
    this._container = null;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  mount(containerEl) {
    this._container = containerEl;
    this._render();
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  setLogs(entries) {
    this._logs = Array.isArray(entries) ? entries.map(this._normalizeEntry) : [];
    this._render();
  }

  appendLogs(entries) {
    if (!Array.isArray(entries) || !entries.length) return;
    this._logs = this._logs.concat(entries.map(this._normalizeEntry));
    const maxBuffer = 500;
    if (this._logs.length > maxBuffer) {
      this._logs = this._logs.slice(this._logs.length - maxBuffer);
    }
    this._render();
  }

  clear() {
    try {
      if (this.hostBridge && typeof this.hostBridge.clearLogs === 'function') {
        this.hostBridge.clearLogs();
      }
    } catch (error) {
      console.error('Failed to clear logs on host', error);
    }
    this._logs = [];
    this._render();
  }

  setSearchQuery(query) {
    this._searchQuery = `${query || ''}`.toLowerCase();
    this._render();
  }

  setLevelFilter(levels) {
    this._levelFilter = new Set(levels.map(Number));
    this._render();
  }

  setShowTime(show) {
    this._showTime = !!show;
    if (!this._container) return;
    this._container.classList.toggle('logs-show-time', this._showTime);
  }

  showProblemsOnly() {
    this.setLevelFilter([0, 1]);
  }

  // ── Internals ────────────────────────────────────────────────────────────────

  _normalizeEntry(entry) {
    if (!entry || typeof entry !== 'object') {
      return { id: -1, time: '', level: 4, text: `${entry}` };
    }
    return {
      id:    Number(entry.id ?? -1),
      time:  `${entry.time ?? ''}`,
      level: Number(entry.level ?? 4),
      text:  `${entry.text ?? ''}`
    };
  }

  static levelLabel(level) {
    switch (level) {
      case 0: return 'ERROR';
      case 1: return 'WARNING';
      case 2: return 'NOTICE';
      case 3: return 'INFO';
      default: return 'DEBUG';
    }
  }

  static levelClass(level) {
    switch (level) {
      case 0: return 'log-level-error';
      case 1: return 'log-level-warning';
      case 2: return 'log-level-notice';
      case 3: return 'log-level-info';
      default: return 'log-level-debug';
    }
  }

  _filtered() {
    return this._logs.filter((entry) => {
      if (!this._levelFilter.has(entry.level)) return false;
      if (this._searchQuery && !entry.text.toLowerCase().includes(this._searchQuery)) return false;
      return true;
    });
  }

  _render() {
    if (!this._container) return;
    const filtered = this._filtered();
    if (!filtered.length) {
      this._container.innerHTML = '<div class="logs-empty">No logs yet.</div>';
      return;
    }

    const fragment = document.createDocumentFragment();
    for (const entry of filtered) {
      fragment.appendChild(this._renderLine(entry));
    }
    this._container.innerHTML = '';
    this._container.appendChild(fragment);
    this._container.scrollTop = this._container.scrollHeight;
  }

  _renderLine(entry) {
    const div = document.createElement('div');
    div.className = `log-line ${LogsController.levelClass(entry.level)}`;
    div.dataset.logId = entry.id;

    const timeEl = document.createElement('span');
    timeEl.className = 'log-time';
    timeEl.textContent = entry.time;
    div.appendChild(timeEl);

    const badge = document.createElement('span');
    badge.className = 'log-level-badge';
    badge.textContent = LogsController.levelLabel(entry.level);
    div.appendChild(badge);

    const text = document.createElement('span');
    text.className = 'log-text';
    text.textContent = entry.text;
    div.appendChild(text);

    return div;
  }

  // ── Toolbar factory (call once after mounting) ────────────────────────────────

  buildToolbar(toolbarEl) {
    if (!toolbarEl) return;

    // Search
    const search = toolbarEl.querySelector('#logs-search');
    if (search) {
      let debounceTimer = 0;
      search.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => this.setSearchQuery(search.value), 200);
      });
    }

    // Level filter dropdown
    const filterBtn = toolbarEl.querySelector('#logs-filter-btn');
    const filterDropdown = toolbarEl.querySelector('#logs-filter-dropdown');
    if (filterBtn && filterDropdown) {
      filterBtn.addEventListener('click', (ev) => {
        ev.stopPropagation();
        filterDropdown.classList.toggle('open');
      });
      document.addEventListener('click', () => filterDropdown.classList.remove('open'));

      const checkboxes = filterDropdown.querySelectorAll('input[type="checkbox"][data-level]');
      const updateFilter = () => {
        const active = [];
        checkboxes.forEach((cb) => { if (cb.checked) active.push(Number(cb.dataset.level)); });
        this.setLevelFilter(active);
        filterBtn.textContent = active.length === 5
          ? 'All levels ▾'
          : active.map((l) => LogsController.levelLabel(l)).join(', ') + ' ▾';
      };
      checkboxes.forEach((cb) => cb.addEventListener('change', updateFilter));
    }

    // Show time toggle
    const showTime = toolbarEl.querySelector('#logs-show-time');
    if (showTime) {
      showTime.addEventListener('change', () => this.setShowTime(showTime.checked));
    }

    // Clear button
    const clearBtn = toolbarEl.querySelector('#logs-clear');
    if (clearBtn) {
      clearBtn.addEventListener('click', () => this.clear());
    }
  }
}

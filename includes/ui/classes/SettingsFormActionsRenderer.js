class SettingsFormActionsRenderer {
  constructor(form) {
    this.form = form;
  }

  renderPluginActionsSummary(pluginId, actions) {
    const grouped = new Map();
    (actions || []).forEach((action) => {
      const category = action.category || 'Actions';
      if (!grouped.has(category)) grouped.set(category, []);
      grouped.get(category).push(action);
    });

    let html = '<div class="setting-group plugin-actions-summary"><h3>Actions</h3>';
    grouped.forEach((items, category) => {
      html += `<div class="plugin-action-category"><div class="plugin-action-category-title">${this.form._escapeHtml(category)}</div>`;
      items.forEach((item) => {
        const actionName = `${item?.action || ''}`;
        const hotkeys = this.form.getHotkeysForAction(actionName);
        const hotkeysHtml = hotkeys.length
          ? hotkeys.map((hk) => this.renderActionHotkeyBadge(pluginId, actionName, hk)).join('')
          : this.renderActionHotkeyBadge(pluginId, actionName, '');
        html += `
          <div class="plugin-action-item" data-plugin-id="${this.form._escapeHtml(pluginId || '')}" data-action-name="${this.form._escapeHtml(actionName)}">
            <div class="plugin-action-head">
              <div class="plugin-action-name">${this.form._escapeHtml(item.label || item.action || '')}</div>
              <div class="plugin-action-description">${this.form._escapeHtml(item.description || '')}</div>
            </div>
            <div class="plugin-action-hotkeys">${hotkeysHtml}</div>
          </div>
        `;
      });
      html += '</div>';
    });
    html += '</div>';

    return html;
  }

  renderActionHotkeyBadge(pluginId, actionName, hotkeyRaw) {
    const readable = AK_HumanizeAhkHotkey(hotkeyRaw);
    const fullActionHandler = hotkeyRaw ? this.form.getFullActionHandlerForHotkey(hotkeyRaw) : '';
    const defaultHotkey = this.form.getDefaultHotkeyForAction(actionName);
    const emptyClass = hotkeyRaw ? '' : ' plugin-hotkey-badge-empty';
    return `
      <button
        type="button"
        class="app-btn plugin-hotkey-badge${emptyClass}"
        data-hotkey-action="${this.form._escapeHtml(actionName)}"
        data-hotkey-action-full="${this.form._escapeHtml(fullActionHandler)}"
        data-hotkey-current="${this.form._escapeHtml(hotkeyRaw)}"
        data-hotkey-default="${this.form._escapeHtml(defaultHotkey)}"
        data-plugin-id="${this.form._escapeHtml(pluginId || '')}"
        data-win-toggle="modal"
        data-win-target="#HotkeyRecorderDialog"
      >
        <span class="plugin-hotkey-badge-label">${this.form._escapeHtml(readable || hotkeyRaw) || 'assign'}</span>
        ${hotkeyRaw ? `<span class="hotkey-badge-remove" data-hotkey-remove="${this.form._escapeHtml(hotkeyRaw)}">&times;</span>` : ''}
      </button>
    `;
  }

  syncPluginActionHotkeys() {
    document.querySelectorAll('.plugin-action-item').forEach((item) => {
      const pluginId = `${item.getAttribute('data-plugin-id') || ''}`;
      const actionName = `${item.getAttribute('data-action-name') || ''}`;
      const host = item.querySelector('.plugin-action-hotkeys');
      if (!host || !actionName) return;

      const hotkeys = this.form.getHotkeysForAction(actionName);
      if (!hotkeys.length) {
        host.innerHTML = this.renderActionHotkeyBadge(pluginId, actionName, '');
        return;
      }
      host.innerHTML = hotkeys.map((hk) => this.renderActionHotkeyBadge(pluginId, actionName, hk)).join('');
    });
  }
}

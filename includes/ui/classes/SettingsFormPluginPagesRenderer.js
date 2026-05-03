class SettingsFormPluginPagesRenderer {
  constructor(form) {
    this.form = form;
  }

  renderPluginSettingsPages(pages) {
    const nav = document.querySelector('.settings-nav');
    const content = document.querySelector('.settings-content');
    if (!nav || !content) return;

    const sortedPages = [...(pages || [])].filter((page) => page && page.id).sort((a, b) => {
      const ao = Number.isFinite(Number(a?.navOrder)) ? Number(a.navOrder) : 100;
      const bo = Number.isFinite(Number(b?.navOrder)) ? Number(b.navOrder) : 100;
      if (ao !== bo) return ao - bo;
      return String(a?.title || a?.id || '').localeCompare(String(b?.title || b?.id || ''));
    });

    const wantedPageIds = new Set(sortedPages.map((page) => `${page.id}`));

    nav.querySelectorAll('[data-dynamic-plugin="1"]').forEach((el) => {
      const sectionName = `${el.getAttribute('data-section') || ''}`;
      const pageId = sectionName.startsWith('plugin-') ? sectionName.slice(7) : '';
      if (!wantedPageIds.has(pageId)) {
        el.remove();
      }
    });

    content.querySelectorAll('[data-dynamic-plugin="1"]').forEach((el) => {
      const id = `${el.id || ''}`;
      const pageId = id.startsWith('section-plugin-') ? id.slice('section-plugin-'.length) : '';
      if (!wantedPageIds.has(pageId)) {
        el.remove();
      }
    });

    const pluginsBtn = nav.querySelector('[data-section="plugins"]');
    const hotkeysBtn = nav.querySelector('[data-section="hotkeys"]');

    for (let i = sortedPages.length - 1; i >= 0; i -= 1) {
      const page = sortedPages[i];
      const pageId = `${page.id}`;
      const navSelector = `[data-dynamic-plugin="1"][data-section="plugin-${CSS.escape(pageId)}"]`;
      let navItem = nav.querySelector(navSelector);
      if (!navItem) {
        navItem = document.createElement('button');
        navItem.className = 'nav-item';
        navItem.setAttribute('data-section', `plugin-${pageId}`);
        navItem.setAttribute('data-dynamic-plugin', '1');
      }

      const navSig = SettingsFormSerializer.signature({
        id: pageId,
        title: page.title || page.id || '',
        icon: page.icon || 'icons10-puzzle'
      });

      if (navItem.dataset.navSig !== navSig) {
        navItem.innerHTML = `<i class="${this.form._escapeHtml(page.icon || 'icons10-puzzle')}"></i><span>${this.form._escapeHtml(page.title || page.id)}</span>`;
        navItem.dataset.navSig = navSig;
      }

      if (pluginsBtn && hotkeysBtn) {
        pluginsBtn.parentNode.insertBefore(navItem, hotkeysBtn);
      } else if (pluginsBtn) {
        pluginsBtn.parentNode.appendChild(navItem);
      }
    }

    sortedPages.forEach((page) => {
      const pageId = `${page.id}`;
      const sectionId = `section-plugin-${pageId}`;
      let section = document.getElementById(sectionId);
      if (!section) {
        section = document.createElement('div');
        section.id = sectionId;
        section.className = 'settings-section';
        section.setAttribute('data-dynamic-plugin', '1');
      }

      this._upsertPluginPage(section, page);
      content.appendChild(section);
    });

    if (!this.form._isPluginResetAllBound) {
      this.form._isPluginResetAllBound = true;
      document.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-plugin-reset-all]');
        if (!btn) return;
        e.preventDefault();
        const pluginId = btn.getAttribute('data-plugin-reset-all');
        this.form._resetPluginFields(pluginId);
      });
    }
  }

  _upsertPluginPage(section, page) {
    if (!section || !page) return;

    const pageId = `${page.id || ''}`;
    if (!pageId) return;

    const shell = this._ensurePluginPageShell(section);
    const headerSig = SettingsFormSerializer.signature({
      id: pageId,
      title: page.title || page.id || '',
      description: page.description || '',
      enabled: !!page.enabled
    });

    const sectionsOrderSig = SettingsFormSerializer.signature((page.sections || []).map((sec, idx) => ({
      id: `${sec?.id || sec?.title || `section-${idx}`}`,
      title: `${sec?.title || sec?.id || ''}`
    })));

    const actionsSig = SettingsFormSerializer.signature(page.actions || []);

    if (shell.header.dataset.sig !== headerSig) {
      shell.header.innerHTML = this._renderPluginHeaderHtml(page);
      shell.header.dataset.sig = headerSig;
    }

    if (shell.sections.dataset.orderSig !== sectionsOrderSig) {
      shell.sections.dataset.orderSig = sectionsOrderSig;
    }

    this._reconcilePluginSections(shell.sections, page);

    if (shell.actions.dataset.sig !== actionsSig) {
      shell.actions.innerHTML = (page.actions && page.actions.length > 0)
        ? this.form._renderPluginActionsSummary(pageId, page.actions)
        : '';
      shell.actions.dataset.sig = actionsSig;
    }

    const resetSig = pageId;
    if (shell.footer.dataset.sig !== resetSig) {
      shell.footer.innerHTML = `
        <div class="setting-group">
          <button type="button" class="app-btn app-btn-outline-danger" data-plugin-reset-all="${this.form._escapeHtml(pageId)}">Reset All</button>
        </div>
      `;
      shell.footer.dataset.sig = resetSig;
    }
  }

  _ensurePluginPageShell(section) {
    let header = section.querySelector(':scope > [data-plugin-slot="header"]');
    let sections = section.querySelector(':scope > [data-plugin-slot="sections"]');
    let actions = section.querySelector(':scope > [data-plugin-slot="actions"]');
    let footer = section.querySelector(':scope > [data-plugin-slot="footer"]');

    if (!header) {
      header = document.createElement('div');
      header.setAttribute('data-plugin-slot', 'header');
      section.appendChild(header);
    }
    if (!sections) {
      sections = document.createElement('div');
      sections.setAttribute('data-plugin-slot', 'sections');
      section.appendChild(sections);
    }
    if (!actions) {
      actions = document.createElement('div');
      actions.setAttribute('data-plugin-slot', 'actions');
      section.appendChild(actions);
    }
    if (!footer) {
      footer = document.createElement('div');
      footer.setAttribute('data-plugin-slot', 'footer');
      section.appendChild(footer);
    }

    return { header, sections, actions, footer };
  }

  _renderPluginHeaderHtml(page) {
    return `
      <div class="setting-group">
        <div class="plugin-page-header">
          <div class="plugin-header-info">
            <h2>${this.form._escapeHtml(page.title || page.id)}</h2>
            <p class="subtitle">${this.form._escapeHtml(page.description || '')}</p>
            ${!page.enabled ? '<div class="plugin-disabled-badge">Plugin is disabled</div>' : ''}
          </div>
        </div>
      </div>
    `;
  }

  _reconcilePluginSections(container, page) {
    if (!container) return;

    const sections = page?.sections || [];
    const wantedIds = new Set();

    sections.forEach((sec, idx) => {
      const secId = `${sec?.id || sec?.title || `section-${idx}`}`;
      wantedIds.add(secId);
    });

    container.querySelectorAll(':scope > .setting-group[data-plugin-section-id]').forEach((el) => {
      const id = `${el.getAttribute('data-plugin-section-id') || ''}`;
      if (!wantedIds.has(id)) {
        el.remove();
      }
    });

    sections.forEach((sec, idx) => {
      const secId = `${sec?.id || sec?.title || `section-${idx}`}`;
      const selector = `:scope > .setting-group[data-plugin-section-id="${CSS.escape(secId)}"]`;
      let secEl = container.querySelector(selector);
      if (!secEl) {
        secEl = document.createElement('div');
        secEl.className = 'setting-group';
        secEl.setAttribute('data-plugin-section-id', secId);
      }

      let titleEl = secEl.querySelector(':scope > h3[data-role="section-title"]');
      if (!titleEl) {
        titleEl = document.createElement('h3');
        titleEl.setAttribute('data-role', 'section-title');
        secEl.appendChild(titleEl);
      }

      const titleText = `${sec?.title || sec?.id || ''}`;
      if (titleEl.textContent !== titleText) {
        titleEl.textContent = titleText;
      }

      let fieldsHost = secEl.querySelector(':scope > [data-role="section-fields"]');
      if (!fieldsHost) {
        fieldsHost = document.createElement('div');
        fieldsHost.setAttribute('data-role', 'section-fields');
        secEl.appendChild(fieldsHost);
      }

      this._reconcilePluginFieldRows(fieldsHost, sec?.fields || [], page.id);
      container.appendChild(secEl);
    });
  }

  _reconcilePluginFieldRows(fieldsHost, fields, pageId) {
    const wantedKeys = new Set();
    (fields || []).forEach((field, idx) => {
      const key = `${field?.key || `field-${idx}`}`;
      wantedKeys.add(key);
    });

    fieldsHost.querySelectorAll(':scope > .plugin-setting-row[data-plugin-field-key]').forEach((row) => {
      const key = `${row.getAttribute('data-plugin-field-key') || ''}`;
      if (!wantedKeys.has(key)) {
        row.remove();
        this.form._rowOpsRemoves = (this.form._rowOpsRemoves || 0) + 1;
      }
    });

    (fields || []).forEach((field, idx) => {
      const key = `${field?.key || `field-${idx}`}`;
      const selector = `:scope > .plugin-setting-row[data-plugin-field-key="${CSS.escape(key)}"]`;
      let row = fieldsHost.querySelector(selector);
      const nextSig = this.form._pluginFieldSignature(field);

      if (!row) {
        row = this._createElementFromHtml(this.form._renderField(field, 'plugin', pageId));
        this.form._rowOpsAdds = (this.form._rowOpsAdds || 0) + 1;
      } else {
        const currentSig = `${row.getAttribute('data-plugin-field-sig') || ''}`;
        if (currentSig !== nextSig) {
          const replacement = this._createElementFromHtml(this.form._renderField(field, 'plugin', pageId));
          row.replaceWith(replacement);
          row = replacement;
          this.form._rowOpsReplaces = (this.form._rowOpsReplaces || 0) + 1;
        }
      }

      fieldsHost.appendChild(row);
    });
  }

  _createElementFromHtml(html) {
    const tpl = document.createElement('template');
    tpl.innerHTML = `${html || ''}`.trim();
    return tpl.content.firstElementChild;
  }
}

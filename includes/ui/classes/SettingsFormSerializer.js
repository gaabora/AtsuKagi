class SettingsFormSerializer {
  static buildStateSignatures(state) {
    if (!state) {
      return {
        generalSchema: '',
        generalValues: '',
        pluginList: '',
        pluginPagesSchema: '',
        pluginFieldValues: '',
        hotkeys: '',
        theme: '',
        title: ''
      };
    }

    return {
      generalSchema: SettingsFormSerializer.signature(SettingsFormSerializer.stripGeneralValues(state.generalPage)),
      generalValues: SettingsFormSerializer.signature(SettingsFormSerializer.extractGeneralValues(state.generalPage)),
      pluginList: SettingsFormSerializer.signature({
        available: state?.plugins?.available || [],
        disabled: state?.plugins?.disabled || []
      }),
      pluginPagesSchema: SettingsFormSerializer.signature(SettingsFormSerializer.stripPluginPageValues(state?.plugins?.pages || [])),
      pluginFieldValues: SettingsFormSerializer.signature(SettingsFormSerializer.extractPluginFieldValues(state?.plugins?.pages || [])),
      hotkeys: SettingsFormSerializer.signature(state.hotkeys || []),
      theme: `${state.theme ?? ''}`,
      title: `${state.title ?? ''}`
    };
  }

  static signature(value) {
    return JSON.stringify(SettingsFormSerializer.toStableValue(value));
  }

  static toStableValue(value) {
    if (Array.isArray(value)) {
      return value.map((item) => SettingsFormSerializer.toStableValue(item));
    }
    if (!value || typeof value !== 'object') {
      return value;
    }

    const out = {};
    Object.keys(value).sort().forEach((key) => {
      out[key] = SettingsFormSerializer.toStableValue(value[key]);
    });
    return out;
  }

  static stripGeneralValues(page) {
    if (!page) return null;
    return {
      id: page.id || '',
      title: page.title || '',
      description: page.description || '',
      icon: page.icon || '',
      navOrder: page.navOrder || 0,
      enableDynamicRender: !!page.enableDynamicRender,
      sections: (page.sections || []).map((section) => ({
        id: section?.id || '',
        title: section?.title || '',
        fields: (section?.fields || []).map((field) => ({
          key: field?.key || '',
          pluginId: field?.pluginId || '',
          label: field?.label || '',
          description: field?.description || '',
          type: field?.type || '',
          control: field?.control || '',
          default: field?.default ?? '',
          scope: field?.scope || '',
          validation: field?.validation || {},
          options: field?.options || []
        }))
      }))
    };
  }

  static extractGeneralValues(page) {
    const out = {};
    if (!Array.isArray(page?.sections)) return out;
    page.sections.forEach((section) => {
      (section?.fields || []).forEach((field) => {
        const key = `${field?.key || ''}`.trim();
        if (!key) return;
        out[key] = field && Object.prototype.hasOwnProperty.call(field, 'value') ? field.value : '';
      });
    });
    return out;
  }

  static stripPluginPageValues(pages) {
    return (pages || []).map((page) => ({
      id: page?.id || '',
      title: page?.title || '',
      description: page?.description || '',
      icon: page?.icon || '',
      enabled: !!page?.enabled,
      navOrder: page?.navOrder || 0,
      sections: (page?.sections || []).map((section) => ({
        id: section?.id || '',
        title: section?.title || '',
        fields: (section?.fields || []).map((field) => ({
          key: field?.key || '',
          pluginId: field?.pluginId || '',
          label: field?.label || '',
          description: field?.description || '',
          type: field?.type || '',
          control: field?.control || '',
          default: field?.default ?? '',
          scope: field?.scope || '',
          validation: field?.validation || {},
          options: field?.options || []
        }))
      })),
      actions: page?.actions || []
    }));
  }

  static extractPluginFieldValues(pages) {
    const out = {};
    (pages || []).forEach((page) => {
      const pageId = `${page?.id || ''}`;
      if (!pageId) return;
      out[pageId] = {};
      (page?.sections || []).forEach((section) => {
        (section?.fields || []).forEach((field) => {
          const key = `${field?.key || ''}`.trim();
          if (!key) return;
          out[pageId][key] = field && Object.prototype.hasOwnProperty.call(field, 'value') ? field.value : '';
        });
      });
    });
    return out;
  }
}
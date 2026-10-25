window.createSettingsDevData = (scenario) => {
  const createAutomation = (id, name, action, triggers, conditions = []) => ({
    id, name, action, triggers, conditions, enabled: true,
    options: { catchUp: false, conditionMode: 'each-trigger', logRuns: true, notifyOnError: false, showInTray: false }
  });
  const automations = [
    createAutomation('work-hours', 'Keep awake during work hours', 'PreventSleep()', [{ type: 'schedule', value: '* 8-17 * * 1-5' }], [{ type: 'idle', value: 10000 }]),
    createAutomation('battery', 'Low battery warning', 'ShowLowBatteryOsd()', [{ type: 'interval', value: 30000 }], [{ type: 'battery-percent-at-most', value: 15 }]),
    createAutomation('night', 'Start fake screensaver at night', 'StartFakeScreensaver()', [{ type: 'schedule', value: '0 23 * * *' }])
  ];
  automations[1].options.conditionMode = 'on-enter';
  automations[2].enabled = false;
  if (scenario === 'long') {
    automations[0].name = 'Keep the computer awake during a long work session with several applications and remote windows';
    automations[0].action = 'DismissMatchingWindows(ahk_exe ExampleApplicationWithAVeryLongName.exe, {Escape})';
  }
  if (scenario === 'invalid') {
    automations[0].enabled = false;
    automations[0].triggers[0].value = 'invalid schedule';
    automations[0].validationErrors = ['Schedule must contain five fields.'];
  }
  const field = (key, label, type, control, value) => ({ key, label, type, control, value, default: value });
  const page = {
    id: 'Automations', title: 'Automations', description: 'Run actions on a schedule or when conditions match.', enabled: true,
    sections: [{ id: 'scheduler', title: 'Scheduler', fields: [
      field('SchedulerEnabled', 'Enable scheduler', 'boolean', 'switch', true),
      { ...field('PollingIntervalMs', 'Polling interval, ms', 'integer', 'number', 1000), validation: { min: 1000 } }
    ] }], actions: []
  };
  return {
    state: {
      title: 'Haribol! - Browser preview', theme: 'light',
      generalPage: { sections: [{ title: 'Browser preview', fields: [] }] },
      plugins: { available: ['Automations'], disabled: [], pages: [page], debugLevels: {}, globalDebugLevel: 0 },
      hotkeys: [], defaultActionHotkeys: {}, logs: []
    },
    automations: scenario === 'empty' ? [] : automations,
    runtime: { running: true, battery: { hasBattery: true, percent: 42, charging: false, powerSource: 'battery' }, automations: {} }
  };
};

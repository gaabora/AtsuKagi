/**
 * DevTools Console Utilities for AHK Settings State Export/Import
 * 
 * Usage in browser DevTools console:
 *   1. exportAhkState()           // logs JSON to console, copy to clipboard
 *   2. importAhkState(jsonString) // pastes and applies state
 * 
 * Example:
 *   let state = exportAhkState();
 *   // Copy output, switch to another browser
 *   importAhkState('{"general": {...}, ...}')
 */

(function() {
  const AhkStateExport = {
    /**
     * Export current form state to JSON
     * @returns {Object} Current state object
     */
    exportState() {
      if (!window.settingsPage || !window.settingsPage.form) {
        const msg = 'Settings form not available. Ensure settings dialog is fully loaded.';
        console.error(msg);
        alert(msg);
        return null;
      }

      const state = window.settingsPage.form.serializeObject();
      const json = JSON.stringify(state, null, 2);
      
      console.log('=== AHK State Export ===');
      console.log(json);
      console.log('======================');
      console.log('State copied to console above. Right-click → Copy → paste in another browser.');
      
      return state;
    },

    /**
     * Import state from JSON and apply to form
     * @param {string|Object} stateJson - JSON string or object to import
     * @returns {boolean} true if successful
     */
    importState(stateJson) {
      if (!window.settingsPage || !window.settingsPage.form) {
        const msg = 'Settings form not available. Ensure settings dialog is fully loaded.';
        console.error(msg);
        alert(msg);
        return false;
      }

      try {
        const state = typeof stateJson === 'string' ? JSON.parse(stateJson) : stateJson;
        
        // Apply general config
        if (state.general) {
          for (const [key, value] of Object.entries(state.general)) {
            const field = document.getElementById(key);
            if (field) {
              field.value = value;
              field.dispatchEvent(new Event('input'));
              field.dispatchEvent(new Event('change'));
            } else {
              console.warn(`Field not found: ${key}`);
            }
          }
        }

        // Apply disabled plugins
        if (state.disabledPlugins) {
          const disabledCheckbox = document.getElementById('DisabledPlugins');
          if (disabledCheckbox) {
            disabledCheckbox.value = state.disabledPlugins.join(',');
            disabledCheckbox.dispatchEvent(new Event('change'));
          }
        }

        // Apply plugin configs
        if (state.pluginConfigs) {
          for (const [pluginId, config] of Object.entries(state.pluginConfigs)) {
            for (const [key, value] of Object.entries(config)) {
              const fieldId = `${pluginId}_${key}`;
              const field = document.getElementById(fieldId);
              if (field) {
                field.value = value;
                field.dispatchEvent(new Event('input'));
                field.dispatchEvent(new Event('change'));
              } else {
                console.warn(`Field not found: ${fieldId}`);
              }
            }
          }
        }

        // Apply hotkeys
        if (state.hotkeys) {
          state.hotkeys.forEach((hotkey) => {
            // Reconstructed hotkey entry - find matching field and update
            // Format: { action, target, value, isPluginAction }
            const targetField = document.getElementById(hotkey.target);
            if (targetField) {
              targetField.value = hotkey.value;
              targetField.dispatchEvent(new Event('input'));
              targetField.dispatchEvent(new Event('change'));
            } else {
              console.warn(`Hotkey field not found: ${hotkey.target}`);
            }
          });
        }

        console.log('✓ State imported successfully. Scroll to verify all fields.');
        return true;
      } catch (err) {
        console.error('Failed to import state:', err.message);
        return false;
      }
    },

    /**
     * Export state and copy to clipboard automatically
     * @returns {void}
     */
    exportToClipboard() {
      if (!window.settingsPage || !window.settingsPage.form) {
        console.error('Settings form not available. Ensure settings dialog is fully loaded.');
        return;
      }

      const state = window.settingsPage.form.serializeObject();
      const json = JSON.stringify(state, null, 2);
      
      navigator.clipboard.writeText(json).then(() => {
        console.log('✓ State copied to clipboard!');
        console.log('Paste it in another browser using: importAhkState(...)');
      }).catch(err => {
        console.error('Clipboard access failed:', err);
        console.log('Manual copy: ', json);
      });
    },

    /**
     * Compare two states and show differences
     * @param {Object|string} state1 - First state
     * @param {Object|string} state2 - Second state
     */
    compareStates(state1, state2) {
      try {
        const s1 = typeof state1 === 'string' ? JSON.parse(state1) : state1;
        const s2 = typeof state2 === 'string' ? JSON.parse(state2) : state2;
        
        console.log('=== State Comparison ===');
        
        const getKeys = (obj) => {
          const keys = new Set();
          const walk = (o) => {
            for (const k in o) {
              keys.add(k);
              if (typeof o[k] === 'object' && o[k] !== null) walk(o[k]);
            }
          };
          walk(obj);
          return Array.from(keys);
        };

        const allKeys = new Set([...getKeys(s1), ...getKeys(s2)]);
        const differences = [];

        for (const key of allKeys) {
          const v1 = JSON.stringify(s1[key]);
          const v2 = JSON.stringify(s2[key]);
          if (v1 !== v2) {
            differences.push({
              key,
              state1: s1[key],
              state2: s2[key]
            });
          }
        }

        if (differences.length === 0) {
          console.log('✓ States are identical');
        } else {
          console.log(`Found ${differences.length} differences:`);
          console.table(differences);
        }
      } catch (err) {
        console.error('Failed to compare states:', err.message);
      }
    }
  };

  // Global aliases for convenience
  window.exportAhkState = () => AhkStateExport.exportState();
  window.importAhkState = (json) => AhkStateExport.importState(json);
  window.exportAhkStateToClipboard = () => AhkStateExport.exportToClipboard();
  window.compareAhkStates = (s1, s2) => AhkStateExport.compareStates(s1, s2);
  
  // Also expose the main object
  window.AhkStateExport = AhkStateExport;

  console.log('✓ AHK State Export loaded. Use: exportAhkState(), importAhkState(json), exportAhkStateToClipboard(), compareAhkStates(s1,s2)');
})();

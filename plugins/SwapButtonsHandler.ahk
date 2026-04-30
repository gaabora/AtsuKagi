class SwapButtonsHandler extends AKPlugin { ; TODO: not yet implemented. some mouses have x1 and x2 (4th and 5th) buttons in different order from the thumb, need to think how is better to override all those mouse buttons to hotkey mapping, maybe better just in global/app config, or in a built-in plugin
  ; ── Descriptor API (Phase 1+) ─────────────────────────────────────────────────
  __DescribePlugin() {
    return Map(
      "plugin", Map(
        "id", "SwapButtonsHandler",
        "title", "Swap Buttons Handler",
        "description", "Mouse button remapping and layout switching. Remap mouse buttons X1/X2 (4th and 5th buttons) for different mouse types.",
        "icon", "icons10-mouse",
        "category", "Input Management"
      ),
      "settingsPage", Map(
        "description", "Configure mouse button remapping and quick layout switching.",
        "icon", "icons10-mouse"
      ),
      "config", [],
      "actions", [],
      "hooks", []
    )
  }

  ; ── Legacy Methods (Phase 1-5: TODO: remove after Phase 5) ─────────────────────
  ; These are now derived from __DescribePlugin() by the base class
  _processBlocklistConfig() {
  }

  _processPluginConfig() {
    ; No plugin-specific config to apply
  }


}
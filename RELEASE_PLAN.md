# Haribol! Release Organization Plan

## Goal
Prepare the project for a clean v1 release by standardizing plugin/action naming, documenting behavior, reducing risk in unfinished plugins, and shipping a simple user-first README.

## Scope
This plan is based on current structure and code in `includes/` and `plugins/`.

## Current Snapshot
- Core architecture is strong: `AKApp` + `AKPlugin` provide a good plugin system and hotkey-action routing.
- Main value features are already present: window management, virtual desktops, layout switching, touch gesture simulation.
- Release blockers are mostly documentation, naming consistency, and incomplete/untested plugins.

## Release Task Plan

### Phase 1: Stabilize and Decide (must do)
- [ ] Decide status for incomplete plugins:
  - `TimerHandlers`: complete it so it can be used by other plugins, like low battery alert - some half transparent animation-osd that watches trend of battery discharge and alert at some percent or time remaining (consider also windows thresholds for sleep/hibernate, so it can say LOW BATTERY! sleep after 5 min) update interval 15s; "bedtime routine" get somehow and show how long (h:mm:ss) until auto sleep, maybe same as low battery alert. and add ability to quicly easily set time after what pc can go sleep (actively prevent sleep before that time (by sending 'shift' key), except battery low) and some default settable in settings active hours for days of week/other cron-like rules
  - `TextToSpeech`: mark experimental and disable by default.
  - `SwapButtonsHandler`: complete now
- [ ] Verify untested plugins and either stabilize or keep disabled with clear note:
  - `RDPWindowHandler`
  - `ShellMessageHook`
- [x] Add explicit error handling around DLL/external dependency calls in:
  - `VirtualDesktopManager`
  - `TouchGesturesSimulator`
- [x] Add startup diagnostics summary (enabled plugins, loaded actions, bound hotkeys). display it in ui (includes\ui\settings.html) on new 'logs' tab
- [x] Add config validation pass before hotkey bind (invalid keys/actions should warn clearly). display it in ui (includes\ui\settings.html) on new 'problems' tab

### Phase 2: Action Naming and API Hygiene (must do)
- [x] Adopt one action naming convention: `VerbNoun` or `VerbNounQualifier`.
- [x] Keep action names user-oriented and command-like (for hotkey mapping clarity).
- [x] Avoid generic/ambiguous names; rename where needed (example: consider `RemapTo` -> `RemapKeyTo`).
- [x] Add collision check on action registration (same action name in multiple plugins should warn/fail fast).
- [x] Add a short deprecation map for renamed actions so old configs keep working for one release cycle.

### Phase 3: Plugin and Action Documentation (must do)
- [x] Implement plugin metadata methods (`AKPlugin` base class already provides templates) docs must be in simple language for even beginner users and pretty compact and descriptive. if method is descriptive:
  - `__ConfigHelp()`: return string describing config keys used (section, key names, purpose)
  - `__UsageHelp()`: return string with typical usage pattern and main feature description
  - `__ActionsHelp()`: return Map of `actionName => "actionName(params) description"` for user-callable actions
  - `__HooksHelp()`: return array of `["HookName(params): description", ...]` for internal hooks registered via `RegisterHook()`
  - These methods are used to populate plugin docs in settings UI and generate `ACTION_CATALOG.md`
- [x] Implement all helper methods in each plugin (`VirtualDesktopManager`, `WindowManager`, `TimerHandlers`, `TextToSpeech`, `ShellMessageHook`, `TouchGesturesSimulator`, `SwapButtonsHandler`, `RDPWindowHandler`, `KDEMoverSizer`)
- [x] Introduce `ACTION_CATALOG.md` auto-generated from all `__ActionsHelp()` methods (some .bat or .py file that can also be CI/CD task or manual build step)
- [x] Document **blocklist** concept in one place (`ARCHITECTURE.md` or `PLUGIN_API.md`):
  - **Blocklist**: config-driven list of window classes/titles that a plugin ignores (skips its actions)
  - Examples: `NoMoveResize` blocklist means "don't move/resize windows with these titles"
  - Mention where it's used: `SkipIfBlocklisted` action checks a window's class/title and returns early if blocklisted
  - Keep language simple: "excludes certain windows from being affected by this plugin"
- [x] Add plugin authoring guide (`PLUGIN_API.md`) with copy-paste template including:
  - class stub with `__ConfigHelp()`, `__UsageHelp()`, `__ActionsHelp()`, `__HooksHelp()`
  - one simple action example
  - one hook registration example
  - note on testing with `app.LoadPlugin()`

### Phase 4: README Overhaul (must do)
- [x] Replace `README.txt` with a clean `README.md` focused on users.
- [x] Keep README short and practical:
  - What Haribol! is
  - Why it is useful
  - Top features
  - Quick start
  - How to configure hotkeys/plugins
  - Troubleshooting basics
- [x] Add a compact plugin status table (Stable / Experimental / Disabled by default).
- [x] Add 6-10 real hotkey examples from default config.

### Phase 5: Test and Ship Readiness (should do)
- [ ] Expand tests beyond `IniFileTests`:
  - action registration test
  - hotkey parse/bind test
  - plugin enable/disable config test
- [ ] Add a smoke test checklist for manual QA:
  - startup
  - reload
  - suspend toggle
  - tray actions
  - 1-2 actions per stable plugin
- [ ] Build an `.exe` with current build task and run regression smoke tests on the binary.

## Action Naming Rules (for docs and config)
Use these prefixes consistently:
- `Toggle*`: binary state changes (`ToggleWindowMaximized`, `ToggleWindowOnTop`)
- `Show*`: UI/info display (`ShowWindowInfo`)
- `Enter*`: mode transitions (`EnterGestureMode`, `EnterWindowMovingMode`)
- `Switch*` or `GoTo*`: navigation/state target (`SwitchKeyboardLayout`, `GoToDesktop`)
- `Increase*` / `Decrease*`: bounded numeric adjustments (transparency, volume, etc.)
- `Set*`: explicit value setters (`SetDesktopName`)
- `Run*`: higher-level orchestration actions

Rules:
- Keep names short, concrete, and imperative.
- Prefer full words over abbreviations unless universally obvious.
- Keep one name per behavior; avoid aliases unless deprecating old names.

## Action Documentation Template
Use this for each documented action:

```md
### ActionName(param1, param2)
Purpose: One-line description.
Used for: Typical user workflow.
Parameters:
- `param1` (type, default): meaning
- `param2` (type, default): meaning
Config dependencies: `[Section] KeyName` (if any)
Blocklist interaction: none | uses `NoMoveResize` | custom
Side effects: window state, input send, desktop switch, etc.
Example hotkey mapping: `#Enter=ActionName()`
```

## README Blueprint (simple and clear)
Use this structure for the new `README.md`:
1. Project title + one-paragraph value statement.
2. Top features (5-7 bullets, user language).
3. Quick start (install AHK v2, run script, open settings).
4. Configuration basics (`config.ini`, plugin enable/disable, hotkeys).
5. Plugin overview table (Name | Purpose | Status).
6. Example hotkeys block.
7. Troubleshooting quick section.
8. Links to advanced docs (`PLUGIN_API.md`, `ACTION_CATALOG.md`).

## Suggested Milestones
- Milestone 1: plugin status decisions + safety/error handling.
- Milestone 2: naming cleanup + compatibility aliases.
- Milestone 3: docs set (`README.md`, `PLUGIN_API.md`, `ACTION_CATALOG.md`).
- Milestone 4: tests, smoke QA, build/release packaging.

## Definition of Ready for Release
All items below should be true:
- Stable plugin set is explicitly declared.
- No known TODO/FIXME in stable plugins without tracked issue.
- Action names follow one convention and are documented.
- README is clear enough for first-time users to install and run in under 10 minutes.
- Basic tests and manual smoke checklist pass on script and built binary.

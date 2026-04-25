# AtsuiKagi Release Organization Plan

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
- [ ] Adopt one action naming convention: `VerbNoun` or `VerbNounQualifier`.
- [ ] Keep action names user-oriented and command-like (for hotkey mapping clarity).
- [ ] Avoid generic/ambiguous names; rename where needed (example: consider `RemapTo` -> `RemapKeyTo`).
- [ ] Add collision check on action registration (same action name in multiple plugins should warn/fail fast).
- [ ] Add a short deprecation map for renamed actions so old configs keep working for one release cycle.

### Phase 3: Plugin and Action Documentation (must do)
- [ ] Add a short header block to each plugin file containing:
  - Purpose
  - Main usage pattern
  - Config keys used
  - Action list summary
  - Side effects / dependencies
- [ ] Introduce `ACTION_CATALOG.md` generated from `__ActionsHelp()` metadata by CI/CD.
- [ ] Document blacklist semantics once, then reference it from each plugin doc.
- [ ] Add one minimal plugin authoring guide (`PLUGIN_API.md`) with a copy-paste template.

### Phase 4: README Overhaul (must do)
- [ ] Replace `README.txt` with a clean `README.md` focused on users.
- [ ] Keep README short and practical:
  - What AtsuiKagi is
  - Why it is useful
  - Top features
  - Quick start
  - How to configure hotkeys/plugins
  - Troubleshooting basics
- [ ] Add a compact plugin status table (Stable / Experimental / Disabled by default).
- [ ] Add 6-10 real hotkey examples from default config.

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
Blacklist interaction: none | uses `NoMoveResize` | custom
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

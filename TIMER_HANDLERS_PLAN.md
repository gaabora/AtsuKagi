# Timer Handlers Implementation Plan

## Status

- Planning document for `plugins/TimerHandlers.ahk` - file to be renamed to Automations.ahk
- The plugin is currently experimental and incomplete.
- This plan is intended to be edited before implementation.

## Goal

Build a configurable scheduler for App actions based on time, intervals, physical idle state, and other optional window conditions.

No need to keep the existing `TimerHandlers` class and plugin ID for compatibility. Present the feature in the settings UI as **Schedules & Idle Automation**. Avoid using "cron" in user-facing names because these schedules combine triggers and conditions rather than implementing standard cron expressions.

## Source Ideas

The existing comments and unfinished code suggest these initial use cases:

1. Keep the computer awake during working hours even when the user is physically idle.
2. Dismiss a recurring dialogs by sending Escape or Alt+F4 to some window class like `ahk_class TRegCheckDlg`.
3. Run any registered App action when some conditions match (time/idle/other...).

These should become optional schedule templates, disabled by default. They should not remain hard-coded behavior.

## Scope

### First Release

- One scheduler timer owned by `TimerHandlers`.
- Enable or disable the scheduler.
- Create, edit, duplicate, run, enable, disable, and delete schedules.
- Trigger types:
  - Repeating interval.
  - Daily time.
  - Becoming physically idle.
- Conditions:
  - Minimum physical idle duration.
  - Time window.
  - Days of the week.
  - Optional target window selector.
- Execute actions through the existing `RunAction(ActionString)` dispatcher.
- Persist schedules as structured data.
- Option to prevent duplicate execution while a condition remains true.
- Log schedule execution and errors.
- Provide starter templates for the two use cases found in comments.

### Deferred

- Full cron expression support.
- Calendar dates, months, and holidays.
- Wake-from-sleep scheduling.
- Catching up missed schedules after the application was closed.
- Remote synchronization?
- Complex boolean condition groups.
- Multi-action visual workflows.

## Open Decisions

Edit these before implementation:

- [x] Confirm the settings-page title: `Automations`.
- [x] schedules(automations) should be stored in a separate data file
- [x] matching belongs in the first release
- [x] `Run now` should ignore time conditions, `Test action` ignores all conditions.
- [x] action failures should generate a visible notification is such option is checked and log entry if corresponding option was checked.
- [x] Confirm the preferred keep-awake implementation: Key pulse such as Right Shift. (defer option Windows execution-state API.)
- [x] disabled example templates should be offered through an `Add example` menu.

## Proposed Data Contract

Each schedule has a stable ID and normalized fields:

```json
{ // must be reconsidered, simplyfied
  "id": "work-hours-keep-awake",
  "name": "Keep awake during work hours",
  "enabled": false,
  "trigger": {
    "type": "interval", // what are other options?
    "intervalSeconds": 30
  },
  "conditions": {
    "idleSeconds": 10,
    "timeFrom": "08:00",
    "timeUntil": "17:00",
    "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
    "windowSelector": ""
  },
  "action": "PreventSleep()",
  "cooldownSeconds": 30 //what does it mean?
}
```

Runtime-only state such as `lastRun`, current idle transition state, and the last matched time slot should not be persisted unless the final missed-run policy requires it.

## Trigger Semantics

### Repeating Interval

- Eligible every configured number of seconds.
- Conditions are evaluated when the interval becomes due.
- The next due time is calculated from the last attempt or last successful run;
  choose one policy and document it before implementation.?

### Daily Time

- Matches a local `HH:MM` time.
- Runs no more than once for that date and minute. need a setting to run if was skipped for that day (like computer was off/sleep) 
- A scheduler polling several times during the matching minute must not execute the action repeatedly.

### Becoming Idle

- Fires when physical idle time crosses the configured threshold.
- Does not repeat while the user remains idle.
- Rearms after physical input resets the idle state.

## Condition Semantics

- All configured conditions must pass.
- Empty conditions are ignored.
- Time comparisons use local system time.
- A time window where `timeFrom` is later than `timeUntil` crosses midnight.
- Day filtering needs a documented policy for after-midnight portions of a
  crossing window.
- Physical idle uses `A_TimeIdlePhysical` wrapped in a helper function for future language change and crossplatform support
- A window selector should use existing AHK window selector syntax where
  possible.

## Action Semantics

- Store the action as an existing AtsuiKagi action string.
- Execute it with `this.RunAction(schedule["action"])`.
- Do not create a second action parser inside `TimerHandlers`.
- Catch and log failures per schedule so one failure cannot stop the scheduler.
- Reject or disable schedules with empty or unknown actions during validation.
- Log the schedule ID, name, action, result, and failure message.

## Proposed Plugin Actions

Only expose actions that are useful outside the settings page:

- `RunSchedule(ScheduleId)` runs one schedule manually.
- `EnableSchedule(ScheduleId)` enables one schedule.
- `DisableSchedule(ScheduleId)` disables one schedule.
- `ToggleSchedule(ScheduleId)` toggles one schedule.
- `PreventSleep()` performs the selected keep-awake behavior.

`RunSchedule` should have clearly documented behavior about whether it ignores
the schedule trigger and conditions.

## Settings UI

### Scheduler Section

- Master scheduler switch.
- Poll interval in milliseconds, default `1000`.
- Read-only status:
  - Running or stopped.
  - Number of enabled schedules.
  - Next due schedule, when calculable.

### Schedules Section

Use a table on wide layouts and stacked cards on narrow layouts.

Columns or summary fields:

- Enabled.
- Name.
- Trigger summary.
- Action.
- Last result or last run.
- Row actions.

Row actions:

- Edit.
- Duplicate.
- Run.
- Delete.

Toolbar actions:

- Add schedule.
- Add example.

### Schedule Editor

General fields:

- Name.
- Enabled.
- Trigger type.

Trigger fields change according to the selected trigger:

- Interval value and unit.
- Daily time.
- Idle threshold.

Optional conditions:

- Minimum physical idle duration.
- Start time and end time.
- Days of week.
- Window selector.

Action fields:

- Action string.
- Available-action picker or suggestions, if practical.
- Cooldown.

Footer:

- Human-readable schedule preview.
- Validation message.
- Save.
- Cancel.

Example generated preview format:

> Every 30s Mond-Fri 08:00-17:00 if idle > 10s

## UI Integration

The current descriptor renderer supports scalar controls but not repeatable, structured schedule rows. Do not encode all schedules into a comma-separated text field.

Preferred integration:

1. Keep ordinary scheduler settings in the plugin descriptor.
2. Add a focused custom schedules component to the plugin settings page.
3. Add WebView bridge methods to load and save the complete schedule collection atomically.
4. Reuse existing settings styles and controls.
5. Keep scheduler-specific UI code separate from generic field rendering where practical.

Potential bridge operations:

- `GetTimerSchedules`
- `SaveTimerSchedules`
- `RunTimerSchedule`

The final names should follow the existing bridge naming style.

## Runtime Design

### Initialization

- Apply descriptor defaults in `_processPluginConfig()`.
- Bind the polling callback once in `_init()`.
- Start the timer only when the scheduler is enabled.
- Keep the bound callback reference so the timer can be stopped reliably.
- Restart or update the timer when the poll interval changes.

### Polling

For each enabled schedule:

1. Determine whether its trigger is due.
2. Evaluate configured conditions.
3. Check edge state and cooldown.
4. Execute the action.
5. Update runtime state.
6. Log the result.

The polling callback must avoid overlapping executions if one polling pass
takes longer than the configured interval.

### Validation

Validate schedules when loading and before saving:

- Stable non-empty ID.
- Non-empty name.
- Supported trigger type.
- Positive interval.
- Valid `HH:MM` values.
- Valid day names.
- Non-negative idle and cooldown values.
- Non-empty action.

Invalid schedules should be disabled and reported clearly instead of crashing
plugin initialization.

## Example Templates

### Keep Awake During Work Hours

```json
{
  "name": "Keep awake during work hours",
  "enabled": false,
  "trigger": {
    "type": "interval",
    "intervalSeconds": 30
  },
  "conditions": {
    "idleSecondsAtLeast": 10,
    "timeFrom": "08:00",
    "timeUntil": "17:00",
    "days": ["Mon", "Tue", "Wed", "Thu", "Fri"]
  },
  "action": "PreventSleep()",
  "cooldownSeconds": 30
}
```

Prefer the Windows execution-state API over simulated keyboard input if it
satisfies the intended behavior.

### Dismiss RAD Studio License Dialog

```json
{
  "name": "Dismiss RAD Studio license dialog",
  "enabled": false,
  "trigger": {
    "type": "interval",
    "intervalSeconds": 1
  },
  "conditions": {
    "windowSelector": "ahk_class TRegCheckDlg"
  },
  "action": "DismissWindowWithKey(ahk_class TRegCheckDlg, {Escape})",
  "cooldownSeconds": 1
}
```

The exact action should be adjusted to a safe registered action. Do not embed
this application-specific behavior directly in the polling loop.

## Existing Code to Replace

The current prototype has these known issues:

- The scheduler timer is commented out and never starts.
- Storage is named `ScheduledTasks`, while processing references `CronJobs`.
- `_executeAction` is referenced but does not exist.
- The parser cannot safely handle commas or nested action arguments.
- `HasKey` is not the expected AHK v2 map API used elsewhere in this project.
- Exact-minute checks would execute every polling tick during that minute.
- Popup dismissal and keep-awake behavior are hard-coded.

Remove the unfinished cron-string parser after structured schedule loading is
implemented. Do not preserve it as a second configuration format unless a real
compatibility requirement appears.

## Implementation Phases

### Phase 1: Runtime Contract

- [ ] Finalize trigger, condition, action, and persistence semantics.
- [ ] Define normalized schedule objects.
- [ ] Add schedule validation.
- [ ] Replace `CronJobs` and `ScheduledTasks` with one consistently named collection.
- [ ] Add runtime state for edge triggering and cooldowns.

Success criteria:

- Static examples can be loaded and normalized.
- Invalid records are disabled with useful log messages.

### Phase 2: Scheduler Engine

- [ ] Start and stop one bound `SetTimer`.
- [ ] Implement interval triggers.
- [ ] Implement daily-time triggers.
- [ ] Implement idle-transition triggers.
- [ ] Implement time, day, idle, and optional window conditions.
- [ ] Execute registered actions through `RunAction`.
- [ ] Prevent duplicate and overlapping execution.

Success criteria:

- Each trigger follows its documented execution policy.
- One failing schedule does not stop other schedules.

### Phase 3: Persistence and Bridge

- [ ] Choose the storage location and format.
- [ ] Load schedules during plugin initialization.
- [ ] Save the collection atomically.
- [ ] Add settings bridge callbacks.
- [ ] Apply saved changes to the running scheduler without restarting the app.

Success criteria:

- Schedule edits survive application restart.
- Failed saves leave the previous stored collection intact.

### Phase 4: Settings UI

- [ ] Add the scheduler settings section.
- [ ] Add schedule list or cards.
- [ ] Add the schedule editor.
- [ ] Add validation and human-readable preview.
- [ ] Add duplicate, run-now, and delete operations.
- [ ] Add example templates.
- [ ] Support narrow settings-window layouts.

Success criteria:

- A user can manage schedules without editing raw configuration.
- UI validation matches runtime validation.

### Phase 5: Documentation and Cleanup

- [ ] Update the plugin descriptor and action definitions.
- [ ] Remove obsolete cron terminology and prototype code.
- [ ] Update `plugins/AGENTS.md` with the scheduler contracts.
- [ ] Update `README.md`.
- [ ] Update `ACTION_CATALOG.md`.
- [ ] Perform the final DOX pass for every changed path.

## Static Verification

Do not run automated tests under the current repository instruction.

Use static review to verify:

- Descriptor action names match public methods.
- Config keys match runtime reads.
- All bound timer references can be stopped.
- Every schedule path has duplicate-run protection.
- Time windows crossing midnight are handled consistently.
- All bridge names match between AHK and JavaScript.
- Save failures preserve the previous UI and persisted state.
- User-facing labels do not incorrectly promise cron compatibility.

## Out of Scope Notes

- This plan does not require changing generic plugin settings into a universal repeatable-form framework.
- This plan does not make the RAD Studio behavior active by default.


# Timer Handlers Implementation Plan

## Status

- Planning document for `plugins/TimerHandlers.ahk`, to be renamed to
  `plugins/Automations.ahk`.
- The plugin is currently experimental and incomplete.
- This plan is intended to be edited before implementation.

## Goal

Build a configurable automation runner for App actions based on time,
intervals, physical idle state, battery state, and optional window conditions.

No need to keep the existing `TimerHandlers` class and plugin ID for
compatibility. Rename the file, class, and plugin ID to `Automations`. Present
the feature in the settings UI as **Automations**. Use "cron" specifically for
the documented five-field schedule trigger, but not as the name of the overall
automation feature.

## Source Ideas

The existing comments and unfinished code suggest these initial use cases:

1. Keep the computer awake during working hours even when the user is physically idle.
2. Dismiss a recurring dialogs by sending Escape or Alt+F4 to some window class like `ahk_class TRegCheckDlg`.
3. Run any registered App action when some conditions match
   (time/idle/battery/window/other).
4. Show time remaining until a scheduled or Windows-configured sleep event.
5. Alert when battery discharge is approaching a configured low or critical
   threshold.
6. Start a fake black screensaver on configurable screen(s) that keeps the system awake.
7. Normalize or dismiss recurring windows that force topmost or other unwanted window attributes.

These should become optional automation templates, disabled by default. They
should not remain hard-coded behavior.

## Scope

All features in this plan must be implemented. The phases define the delivery order and review points, not optional scope. Keep the scheduler, battery monitoring, OSD, bedtime countdown, fake screensaver, recurring-window handling, persistence, settings UI, and tray integration as separate focused functions or modules even when they are delivered in the same implementation effort.

### First Release

- One scheduler timer owned by `Automations`.
- Enable or disable the scheduler.
- Create, edit, duplicate, run, enable, disable, and delete automations.
- Trigger types:
  - Cron-format schedule.
  - Repeating interval for sub-minute checks.
- Conditions:
  - Minimum physical idle duration.
  - Battery thresholds and discharge state.
  - Explicit window state checks.
  - AC or battery power source.
  - Boolean `or` and `not` groups.
- Execute actions through the existing `RunAction(ActionString)` dispatcher.
- Persist automations as structured data.
- Option to prevent duplicate execution while a condition remains true.
- Log automation execution and errors.
- Provide starter templates for the two use cases found in comments.
- Provide a low-battery automation with a default battery sample interval of `30 seconds`.
- Provide tray quick actions for viewing, running, enabling, disabling, and
  editing automations.

### Deferred

- Cron extensions beyond the documented five-field syntax.
- Named months/weekdays, `L`, `W`, `#`, seconds, and year fields.
- Wake-from-sleep scheduling.
- General catch-up queues for arbitrary interval automations.
- Remote synchronization?
- Arbitrarily deep boolean expression trees unless real examples require them.
- Multi-action visual workflows.
- Windows execution-state API as an alternative keep-awake mechanism.
- Battery health and long-term charge history.

## Open Decisions

Edit these before implementation:

- [x] Confirm the settings-page title: `Automations`.
- [x] Automations should be stored in a separate data file.
- [x] Window matching belongs in the first release.
- [x] `Run now` ignores triggers and expiry but evaluates conditions; `Test
      action` ignores triggers and all conditions.
- [x] Action failures should generate a visible notification when that option is checked and a log entry when run logging is checked.
- [x] Confirm the preferred keep-awake implementation: Key pulse such as Right Shift. (defer option Windows execution-state API.)
- [x] Disabled example templates should be offered through an `Add example` menu.
- [x] Daily catch-up is allowed within a configurable maximum lateness such as 1-24 hours.
- [x] Battery trend history survives app restart in a SQLite file.
- [x] Source priority for bedtime countdown: use 3 (Earliest of 1 and 2)
  - 1. Next enabled App automation that performs sleep/hibernate.
  - 2. Windows active power-plan idle sleep timeout.
  - 3. Earliest of both, with the source shown in the OSD.
- [x] fake screensaver covers configurable monitor(s) and when mouse enters the monitor it should show an eye.png icon-button in the middle with white explaination text above, hovering icon make black overlay 80% transparent, click exits on all screens, right click exits on hovered screen only
- [x] Annoying popup operations: remove topmost, lower behind normal windows, minimize, close, or send a configured key.
- [x] The first-release minimum interval is `1000 ms`. Store interval values in milliseconds so later versions can support shorter millisecond intervals without changing the data contract.
- [x] Keep the weekly timetable as a compact 7 by 24 grid. Cells can be about 10 by 10 pixels, so the full grid fits in the current settings window.
- [x] Implement every feature in this plan, but keep the features in separate focused functions or modules and use the implementation phases as review points.
- [x] Keep battery history for 30 days by default, with a configurable 1-365 day limit. Store `automation-history.sqlite3` beside the active config and use the Windows 10/11 system `winsqlite3.dll` through a Windows-specific adapter.

## Proposed Data Contract

Each automation has a stable ID and normalized fields:

`automations.json` uses a root object with `schemaVersion: 1` and an `automations` array. Runtime state and validation messages are not written into the persisted automation records.

Recommended simplified first-release shape:

```json
{
  "id": "work-hours-keep-awake",
  "name": "Keep awake during work hours",
  "enabled": false,
  "triggers": [
    {
      "type": "schedule",
      "value": "* 8-17 * * 1-5"
    },
    {
      "type": "schedule",
      "value": "* 7-19 * * *",
      "expires": "2026-07-12"
    }
  ],
  "conditions": [
    {
      "type": "idle",
      "value": 2000
    }
  ],
  "action": "PreventSleep()",
  "options": {
    "catchUp": false,
    "conditionMode": "each-trigger",
    "logRuns": true,
    "notifyOnError": false
  }
}
```

JSON examples must remain valid JSON; explanatory comments belong outside code
blocks. The second schedule above represents a temporary extension added from
the tray timetable and expires at the end of July 12, 2026.

### Trigger Records

Triggers are OR alternatives. An automation is due when any non-expired trigger
is due. If several triggers become due in the same polling pass, run the
automation only once and record all matching trigger indexes for diagnostics.

Supported trigger types:

- `schedule`: five-field cron syntax: `minute hour day-of-month month weekday`.
- `interval`: milliseconds, restricted to intervals shorter than one minute.

Supported cron operators:

- `*`: any value.
- `,`: list separator.
- `-`: inclusive range.
- `/`: step.

Numeric field ranges:

- Minute: `0-59`.
- Hour: `0-23`.
- Day of month: `1-31`.
- Month: `1-12`.
- Weekday: `0-7`, where both `0` and `7` are Sunday.

The first release should reject unsupported syntax rather than guess. Define
day-of-month plus weekday behavior explicitly; recommendation: standard cron OR
semantics when both fields are restricted.

`expires` is optional. A date-only value is valid through `23:59:59` local time
on that date. Expired triggers are ignored but retained until the user removes
them, allowing the UI to show and renew past temporary extensions.

An `interval` trigger and a `schedule` trigger in the same array are still OR
alternatives. Therefore, an interval does not become limited by the schedule.
To perform sub-minute checks only during selected hours, add a dedicated
schedule-membership condition later or use a one-minute schedule trigger in the
first release.

### Condition Records

Top-level condition entries use implicit AND. Each leaf has a specific type and
value. First-release leaf conditions:

- `idle`: physical idle time is at least `value` milliseconds.
- `window-exists`: at least one matching window exists.
- `window-active`: the active window matches.
- `window-topmost`: at least one matching window is topmost.
- `power-source`: value is `ac` or `battery`.
- `battery-percent-at-most`: current percentage is at or below the value.
- `battery-minutes-at-most`: reported or estimated remaining time is at or
  below the value.
- `charging`: boolean.

Boolean groups:

- `or`: its `value` array passes when any child passes.
- `not`: its `value` contains one child condition and inverts it.

Keep top-level implicit AND and avoid an explicit `and` type initially. Add
nested `and` only when a real use case cannot be expressed by top-level AND,
`or`, and `not`.

Useful boolean examples:

- Popup variants: window A OR window B exists.
- Keep awake only when an RDP window exists AND the workstation is idle.
- Do not show an OSD while a fullscreen presentation window is active.
- Run cleanup when a window exists AND it is NOT the active window.
- Low-battery alert when on battery AND (percentage is low OR remaining time is
  short).

`conditionMode` applies to the final boolean result of the complete condition
tree, not to individual leaves:

`conditionMode` controls the requested duplicate behavior:

- `each-trigger`: run whenever the trigger is due and conditions pass.
- `on-enter`: while conditions are false the automation is armed; the first due
  trigger for which the complete condition tree is true runs the action and
  disarms it; any later false evaluation rearms it.

This avoids losing an edge when conditions become true between cron ticks.
Conditions should still be sampled often enough to detect the false state
needed for rearming.

`on-enter` with an empty condition array would run once and never rearm, so the
editor should reject that combination or require `each-trigger`.

Runtime-only state such as `lastRun`, `nextRun`, current condition episode, and
the last matched trigger slot should not be stored in `automations.json`.
Battery trend samples are the exception and persist in the separate SQLite
history database. Persist user-visible automation result history separately
only if the UI needs it after restart.

## Trigger Semantics

### Repeating Interval

- Eligible every configured number of milliseconds.
- Intended for sub-minute checks; use cron schedules for minute-or-longer
  calendar timing.
- Conditions are evaluated when the interval becomes due.
- Calculate the next due time from the prior due time, not action completion, to
  avoid interval drift.
- If execution is still running when another interval becomes due, skip that
  occurrence and log it when run logging is enabled.

### Cron Schedule

- Evaluates the documented five-field expression against local system time.
- Runs no more than once for each matching local minute per trigger.
- Optional `catchUp` runs the latest missed schedule occurrence once after
  startup or resume when it falls within the configured maximum lateness.
- A scheduler polling several times during the matching minute must not execute the action repeatedly.
- An expired schedule trigger is never considered for catch-up.
- For multiple missed occurrences, run at most once and record which occurrence
  was selected.

## Condition Semantics

- All top-level configured conditions must pass.
- An empty conditions array passes.
- Invalid or unknown condition types fail validation; they are not silently
  ignored.
- Physical idle uses `A_TimeIdlePhysical`, wrapped in a helper function for
  future platform or API changes.
- Window conditions use existing AHK window selector syntax where possible.
- Window checks must state the requested relation explicitly rather than using
  a generic `window` condition.
- Battery conditions expose percentage, charging state, power source, Windows
  critical threshold/action, reported remaining seconds, and trend-estimated
  remaining seconds.
- Battery status is sampled every `30 seconds` by default and cached for
  condition evaluation.
- Battery threshold state uses hysteresis when rearming `on-enter` automations,
  so noisy estimates near a threshold do not repeatedly fire.

## Action Semantics

- Store the action as an existing AtsuiKagi action string.
- Execute it with `this.RunAction(automation["action"])`.
- Do not create a second action parser inside `Automations`.
- Catch and log failures per automation so one failure cannot stop the runner.
- Reject or disable automations with empty or unknown actions during validation.
- Log the automation ID, name, action, result, and failure message.

## Proposed Plugin Actions

Only expose actions that are useful outside the settings page:

- `RunAutomation(AutomationId)` runs one automation manually.
- `TestAutomationAction(AutomationId)` runs only its stored action.
- `EnableAutomation(AutomationId)` enables one automation.
- `DisableAutomation(AutomationId)` disables one automation.
- `ToggleAutomation(AutomationId)` toggles one automation.
- `PreventSleep()` performs the selected keep-awake behavior.
- `ShowLowBatteryOsd()` displays the latest battery state and Windows critical
  policy using the shared OSD.
- `ShowTimeUntilSleep()` displays the best known sleep countdown and its source.
- `StartFakeScreensaver(HotkeyToExit:="Escape", HotkeyToKeepAwake:="Shift",
  SendHotkeyIntervalSec:=10)` starts the black multi-monitor overlay.
- `StopFakeScreensaver()` closes the overlay and stops its keep-awake timer.
- `NormalizeMatchingWindows(WindowSelector, Operations)` applies explicit,
  limited window-state changes.
- `DismissMatchingWindows(WindowSelector, Hotkey:="{Escape}")` sends a
  configured dismissal key without activating the target.

`RunAutomation` ignores triggers and expiry but still evaluates the complete
condition tree. `TestAutomationAction` executes only the stored action and
ignores all trigger and condition checks.

Prefer `NormalizeMatchingWindows` and `DismissMatchingWindows` over a broad
`KillAnnoyingPopups()` action. The latter hides what will happen and invites
unsafe close/kill behavior. An example may still be labelled "Handle annoying
popups" in the UI.

## Settings UI

### Scheduler Section

- Master scheduler switch.
- Poll interval in milliseconds, default `1000`.
- Read-only status:
  - Running or stopped.
  - Number of enabled automations.
  - Next due automation, when calculable.
  - Battery monitor state and last sample time.

### Automations Section

Use a table on wide layouts and stacked cards on narrow layouts.

Columns or summary fields:

- Enabled.
- Name.
- Trigger summary.
- Action.
- Last result or last run.
- Remaining time or current trigger state.
- Row actions.

Row actions:

- Edit.
- Duplicate.
- Run.
- Test action.
- Delete.

Toolbar actions:

- Add automation.
- Add example.

### Automation Editor

General fields:

- Name.
- Enabled.
- Ordered trigger list with Add, Duplicate, and Delete.

Trigger editor:

- Schedule expression with plain-language preview.
- Visual weekly timetable button for common hour/weekday expressions.
- Interval milliseconds for sub-minute polling.
- Optional expiry date for temporary schedule triggers.
- Next matching occurrence preview.

Conditions editor:

- Top-level condition list uses AND.
- Leaf condition type and value controls.
- Add OR group.
- Add NOT wrapper.
- Group indentation and a generated boolean summary.
- Keep nesting shallow in the first release.

Action fields:

- Action string.
- Available-action picker or suggestions, if practical.
- Run logging switch.
- Visible notification on failure switch.
- Catch-up switch for supported triggers.
- Repeat behavior: each trigger or only when conditions become true.

Footer:

- Human-readable automation preview.
- Next-run or current-state preview.
- Validation message.
- Save.
- Cancel.

Example generated preview format:

> Every minute Monday-Friday 08:00-17:59 if idle >= 2s and either matching
> popup window exists.

### Weekly Timetable Editor

The **Extend** tray action and schedule-trigger editor may open the same
HTML/JavaScript timetable component:

- Rows: Monday through Sunday.
- Columns: hours `00` through `23`.
- Click a cell to toggle an hour.
- Drag across cells to paint enabled or disabled ranges.
- Row and column headers toggle a whole day or hour.
- Show the generated cron expression before applying.
- Optional expiry date is required for tray-created temporary extensions.
- Merge adjacent cells into compact cron ranges where possible.
- If the selected grid cannot be represented compactly by one expression,
  generate multiple `schedule` trigger records.

Library review:

- **Recommended first implementation: custom CSS Grid.** The required editor is
  only a fixed 7 by 24 boolean matrix, so a small delegated pointer handler is
  simpler than adapting a date-calendar model.
- **DayPilot Lite** is the closest ready-made alternative. Its open-source
  Scheduler has a horizontal timeline, row resources, drag selection, and an
  Apache 2.0 license with attribution:
  <https://javascript.daypilot.org/open-source/>.
- **FullCalendar Standard** is MIT licensed and supports selectable TimeGrid
  ranges, but its natural layout is days horizontally and time vertically:
  <https://fullcalendar.io/docs/timegrid-view> and
  <https://fullcalendar.io/docs/selectable>.
- **Schedule-X** has suitable calendar views, but drag-to-create and related
  interactive scheduling plugins are premium, making it a poor fit for this
  small editor:
  <https://schedule-x.dev/docs/calendar/plugins/drag-and-drop>.

Prototype the custom grid first. Reconsider DayPilot Lite only if selection,
keyboard accessibility, or range-editing behavior grows beyond a small local
component.

## UI Integration

The current descriptor renderer supports scalar controls but not repeatable,
structured automation rows. Do not encode all automations into a
comma-separated text field.

Preferred integration:

1. Keep ordinary scheduler settings in the plugin descriptor.
2. Add a focused custom automations component to the plugin settings page.
3. Add WebView bridge methods to load and save the complete automation
   collection atomically.
4. Reuse existing settings styles and controls.
5. Keep scheduler-specific UI code separate from generic field rendering where practical.

Potential bridge operations:

- `GetAutomations`
- `SaveAutomations`
- `RunAutomation`
- `TestAutomationAction`
- `OpenAutomationEditor`

The final names should follow the existing bridge naming style.

## Tray Menu

Add an **Automations** submenu to the application tray menu.

Top-level submenu items:

- `Next: <name> in h:mm:ss`, disabled display row.
- `Open Automations`.
- `Run automation...`.
- `Extend automation...`.
- Separator.
- One row per pinned automation, with enabled state shown as a check mark.

Per-automation submenu:

- Remaining time or current trigger state.
- Run now. This ignores triggers and expiry but evaluates conditions.
- Test action. This ignores all trigger and condition checks.
- Enable or disable.
- Edit. Opens Settings directly on that automation.
- Extend. Opens the weekly timetable editor and appends one or more temporary
  `schedule` triggers with an expiry date.

Only automations explicitly marked `showInTray` should receive a persistent tray
row so the menu stays usable. The tray menu must refresh after automation edits
and when opened, not on every scheduler tick.

The current application tray menu is core-owned and its plugin menu hook is only
a TODO. Implement a real core menu-extension contract instead of letting the
plugin directly rebuild `A_TrayMenu`.

## Runtime Design

### Initialization

- Apply descriptor defaults in `_processPluginConfig()`.
- Bind the polling callback once in `_init()`.
- Start the timer only when the scheduler is enabled.
- Keep the bound callback reference so the timer can be stopped reliably.
- Derive the polling period from the configured default and the shortest enabled
  interval trigger.
- Enforce a first-release minimum supported interval of `1000 ms` to avoid accidental busy loops. Keep all stored and runtime interval values in milliseconds so this limit can be lowered later without a data migration.
- Restart or update the timer when automations or timing settings change.

### Polling

For each enabled automation:

1. Collect all due, non-expired triggers.
2. Evaluate configured conditions.
3. Check edge state and duplicate-run guards.
4. Execute the action.
5. Update runtime state.
6. Log the result.

The polling callback must avoid overlapping executions if one polling pass
takes longer than the configured interval.

Expensive or slow data sources should maintain their own sample cadence:

- Scheduler due checks: default `1000 ms`, reduced when a shorter interval
  trigger requires it.
- Battery sampling: default `30 seconds`.
- Tray countdown text: refresh when the menu opens.
- OSD animation: its own short-lived rendering timer.

### Validation

Validate automations when loading and before saving:

- Stable non-empty ID.
- Non-empty name.
- At least one supported trigger.
- Valid five-field cron syntax and numeric ranges.
- Interval milliseconds at or above the supported minimum and below `60000`.
- Valid optional expiry date.
- Supported condition types and value shapes.
- Non-negative idle milliseconds.
- Boolean groups are non-empty and within the supported nesting depth.
- Valid battery thresholds and sample interval.
- Non-empty action.

Invalid automations should be disabled and reported clearly instead of crashing
plugin initialization.

## Example Templates

### Keep Awake During Work Hours

```json
{
  "name": "Keep awake during work hours",
  "enabled": false,
  "triggers": [
    {
      "type": "schedule",
      "value": "* 8-17 * * 1-5"
    }
  ],
  "conditions": [
    {
      "type": "idle",
      "value": 10000
    }
  ],
  "action": "PreventSleep()",
  "options": {
    "conditionMode": "each-trigger",
    "logRuns": false,
    "notifyOnError": true,
    "showInTray": true
  }
}
```

Use the selected simulated key pulse for the first release. Keep the sending
logic in `PreventSleep()` so a future Windows execution-state implementation
does not require changing stored automations.

### Dismiss RAD Studio License Dialog

```json
{
  "name": "Dismiss RAD Studio license dialog",
  "enabled": false,
  "triggers": [
    {
      "type": "interval",
      "value": 1000
    }
  ],
  "conditions": [
    {
      "type": "window-exists",
      "value": "ahk_class TRegCheckDlg"
    }
  ],
  "action": "DismissMatchingWindows(ahk_class TRegCheckDlg, {Escape})",
  "options": {
    "conditionMode": "each-trigger",
    "logRuns": true,
    "notifyOnError": false
  }
}
```

The exact action should be adjusted to a safe registered action. Do not embed
this application-specific behavior directly in the polling loop.

### Low Battery Warning

```json
{
  "name": "Low battery warning",
  "enabled": false,
  "triggers": [
    {
      "type": "interval",
      "value": 30000
    }
  ],
  "conditions": [
    {
      "type": "power-source",
      "value": "battery"
    },
    {
      "type": "or",
      "value": [
        {
          "type": "battery-percent-at-most",
          "value": 15
        },
        {
          "type": "battery-minutes-at-most",
          "value": 20
        }
      ]
    }
  ],
  "action": "ShowLowBatteryOsd()",
  "options": {
    "conditionMode": "on-enter",
    "logRuns": true,
    "notifyOnError": true,
    "showInTray": true
  }
}
```

The explicit `or` group makes either battery threshold sufficient. With
`conditionMode: "on-enter"`, the alert fires once per low-battery episode and
rearms after the combined condition becomes false.

## Related Feature Designs

### Low Battery Alert

Purpose:

- Alert based on current battery level, discharge trend, estimated remaining
  time, and Windows low/critical battery policy.

Behavior:

- Sample every `30 seconds` by default.
- Keep a rolling sample window and ignore samples while charging.
- Prefer valid Windows-provided remaining time; otherwise estimate from the
  smoothed percentage or energy discharge trend.
- Avoid noisy estimates until enough samples and elapsed time exist.
- Show a semi-transparent animated OSD when crossing configured thresholds.
- Increase alert urgency near the Windows critical threshold or configured
  sleep/hibernate action.
- Suppress repeated alerts until the battery drops by another configured step,
  a repeat interval passes, or the urgency level changes.

OSD contents:

- Battery percentage.
- Charging/discharging state.
- Reported or estimated `h:mm:ss` remaining.
- Windows low and critical thresholds.
- Expected Windows action, such as Sleep or Hibernate.
- Estimated time until that threshold, clearly marked as an estimate.

Do not promise "sleep after 5 min" unless both the configured Windows action and
the estimate support that statement. Use "estimated" whenever derived from
trend data.

### Bedtime Routine and Sleep Countdown

`ShowTimeUntilSleep()` should resolve the earliest known sleep event:

1. Next enabled App automation whose action is recognized as sleep or
   hibernate.
2. Windows active power-plan idle sleep timeout, calculated from current
   physical idle time.

Display:

- Countdown as `h:mm:ss`.
- Source: automation name or Windows power plan.
- Whether activity will reset the countdown.
- `Never`, `unknown`, or `not on current power source` when appropriate.

The first release should not inspect arbitrary Windows Task Scheduler entries.
That can be added later as another schedule source.

The bedtime routine itself can be an ordinary cron-scheduled automation that
runs a sequence action later, but multi-action workflow editing remains
deferred.

### Fake Screensaver

`StartFakeScreensaver(...)` behavior:

- Create one borderless black fullscreen window per configured monitor.
- Keep each base overlay topmost, unfocused, and shown with `NoActivate`.
- Do not steal focus from the active application.
- Register a scoped exit hotkey and close every overlay on exit.
- Send the configured keep-awake key at the configured interval.
- Poll the mouse position to detect when it enters a covered monitor; a fully
  click-through overlay cannot receive reliable hover events itself.
- On the hovered covered monitor, show white explanatory text and a centered
  `eye.png` image button.
- Hovering the eye button changes that monitor's black overlay to 80%
  transparency.
- Left-clicking the eye exits the fake screensaver on all monitors.
- Right-clicking the eye exits only the hovered monitor.
- When no configured monitors remain covered, stop the keep-awake timer and
  unregister all related hotkeys.
- Calling Start while active is idempotent or updates the active configuration.
- `StopFakeScreensaver()` always removes hotkeys, timers, and every overlay.
- Stop automatically during application exit or reload.

The action needs explicit documentation that it hides the screen but is not a
security boundary and does not lock the workstation.

### Recurring Popup Handling

Separate matching from operations:

- Match by AHK window selector.
- Optional conditions for title, executable, visibility, and current topmost
  state.
- Explicit operations: remove topmost, lower, minimize, close, send key, or
  remove a narrowly defined extended style.

Safety:

- Default examples must not terminate processes.
- Destructive close behavior must be explicit.
- Resolve and validate HWNDs immediately before each mutation.
- Respect an applicable blocklist/allowlist contract.
- Log affected HWND, process, title, and operation when enabled.
- If another program repeatedly restores the attribute, apply the operation
  through an interval automation rather than installing an unbounded loop.

### Shared OSD

Battery alerts and sleep countdown need a small reusable OSD capability:

- Semi-transparent, non-activating, click-through, topmost window.
- Supports text, progress, urgency color, and short enter/exit animation.
- Own display duration and animation timers separately from scheduler polling.
- Coalesce updates by OSD channel so repeated battery samples update one OSD
  instead of stacking windows.
- Keep the first implementation local to `Automations` unless another plugin
  immediately needs the same API; extract it only when reuse is real.

## Existing Code to Replace

The current prototype has these known issues:

- The scheduler timer is commented out and never starts.
- Storage is named `ScheduledTasks`, while processing references `CronJobs`.
- `_executeAction` is referenced but does not exist.
- The parser cannot safely handle commas or nested action arguments.
- `HasKey` is not the expected AHK v2 map API used elsewhere in this project.
- Exact-minute checks would execute every polling tick during that minute.
- Popup dismissal and keep-awake behavior are hard-coded.

Remove the unfinished cron-string parser after structured automation loading is
implemented. Do not preserve it as a second configuration format unless a real
compatibility requirement appears.

## Implementation Phases

### ✅ Phase 1: Runtime Contract

- [x] ✅ Finalize trigger, condition, action, and persistence semantics.
- [x] ✅ Define normalized automation objects.
- [x] ✅ Add automation validation.
- [x] ✅ Replace `CronJobs` and `ScheduledTasks` with one consistently named collection.
- [x] ✅ Add runtime state for edge triggering and duplicate-run guards.
- [x] ✅ Rename file, class, plugin ID, descriptor, and generated include from
      `TimerHandlers` to `Automations`.

Success criteria:

- Static automation examples can be loaded and normalized.
- Invalid records are disabled with useful log messages.

### ✅ Phase 2: Scheduler Engine

- [x] ✅ Start and stop one bound `SetTimer`.
- [x] ✅ Implement interval triggers.
- [x] ✅ Implement and validate five-field cron schedule triggers.
- [x] ✅ Implement trigger expiry and catch-up.
- [x] ✅ Implement leaf conditions for idle, battery, power, and explicit window
      relations.
- [x] ✅ Implement top-level AND plus `or` and `not` condition groups.
- [x] ✅ Implement `each-trigger` and aggregate `on-enter` state.
- [x] ✅ Execute registered actions through the central action dispatcher.
- [x] ✅ Prevent duplicate and overlapping execution.

Success criteria:

- Each trigger follows its documented execution policy.
- One failing automation does not stop other automations.

### ✅ Phase 3: Persistence and Bridge

- [x] ✅ Store JSON in `automations.json` beside the active configuration file, so
      custom config locations keep their automation data with them.
- [x] ✅ Save through a temporary file and atomic replacement.
- [x] ✅ Load automations during plugin initialization.
- [x] ✅ Save the collection atomically.
- [x] ✅ Store battery trend samples in a separate SQLite database with retention
      and compaction limits.
- [x] ✅ Add settings bridge callbacks.
- [x] ✅ Apply saved changes to the running scheduler without restarting the app.

Success criteria:

- Automation edits survive application restart.
- Failed saves leave the previous stored collection intact.

### ✅ Phase 4: Settings UI

- [x] ✅ Add the automation-runner settings section.
- [x] ✅ Add automation list or cards.
- [x] ✅ Add the automation editor.
- [x] ✅ Add validation and human-readable preview.
- [x] ✅ Add cron text editing and plain-language preview.
- [x] ✅ Add the weekly timetable editor and cron conversion.
- [x] ✅ Add temporary Extend flow with required expiry.
- [x] ✅ Add boolean condition-group editing.
- [x] ✅ Add duplicate, run-now, and delete operations.
- [x] ✅ Add example templates.
- [x] ✅ Add low-battery OSD and sleep countdown UI.
- [x] ✅ Support narrow settings-window layouts.

Success criteria:

- A user can manage automations without editing raw configuration.
- UI validation matches runtime validation.

### ✅ Phase 5: Related Actions

- [x] ✅ Add `PreventSleep`.
- [x] ✅ Add fake screensaver start/stop lifecycle.
- [x] ✅ Add safe popup normalization and dismissal actions.
- [x] ✅ Add `ShowTimeUntilSleep`.
- [x] ✅ Add shared OSD behavior required by battery and bedtime features.

Success criteria:

- Each action cleans up its timers, hotkeys, and windows.
- Popup actions perform only explicitly configured operations.
- Fake screensaver covers all monitors without activating its windows.

### ✅ Phase 6: Tray Integration

- [x] ✅ Add a core-owned tray menu extension contract.
- [x] ✅ Add the Automations submenu.
- [x] ✅ Show next-run and remaining-time information.
- [x] ✅ Add run, test, enable/disable, and edit commands.
- [x] ✅ Refresh tray state after automation changes and when the menu opens.

Success criteria:

- Tray actions target stable automation IDs.
- Edit opens the correct automation in Settings.
- The menu remains concise through `showInTray`.

### Phase 7: Documentation and Cleanup

- [ ] Update the plugin descriptor and action definitions.
- [ ] Remove obsolete cron terminology and prototype code.
- [ ] Update `plugins/AGENTS.md` with the automation contracts.
- [ ] Update `README.md`.
- [ ] Update `ACTION_CATALOG.md`.
- [ ] Perform the final DOX pass for every changed path.

## Static Verification

Use static review to verify:

- Descriptor action names match public methods.
- Config keys match runtime reads.
- All bound timer references can be stopped.
- Every automation path has duplicate-run protection.
- Battery threshold alerts rearm correctly after charging or hysteresis.
- Cron field ranges, steps, expiry, and day-of-month/weekday behavior are
  handled consistently.
- Top-level AND, `or`, `not`, and aggregate `conditionMode` behavior match the
  documented condition semantics.
- All bridge names match between AHK and JavaScript.
- Tray callbacks remain valid after automations are reloaded.
- Fake screensaver cleanup covers reload, exit hotkey, and explicit stop.
- Popup actions validate the target immediately before mutation.
- Save failures preserve the previous UI and persisted state.
- User-facing cron labels match the documented supported subset.

## Out of Scope Notes

- This plan does not require changing generic plugin settings into a universal repeatable-form framework.
- This plan does not make the RAD Studio behavior active by default.

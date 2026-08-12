# Automations

## Purpose

- Own automation data validation, cron matching, scheduler state, persistence, battery sampling, OSD, fake screensaver state, and platform-specific system work used by `plugins/Automations.ahk`.

## Ownership

- `AutomationCron.ahk` owns the supported five-field cron parser and matcher.
- `AutomationDefinition.ahk` owns normalized persisted automation records and validation.
- `AutomationScheduler.ahk` owns due checks, condition evaluation, duplicate guards, and action execution policy.
- `AutomationPersistence.ahk` owns atomic JSON storage and SQLite battery history.
- `AutomationBatteryMonitor.ahk` owns battery sampling cadence and remaining-time estimates.
- `WindowsAutomationPlatform.ahk` wraps Windows-specific idle, power policy, battery, window, input, clock, and atomic-file APIs.
- `WindowsAutomationOsd.ahk` owns coalesced non-activating OSD windows and their animation timers.
- `WindowsFakeScreensaver.ahk` owns per-monitor overlays, scoped exit input, hover UI, and complete cleanup.

## Local Contracts

- Persist automation and interval durations in milliseconds.
- Keep the first-release minimum interval at `1000 ms` while accepting a lower limit later without changing stored records.
- Treat top-level conditions as AND and support only the documented `or` and `not` nested groups.
- Keep Windows API calls inside `WindowsAutomationPlatform` or a clearly named Windows-specific persistence or visual class.
- Keep the fake screensaver non-activating and state clearly that it is not a lock or security boundary.
- Scheduler actions must use the central App action dispatcher.
- The Automations tray menu must use stable automation IDs, show persistent rows only for `showInTray`, and refresh after data changes and when the submenu opens.

## Work Guidance

- Keep runtime-only state outside `automations.json`.
- Keep invalid loaded records visible but disabled with clear validation errors.
- Do not let one automation failure stop later automations.

## Verification

- Use static review for cron ranges, duplicate guards, timer cleanup, descriptor parity, JSON replacement, and SQLite statement cleanup.

## Child DOX Index

- No child DOX files.

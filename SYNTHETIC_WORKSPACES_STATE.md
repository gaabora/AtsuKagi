# Synthetic Workspaces State Specification

<a id="state-1"></a>
## STATE-1: Ownership

This document is the only source of truth for:

- Workspace and window state.
- Window discovery, classification, events, and cache repair.
- Workspace switching, desktop covers, focus, and recovery.
- Layout and monitor geometry.
- Stable window identity.
- Persisted data, validation, load, and save.

Input timing is owned by [`SYNTHETIC_WORKSPACES_INPUT.md`](SYNTHETIC_WORKSPACES_INPUT.md). Overview presentation and commands are owned by [`SYNTHETIC_WORKSPACES_OVERVIEW.md`](SYNTHETIC_WORKSPACES_OVERVIEW.md).

<a id="state-2"></a>
## STATE-2: Workspace model and decisions

### Terms

- **Slot**: one fixed position in the 3 by 3 direction grid, such as `ne`.
- **Workspace**: a stable logical space with its own ID, windows, custom settings, layout, and focus history.
- **Slot map**: the current one-to-one mapping from each fixed slot to a workspace ID.
- **Runtime window record**: live state for one current top-level window. It is not a persistent identity.
- **Window profile**: saved state for one logical window, including its match rule, workspace, placement, and unique visual overrides.
- **App visual rule**: a broad style rule that may match several windows but never owns placement or focus history.
- **Active window**: the real foreground window in the active workspace.
- **Last-active window**: the valid window that should receive focus when its workspace becomes active.

### Invariants

- There are eight stable workspace records and eight fixed directional slots from [`INPUT-2`](SYNTHETIC_WORKSPACES_INPUT.md#input-2).
- The Control Center is not a ninth workspace.
- Stable workspace IDs do not change when slot positions change.
- A slot map contains every known slot exactly once and maps every workspace exactly once.
- Runtime state keeps observed, desired, and pending window properties separate.
- Runtime HWND, PID, and internal record IDs are never persistent identity.
- Synthetic workspaces never rename or move native Windows virtual desktops.

### Decisions

This table is the only place that tracks core workspace decision status.

| ID | Status | MVP blocker | Decision or recommended result |
|---|---|---|---|
| `ST-D01` | Chosen | Yes | Stable workspace IDs are separate from directional slots. |
| `ST-D02` | Chosen | Yes | A direction selects the workspace currently mapped to that slot. |
| `ST-D03` | Chosen | No | Swapping slots moves the complete workspace identity, including windows, custom name, custom color, layout, rules, and focus history. |
| `ST-D04` | Chosen | Yes | One workspace is active globally across all monitors for the MVP. |
| `ST-D05` | Chosen | Yes | A normal managed window belongs to exactly one workspace for the MVP. |
| `ST-D06` | Chosen | Yes | A taskbar or application activation request for an inactive window switches to that window's workspace. |
| `ST-D07` | Chosen | Yes | Use the MVP special-window policy in [`STATE-4`](#state-4-special). |
| `ST-D08` | Chosen | Yes | Synthetic workspaces and `VirtualDesktopManager` remain independent. |
| `ST-D09` | Chosen | No | Untouched default name, badge, and color follow the current slot, while custom overrides move with the workspace identity. Reset returns to the current slot default. |
| `ST-D10` | Open | No | Choose the first shipped tiling templates from the candidates in [`STATE-7`](#state-7). |

<a id="state-3"></a>
## STATE-3: Public service and platform boundary

### Public actions

The `SyntheticWorkspaces` plugin declares actions and simple settings, starts and stops services, and contains no direct Win32 calls.

Suggested public actions:

- `SwitchSyntheticWorkspace(Slot)`
- `MoveWindowToSyntheticWorkspace(Slot, Hwnd:=0)`
- `MoveWindowAndSwitchSyntheticWorkspace(Slot, Hwnd:=0)`
- `ShowSyntheticWorkspaceOverview()`
- `HideSyntheticWorkspaceOverview()`
- `ToggleSyntheticWorkspaceOverview()`
- `DisableSyntheticWorkspaces()`
- `RestoreAllSyntheticWorkspaceWindows()`

Every action runs through the existing central dispatcher.

### Platform capabilities

| Capability | Windows/AHK implementation |
|---|---|
| Window enumeration | AHK window APIs through the window backend |
| Window events | WinEvent and shell events through one event service |
| Geometry | DWM visible frame with normal window-position fallback |
| Batch placement | `SetWindowPos` and deferred-window positioning when useful |
| Focus | Validated foreground and activation calls |
| Cover layer | One non-activating Haribol! GUI per monitor |
| App metadata | Icon, AppUserModelID, and optional guarded process launch-argument reads |
| Monitor identity | Display device identity with documented fallback |
| Persistence | JSON sidecar and Windows-safe atomic replacement |

Input capabilities are owned by [`INPUT-4`](SYNTHETIC_WORKSPACES_INPUT.md#input-4). Process-launch capability for later Control Center work is owned by [`OVERVIEW-7`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-7).

The portable model, identity matcher, layout math, validation, and overview protocol call only capability interfaces. A backend reports an unavailable operation explicitly.

<a id="state-4"></a>
## STATE-4: Runtime windows

### Runtime record

Each managed live window record contains:

- Internal runtime record ID.
- HWND and PID.
- Executable path and name.
- Window class.
- AppUserModelID when available.
- Current and normalized title.
- Owner, root owner, and popup relation.
- Observed geometry and monitor.
- Observed visible, minimized, maximized, fullscreen, topmost, cloaked, and stack state.
- Desired workspace, geometry, topmost state, and focus.
- Pending properties from the current transaction.
- Last focus time.
- Matched persistent profile ID when unambiguous.
- Resolved display title, icon, base color, and color preset.

### Classification

The backend classifies each top-level window and gives a diagnostic reason:

| Class | Meaning |
|---|---|
| `managed` | Normal window that can join a workspace |
| `owned-dialog` | Dialog that follows its root owner's workspace and stacking group |
| `global` | Window visible on every workspace by explicit rule |
| `shell` | Windows shell or Haribol! shell UI |
| `ignored` | Hidden, cloaked, tool, or other non-user window |
| `unsupported` | Window that cannot join normal operations and must use the parked layer |

<a id="state-4-special"></a>
### MVP special-window policy

- Keep a window's saved topmost state while its assigned workspace is active. Temporarily clear topmost before placing it in an inactive workspace and restore topmost when its workspace becomes active. Classify the window as `unsupported` if this cannot be done safely.
- For a controllable fullscreen window that is not blocklisted, minimize it when its workspace becomes inactive and restore its previous fullscreen state when the workspace becomes active. Classify it as `unsupported` if minimize or restore fails.
- Classify elevated, protected, and non-responsive windows as `unsupported`. Save their observed workspace, geometry, fullscreen, minimized, and topmost state. Do not focus, move, hide, minimize, or restore them while they are unsupported.
- Make one bounded non-activating asynchronous attempt to clear topmost and place an unsupported root-owner group in the parked layer below the monitor cover. Keep every monitor cover in place.
- If Windows rejects the parked-layer operation, stop retrying, keep the covers, and report that the window may remain visible above its cover.
- Recheck unsupported windows through low-rate reconciliation. When a window becomes controllable again, return it to normal workspace handling and restore its saved topmost state only when its assigned workspace is active.
- A later `pinned` rule may keep a window topmost and visible in the same position on every workspace. It is not part of the MVP.

Drag eligibility and workspace eligibility are different. Do not reuse a private WinDrag filter as the workspace filter.

### New-window defaults

- A dialog inherits its root owner's workspace.
- A normal unowned window starts in the active workspace.
- A window with one saved unambiguous profile uses that profile's workspace.
- If a profile points to an inactive workspace, apply decision `ST-D06`.
- Unsupported windows keep their workspace assignment, use the parked layer when possible, and appear in diagnostics.

### Runtime focus and layout identity

- Keep runtime focus history by runtime record ID for every live managed root window, including ambiguous and session-only windows.
- A session-only window may be last-active and may keep a runtime template position during the current run.
- Persist only unambiguous profile IDs in focus history and layout order.
- After restart, resolve saved profile IDs to live runtime records, then append other live windows in stable session order.
- Never save HWND, PID, or a runtime record ID.

<a id="state-5"></a>
## STATE-5: Window cache and events

- Native create, destroy, activate, title, state, and geometry events update the cached model.
- Read complete window snapshots, including owner and root owner.
- Read AppUserModelID with a clear unavailable result.
- Read command lines only for an enabled advanced identity rule and never log the full value.
- Extract and cache app icons through the window backend.
- Exclude covers, overview windows, and other Haribol! shell UI.
- Apply blocklist and unsupported-window policy before a window becomes managed.
- Every listener, hook, timer, and callback has a cleanup path.

Use a low-rate reconciliation scan, recommended every one or two seconds, to find missed events. Scan only properties needed to repair the model. Pause or reduce scanning while a switch transaction applies.

Expected native events from a transaction update observed state without starting another switch. An unexpected create, destroy, geometry, stack, or focus event marks the plan stale and follows the bounded replan rule in [`STATE-6`](#state-6).

<a id="state-6"></a>
## STATE-6: Workspace switching and recovery

### Transaction

A switch is one guarded transaction:

1. Validate the destination slot and resolve its current workspace ID.
2. Refresh the window cache before saving current geometry or focus.
3. Build an in-memory candidate with refreshed geometry, focus history, and a rollback snapshot.
4. Resolve owner groups, dialogs, unsupported windows, and monitor groups.
5. Prepare geometry, z-order, topmost, cover, and focus operations without changing the desktop.
6. Start one transaction guard and mark each expected property as pending.
7. Apply prepared geometry in batches.
8. Stack complete root-owner groups in this normal order: parked unsupported groups, inactive groups, all monitor covers as one band, active groups, and Haribol! shell UI.
9. Handle approved topmost windows outside the normal band.
10. Focus the valid last-active runtime window or the next valid entry in runtime focus history.
11. Read back geometry, stack bands, covers, and foreground focus.
12. Run at most one bounded refresh, replan, and repair pass.
13. On failure, restore only snapshot properties that still match values applied by this transaction.
14. If safe stacking of covers or manageable windows cannot be restored, remove every cover and make all manageable windows reachable. A rejected unsupported parked-layer operation follows the reported exception in [`STATE-4`](#state-4-special) and does not remove covers.
15. Commit `activeWorkspaceId`, geometry, focus history, and candidate state only after successful verification.
16. Clear pending state and the transaction guard through one cleanup path, then save and publish one new model revision.

Each pending entry records the transaction ID, runtime record ID, property, prior value, and expected target. A failed transaction does not change or save `activeWorkspaceId`.

### Desktop covers

- Create one non-activating cover per monitor.
- Covers belong to Haribol! and never enter workspace enumeration or focus history.
- Treat a root owner and its owned dialogs as one stacking group.
- Keep every monitor cover in one contiguous band between inactive and active groups.
- Keep overview and other Haribol! shell UI above active application windows.
- Apply the special-window policy from [`STATE-4`](#state-4-special) outside the normal band.
- Keep covers in place when Windows rejects an unsupported parked-layer operation, and expose the failed window in diagnostics.
- If cover placement cannot be verified, remove all covers and stop synthetic mode.
- Process-owned covers disappear if the app crashes.

### Suspend and emergency restore

- Before app-wide hotkeys suspend, remove covers, clear temporary topmost changes, restore manageable windows, and release suppressing contexts.
- On resume, rebuild and verify the cache before covers may return.
- Keep `RestoreAllSyntheticWorkspaceWindows()` in an unsuspended tray path that does not depend on the input router.
- The emergency action removes covers, clears temporary topmost changes, makes every manageable window reachable, and disables switching.
- Reload and exit use the same cleanup.
- Disable synthetic mode when suspend cleanup or resume verification fails.

### Failure rules

- Never report a switch as complete when destination focus or stack verification fails.
- Do not hide unsupported windows from diagnostics.
- Keep covers and stop bounded park retries when Windows rejects an unsupported parked-layer operation.
- A newer external window change wins over rollback.

<a id="state-7"></a>
## STATE-7: Layouts, monitors, and geometry

### MVP behavior

- The MVP requires `freeform` saved normalized rectangles.
- Save geometry relative to the monitor work area.
- Use a backend-provided stable monitor key, not only a numeric monitor index.
- Prefer a Windows display device path or stable device identity. Fall back to device name plus geometry signature.
- Keep every restored titlebar reachable and clamp unsafe geometry.
- If a saved monitor is absent, keep its saved placement unchanged and temporarily project the window onto the pointer or primary monitor.
- Replace an absent-monitor record only after the user moves the window or confirms the fallback.

### Later templates

The exact shipped list is an open later decision. Current candidates are:

- `full`
- `two-columns`
- `two-rows`
- `four-grid`

Template rules:

- Use normalized rectangle math with explicit outer and inner gaps.
- Respect known minimum window sizes.
- Apply a template separately per workspace and monitor.
- Use workspace `profileOrder` as the only persisted template order.
- Append session-only runtime IDs in stable session order without saving them.
- Missing windows do not remove their saved profile order.
- Choose one clear policy for windows beyond the template slot count.
- A profiled window drop updates `profileOrder`; a session-only drop updates runtime order only.
- A `freeform` drop saves a normalized rectangle only when identity is stable.

Do not call private WinDrag or WindowStash helpers. Move only required geometry ideas behind shared layout or backend interfaces.

<a id="state-8"></a>
## STATE-8: Persistence decisions and boundaries

This table is the only place that tracks persistence decision status.

| ID | Status | MVP blocker | Decision or recommended result |
|---|---|---|---|
| `PS-D01` | Chosen | Yes | Store structured state in a versioned `synthetic-workspaces.json` beside the active config file. |
| `PS-D02` | Chosen | Yes | Write through a temporary file and replace the previous file atomically through the platform backend. |
| `PS-D03` | Open | No | Process launch-argument matching uses an app's launch arguments as an optional later identity condition. Keep it disabled by default unless the user enables such a rule in [`STATE-9`](#state-9). |

Runtime observed, desired, pending, HWND, PID, and runtime record IDs are never stored.

<a id="state-9"></a>
## STATE-9: Stable window identity

### Profile selection

1. Every condition inside one profile must match the live window.
2. Keep matching profiles at the highest numeric priority.
3. Use the profile only when exactly one highest-priority profile remains.
4. Mark a tie as ambiguous. File order and launch order are not tie-breakers.
5. Give automatic profiles a lower default priority than user profiles.
6. Mark a profile ambiguous when it matches several live top-level windows.
7. Return the match reason and confidence for diagnostics.

### Unique profiles

A unique window profile may contain:

- Stable profile ID, source (`auto` or `user`), and priority.
- Exact executable path or name.
- Exact window class.
- Exact AppUserModelID when available.
- Exact, contains, wildcard, or regular-expression title matcher.
- Optional contains or regular-expression process launch-argument matcher.
- Optional root-owner rule.
- One workspace assignment for the MVP.
- Monitor-specific normalized freeform geometry.
- Custom display title, title format, icon, and per-window color override.

Do not apply placement or workspace assignment from a profile that currently matches several windows.

### MVP identity behavior

- Use an existing profile when it matches one live window without a top-priority tie.
- Create an automatic profile only when stable fields identify one current window.
- Treat a matcher based only on the current exact title as fragile and keep it as a draft until confirmed.
- Apply weak, fragile, or ambiguous changes for the current session only and show `Not saved - define identity`.
- Give same-app ambiguous windows visible session labels such as `1 of 3`.
- Show a `Needs identity rule` marker.

### Later identity and visual tools

- Let the user build a rule from current executable, class, title, AppUserModelID, and optional process launch arguments.
- Show which current windows a draft rule matches before save.
- Let a user replace an automatic title matcher with a project, document, or process launch-argument rule.
- App visual rules may match several windows by grouping key, executable path or name, or AppUserModelID.
- App visual rules own only icon fallback, base color, and same-app color preset.
- Choose one highest-priority app visual rule. On a tie, report conflict and use the built-in default.
- A unique profile visual override wins over an app visual rule.
- App visual rules never store workspace assignment, geometry, focus history, or unique window title.

Process launch-argument inspection runs locally only for an enabled advanced rule. Store only the user-entered matcher, report access denial, and do not log full launch arguments or private local paths.

<a id="state-10"></a>
## STATE-10: Persisted schema and validation

Top-level schema version 1 contains:

| Field | Content |
|---|---|
| `schemaVersion` | Exact supported schema version |
| `activeWorkspaceId` | Last successfully committed active workspace |
| `slotMap` | The eight slot-to-workspace mappings |
| `workspaces` | Eight workspace records with custom values, layouts, and focus profile IDs |
| `windowProfiles` | Unique window match rules, assignment, placement, and unique visual overrides |
| `appVisualRules` | Broad app presentation defaults only |
| `quickLaunchEntries` | Later validated Control Center launch records |
| `controlCenter` | Later enabled provider IDs and typed pins |

A workspace record contains a stable ID, nullable custom name and color, layouts by monitor, and filtered focus-history profile IDs. A layout record contains a template ID, gaps, and one `profileOrder`. A window profile contains its match rule, one workspace ID, placements by monitor, and unique visuals. Quick-launch fields are defined in [`OVERVIEW-7`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-7).

The default-state generator creates all eight workspace records and the complete slot map.

Validation requires:

- Exactly the known eight slot keys and eight workspace records.
- Unique workspace IDs and a one-to-one slot map.
- An active workspace present in the workspace list and slot map.
- Unique profile, app-rule, and quick-launch IDs.
- Every reference to resolve in the correct namespace.
- One valid workspace ID per MVP window profile.
- Every persisted focus and layout-order profile to belong to the same workspace.
- `profileOrder` to be the only persisted template order.
- No duplicate profile in one monitor order or conflicting workspace orders.
- Pin type to be `action` or `quickLaunch` and its ID to exist in that namespace.
- Finite normalized geometry in allowed ranges.
- Valid template IDs, monitor keys, colors, title formats, priorities, and launch fields.
- Unsupported schema versions to fail without speculative migration code.

<a id="state-11"></a>
## STATE-11: Load and save

- Parse and validate a complete candidate before replacing the current in-memory model.
- Invalid JSON or invalid data leaves the previous valid model active.
- Write a complete temporary file through the platform persistence backend.
- Flush and close the temporary file before replacement.
- Replace the old file atomically when the platform supports it.
- A failed save leaves the previous valid file unchanged.
- Debounce rapid UI geometry and color updates.
- Save immediately after a completed workspace switch, slot swap, assignment, or identity-rule edit.
- Never delete a missing monitor's saved placement during temporary fallback.
- Persist committed state only. Never persist a partly applied transaction.

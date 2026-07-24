# Synthetic Workspaces Verification

<a id="test-1"></a>
## TEST-1: Use of this document

This document contains verification scenarios only. It does not define product behavior. Each group links to its owning specification.

Do not run these checks while editing planning documents. Run them only when the user asks to verify an implementation.

When a specification changes, update the linked checks in this file. If wording conflicts, the owning specification is authoritative.

<a id="test-2"></a>
## TEST-2: MVP completion gate

The MVP gate passes only when:

- [ ] Every MVP input check in [`TEST-3`](#test-3) passes.
- [ ] Every MVP state and switching check in [`TEST-4`](#test-4) passes.
- [ ] Every MVP persistence and identity check in [`TEST-5`](#test-5) passes.
- [ ] Every MVP overview check in [`TEST-6`](#test-6) passes.
- [ ] Every static and integration check in [`TEST-7`](#test-7) passes.
- [ ] No unresolved MVP-blocking decision remains in [`INPUT-3`](SYNTHETIC_WORKSPACES_INPUT.md#input-3), [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2), [`STATE-8`](SYNTHETIC_WORKSPACES_STATE.md#state-8), or [`OVERVIEW-2`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-2).

<a id="test-3"></a>
## TEST-3: MVP input checks

Canonical behavior: [`INPUT-2`](SYNTHETIC_WORKSPACES_INPUT.md#input-2) through [`INPUT-7`](SYNTHETIC_WORKSPACES_INPUT.md#input-7).

### Backend feasibility gate

- [ ] Dynamic AHK callbacks can observe and consume every managed CapsLock down/up sequence without blocking unowned WASD or Space.
- [ ] If dynamic callbacks fail a required case, a small low-level-hook prototype can provide the same router events and cleanup contract.
- [ ] Suspend, reload, focus change, and a missed key-up cannot leave a managed key suppressed.

### Chords and commit

- [ ] CapsLock tap runs the approved configured tap action.
- [ ] In `while-held` mode, `CapsLock+W` held unchanged for 100 ms switches North once.
- [ ] `CapsLock+W+D` and `CapsLock+D+W` held unchanged for 100 ms switch North East once.
- [ ] Both direction press orders and release orders produce the same diagonal result.
- [ ] Changing a valid mask before 100 ms restarts the timer and does not switch the earlier mask.
- [ ] Keeping one valid chord held after its switch does not repeat.
- [ ] Releasing all direction keys rearms another switch without requiring CapsLock release.
- [ ] An invalid mask cancels only its timer; a later stable valid mask can still switch during the same CapsLock hold.
- [ ] In `on-release` mode, no direction switches while CapsLock is held and CapsLock release switches once to the last valid mask.
- [ ] Every cardinal and diagonal mapping reaches the correct slot.
- [ ] A direction held before CapsLock remains application input and is ignored by that session.
- [ ] W released before D starts a separate gesture and is not merged into a diagonal.
- [ ] `CapsLock+W+Space` does not toggle the overview and does not stop later direction gestures.
- [ ] `CapsLock+Space` opens or closes the overview, sends no Space, and locks other Caps-mode actions until CapsLock release.
- [ ] Keys still held from opening do not navigate the overview.
- [ ] An unbound `CapsLock+Q` passes Q through and does not run the CapsLock tap action.
- [ ] Keyboard auto-repeat does not dispatch an extra workspace action.

### Legacy and pass-through

- [ ] Alt then CapsLock and CapsLock then Alt follow the approved exact legacy rule.
- [ ] Ctrl then CapsLock and CapsLock then Ctrl follow the approved exact legacy rule.
- [ ] Alt and Ctrl both held before CapsLock run no legacy or tap action, and their key-up events pass through.
- [ ] WASD and Space reach normal applications when no owning context is active.
- [ ] Closing the overview releases its logical input ownership.
- [ ] A consumed key remains guarded until its physical key-up after a context closes.
- [ ] `workspace-system` toggle works from every overview subcontext unless hotkey recording owns input.

<a id="test-4"></a>
## TEST-4: MVP state, window, and switching checks

Canonical behavior: [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2) through [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7).

### Cover feasibility gate

- [ ] A prototype can keep normal inactive windows below one non-activating cover per monitor and active windows above the cover.
- [ ] Haribol! shell UI stays above the active application band.
- [ ] Normal activation and z-order changes can be detected and repaired without trapping a window.
- [ ] A failed stack operation removes every cover and leaves all manageable windows reachable.
- [ ] A controllable topmost window loses topmost only while its assigned workspace is inactive, then regains it when that workspace becomes active.
- [ ] A controllable non-blocklisted fullscreen window minimizes while its assigned workspace is inactive, then returns to its prior fullscreen state when that workspace becomes active.
- [ ] An elevated, protected, or non-responsive window becomes unsupported without a forced move, stack, focus, minimize, or restore operation.
- [ ] If a cover could make an unsupported window unreachable, that monitor stays uncovered and reports reduced isolation.

### Model and events

- [ ] The default model contains exactly eight stable workspaces and a valid one-to-one slot map.
- [ ] A direction action selects the workspace currently mapped to its slot.
- [ ] A new normal window joins the active workspace.
- [ ] A saved matching profile may assign a new window to its saved workspace.
- [ ] An owned dialog follows its root owner through assignment and z-order changes.
- [ ] The cache follows normal create, destroy, focus, title, state, and geometry changes.
- [ ] Reconciliation repairs a missed event without high-rate full-property polling.
- [ ] Unsupported windows keep a visible diagnostic reason.

### Switching and recovery

- [ ] Switching refreshes and saves old geometry before restoring destination geometry.
- [ ] Only active managed workspace windows are above the cover after a successful switch.
- [ ] Last-active focus restores when valid.
- [ ] Missing last-active focus uses the next safe runtime focus entry.
- [ ] A session-only window can be last-active during the current run.
- [ ] A failed verification keeps the previous committed active workspace.
- [ ] An unexpected event during apply causes one bounded refresh and replan or a safe rollback.
- [ ] Rollback does not overwrite a newer external window change.
- [ ] Normal z-order is inactive owner groups, covers, active owner groups, and Haribol! shell UI.
- [ ] Suspend, reload, disable, and exit remove every cover and temporary topmost change.
- [ ] Emergency tray restore works while normal hotkeys are suspended.
- [ ] Emergency restore makes every manageable window reachable.

### Geometry and monitors

- [ ] Freeform geometry restores from normalized work-area coordinates.
- [ ] Every restored titlebar stays reachable.
- [ ] A missing monitor uses the documented temporary fallback without deleting its saved placement.
- [ ] Reconnecting the monitor restores the original saved placement when the user did not replace it.

<a id="test-5"></a>
## TEST-5: MVP persistence and identity checks

Canonical behavior: [`STATE-8`](SYNTHETIC_WORKSPACES_STATE.md#state-8) through [`STATE-11`](SYNTHETIC_WORKSPACES_STATE.md#state-11).

- [ ] The generated default contains exactly eight valid mapped workspaces.
- [ ] Workspace assignment, slot map, freeform geometry, and focus history survive restart.
- [ ] HWND, PID, and runtime record IDs never appear as persistent identity.
- [ ] One window matching tied top profiles becomes ambiguous instead of using file order.
- [ ] One profile matching several live windows becomes ambiguous.
- [ ] Two different VS Code projects can use different explicit profiles.
- [ ] A fragile current-title draft is not saved automatically as stable identity.
- [ ] Broad app visual rules never receive workspace placement or focus history.
- [ ] Every saved focus and layout-order profile belongs to its workspace.
- [ ] No second persisted template index can disagree with `profileOrder`.
- [ ] Invalid JSON or invalid references leave the previous in-memory model active.
- [ ] A failed save leaves the previous JSON file valid.
- [ ] An unsupported schema version fails clearly without a guessed migration.

<a id="test-6"></a>
## TEST-6: MVP overview checks

Canonical behavior: [`OVERVIEW-2`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-2) through [`OVERVIEW-5`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-5), [`OVERVIEW-9`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-9), and [`OVERVIEW-10`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-10).

- [ ] The overview opens at the bounds selected by decision `UI-D01`.
- [ ] Other monitors keep showing the active workspace, and the dim setting controls only their dim layer.
- [ ] Every directional slot uses the arrow and initial color from the canonical [slot mapping](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-2-direction).
- [ ] A slot without a custom name shows its arrow once, while a custom name keeps the arrow as its fixed badge.
- [ ] The grid always contains nine equal cells.
- [ ] Eight slots and the center Control Center stay in the correct cells.
- [ ] The Control Center is clearly a placeholder, not a ninth workspace.
- [ ] All monitor work areas and windows remain visible in each workspace preview.
- [ ] Active workspace, active window, and inactive last-active window use different non-color-only markers.
- [ ] Ambiguous and unsupported windows have visible markers.
- [ ] Keyboard and pointer selection send the same result.
- [ ] Direction navigation chooses the expected cell or nearest window.
- [ ] Choosing a window switches and focuses through one state transaction.
- [ ] Closing without a choice restores the prior valid foreground window.
- [ ] A valid cross-workspace window drop changes assignment.
- [ ] An ambiguous drop remains session-only instead of saving guessed identity.
- [ ] A rejected drop restores only its prior UI state.
- [ ] The visible model matches the newest host revision.
- [ ] Stale replies cannot undo a newer accepted action.
- [ ] Closing the overview removes every overview input context.

<a id="test-7"></a>
## TEST-7: Static and integration checks

Canonical boundaries: [`PLAN-4`](SYNTHETIC_WORKSPACES_PLAN.md#plan-4), [`STATE-3`](SYNTHETIC_WORKSPACES_STATE.md#state-3), and [`OVERVIEW-9`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-9).

- [ ] Descriptor action names match public plugin methods.
- [ ] Default bindings and action catalog names match the implemented actions.
- [ ] Every bridge method name matches between AHK and JavaScript.
- [ ] Every event callback, timer, hotkey, hook, GUI, and context has a cleanup path.
- [ ] Every WebView asset exists in compiled resources.
- [ ] Backend capability failures are explicit.
- [ ] Portable model code contains no direct Windows or AHK input calls.
- [ ] Portable state-store code contains no direct filesystem replacement calls.
- [ ] WebView messages cannot launch raw file paths or arbitrary action strings.
- [ ] No unrelated TODO or FIXME comment was removed.
- [ ] The final DOX pass is complete.

<a id="test-8"></a>
## TEST-8: Later feature checks

These checks do not block the current MVP.

### WinDrag

Canonical behavior: [`INPUT-8`](SYNTHETIC_WORKSPACES_INPUT.md#input-8).

- [ ] A pre-held quick-position modifier is active at drag start.
- [ ] Live quick-modifier down/up changes update drag behavior.
- [ ] The quick modifier remains pass-through.
- [ ] Rejected or blocklisted wildcard starts preserve normal mouse input without replay.
- [ ] Required prefix and quick modifier cannot be configured as the same key.

### Layouts, swap, and settings

Canonical behavior: the later part of [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7) and [`OVERVIEW-6`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-6).

- [ ] Each template applies separately per workspace and monitor.
- [ ] Slot swaps keep the complete workspace identity together.
- [ ] Direction badges and untouched defaults follow slots after a swap.
- [ ] Custom names and colors move with workspace identities.
- [ ] In-cell move and resize previews match committed geometry.
- [ ] Profiled drops survive restart.
- [ ] Session-only drops do not save runtime identity.
- [ ] Host rejection rolls back only the matching optimistic change.
- [ ] Tied top app visual rules report a conflict and use the built-in default.

### Control Center and One-Hand Control

Canonical behavior: [`OVERVIEW-7`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-7) and [`OVERVIEW-8`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-8).

- [ ] Search can switch workspaces, focus windows, run registered actions, and open saved launches.
- [ ] Quick-launch records survive restart and cannot execute unsaved WebView text.
- [ ] Launch arguments round-trip spaces, empty values, embedded quotes, and trailing backslashes.
- [ ] Deleted quick-launch entries remove stale pins.
- [ ] Provider enable settings change the active result sources.
- [ ] One-Hand labels always match the active router mapping.
- [ ] Clickable actions and held-key highlighting follow the active overview context.

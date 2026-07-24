# Synthetic Workspaces MVP Implementation Plan

## Status

- Planning document for the first Windows and AutoHotkey implementation.
- No implementation phase in this document is complete yet.
- This plan turns the direction in `ROADMAP.md` and the `one-left` note in
  `TODO.txt` into an implementable MVP.
- Review the open decisions before implementation.

## Goal

Add eight synthetic workspaces arranged around a central Control Center:

```text
North West    North        North East
West          Control      East
South West    South        South East
```

The workspaces do not use Windows virtual desktops. Haribol! owns the workspace
assignment, saved geometry, focus history, layout, overview, and switching
behavior.

The first version must be useful on Windows now, while keeping operating-system
calls behind small wrappers so the behavior model and stored data can later be
moved to C++ or Rust.

## Roadmap Contract

This plan keeps these rules from `ROADMAP.md`:

- Normal windows receive workspace assignments managed by Haribol!.
- Inactive workspace windows stay below a desktop cover.
- Active workspace windows stay above that cover.
- Haribol! shell UI stays above managed application windows.
- Switching restores saved geometry and focus.
- The app keeps observed, desired, and pending window state separate.
- Switching is one transaction, not many unrelated window actions.
- Native events update the cache, with a slower reconciliation scan as backup.
- Windows-specific input, window, focus, stacking, monitor, and overlay work
  stays outside the portable workspace rules.

Native Windows virtual desktops remain a separate feature. Synthetic
workspaces must not silently move or rename native desktops.

## Terms

- **Slot**: one fixed position in the 3 by 3 direction grid, such as `ne`.
- **Workspace**: a stable logical space with its own ID, windows, name, color,
  layout, and focus history.
- **Slot map**: the current mapping from each fixed slot to a workspace ID.
- **Window record**: live state for one current HWND. It is not a persistent
  identity.
- **Window profile**: saved state for one logical window, including its identity rule, workspace, placement, and unique visual overrides.
- **Window identity rule**: the matching part of a unique window profile.
- **App visual rule**: a broad rule that may style several windows but never owns workspace placement or focus history.
- **Active window**: the real foreground window in the active workspace.
- **Last-active window**: the window that should receive focus next time its
  workspace becomes active.
- **Overview**: the 3 by 3 WebView used to see, configure, and move workspaces
  and windows.
- **Control Center**: the middle cell. It is not a ninth workspace.
- **One-hand control**: contextual keyboard help and actions, also called
  `one-left` in the current TODO note.

## Fixed Direction Model

Use these slot keys in code and stored data:

| Slot | Default label | Direction keys |
|---|---|---|
| `n` | North | `W` |
| `ne` | North East | `W+D` |
| `e` | East | `D` |
| `se` | South East | `S+D` |
| `s` | South | `S` |
| `sw` | South West | `S+A` |
| `w` | West | `A` |
| `nw` | North West | `W+A` |

`CapsLock+Space` opens or closes the overview.

Directional input can use a four-bit mask:

| Direction | Bit |
|---|---|
| North | `1` |
| East | `2` |
| South | `4` |
| West | `8` |

Examples:

- North East is `1 | 2`, which equals `3`.
- South East is `4 | 2`, which equals `6`.
- South West is `4 | 8`, which equals `12`.
- North West is `1 | 8`, which equals `9`.
- North plus South, or East plus West, is invalid.

The bitmask makes matching fast, but it does not solve key ordering by itself.
Correct key-down, key-up, consumption, and commit rules are still required.

## Proposed MVP Defaults

These recommendations are not final until their matching Open Decision is checked:

- There are exactly eight workspace slots.
- One workspace is active globally across all monitors.
- A normal managed window belongs to one workspace.
- Each persistent window profile stores exactly one `workspaceId` for the MVP.
  Multiple workspace tags remain deferred.
- A directional chord targets a slot. It does not target a fixed workspace ID.
- Swapping spaces exchanges their slot positions. Each workspace keeps its
  windows, custom name, color, layout, and rules.
- The direction badge always comes from the current slot.
- An untouched default name and Vastu color also come from the current slot.
- Custom name and color overrides belong to the workspace and move with it.
- Resetting a custom name or color returns to the default of the workspace's
  current slot.
- The overview opens on the monitor containing the mouse pointer.
- Other monitors keep showing the active workspace and may receive a simple
  dim layer while the overview is open.
- The first overview uses colored rectangles, not live window thumbnails.
- Normal `[HOTKEYS]` bindings continue to use the current path, except managed
  CapsLock variants and router-managed mouse triggers.
- The new input router owns multi-key chords and modal input contexts.
- `CapsLock` must go down before a workspace suffix. Direction keys already held
  before it remain normal app input and are ignored for that session.
- Direction-key order after CapsLock is independent. Shift is the default
  WinDrag quick-position modifier.

## MVP Scope

### Workspace Core

- Eight stable workspace records and eight fixed directional slots.
- One active workspace and one last-active window per workspace.
- Assignment of normal windows to one workspace.
- Saved window geometry, monitor, layout position, and focus history.
- Event-driven create, destroy, activate, title, geometry, and state updates.
- A slower reconciliation scan for missed events.
- Transaction-based switching with a desktop cover.
- Safe cleanup on disable, reload, and exit.
- An emergency action that removes covers and restores all manageable windows.

### Input

- `CapsLock` as a pseudo-modifier for the direction layer.
- Direct cardinal and diagonal workspace switching.
- `CapsLock+Space` overview toggle.
- Order-independent direction suffixes after the CapsLock prefix, plus
  order-independent WinDrag modifier state at mouse-down time.
- Contexts for workspace-system input, workspace selection, overview submodes,
  window drag, and hotkey recording.
- One action dispatch path through `App.RunAction()`.
- A held-key snapshot that WinDrag can use at drag start.
- Live modifier changes while a window drag is active.

### Overview

- Full-monitor 3 by 3 WebView grid with eight workspace cells.
- Equal cell sizing, with the Control Center in the middle.
- Space name, short direction badge, color, layout, and activity state.
- Window rectangles based on saved or observed geometry.
- App icon, display title, instance marker, and optional short extra line.
- Strong visual state for the active window and active workspace.
- A separate visible marker for each inactive workspace's last-active window.
- Hover and keyboard-focus toolbars.
- Workspace slot swapping by dragging a dedicated handle.
- Moving windows between workspaces by drag and drop.
- Moving or snapping windows inside one workspace preview.
- Keyboard navigation between workspace cells and window rectangles.

### Workspace Settings

- Custom workspace name.
- Direction badge remains visible after the name is customized.
- Custom solid workspace color.
- Tiling template selection.
- Reset name, color, and layout to defaults.

### Window Settings

- Display-only custom title. This does not rename the real application window.
- Optional display-title format using safe known fields.
- Custom overview icon with app-icon fallback.
- Solid base color and color picker.
- One simple same-app color gradation preset for the MVP.
- A large blurred color preview near the picker.
- Unique settings attach to a window profile when possible, never directly to a
  saved HWND.

### Identity and Persistence

- Versioned `synthetic-workspaces.json` beside the active config file.
- Atomic save through a temporary file and replacement.
- Stable workspace IDs.
- Stable user-defined window identity rules.
- Matching by executable path, class, title rule, and optional command-line
  rule.
- Clear handling for ambiguous windows that cannot be safely identified.
- Saved window assignment, normalized geometry, monitor key, layout slot, and
  visual overrides.

### Control Center

- Search across registered Haribol! actions, workspaces, and open windows.
- Manually configured quick-launch entries.
- Pinned actions or launch entries.
- A small built-in clock/date widget.
- A current-workspace status widget.
- Search providers can be enabled or disabled.
- Only registered actions or saved launch entries can be executed.

### One-Hand Control

- A clickable keyboard-shaped overlay for the current overview context.
- Key labels and action labels come from the same input mapping used by the
  router.
- Physical key state is highlighted in the overlay.
- The visible mapping changes when focus moves between spaces, windows,
  settings, search, and drag mode.
- The first release supports the overview only.

## Deferred

- More or fewer than eight slots.
- Multiple workspace tags on one window.
- A separate active workspace for every monitor.
- Native macOS and Linux backends.
- Live DWM thumbnails or video previews.
- Process suspension.
- A complete popup and focus-policy editor.
- A public widget SDK.
- Web, file, calculator, clipboard, and plugin search providers.
- Complex gradients for windows or workspaces.
- Many automatic color-family algorithms.
- Full icon editing or image cropping.
- A universal one-hand overlay for every app mode.
- UI Automation based identity.
- Cloud sync.

## Open Decisions

Resolve these before their related phase starts:

- [x] Use eight directional slots around a central Control Center.
- [x] Use `CapsLock+W/A/S/D` for cardinal directions and two direction keys for
  diagonals.
- [x] Use `CapsLock+Space` to toggle the overview.
- [x] Keep stable workspace IDs separate from directional slots.
- [x] Store structured state in a versioned JSON sidecar.
- [ ] Confirm that tapping and releasing `CapsLock` without a consumed chord
  still runs `SwitchKeyboardLayout()`.
- [ ] Confirm that `Alt+CapsLock` and `Ctrl+CapsLock` keep their current actions
  with the exact legacy arbitration rules below.
- [ ] Confirm one workspace result per CapsLock hold, committed only when
  `CapsLock` is released. This prevents North from firing before North East is
  complete and makes direction-key release order irrelevant.
- [ ] Confirm that opposite direction pairs do nothing and show short visual
  feedback.
- [ ] Confirm that `CapsLock` must be pressed before its workspace suffixes, 
  while the direction suffix order after it remains independent.
- [ ] Confirm Shift as the default WinDrag quick-position modifier.
- [ ] Confirm that `CapsLock` and an owned suffix are consumed for their full
  down/up cycle, while `W`, `A`, `S`, `D`, and `Space` reach the active app when
  no router context owns them.
- [ ] Confirm that directional chords target slots, so swapping spaces changes
  which workspace a direction opens.
- [ ] Confirm that swapping spaces moves the complete workspace identity,
  including its windows, name, color, layout, and focus history.
- [ ] Confirm one global active workspace across all monitors for the MVP.
- [ ] Confirm that the overview opens on the pointer monitor instead of
  spanning the full virtual screen.
- [ ] Confirm one workspace assignment per normal window for the MVP.
- [ ] Choose the default behavior for a taskbar or app activation request from
  an inactive workspace. Recommended MVP: switch to that window's workspace.
- [ ] Choose the MVP policy for topmost, fullscreen, elevated, and
  non-responsive windows.
- [ ] Confirm the exact eight Vastu colors and hex values. The current request
  defines North as green, South as red, East as orange, and West as dark blue.
  The four diagonal colors are not yet defined.
- [ ] Confirm default visible names. Recommended: full names such as
  `North East`, plus a fixed short badge such as `NE`.
- [ ] Confirm the first layout templates. Recommended: `freeform`, `full`,
  `two-columns`, `two-rows`, and `four-grid`.
- [ ] Confirm the first same-app color preset. Recommended: `none` and
  `lightness steps`.
- [ ] Confirm whether custom icon selection accepts any local image or only
  `.ico`, `.png`, and executable icons.
- [ ] Confirm Control Center search providers and the two built-in widgets.
- [ ] Confirm whether `One-Hand Control` is the user-facing name and
  `one-left` remains only an internal nickname.
- [ ] Define the first one-hand action maps. The TODO note gives ideas, but not
  a complete safe mapping.
- [ ] Confirm whether command-line matching is allowed by default in advanced
  identity rules.
- [ ] Confirm that synthetic workspaces and `VirtualDesktopManager` remain
  independent for the MVP.

## App-Wide Chord Input

### Current Limit

The current app maps one AHK hotkey expression to one action. It supports normal
modifiers and one native custom combination such as `CapsLock & W`, but it
cannot represent `CapsLock+W+D` as one order-independent chord.

WinDrag also checks its quick-position modifier after the mouse drag starts.
It currently ignores that mode when the modifier was already held at drag
start. This is why a sequence such as Win, then Shift, then click can behave
differently from pressing Shift after dragging has started.

### Router Ownership

Normal `[HOTKEYS]` keep the current binder, except bindings that use an input
owned by the router while synthetic workspace input is enabled:

- Plain `CapsLock` and managed Alt or Ctrl CapsLock variants.
- CapsLock workspace suffixes.
- Router-managed Win plus mouse drag triggers.

The router reads the configured actions for these bindings and dispatches them
itself. The normal binder must skip them so CapsLock tap and legacy variants do
not fire early or twice.

### Options

| Option | Good parts | Main problem |
|---|---|---|
| Add more exact AHK hotkeys | Small change | Does not solve general three-key chords or contexts |
| Combine `HotIf`, wildcard hotkeys, and local state in every plugin | Works for one focused mode | Repeats state logic and gives different behavior in each plugin |
| Add one app-owned input router with a small Windows/AHK backend | Shared ordering, contexts, consumption, and OSK data | Needs a clear lifecycle and careful key-up cleanup |
| Install a permanent low-level keyboard and mouse hook | Full event control | Higher risk, overlaps the recorder, and is not needed for the first managed key set |

Use one app-owned input router. For the AHK MVP, its Windows backend should
register wildcard down/up callbacks only for the small managed key set. It can
read physical `GetKeyState(..., "P")` to seed or repair state.

Keep a low-level hook as a backend replacement only if dynamic hotkeys cannot
reliably consume or observe a required sequence. The core chord records and
context behavior must not depend on which Windows backend is used.

### Input Router Responsibilities

- Normalize keyboard and mouse names.
- Track managed keys as down or up.
- Keep one fast physical held-key bitmask plus separate masks owned by each
  active binding session.
- Repair state from physical key state after focus changes or missed key-up
  events.
- Keep an ordered context stack.
- Apply each binding's order rule. CapsLock must precede workspace suffixes,
  while suffix directions may arrive in either order.
- Prefer the most specific matching chord.
- Support an explicit commit event for each binding.
- Keep a per-session `hasCommitted` guard so later releases only clear state.
- Ignore normal keyboard auto-repeat unless a binding enables repeat.
- Record which key-down events were consumed and also consume their key-up
  events.
- Keep backend release guards until consumed keys are physically up, even after
  a logical context closes.
- Treat logical context reset and backend release-guard cleanup as separate
  operations. Closing a context stops new ownership but does not drop guards for
  keys that are still down.
- Support pass-through bindings.
- Reset safely on app suspend, reload, lock, hook restart, and context close.
- Dispatch actions through the existing central action dispatcher.
- Give the overview the same active context and mapping data used for actual
  input.

- Register suppressing wildcard hotkeys only under an active `HotIf` context,
  or enable them only while that context owns the keys.
- Define extra keys against the managed matching set. Unrelated unmanaged keys
  do not change a workspace match, while extra direction keys can invalidate it.

### Required Contexts

| Context | Purpose |
|---|---|
| `workspace-system` | Overview toggle across closed and open overview modes |
| `workspace-layer` | CapsLock pseudo-modifier and direct workspace selection |
| `overview-space` | Select a workspace or the Control Center |
| `overview-window` | Select and activate a preview window |
| `overview-move` | Move or snap a selected window |
| `overview-settings` | Workspace and window quick settings |
| `overview-search` | Pass printable input to the WebView search field |
| `window-drag` | WinDrag start state and live modifier changes |
| `hotkey-recording` | Prevent workspace commands while recording another hotkey |

Use this priority for managed input:

1. `hotkey-recording` and app suspension block all workspace bindings.
2. `workspace-system` cannot be shadowed by overview subcontexts.
3. An active `workspace-layer` session owns its managed CapsLock suffixes.
4. The current overview subcontext or window-drag context owns its remaining
   managed input.

Within one level, the highest pushed context wins. Each overview submode is a
real context with a clear entry, exit, and pass-through policy. Closing a mode
must remove its logical context even after an error, while existing release
guards remain until their keys are physically up.

`CapsLock+Space` is a workspace-system binding in both closed and open overview
states, so it can toggle in both directions. Hotkey recording blocks it. After
opening, overview navigation stays disabled until every key from the opening
chord is physically released.

### Proposed Binding Shape

```json
{
  "id": "switch-workspace-ne",
  "context": "workspace-layer",
  "prefixKey": "CapsLock",
  "requiredSuffixKeys": ["W", "D"],
  "suffixOrder": "any",
  "trigger": "prefix-release",
  "allowExtraManagedKeys": false,
  "consume": true,
  "repeat": false,
  "action": "SwitchSyntheticWorkspace(ne)"
}
```

The final stored form may use key IDs or masks internally. User-facing data
should keep readable names.

### CapsLock Session

Recommended behavior after the matching open decisions are accepted:

Session state keeps these values separate:

- `ignoredPreheldSuffixes`: managed suffix keys already down when CapsLock goes
  down. They remain normal app input for this hold.
- `heldDirectionMask`: eligible directions from this session that are still
  physically down.
- `candidateDirectionMask`: the best simultaneous direction mask reached by the
  first direction gesture. Key-up never shrinks it.
- `directionGestureFrozen`: true after all keys from that first gesture are up.
- `isInvalid`, `hasCommitted`, and the set of consumed keys with release guards.

Session rules:

1. `CapsLock` down starts exactly one workspace-layer session and is
   provisionally consumed. The router snapshots pre-held suffixes into
   `ignoredPreheldSuffixes`.
2. A pre-held suffix is not part of the chord. Its matching key-up passes
   through because its key-down already passed through.
3. The router always consumes the matching `CapsLock` up event.
4. The first eligible suffix locks the session type to `direction` or `space`.
5. In direction mode, each eligible direction key-down updates
   `heldDirectionMask`. While the first gesture still has a key down, a valid
   simultaneous mask replaces `candidateDirectionMask`.
6. Direction key-up updates only `heldDirectionMask`. When it becomes empty,
   freeze the candidate. A later separate direction press in the same CapsLock
   hold marks the session invalid instead of merging two taps into a diagonal.
7. An opposite pair, a third direction, or any other invalid direction mask
   makes the session invalid. Invalid state is permanent for that hold.
8. If Space is the first suffix, toggle the overview immediately and set
   `hasCommitted`. Later managed suffixes are consumed but run no second action.
9. If direction mode started first, Space is an incompatible extra suffix. It
   marks the session invalid and does not toggle the overview.
10. On `CapsLock` release, freeze and commit the candidate exactly once. A valid
    cardinal or diagonal switches; an invalid or empty candidate
    gives short feedback and switches nothing.
11. A session with no eligible suffix and no legacy modifier runs the configured
    CapsLock tap action on release.
12. `hasCommitted` prevents another action when remaining keys are released.
13. Release guards keep every consumed suffix down/up pair consumed until its
    physical up event, including after the overview opens or a context changes.
14. Opening the overview starts a transition guard. Navigation becomes active
    only after every key used to open it has been released.
15. The overview remains open after `CapsLock` is released.

Legacy `Alt+CapsLock` and `Ctrl+CapsLock` rules:

- An exact legacy chord works in either key order when it becomes complete
  before the first workspace suffix is accepted.
- The first eligible legacy chord locks the session, sets `hasCommitted`, and
  dispatches once.
- A legacy modifier held before CapsLock is never consumed. Its down already
  passed through, so its up must also pass through.
- A legacy modifier pressed after CapsLock is consumed with a release guard.
- If both `Alt` and `Ctrl` are already down when CapsLock starts, neither exact
  legacy chord matches. The session is invalid and consumed, while both
  pre-held modifier up events still pass through.
- After a suffix or legacy chord locks the session, later router-managed
  modifiers cannot replace the result or cause a second action.

### WinDrag Integration

- Start WinDrag through a suppressing wildcard mouse binding enabled by a fast
  `HotIf` eligibility predicate. Extra allowed modifiers must not prevent the
  start handler from seeing the event.
- The predicate checks the required Win prefix, the complete managed modifier
  set, the configured mouse button, and the target blocklist before AHK consumes
  mouse-down. If it is false, the suppressing callback does not fire and native
  mouse down/up passes through. Do not try to replay rejected input afterward.
- The MVP accepts the required Win prefix plus the configured quick-position
  modifier, which defaults to Shift. Other managed modifiers reject the start
  unless a future binding explicitly allows them.
- For an accepted start, pass the normalized trigger button and initial held-key
  snapshot to WinDrag. Consume the handled mouse down/up pair with a release
  guard.
- Observe the quick-position modifier as pass-through input. Its down and up
  events still reach the active app during `window-drag`.
- If the quick-position modifier is already down, quick positioning starts
  immediately.
- During the drag loop, WinDrag reads `InputRouter.GetHeldSnapshot()` or
  `InputRouter.IsKeyDown()` for live modifier changes. The router must not call
  reentrant feature actions for every modifier event.
- Remove the current rule that requires the modifier to be released once before
  it can activate.
- Validate settings so the required drag prefix and optional quick-position
  modifier cannot use the same key.
- Stop making feature code depend on `A_ThisHotkey` when the router provides the
  trigger button directly.

## Suggested Logical Components

The exact filenames may follow repository conventions at implementation time,
but these responsibilities must stay separate.

### `SyntheticWorkspaces` Plugin

- Declares user actions and simple plugin settings.
- Starts and stops workspace services.
- Does not contain direct Win32 calls.

Suggested public actions:

- `SwitchSyntheticWorkspace(Slot)`
- `MoveWindowToSyntheticWorkspace(Slot, Hwnd:=0)`
- `MoveWindowAndSwitchSyntheticWorkspace(Slot, Hwnd:=0)`
- `ShowSyntheticWorkspaceOverview()`
- `HideSyntheticWorkspaceOverview()`
- `ToggleSyntheticWorkspaceOverview()`
- `DisableSyntheticWorkspaces()`
- `RestoreAllSyntheticWorkspaceWindows()`

### `WorkspaceService`

- Owns workspace records, slot map, active workspace, assignments, focus
  history, and switch transactions.
- Applies create, destroy, activate, and geometry events to the cached model.
- Calls only backend interfaces for operating-system work.

### `WorkspaceStateStore`

- Loads, validates, and saves the JSON data.
- Resolves its file beside the active configuration through an injected
  persistence backend.
- Debounces frequent UI changes.
- Keeps the previous valid state when parsing or saving fails.
- Rejects an unsupported schema version. Add migration code only after a
  released schema actually needs it.

### `PlatformPersistenceBackend`

- Writes and flushes a complete temporary file, then replaces the target using
  the platform's safest atomic operation.
- Keeps filesystem and replacement details outside the portable state store.
- Reports capability or replacement failure without deleting the last valid
  file.

### `WindowIdentityMatcher`

- Builds runtime identity candidates.
- Applies user and automatic window profiles by explicit priority.
- Selects broad app visual rules through their separate priority namespace.
- Returns match reason and confidence for diagnostics.
- Does not silently choose between tied top matches.

### `LayoutEngine`

- Uses normalized rectangles and monitor work areas.
- Has no Win32 calls.
- Calculates template rectangles, freeform restore positions, gaps, snapping,
  and preview geometry.

### `InputRouter`

- Owns contexts, held input, chord matching, consumption, repeat, and action
  dispatch.
- Does not install Windows hooks directly.

### `WindowsInputBackend`

- Registers and unregisters managed key and mouse events.
- Reads physical key state.
- Implements consumed input and key-up cleanup.
- Is the only input component that knows AHK hotkey syntax or low-level Windows
  hook details.

### `WindowsWindowBackend`

- Enumerates manageable windows.
- Reads full window snapshots.
- Reads root owner and popup relationships.
- Reads AppUserModelID when available.
- Reads command lines only for an explicitly enabled advanced identity rule and
  reports access denial without exposing the value in logs.
- Moves, resizes, stacks, activates, and validates windows.
- Reads monitor identities and work areas.
- Subscribes to native window events.
- Creates desktop cover windows.
- Extracts and caches app icons.
- Reports unsupported operations instead of pretending they succeeded.

### `PlatformLauncher`

- Accepts only a validated saved quick-launch record.
- Starts an executable with a separate argument array and working directory.
- On Windows, passes the executable separately when possible and serializes the
  argument array with CreateProcess-compatible rules for spaces, empty values,
  embedded quotes, and trailing backslashes.
- Keeps operating-system launch calls outside Control Center logic.

### `WorkspaceOverviewGui`

- Owns the overview WebView window and its callbacks.
- Sends one normalized state payload to JavaScript.
- Pushes throttled later updates.
- Validates all commands received from the WebView.
- Stays separate from the settings WebView bridge.

### Overview Frontend

- Own HTML, CSS, JavaScript, grid rendering, selection, pointer drag, snapping,
  quick settings, search, and one-hand hints.
- Uses Pointer Events for mouse and touch drag behavior.
- Does not duplicate workspace business rules from the AHK service.

## Window Model

### Runtime Window Record

Each managed live window needs:

- Internal runtime record ID.
- HWND and PID.
- Executable path and executable name.
- Window class.
- AppUserModelID when available.
- Current title and normalized title.
- Owner, root-owner, and popup relation.
- Observed geometry and monitor.
- Observed visible, minimized, maximized, fullscreen, topmost, and cloaked state.
- Observed stack position.
- Desired workspace, geometry, topmost state, and focus.
- Pending changes from the current transaction.
- Last focus time.
- Matched persistent identity rule ID, if any.
- Display title, icon, base color, and color preset.

HWND and PID must never be saved as persistent identity.

### Managed Window Filter

The backend should classify each top-level window as:

- `managed`: normal window that can join a workspace.
- `owned-dialog`: follows its root owner's workspace.
- `global`: visible on every workspace by explicit rule.
- `shell`: Windows or Haribol! shell UI.
- `ignored`: tool, hidden, cloaked, or other non-user window.
- `unsupported`: elevated, protected, fullscreen, or otherwise not safely
  controllable under the selected policy.

The filter must explain its result for diagnostics. Do not reuse a private
WinDrag filter because drag eligibility and workspace eligibility are not the
same.

### New Window Defaults

- A dialog inherits its root owner's workspace.
- A normal unowned window starts in the active workspace.
- A window with a saved matching rule uses that rule's workspace.
- If a saved rule points to another workspace, the default popup policy decides
  whether to switch, show without focus, or mark that workspace urgent.
- The recommended MVP activation policy is to switch to the target workspace.

### Runtime Focus and Layout Identity

- Keep runtime focus history by runtime window record ID for every live managed
  root window, including session-only and ambiguous windows.
- A session-only window may be last-active and restore focus during the current
  run.
- Persist only the filtered unambiguous profile IDs as
  `focusHistoryProfileIds`. After restart, resolve them back to live runtime
  records and append other focused live windows in session order.
- Build each monitor's runtime template order from resolved persisted
  `profileOrder` entries, followed by session-only runtime record IDs in stable
  current-session order.
- Never save an HWND or runtime record ID. Session-only focus and order disappear
  at exit without blocking their current-session behavior.

## Stable Window Identity

### Profile Selection

1. Every condition inside one profile must match the live window.
2. Collect all matching profiles and keep only the highest numeric priority.
3. If exactly one profile remains, use it.
4. If several profiles share the highest priority, mark the live window
   ambiguous. Do not use file order as a tie-breaker.
5. Give automatic profiles a lower default priority than user profiles.

Also mark a profile ambiguous if it matches several live top-level windows. Do
not use launch order as a permanent identity. It can be used only as a temporary
session label such as `2 of 3`.

### Unique Window Profiles

A window profile must identify at most one logical top-level window. It owns the
state that would be unsafe to apply to several windows:

- Stable profile ID, source (`auto` or `user`), and rule priority.
- Executable path or name exact match.
- Window class exact match.
- AppUserModelID exact match when available.
- Title exact, contains, wildcard, or regular-expression match.
- Optional command-line contains or regular-expression match.
- Optional root-owner rule.
- Exactly one workspace assignment for the MVP.
- Monitor-specific normalized freeform geometry.
- Custom display title, title format, icon, and per-window color override.

If one profile matches several live top-level windows at equal strength, it is
ambiguous. Do not apply its workspace or placement until the user narrows it.

### App Visual Rules

App visual rules may intentionally match several windows. They provide only
broad presentation defaults such as:

- Stable rule ID and numeric priority.
- App grouping key.
- Executable path, executable name, or AppUserModelID match.
- Default icon fallback.
- Base color.
- Same-app instance color preset.

Choose the single highest-priority matching app visual rule. If top priority is
tied, report the conflict and use the built-in visual default instead of file
order. App visual rules never store workspace assignment, geometry, focus
history, or a unique window title. A unique window profile visual override wins
over the selected app visual rule.

### Command-Line Privacy

Command-line inspection can fail for elevated apps and can expose private local
paths. It is disabled by default, runs locally only when a user enables an
advanced rule, stores only the user-entered matcher, and reports access failure
without logging the full command line.

### Ambiguous Windows

When several windows have the same weak identity:

- Give them visible session labels such as `1 of 3`.
- Do not silently restore one project's geometry onto another project.
- Show a `Needs identity rule` marker in overview settings.
- Let the user create a rule from current executable, class, and title data.
- Show a plain preview of which current windows the rule matches before save.

VS Code projects are a main example. A user rule can match a stable project or
folder part of the title instead of only matching `Code.exe`.

### Persisting a Moved Window

When the user moves a window, changes its workspace, or saves its quick
settings:

1. If it already has one unambiguous window profile, update that profile.
2. Otherwise, create an `auto` profile only when stable fields, such as
   AppUserModelID or executable path plus class and a stable title marker,
   identify one current window.
3. Treat a matcher based only on the current exact title as fragile. Keep it as
   a draft until the user confirms it.
4. If the candidate is weak, fragile, or matches several windows, apply the
   change for this session only, show `Not saved - define identity`, and offer
   the advanced identity editor with a match preview.

Do not put placement into a broad app visual rule. The user may replace an
automatic exact-title matcher with a better project, document, or command-line
rule later.

## Persistence Contract

Store data in `synthetic-workspaces.json` beside the active config file.

Recommended first schema excerpt. It shows record shapes but is not a complete
valid file:

```json
{
  "schemaVersion": 1,
  "activeWorkspaceId": "ws-01",
  "slotMap": {
    "n": "ws-01",
    "ne": "ws-02",
    "e": "ws-03",
    "se": "ws-04",
    "s": "ws-05",
    "sw": "ws-06",
    "w": "ws-07",
    "nw": "ws-08"
  },
  "workspaces": [
    {
      "id": "ws-01",
      "customName": null,
      "customColor": null,
      "layoutsByMonitor": {
        "display-primary": {
          "templateId": "freeform",
          "gap": 8,
          "profileOrder": ["window-vscode-atsuikagi"]
        }
      },
      "focusHistoryProfileIds": ["window-vscode-atsuikagi"]
    }
  ],
  "windowProfiles": [
    {
      "id": "window-vscode-atsuikagi",
      "source": "user",
      "priority": 100,
      "match": {
        "processName": "Code.exe",
        "class": "Chrome_WidgetWin_1",
        "titleContains": "AtsuiKagi"
      },
      "workspaceId": "ws-01",
      "placementByMonitor": {
        "display-primary": {
          "normalizedRect": {
            "leftRatio": 0.0,
            "topRatio": 0.0,
            "widthRatio": 0.5,
            "heightRatio": 1.0
          }
        }
      },
      "visual": {
        "customTitle": "AtsuiKagi",
        "titleFormat": "{customTitle} - {instance}/{count}",
        "icon": "",
        "baseColor": "#4F8DF7"
      }
    }
  ],
  "appVisualRules": [
    {
      "id": "app-vscode",
      "priority": 50,
      "match": {
        "processName": "Code.exe"
      },
      "visual": {
        "baseColor": "#4F8DF7",
        "colorPreset": "lightness-steps"
      }
    }
  ],
  "quickLaunchEntries": [
    {
      "id": "launch-example",
      "name": "Example",
      "executable": "C:\\Path\\To\\App.exe",
      "arguments": ["--example"],
      "workingDirectory": "C:\\Path\\To",
      "icon": ""
    }
  ],
  "controlCenter": {
    "enabledProviders": ["actions", "workspaces", "windows", "quickLaunch"],
    "pins": [
      {"type": "quickLaunch", "id": "launch-example"}
    ]
  }
}
```

The default-state generator must create the omitted seven workspace records.
Validation must require:

- Exactly the known eight slot keys and exactly eight workspace records.
- Unique workspace IDs and a one-to-one slot-to-workspace mapping.
- An `activeWorkspaceId` present in both the workspace records and slot map.
- Unique profile, app-rule, and quick-launch IDs.
- Every workspace, profile, focus-history, layout-order, and typed pin reference
  to resolve to the correct record type or registered action.
- One valid `workspaceId` per window profile for the MVP.
- Every persisted focus-history and `profileOrder` entry to reference a profile
  assigned to that same workspace.
- `profileOrder` to be the only persisted source for template ordering. Do not
  also save a per-profile template index.
- No duplicate profile in one monitor order or in conflicting workspace orders.
- Pin types limited to `action` and `quickLaunch` for the MVP, with the ID
  validated in the matching namespace.
- Finite normalized geometry values within their allowed ranges.
- Valid template IDs, monitor keys, colors, title formats, priorities, and launch
  fields.

### Save Rules

- Validate before replacing the current in-memory model.
- Write a complete temporary file.
- Flush and close it before replacement.
- Replace the old file atomically when the platform supports it.
- Keep the previous valid file if any step fails.
- Debounce rapid drag and color-picker updates.
- Save immediately after a completed workspace switch, slot swap, assignment,
  or identity-rule edit.
- Never store runtime observed or pending state.

### Monitor and Geometry Rules

- Save geometry normalized to the monitor work area.
- Save a backend-provided monitor key, not only a numeric monitor index.
- Prefer a Windows display device path or stable device identity when
  available. Fall back to device name and geometry signature.
- Apply a workspace template separately on each monitor. Group windows by their
  saved monitor key and keep one stable profile order per workspace and monitor.
- Template layouts recalculate real pixels from the current work-area size.
- If a saved monitor is missing, keep its original placement record unchanged.
  Temporarily project its windows onto the pointer or primary monitor and clamp
  them to that work area.
- Replace the missing-monitor record only after the user moves the window or
  confirms the fallback. This allows the original layout to return when the
  monitor reconnects.

## Workspace Switching Transaction

A switch must run as one guarded prepare, apply, verify, and commit transaction:

1. Validate the destination slot and resolve its workspace ID.
2. Refresh the window cache before saving any current geometry or focus.
3. Capture refreshed geometry, focus history, and a rollback snapshot in an
   in-memory candidate state.
4. Resolve root-owner groups, dialogs, unsupported windows, and monitor groups.
5. Prepare saved freeform or template geometry, z-order, topmost, cover, and
   runtime focus operations without changing the real desktop.
6. Start the guard and mark each expected property change as pending under one
   transaction ID.
7. Apply the prepared geometry once in batches.
8. Stack whole root-owner groups in this normal z-order: inactive groups, all
   monitor covers as one contiguous band, active groups, then Haribol! shell UI.
   Handle approved topmost windows separately.
9. Focus the valid last-active runtime window record, or the next valid runtime
   record in focus history.
10. Read back geometry, stack bands, covers, and foreground focus.
11. Run at most one bounded repair pass, then verify again.
12. On failure, restore only snapshot properties that still equal values applied
   by this transaction. Never overwrite a newer external change.
13. If safe stacking cannot be restored, remove every cover and make all
   manageable windows reachable.
14. Only after successful verification, commit `activeWorkspaceId`, geometry,
   focus history, and the candidate state.
15. Clear pending state and the transaction guard in one cleanup path.
16. Save the committed state and push one new model revision to the overview.

Each pending entry records the transaction ID, runtime record ID, property,
prior value, and expected target. A native event matching that target updates
observed state but cannot start another switch. An unexpected create, destroy,
geometry, stacking, or focus event marks the plan stale. Stop applying, refresh,
and replan at most once. If it still cannot verify, use the guarded rollback and
safe cover removal path. A failed transaction must not change or save
`activeWorkspaceId`.

### Desktop Cover

- Use one non-activating cover window per monitor.
- Covers belong to Haribol! and are excluded from workspace enumeration and
  focus history.
- Treat every root owner and its owned dialogs as one stacking group.
- Keep all monitor covers together between inactive and active owner groups.
- Overview and other Haribol! shell UI stay above the active application layer.
- Apply the approved topmost policy outside the normal z-order band.
- Destroying the app must also destroy the covers.
- If the app crashes, owned cover windows disappear with the process, so normal
  windows are not permanently hidden.

### Suspend and Emergency Restore

- Add workspace lifecycle callbacks that run before app-wide hotkeys are
  suspended and after they resume.
- Before suspend, remove covers, clear temporary topmost changes, restore all
  manageable windows, and release suppressing input contexts.
- On resume, rebuild and verify the cache before synthetic mode can recreate
  covers.
- Keep an emergency restore command in the tray menu. It must remain callable
  while normal hotkeys are suspended and must not depend on the input router.
- Disable synthetic switching if suspend cleanup or resume verification fails.

### Reconciliation

- Use native window events for immediate updates.
- Run a low-rate scan, recommended every one or two seconds.
- Scan only properties needed to repair the cached model.
- Do not poll every window property at a high rate.
- Pause or reduce reconciliation while a switch transaction is applying.

## Layout Engine

### First Templates

- `freeform`: saved normalized rectangles.
- `full`: one full work-area slot.
- `two-columns`: equal left and right slots.
- `two-rows`: equal top and bottom slots.
- `four-grid`: equal 2 by 2 slots.

The exact shipped list remains an open decision.

### Rules

- Template math uses normalized rectangles.
- Apply configured outer gap and inner gap.
- Respect minimum window sizes where known.
- Keep every resulting titlebar reachable.
- Use workspace `profileOrder` as the canonical persisted template order.
- Append session-only runtime record IDs in stable current-session order without
  saving them.
- Extra windows stack in the last slot or remain freeform according to one
  explicit template policy.
- Missing windows do not destroy their saved profile order.
- Dragging inside an overview cell shows candidate snap zones before drop.
- Dropping a profiled window into a template slot updates `profileOrder`.
  Dropping a session-only window updates only runtime order.
- Dropping in `freeform` stores a normalized rectangle when identity is stable.

Do not call private WinDrag or WindowStash helpers. Move only the required
rectangle and monitor ideas into the shared layout or backend boundary.

## Workspace Overview

### Window and Grid

- Use a separate borderless `WebViewGui`, not the settings WebView.
- Open at the pointer monitor's work-area bounds.
- Use CSS Grid with three equal columns and three equal rows.
- Give every workspace cell a stable `data-slot` and `data-workspace-id`.
- Keep the center cell reserved for the Control Center.
- Scale current monitor work areas into each workspace preview and show clear
  monitor boundaries, so windows from all monitors remain visible.
- Support mouse, touch, and keyboard focus.
- Add all frontend assets to compiled-build resources.

### Focus Lifecycle

- Capture the foreground managed window before activating the overview WebView.
- Exclude the overview, covers, and other Haribol! shell UI from workspace focus
  history and inactive-window activation policy.
- Opening the overview must not change `activeWorkspaceId`.
- When the user chooses a window, close the overview and make that switch and
  focus target part of one workspace transaction.
- When the overview closes without a choice, restore the captured window if it
  is still valid in the active workspace. Otherwise use the normal safe focus
  fallback.
- Remove all overview input contexts even if close or focus restoration fails.

### Workspace Cell

Each cell shows:

- Custom name.
- Fixed short direction badge.
- Workspace color.
- Selected layout name or icon.
- Window count.
- Urgent or unsupported-window marker when needed.
- A miniature work-area surface containing window rectangles.
- Bottom toolbar on hover or keyboard focus.

Workspace toolbar:

- Drag handle for slot swap.
- Edit name and color.
- Choose layout.
- Reset workspace defaults.

Dragging must start only from the handle, so selecting a space does not
accidentally move it.

### Window Rectangle

Each rectangle shows as space allows:

- Solid base color.
- App icon.
- Display title.
- App name or short extra line.
- Same-app instance marker such as `2/3`.
- Unsupported or ambiguous identity marker.
- Hover or keyboard-focus settings button.

Visual state:

- Active real window: thick white rounded border plus shadow.
- Active workspace: strong outer ring.
- Last-active window in an inactive workspace: thinner focus marker.
- Other windows: slightly dimmed, but still readable.
- Do not use color as the only active or error indicator.

Window quick settings:

- Custom display title.
- Display-title format.
- Custom icon.
- Solid base color.
- Same-app color preset.
- Open advanced identity rule.
- Reset visual overrides.

For the MVP, use `none` and one predictable lightness-step preset. More
gradation modes and gradients can be added later.

### Color Picker

- Reuse the existing local color-picker ideas where practical.
- Show the selected color as a large blurred preview near the picker.
- Keep the exact hex value visible and editable.
- Show readable foreground text over light and dark colors.
- Save only after a valid color is selected.

### Window Movement

- Dragging to another workspace cell changes workspace assignment on drop.
- Dragging inside one cell updates freeform geometry or a template slot.
- Show a snap preview before drop.
- Keep UI drag state local until a valid drop commits.
- Send one validated command to the host after drop.
- If the host rejects the change, restore the prior UI state and show the
  reason.

### Keyboard Navigation

Minimum behavior:

- Overview focus starts on the active workspace.
- `W`, `A`, `S`, and `D` move between the 3 by 3 cells.
- `Enter` opens the selected space or enters its window-selection level.
- Inside a workspace, direction keys choose the nearest window in that
  direction using rectangle centers.
- `Enter` on a window switches to its workspace and focuses it.
- `Escape` goes back one level, then closes the overview.
- A clear key opens workspace or window settings.
- A clear key enters move mode.
- Search focus temporarily gives text keys to the search box.

The exact one-hand command keys remain an open decision. Navigation and command
bindings must not conflict in one context.

## Control Center

### Middle Cell

The collapsed middle cell shows:

- Search field.
- Current time and date.
- Active workspace name.
- A small list of pinned actions or launches.

Selecting the middle cell may expand the Control Center over the overview while
keeping a clear Back action.

### Search Providers

First providers:

- Registered Haribol! actions.
- Workspace names and direction badges.
- Open managed windows.
- Manually saved quick-launch entries.

Search results must carry typed IDs. Do not send arbitrary JavaScript strings
to the AHK action parser.

Action results run through the existing registered action dispatcher. Quick
launch results run only saved, validated launch records.

### Quick-Launch Entries

- Provide create, edit, delete, pin, unpin, and run controls inside the Control
  Center settings.
- Store a stable ID, display name, executable path, argument array, optional
  working directory, and optional icon.
- Keep the executable and each argument as separate values. Never build a shell
  command string from WebView text.
- Validate the record in AHK before save and again before launch.
- Run entries through a platform launcher wrapper. The Windows backend starts
  the validated executable directly without a command shell and uses the
  defined CreateProcess-compatible argument quoting.
- Deleting an entry also removes stale pin references.
- Launch paths and arguments remain local and are not included in diagnostics by
  default.

### Widgets

MVP widgets:

- Clock and date.
- Current workspace status.

Keep these as built-in cards. Do not design a public widget platform until a
real third widget needs the contract.

## One-Hand Control

### Source Layout

The current TODO note gives this left-side keyboard idea:

```text
Q W E R T
A S D F G
Z X C V B
```

Its draft labels include Quit, Window, Run, Top or Tile, App, Space or system
actions, Drag, Find, Grid, Overlap, and Color. These are ideas, not a complete
safe binding table.

### MVP Behavior

- Render the small keyboard overlay inside the overview.
- Show only actions valid for the current focus level.
- Make every shown key clickable.
- Highlight held physical keys.
- Use the input router's binding records as the source of truth.
- Hide or dim actions that cannot run for the selected item.
- Show a short description on hover or focus.
- Keep destructive actions such as closing a real window clearly separated and
  confirmed according to existing app safety rules.

The OSK follows the real router contexts:

- `overview-space` for workspace and Control Center selection.
- `overview-window` for window selection.
- `overview-move` for window move and snap actions.
- `overview-settings` for the selected workspace or window settings.
- `overview-search` for search commands while printable text passes through.

The OSK must not keep a second action map that can drift away from real
bindings.

## WebView Bridge

Use a focused overview bridge with operations similar to:

- `GetWorkspaceOverviewState`
- `SwitchWorkspace`
- `FocusWorkspaceWindow`
- `SwapWorkspaceSlots`
- `MoveWorkspaceWindow`
- `UpdateWorkspace`
- `CreateWindowProfile`
- `UpdateWindowProfile`
- `DeleteWindowProfile`
- `UpdateAppVisualRule`
- `CreateQuickLaunchEntry`
- `UpdateQuickLaunchEntry`
- `DeleteQuickLaunchEntry`
- `SearchControlCenter`
- `RunControlCenterResult`
- `CloseWorkspaceOverview`

Final names should match existing bridge style.

Bridge rules:

- Pass JSON for structured input and output.
- Include a monotonic `modelRevision` in every full state and pushed update.
- Give every mutating command a unique `requestId` and `basedOnRevision`.
  Return the same request ID and resulting revision in success or error replies.
- Reject a stale mutation when applying it could overwrite newer host state.
- JavaScript ignores older revisions and rolls back only the optimistic change
  linked to the rejected request ID.
- Validate slot IDs, workspace IDs, runtime window record IDs, profile IDs,
  app-rule IDs, and quick-launch IDs in AHK.
- Never trust an HWND received from JavaScript without resolving it against the
  current cached record.
- Return structured success or error results.
- Throttle event pushes and coalesce repeated geometry updates.
- Do not expose raw file execution to arbitrary WebView messages.

## Platform Boundary

The portable logic should depend on capabilities, not direct Windows calls.

| Capability | Windows MVP implementation |
|---|---|
| Input events | Dynamic AHK wildcard key and mouse callbacks |
| Physical input state | `GetKeyState(..., "P")` through input backend |
| Window enumeration | AHK window APIs through window backend |
| Window events | WinEvent and shell events through one event service |
| Geometry | DWM visible frame with normal window-position fallback |
| Batch placement | `SetWindowPos` and deferred-window positioning when practical |
| Focus | Validated foreground and activation calls |
| Cover layer | Non-activating Haribol! GUI per monitor |
| App metadata | Icon, AppUserModelID, and optional guarded command-line reads |
| Monitor identity | Display device identity with documented fallback |
| Process launch | Direct validated executable launch without a command shell |
| Persistence | JSON sidecar and Windows-safe atomic replacement |

The core service, identity matcher, layout math, data validation, and overview
protocol must not call `WinGet*`, `WinMove`, `DllCall`, `GetKeyState`, or read
`A_ThisHotkey`.

## Failure and Recovery Rules

- Never report a switch as complete if the destination focus or stacking check
  failed.
- Show unsupported windows in diagnostics instead of hiding them from the
  model.
- Keep elevated or protected windows visible under the chosen safe policy.
- If a cover cannot be placed correctly, remove it and stop synthetic mode.
- `RestoreAllSyntheticWorkspaceWindows()` removes covers, clears temporary
  topmost changes, makes managed windows reachable, and disables switching.
- Reload and exit handlers perform the same cleanup.
- Invalid JSON does not replace the last valid in-memory state.
- A failed save does not replace the last valid file.
- A failed WebView command restores the prior visual state.
- A missed key-up event cannot leave WASD blocked after a context closes.

## Existing Code to Reuse Carefully

- `includes/AKApp.ahk`
  - Action catalog, central action dispatch, logging, and error handling.
- `includes/AKGui.ahk`
  - WebView creation, callback registration, JSON state injection, and later
    script updates.
- `includes/HotkeyRecorder.ahk`
  - Reference for normalized Windows keyboard and mouse event handling.
  - Do not turn the recorder itself into an always-running router.
- `plugins/WindowResizeDialog.ahk`
  - Reference for contextual wildcard WASD down/up state and diagonal input.
- `plugins/WinDrag.ahk`
  - `SetWindowPos`, visible frame, snap-zone, and neighboring-window ideas.
  - Do not call its private helpers from workspace code.
- `plugins/WindowStash.ahk`
  - Monitor-change, work-area, clamping, and invisible-border ideas.
- `plugins/WindowManager.ahk`
  - Window enumeration, visible-frame fallback, app border highlighting, and
    WinEvent-hook patterns.
- `plugins/ShellMessageHook.ahk`
  - Reference for create, destroy, and activate events.
  - It is currently incomplete and should not be treated as the full window
    event service without repair.
- `lib/jsongo.ahk`
  - JSON conversion.
- Existing color picker and local icon assets
  - Reuse generic behavior, but keep the overview bridge separate from settings.

## Implementation Phases

### Phase 1: Resolve Product Decisions and Data Contracts

- [ ] Resolve the CapsLock, chord timing, invalid direction, and key
  consumption decisions.
- [ ] Resolve the one-workspace, global-monitor, and overview-monitor decisions.
- [ ] Define the complete default direction names and Vastu colors.
- [ ] Confirm whether default names and colors follow slots while custom values
  move with workspace identity.
- [ ] Confirm first layouts, color preset, Control Center providers, and widgets.
- [ ] Confirm safe unsupported-window behavior.
- [ ] Finalize runtime records, persisted schema, bridge payloads, and revision
  rules.
- [ ] Define input, window, overlay, launch, and persistence backend capabilities.
- [ ] Define a complete default-state generator for all eight workspaces.

Success criteria:

- The document has no unresolved decision that changes the core data model or
  input semantics.
- A complete default document based on the example passes the planned validator.

### Phase 2: Shared Input Router

- [ ] Add normalized key and mouse IDs.
- [ ] Add physical held-key state, ignored pre-held suffixes, separate live and
  candidate direction masks, and physical-state repair.
- [ ] Add context stack, non-shadowable workspace-system priority, entry, exit,
  and pass-through rules.
- [ ] Register suppressing wildcard inputs only while an owning `HotIf` context
  is active.
- [ ] Add prefix-first matching, first-suffix mode lock, candidate freeze,
  CapsLock-release commit, repeat, and full down/up consumption.
- [ ] Add the `hasCommitted` latch, invalid-session consumption, release guards,
  and overview opening guard.
- [ ] Route CapsLock tap and exact Alt/Ctrl legacy chords through the router and
  exclude their duplicate normal hotkey registrations.
- [ ] Use temporary recorder actions for workspace bindings in this phase. Do
  not expect real switching before the workspace service and backend exist.
- [ ] Add overview system and subcontext binding records, including search text
  pass-through.
- [ ] Add suspend, reload, recorder, and missed-key-up cleanup.
- [ ] Route temporary recorder actions through the central dispatcher.
- [ ] Gate WinDrag mouse suppression in its `HotIf` predicate so pre-held Shift
  starts correctly and rejected input passes through without replay.
- [ ] Keep the configured quick modifier itself pass-through.
- [ ] Keep live modifier changes during dragging through router state reads.

Success criteria:

- Recorded CapsLock tap and every approved recorder action fire exactly once.
- Both direction-key orders and both release orders resolve to the same mask.
- A direction held before CapsLock remains app input, and separate direction
  taps are never merged into a diagonal.
- Releasing CapsLock before suffix keys commits once; later releases only clear.
- Invalid masks and direction-plus-Space never run the CapsLock tap or overview
  toggle action.
- Alt/Ctrl legacy chords work in both key orders under the approved priority.
- Workspace-system toggle works from every overview subcontext unless hotkey
  recording owns input.
- Overview input owns WASD only while its context is active, and opening keys do
  not navigate it.
- Pre-held WinDrag modifiers work, while rejected or blocklisted starts preserve
  normal mouse input.

### Phase 3: Workspace Model, Layout, and Persistence

- [ ] Add the `SyntheticWorkspaces` plugin and public action surface, with real
  switching kept disabled until Phase 5 is ready.
- [ ] Create exactly eight stable workspace records and the one-to-one slot map.
- [ ] Add active workspace and persistent per-workspace focus history.
- [ ] Add runtime observed, desired, and pending window records.
- [ ] Add normalized freeform geometry and monitor-scoped template order.
- [ ] Add first tiling templates and stable profile-to-slot order per monitor.
- [ ] Split unique window profiles from broad app visual rules.
- [ ] Add persistent quick-launch record validation and storage.
- [ ] Validate all IDs, references, slot keys, record counts, and normalized
  ranges with useful error messages.
- [ ] Add atomic load and save through the injected Windows persistence backend.
- [ ] Reject unsupported schema versions without speculative migration code.
- [ ] Add save debounce.
- [ ] Add stable monitor keys and non-destructive missing-monitor fallback.
- [ ] Add identity matching, automatic stable profiles, overlapping-profile
  ambiguity, app visual rule priority, and fragile-title draft reporting.
- [ ] Add runtime record focus history and session-only template order.

Success criteria:

- A pure in-memory model can swap slots without changing workspace identity.
- A complete generated default has eight unique mapped workspaces and validates.
- Valid workspace, layout, identity, and quick-launch data survives restart.
- Invalid data leaves the previous valid state untouched.

### Phase 4: Windows Window Backend and Cache

- [ ] Add manageable-window enumeration and classification.
- [ ] Read complete snapshots including owner and root owner.
- [ ] Read AppUserModelID with a clear unavailable result.
- [ ] Add optional command-line reads for enabled advanced rules, with access
  failure and privacy-safe diagnostics.
- [ ] Add stable monitor and work-area discovery.
- [ ] Add create, destroy, activate, title, state, and geometry event handling.
- [ ] Add listener cleanup.
- [ ] Add low-rate reconciliation.
- [ ] Add icon extraction and cache.
- [ ] Exclude Haribol! covers, overview, and shell UI.
- [ ] Apply blocklist and unsupported-window policy.

Success criteria:

- The cache follows normal window creation, destruction, focus, title, and
  geometry changes.
- Dialogs are linked to their root owners.
- AppUserModelID and optional command-line failures are explicit and safe.
- Unsupported windows have a visible reason.

### Phase 5: Cover and Workspace Transactions

- [ ] Create one non-activating cover per monitor.
- [ ] Add prepare, apply, verify, commit, bounded repair, and guarded rollback.
- [ ] Match expected native events to pending properties and replan once after
  an unexpected event.
- [ ] Add batched geometry and root-owner-group z-order application.
- [ ] Keep all monitor covers in one band between inactive and active groups.
- [ ] Add saved per-monitor geometry or template restore.
- [ ] Add last-active focus restore and focus-history fallback.
- [ ] Add inactive-window activation policy.
- [ ] Add separate temporary topmost-state handling.
- [ ] Commit and save `activeWorkspaceId` only after successful verification.
- [ ] Connect the router's real cardinal, diagonal, and overview actions now that
  the workspace service and switch transaction exist.
- [ ] Add pre-suspend cleanup, safe resume, disable, reload, and exit cleanup.
- [ ] Add an unsuspended tray emergency restore action.

Success criteria:

- Direct switching shows only the active managed workspace above the cover.
- Switching restores valid geometry and focus.
- Failed stacking removes the cover instead of trapping windows.
- Failed verification leaves the prior active workspace committed.
- Emergency restore makes every manageable window reachable.

### Phase 6: Overview WebView

- [ ] Add the separate overview WebView host and bridge.
- [ ] Add compiled-build resources.
- [ ] Render the equal 3 by 3 grid and monitor sub-surfaces.
- [ ] Render all workspace metadata and window rectangles.
- [ ] Add active, last-active, ambiguous, urgent, and unsupported visual states.
- [ ] Add keyboard cell and window navigation through real router subcontexts.
- [ ] Reserve toolbar layout and keyboard focus targets, but keep mutation
  controls disabled until Phase 7 implements their commands.
- [ ] Add color picker and large blurred preview.
- [ ] Capture prior focus, exclude shell focus events, and restore or apply the
  selected focus target on close.
- [ ] Add `modelRevision`, command `requestId`, stale-update rejection, and
  request-scoped UI rollback.
- [ ] Add throttled live model updates.

Success criteria:

- The overview opens and closes without changing the active app unexpectedly.
- Eight slots and the center Control Center always occupy the correct cells.
- The visible model matches the newest host revision.
- Stale replies cannot undo a newer drag or settings change.

### Phase 7: Drag, Snap, and Configuration

- [ ] Add handle-only workspace slot swapping.
- [ ] Add window movement between workspaces.
- [ ] Add freeform rectangle movement and resize inside a cell.
- [ ] Add template slot snapping and preview.
- [ ] Apply valid drops as one host transaction.
- [ ] Persist through an existing unique profile, create an automatic profile
  only for a unique candidate, or show the session-only warning.
- [ ] Enable workspace and window quick-setting toolbars and host commands.
- [ ] Add workspace name, color, and layout reset using current slot defaults.
- [ ] Add custom display title and format.
- [ ] Add custom icon selection and fallback.
- [ ] Add unique per-window color overrides and broad same-app visual rules.
- [ ] Add advanced identity-rule editor and match preview.

Success criteria:

- Slot swaps keep the full workspace identity together.
- Window drops survive restart when a stable identity rule exists.
- Ambiguous drops never save guessed placement to a broad app rule.
- Rejected drops and settings changes restore the previous UI state.

### Phase 8: Control Center and One-Hand Control

- [ ] Add action, workspace, window, and quick-launch search providers.
- [ ] Add quick-launch create, edit, delete, pin, unpin, and run UI.
- [ ] Add the validated platform launcher backend without shell command strings.
- [ ] Add and verify CreateProcess-compatible Windows argument quoting.
- [ ] Add provider enable settings.
- [ ] Add pinned results and clean stale pins after deletion.
- [ ] Add clock/date and current-workspace widgets.
- [ ] Run typed, validated result IDs only.
- [ ] Render the contextual one-hand keyboard.
- [ ] Generate its labels from active input mappings.
- [ ] Add clickable actions and pressed-key highlighting.
- [ ] Add approved action maps for each overview context.

Success criteria:

- Search can switch spaces, focus windows, run registered actions, and open
  saved launches.
- Quick-launch records survive restart and cannot execute unsaved WebView text.
- The one-hand overlay always matches the active keyboard bindings.

### Phase 9: Integration, Documentation, and Cleanup

- [ ] Finalize plugin descriptor settings and public action descriptions.
- [ ] Review and document the safe default bindings connected in Phase 5.
- [ ] Update the settings UI where global options belong.
- [ ] Update `README.md`.
- [ ] Update `ACTION_CATALOG.md`.
- [ ] Update `ROADMAP.md` current state only after the MVP works.
- [ ] Update every affected `AGENTS.md` and Child DOX Index.
- [ ] Remove only obsolete code made unnecessary by this implementation.
- [ ] Keep unrelated TODO and FIXME comments.
- [ ] Perform the final DOX pass.

Success criteria:

- Public actions, default bindings, descriptors, docs, and bridge names agree.
- No Windows-specific call exists in the portable workspace rules.
- The plan can be marked fully completed.

## Verification for Future Implementation

Do not run these checks while only editing this plan. Run them only when the
user asks to verify an implementation.

### Input Checks

- CapsLock tap runs its approved tap action.
- `CapsLock+W` switches North once.
- `CapsLock+W+D` and `CapsLock+D+W` switch North East once.
- Both W/D release orders produce one North East action.
- Releasing CapsLock before the direction keys commits once; remaining releases
  do not dispatch again.
- W pressed and released before D in one CapsLock hold is not merged into a
  diagonal and follows the invalid second-gesture rule.
- A direction held before CapsLock remains app input, is ignored by the session,
  and has a pass-through key-up.
- Every other cardinal and diagonal mapping reaches the correct slot.
- Opposite or extra direction keys consume the session, switch nothing, and do
  not run the CapsLock tap action.
- `CapsLock+W+Space` becomes invalid and does not toggle the overview.
- `CapsLock+Space` opens and closes the overview from every overview subcontext
  without sending a space.
- Keys still held from opening do not navigate the overview.
- `Alt` then CapsLock, CapsLock then `Alt`, `Ctrl` then CapsLock, and CapsLock
  then `Ctrl` follow the approved exact legacy rules.
- Alt and Ctrl both held before CapsLock run no legacy or tap action, and their
  key-up events pass through.
- WASD reaches normal apps when no owning context is active.
- Closing overview always releases its keys.
- A missed key-up repair clears stale state.
- Pre-held Shift still lets the WinDrag start handler run and enables quick
  position immediately.
- The configured quick modifier's down/up events pass through during WinDrag.
- Rejected wildcard combinations and blocklisted targets preserve normal mouse
  input without replay.

### Workspace Checks

- Each direct key selects the workspace currently mapped to that slot.
- Swapping two slots keeps their full workspace records unchanged.
- A new normal window joins the active workspace.
- An owned dialog follows its root owner through assignment and z-order changes.
- Switching refreshes, then saves old geometry and restores destination geometry.
- Templates and stable order apply separately on each monitor.
- A session-only window can be last-active and keep a runtime template position
  without saving an HWND or runtime ID.
- Last-active focus restores when valid.
- Missing last-active focus falls back safely.
- Inactive activation follows the approved policy.
- A failed switch keeps the previous committed active workspace.
- An unexpected create, destroy, geometry, stack, or focus event during apply
  causes a bounded refresh and replan or the safe rollback path.
- Normal z-order remains inactive owner groups, covers, active owner groups, and
  Haribol! shell UI.
- Suspend, reload, and exit remove every cover and temporary topmost change.
- Emergency tray restore works even while normal hotkeys are suspended and
  makes every manageable window reachable.

### Persistence and Identity Checks

- The generated default contains exactly eight valid mapped workspaces.
- Workspace names, colors, layouts, assignments, and slot swaps survive restart.
- HWND and PID never appear as persistent identity.
- Two different VS Code projects can use different explicit profiles.
- One window matching tied top profiles becomes ambiguous instead of using file
  order. One profile matching several windows also becomes ambiguous.
- Tied top app visual rules report a conflict and use the built-in default.
- A fragile current-title draft is not saved automatically as stable identity.
- Broad app visual rules never receive workspace placement or focus history.
- Every persisted `profileOrder` and focus reference belongs to its workspace,
  and no second template index can disagree with it.
- A missing monitor uses the documented fallback without deleting its saved
  placement, and reconnecting restores the original layout.
- Quick-launch create, edit, delete, typed pin lookup, and stale-pin cleanup
  survive restart.
- Windows launch arguments round-trip spaces, empty values, embedded quotes,
  and trailing backslashes correctly.
- A failed save leaves the previous JSON file valid.
- Invalid JSON leaves the previous in-memory model active.

### Overview Checks

- The grid always has nine equal cells.
- Direction badges and untouched defaults follow slots after swaps.
- Custom names and colors move with workspace identities after swaps.
- Active and last-active markers are visually different.
- Keyboard and pointer selection produce the same result.
- Opening and closing without a choice restores the prior valid foreground.
- Window drag previews match committed host geometry.
- Stale model revisions are ignored, and host rejection rolls back only its
  matching request.
- Search and quick launch execute only validated saved result IDs.
- One-hand labels match the active router context.
- Color and focus state remain understandable without relying on color alone.

### Static Checks

- Descriptor action names match public plugin methods.
- All bridge method names match between AHK and JavaScript.
- Every installed event callback, timer, hotkey, hook, GUI, and context has a
  cleanup path.
- All WebView assets are present in compiled resources.
- Backend capability failures are handled explicitly.
- The portable state store has no direct filesystem replacement calls.
- No portable model code calls Windows or AHK input APIs directly.

## Safety Boundaries

- Synthetic workspaces do not replace, rename, or move native virtual desktops.
- Protected, elevated, or fullscreen game windows may remain unsupported under
  the approved safe policy.
- The Control Center is not a complete desktop-shell replacement in this MVP.
- Display-title customization never mutates the real application window title.
- Recovery must prefer reachable windows over preserving the synthetic stack.

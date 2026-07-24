# Synthetic Workspaces MVP Implementation Plan

## Status

- Planning document for the first Windows and AutoHotkey implementation.
- No implementation phase in this document is complete yet.
- This plan turns the direction in `ROADMAP.md` and the `one-left` note in
  `TODO.txt` into an implementable MVP.
- Review the open decisions before implementation.
- When a phase is implemented, mark its completed tasks with `✅`.
- When the whole plan is complete, rename the main header to
  `# ✅ COMPLETED: Synthetic Workspaces MVP Implementation Plan`.

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
- **Window identity rule**: saved matching data used to find the same logical
  window after restart.
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

## Main Assumptions for the MVP

These are recommended limits, not long-term limits:

- There are exactly eight workspace slots.
- One workspace is active globally across all monitors.
- A normal managed window belongs to one workspace.
- The stored format may use a `workspaceIds` array, but MVP validation allows
  one workspace ID only.
- A directional chord targets a slot. It does not target a fixed workspace ID.
- Swapping spaces exchanges their slot positions. Each workspace keeps its
  windows, custom name, color, layout, and rules.
- The overview opens on the monitor containing the mouse pointer.
- Other monitors keep showing the active workspace and may receive a simple
  dim layer while the overview is open.
- The first overview uses colored rectangles, not live window thumbnails.
- Normal `[HOTKEYS]` bindings continue to use the current `Hotkey()` path.
- The new input router owns only multi-key chords and modal input contexts.

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
- Order-independent held-key state for supported chords.
- Contexts for global input, workspace selection, overview, window drag, and
  hotkey recording.
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
- Settings are attached to a stable identity rule when possible, not an HWND.

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
  and take priority over the workspace layer.
- [ ] Choose direction commit timing. Recommended MVP: commit once when the
  direction keys or `CapsLock` are released. This prevents North from firing
  before North East is complete.
- [ ] Confirm that opposite direction pairs do nothing and show short visual
  feedback.
- [ ] Confirm that `W`, `A`, `S`, `D`, and `Space` are blocked from the active
  app while the CapsLock workspace layer owns them.
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
- Keep a fast held-key bitmask.
- Repair state from physical key state after focus changes or missed key-up
  events.
- Keep an ordered context stack.
- Match required keys without depending on press order.
- Prefer the most specific matching chord.
- Handle a short pending or release-based commit for overlapping chords.
- Run one action on the inactive-to-active chord transition.
- Ignore normal keyboard auto-repeat unless a binding enables repeat.
- Record which key-down events were consumed and also consume their key-up
  events.
- Support pass-through bindings.
- Reset safely on app suspend, reload, lock, hook restart, and context close.
- Dispatch actions through the existing central action dispatcher.
- Give the overview the same active context and mapping data used for actual
  input.

### Required Contexts

| Context | Purpose |
|---|---|
| `global` | Existing normal app hotkeys |
| `workspace-layer` | CapsLock pseudo-modifier and direct workspace selection |
| `workspace-overview` | Navigation and commands while the overview is open |
| `workspace-window-drag` | Moving a preview rectangle or real window |
| `window-drag` | WinDrag start state and live modifier changes |
| `hotkey-recording` | Prevent workspace commands while recording another hotkey |

The highest active context owns a managed key. Closing a mode must remove its
context even after an error.

### Proposed Binding Shape

```json
{
  "id": "switch-workspace-ne",
  "context": "workspace-layer",
  "requiredKeys": ["CapsLock", "W", "D"],
  "trigger": "release",
  "allowExtraKeys": false,
  "consume": true,
  "repeat": false,
  "action": "SwitchSyntheticWorkspace(ne)"
}
```

The final stored form may use key IDs or masks internally. User-facing data
should keep readable names.

### CapsLock Session

Recommended behavior:

1. `CapsLock` down starts a workspace-layer session.
2. Direction keys update the current direction mask in any order.
3. `Space` opens the overview and marks the session consumed.
4. A valid direction commits one workspace switch.
5. An invalid opposite pair commits nothing and gives short feedback.
6. Releasing `CapsLock` after a consumed chord does not run the CapsLock tap
   action.
7. Releasing `CapsLock` without a consumed chord runs the configured tap action.
8. The overview remains open after `CapsLock` is released.

### WinDrag Integration

- Route Win plus mouse start through the input router, or register a wildcard
  start binding that sends a normalized input snapshot to WinDrag.
- Read all relevant modifiers at drag start.
- If the quick-position modifier is already down, quick positioning starts
  immediately.
- Continue updating the mode when the modifier changes during the drag.
- Remove the current rule that requires the modifier to be released once before
  it can activate.
- Do not use the same key as both the required drag prefix and the optional
  quick-position modifier.
- Keep blocklisted-window mouse pass-through behavior.
- Stop making feature code depend on `A_ThisHotkey` when the router can provide
  the trigger button directly.

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

- Loads, validates, upgrades, and saves the JSON data.
- Resolves its file beside the active configuration.
- Debounces frequent UI changes.
- Uses a temporary file and atomic replacement.
- Keeps the previous valid state when parsing or saving fails.

### `WindowIdentityMatcher`

- Builds runtime identity candidates.
- Applies user rules in priority order.
- Returns match reason and confidence for diagnostics.
- Does not silently choose between equally strong matches.

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
- Moves, resizes, stacks, activates, and validates windows.
- Reads monitor identities and work areas.
- Subscribes to native window events.
- Creates desktop cover windows.
- Extracts and caches app icons.
- Reports unsupported operations instead of pretending they succeeded.

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

## Stable Window Identity

### Matching Order

1. Exact user rule with the highest priority.
2. Executable path, class, and stable title rule.
3. AppUserModelID plus title rule when available.
4. Executable path and class when only one candidate exists.
5. Keep the window session-only and mark it ambiguous.

Do not use launch order as a permanent identity. It can be used only as a
temporary session label such as `2 of 3`.

### Rule Fields

Advanced identity rules may support:

- Executable path exact match.
- Executable name exact match.
- Window class exact match.
- AppUserModelID exact match.
- Title exact, contains, wildcard, or regular-expression match.
- Command line contains or regular-expression match.
- Root-owner rule.
- Rule priority.
- Stable user identity key.
- Workspace assignment.
- Layout slot or normalized freeform geometry.
- Custom display title and title format.
- Custom icon.
- Base color and instance color preset.

Command-line inspection can fail for elevated apps and can expose private local
paths. It must be optional and local-only.

### Ambiguous Windows

When several windows have the same weak identity:

- Give them visible session labels such as `1 of 3`.
- Do not silently restore one project's geometry onto another project.
- Show a `Needs identity rule` marker in overview settings.
- Let the user create a rule from current executable, class, and title data.
- Show a plain preview of which current windows the rule matches before save.

VS Code projects are a main example. A user rule can match a stable project or
folder part of the title instead of only matching `Code.exe`.

## Persistence Contract

Store data in `synthetic-workspaces.json` beside the active config file.

Recommended first schema:

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
      "name": "North",
      "shortName": "N",
      "color": "#2E7D32",
      "layout": {
        "templateId": "freeform",
        "gap": 8
      },
      "lastActiveIdentityId": ""
    }
  ],
  "windowRules": [
    {
      "id": "vscode-atsuikagi",
      "priority": 100,
      "identityKey": "vscode:atsuikagi",
      "match": {
        "processName": "Code.exe",
        "class": "Chrome_WidgetWin_1",
        "titleContains": "AtsuiKagi"
      },
      "workspaceIds": ["ws-02"],
      "layout": {
        "monitorKey": "display-primary",
        "normalizedRect": {
          "x": 0.0,
          "y": 0.0,
          "w": 0.5,
          "h": 1.0
        }
      },
      "visual": {
        "customTitle": "AtsuiKagi",
        "titleFormat": "{customTitle} - {instance}/{count}",
        "icon": "",
        "color": "#4F8DF7",
        "colorPreset": "lightness"
      }
    }
  ],
  "controlCenter": {
    "enabledProviders": ["actions", "workspaces", "windows", "quickLaunch"],
    "pinnedIds": []
  }
}
```

The example does not need to list all eight workspace objects, but validation
must require all IDs referenced by `slotMap`.

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
  available.
- Fall back to device name and geometry signature.
- If a saved monitor is missing, place the window on the pointer or primary
  monitor and clamp it to the work area.
- Template layouts recalculate real pixels from current work-area size.

## Workspace Switching Transaction

A switch must run as one guarded transaction:

1. Validate the destination slot and resolve its workspace ID.
2. Save geometry and last active window for the current workspace.
3. Refresh the window cache.
4. Resolve owned dialogs and unsupported windows.
5. Calculate all desired geometry, z-order, topmost, and focus changes.
6. Mark those expected changes as pending.
7. Put inactive managed windows below the desktop cover.
8. Put destination workspace windows above the cover.
9. Restore saved freeform geometry or apply the selected layout template.
10. Restore temporary topmost state allowed by policy.
11. Focus the destination workspace's valid last-active window.
12. If it no longer exists, focus the next window from focus history.
13. Read the result once and repair missed changes.
14. Clear the transaction guard.
15. Save active workspace and changed state.
16. Push one updated model to the overview if it is open.

Native events caused by the transaction update observed state but must not start
another switch transaction.

### Desktop Cover

- Use one non-activating cover window per monitor.
- Covers belong to Haribol! and are excluded from workspace enumeration.
- Covers stay above inactive normal windows and below active workspace windows.
- Overview and other Haribol! shell UI stay above the active application layer.
- Destroying the app must also destroy the covers.
- If the app crashes, owned cover windows disappear with the process, so normal
  windows are not permanently hidden.

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
- Keep a stable window-to-layout-slot order using persistent identity IDs.
- Extra windows stack in the last slot or remain freeform according to one
  explicit template policy.
- Missing windows do not destroy their saved slot assignment.
- Dragging inside an overview cell shows candidate snap zones before drop.
- Dropping into a template slot updates the stable layout order.
- Dropping in `freeform` stores a normalized rectangle.

Do not call private WinDrag or WindowStash helpers. Move only the required
rectangle and monitor ideas into the shared layout or backend boundary.

## Workspace Overview

### Window and Grid

- Use a separate borderless `WebViewGui`, not the settings WebView.
- Open at the pointer monitor's work-area bounds.
- Use CSS Grid with three equal columns and three equal rows.
- Give every workspace cell a stable `data-slot` and `data-workspace-id`.
- Keep the center cell reserved for the Control Center.
- Support mouse, touch, and keyboard focus.
- Add all frontend assets to compiled-build resources.

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

Suggested overview contexts:

- Space selection.
- Window selection.
- Window move.
- Workspace settings.
- Window settings.
- Control Center search.

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
- `UpdateWindowVisualRule`
- `SaveWindowIdentityRule`
- `SearchControlCenter`
- `RunControlCenterResult`
- `CloseWorkspaceOverview`

Final names should match existing bridge style.

Bridge rules:

- Pass JSON for structured input and output.
- Validate slot IDs, workspace IDs, window record IDs, and rule IDs in AHK.
- Never trust an HWND received from JavaScript without resolving it against the
  current cached record.
- Return structured success or error results.
- Roll back optimistic UI state when the host rejects a command.
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
| App icons | Windows executable or window icon extraction with cache |
| Monitor identity | Display device identity with documented fallback |
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
- [ ] Define the complete default direction names and colors.
- [ ] Confirm first layouts, color preset, Control Center providers, and widgets.
- [ ] Confirm safe unsupported-window behavior.
- [ ] Finalize runtime records, persisted schema, and bridge payloads.
- [ ] Define input, window, overlay, and persistence backend capabilities.

Success criteria:

- The document has no unresolved decision that changes the core data model or
  input semantics.
- Example JSON passes the planned validator.

### Phase 2: Shared Input Router

- [ ] Add normalized key and mouse IDs.
- [ ] Add held-key bitmask and physical-state repair.
- [ ] Add context stack and ownership rules.
- [ ] Add chord matching, specificity, commit, repeat, and consumption.
- [ ] Add CapsLock tap-versus-chord session behavior.
- [ ] Add workspace cardinal, diagonal, and overview bindings.
- [ ] Add suspend, reload, recorder, and missed-key-up cleanup.
- [ ] Route actions through the central dispatcher.
- [ ] Make WinDrag accept a held modifier at drag start.
- [ ] Keep live modifier changes during dragging.

Success criteria:

- CapsLock tap and every approved CapsLock chord fire exactly once.
- `CapsLock+W+D` and `CapsLock+D+W` resolve to the same slot.
- Overview input owns WASD only while its context is active.
- Pre-held WinDrag modifiers behave the same as modifiers pressed during drag.

### Phase 3: Workspace Model, Layout, and Persistence

- [ ] Create eight stable workspace records and slot map.
- [ ] Add active workspace and focus history.
- [ ] Add runtime observed, desired, and pending window records.
- [ ] Add normalized freeform geometry.
- [ ] Add first tiling templates and stable layout order.
- [ ] Add JSON validation and useful error messages.
- [ ] Add atomic load and save.
- [ ] Add save debounce.
- [ ] Add monitor key and missing-monitor fallback.
- [ ] Add window identity rules and ambiguity reporting.

Success criteria:

- A pure in-memory model can swap slots without changing workspace identity.
- Valid workspace, layout, and identity data survives restart.
- Invalid data leaves the previous valid state untouched.

### Phase 4: Windows Window Backend and Cache

- [ ] Add manageable-window enumeration and classification.
- [ ] Read complete snapshots including owner and root owner.
- [ ] Add stable monitor and work-area discovery.
- [ ] Add create, destroy, activate, title, state, and geometry event handling.
- [ ] Add listener cleanup.
- [ ] Add low-rate reconciliation.
- [ ] Add icon extraction and cache.
- [ ] Exclude Haribol! covers and shell UI.
- [ ] Apply blocklist and unsupported-window policy.

Success criteria:

- The cache follows normal window creation, destruction, focus, title, and
  geometry changes.
- Dialogs are linked to their root owners.
- Unsupported windows have a visible reason.

### Phase 5: Cover and Workspace Transactions

- [ ] Create one non-activating cover per monitor.
- [ ] Add guarded switch transaction planning.
- [ ] Add batched geometry and z-order application.
- [ ] Add saved geometry or template restore.
- [ ] Add last-active focus restore and fallback.
- [ ] Add inactive-window activation policy.
- [ ] Add temporary topmost-state handling.
- [ ] Verify and reconcile each transaction.
- [ ] Add disable, reload, exit, and emergency restore cleanup.

Success criteria:

- Direct switching shows only the active managed workspace above the cover.
- Switching restores valid geometry and focus.
- Failed stacking removes the cover instead of trapping windows.
- Emergency restore makes every manageable window reachable.

### Phase 6: Overview WebView

- [ ] Add the separate overview WebView host and bridge.
- [ ] Add compiled-build resources.
- [ ] Render the equal 3 by 3 grid.
- [ ] Render all workspace metadata and window rectangles.
- [ ] Add active, last-active, ambiguous, urgent, and unsupported visual states.
- [ ] Add keyboard cell and window navigation.
- [ ] Add workspace and window quick settings.
- [ ] Add color picker and large blurred preview.
- [ ] Add structured host error handling and UI rollback.
- [ ] Add throttled live model updates.

Success criteria:

- The overview opens and closes without changing the active app unexpectedly.
- Eight slots and the center Control Center always occupy the correct cells.
- The visible model matches the host's cached state.

### Phase 7: Drag, Snap, and Configuration

- [ ] Add handle-only workspace slot swapping.
- [ ] Add window movement between workspaces.
- [ ] Add freeform rectangle movement and resize inside a cell.
- [ ] Add template slot snapping and preview.
- [ ] Apply valid drops as one host transaction.
- [ ] Add workspace name, color, and layout reset.
- [ ] Add custom display title and format.
- [ ] Add custom icon selection and fallback.
- [ ] Add base window color and same-app gradation.
- [ ] Add advanced identity-rule editor and match preview.

Success criteria:

- Slot swaps keep the full workspace identity together.
- Window drops survive restart when a stable identity rule exists.
- Rejected drops and settings changes restore the previous UI state.

### Phase 8: Control Center and One-Hand Control

- [ ] Add action, workspace, window, and quick-launch search providers.
- [ ] Add provider enable settings.
- [ ] Add pinned results.
- [ ] Add clock/date and current-workspace widgets.
- [ ] Run typed, validated result IDs only.
- [ ] Render the contextual one-hand keyboard.
- [ ] Generate its labels from active input mappings.
- [ ] Add clickable actions and pressed-key highlighting.
- [ ] Add approved action maps for each overview context.

Success criteria:

- Search can switch spaces, focus windows, run registered actions, and open
  saved launches.
- The one-hand overlay always matches the active keyboard bindings.

### Phase 9: Integration, Documentation, and Cleanup

- [ ] Add plugin descriptor settings and public action definitions.
- [ ] Add safe default bindings.
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
- Every other cardinal and diagonal mapping reaches the correct slot.
- Opposite pairs follow the approved invalid-input behavior.
- `CapsLock+Space` opens overview without sending a space.
- Existing approved `Alt+CapsLock` and `Ctrl+CapsLock` actions still work.
- WASD reaches normal apps when no owning context is active.
- Closing overview always releases its keys.
- A missed key-up repair clears stale state.
- A pre-held WinDrag quick-position modifier is active immediately.
- Blocklisted WinDrag targets still receive normal mouse input.

### Workspace Checks

- Each direct key selects the workspace currently mapped to that slot.
- Swapping two slots keeps their full workspace records unchanged.
- A new normal window joins the active workspace.
- An owned dialog follows its main window.
- Switching saves old geometry and restores destination geometry.
- Last-active focus restores when valid.
- Missing last-active focus falls back safely.
- Inactive activation follows the approved policy.
- Reload and exit remove every cover and temporary topmost change.
- Emergency restore makes all manageable windows reachable.

### Persistence and Identity Checks

- Workspace names, colors, layouts, assignments, and slot swaps survive restart.
- HWND and PID never appear as persistent identity.
- Two different VS Code projects can use different explicit rules.
- Equal-strength ambiguous matches do not receive guessed geometry.
- A missing monitor uses the documented fallback and clamps the window.
- A failed save leaves the previous JSON file valid.
- Invalid JSON leaves the previous in-memory model active.

### Overview Checks

- The grid always has nine equal cells.
- Direction badges stay correct after slot swaps and custom names.
- Active and last-active markers are visually different.
- Keyboard and pointer selection produce the same result.
- Window drag previews match committed host geometry.
- Host rejection rolls back optimistic UI state.
- Search executes only validated result IDs.
- One-hand labels match the active router context.
- Color and focus state remain understandable without relying on color alone.

### Static Checks

- Descriptor action names match public plugin methods.
- All bridge method names match between AHK and JavaScript.
- Every installed event callback, timer, hotkey, hook, GUI, and context has a
  cleanup path.
- All WebView assets are present in compiled resources.
- Backend capability failures are handled explicitly.
- No portable model code calls Windows or AHK input APIs directly.

## Out of Scope Notes

- This plan does not replace `VirtualDesktopManager`.
- This plan does not promise that protected, elevated, or fullscreen game
  windows can be stacked like normal windows.
- This plan does not make process suspension part of workspace switching.
- This plan does not make the Control Center a full desktop-shell replacement.
- This plan does not require live thumbnails.
- This plan does not mutate real application window titles for display
  customization.

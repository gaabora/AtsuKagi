# Synthetic Workspaces Overview Specification

<a id="overview-1"></a>
## OVERVIEW-1: Ownership

This document is the only source of truth for:

- The 3 by 3 overview WebView.
- Workspace and window presentation.
- Overview navigation and pointer interaction.
- Workspace and window settings.
- Control Center, quick launch, widgets, and search.
- One-Hand Control.
- The overview WebView bridge and revision rules.

Input ownership and context timing are defined in [`SYNTHETIC_WORKSPACES_INPUT.md`](SYNTHETIC_WORKSPACES_INPUT.md). Workspace state and persistence are defined in [`SYNTHETIC_WORKSPACES_STATE.md`](SYNTHETIC_WORKSPACES_STATE.md).

<a id="overview-2"></a>
## OVERVIEW-2: Overview decisions

This table is the only place that tracks overview decision status.

| ID | Status | MVP blocker | Decision or recommended result |
|---|---|---|---|
| `UI-D01` | Chosen | Yes | Open the overview on the monitor containing the pointer instead of spanning the virtual screen. |
| `UI-D02` | Chosen | No | Use the [other-monitor display rule](#overview-2-other-monitors). |
| `UI-D03` | Chosen | Yes | Use colored window rectangles for the first overview, not live thumbnails. |
| `UI-D04` | Chosen | Yes | Use the fixed [slot-to-arrow mapping](#overview-2-direction). Each arrow is both the slot badge and its default name. |
| `UI-D05` | Chosen | Yes | Use the initial colors from the same [slot mapping](#overview-2-direction). |
| `UI-D06` | Chosen | No | Ship `none` and one predictable lightness-step same-app color preset. |
| `UI-D07` | Chosen | No | Custom icons accept `.ico`, `.png`, or an icon extracted from a selected executable. |
| `UI-D08` | Open | No | Confirm the first Control Center providers and the clock/date plus current-workspace widgets. |
| `UI-D09` | Chosen | No | `One-Hand Control` is the user name and internal name. |
| `UI-D10` | Open | No | Approve one key-to-action map for each One-Hand router context in [`OVERVIEW-8`](#overview-8). Safe means that one key cannot run two actions in the same context and destructive actions use confirmation. |

<a id="overview-2-other-monitors"></a>
### Other monitors

While the overview is open, all other monitors keep showing the active workspace. The `dimOtherMonitorsInOverview` setting controls whether they receive a simple dim layer. The setting is enabled by default.

<a id="overview-2-direction"></a>
### Direction badges, default names, and colors

This table is the only slot-to-arrow and default-color mapping:

| Slot | Arrow | Direction label | Initial color |
|---|---|---|---|
| `n` | ⬆️ | Top | `#49A84A` |
| `ne` | ↗️ | Top Right | `#8DA63E` |
| `e` | ➡️ | Right | `#D48A33` |
| `se` | ↘️ | Bottom Right | `#D25B42` |
| `s` | ⬇️ | Bottom | `#C84C61` |
| `sw` | ↙️ | Bottom Left | `#8556B4` |
| `w` | ⬅️ | Left | `#3D70C4` |
| `nw` | ↖️ | Top Left | `#3F97A2` |

Display rules:

- Without a custom name, show the arrow once. It acts as both the default name and the direction badge.
- With a custom name, show the custom name together with the fixed arrow badge.
- Use the direction label for the tooltip and accessible label.
- The colors may be tuned later without changing the slot-to-arrow mapping.

<a id="overview-3"></a>
## OVERVIEW-3: Host, grid, and focus lifecycle

### Host and grid

- Use a separate borderless `WebViewGui`, not the settings WebView.
- Open at the selected monitor's work-area bounds according to `UI-D01`.
- Use CSS Grid with three equal columns and three equal rows.
- Reserve the middle cell for the Control Center.
- Give each workspace cell stable `data-slot` and `data-workspace-id` values.
- Scale all current monitor work areas into each workspace preview and show clear monitor boundaries.
- Use Pointer Events for mouse and touch interaction and support keyboard focus.
- Add every frontend asset to compiled-build resources.

### Focus lifecycle

- Capture the current foreground managed window before activating the overview.
- Exclude overview, cover, and other Haribol! shell windows from workspace focus history and inactive-window activation policy.
- Opening the overview does not change `activeWorkspaceId`.
- Choosing a window closes the overview and makes workspace switch plus focus one state transaction.
- Closing without a choice restores the captured window when it is still valid in the active workspace.
- If the captured window is not valid, use the normal safe focus fallback from [`STATE-6`](SYNTHETIC_WORKSPACES_STATE.md#state-6).
- Remove every overview input context even when close or focus restore fails.
- Opening keys cannot navigate the overview until the transition guard in [`INPUT-5`](SYNTHETIC_WORKSPACES_INPUT.md#input-5) clears.

<a id="overview-4"></a>
## OVERVIEW-4: Workspace and window display

### Workspace cell

Each workspace cell shows:

- Resolved workspace label and fixed badge from the [slot mapping](#overview-2-direction).
- Resolved workspace color.
- Selected layout name or icon.
- Window count.
- Active-workspace state.
- Urgent or unsupported-window marker when needed.
- A miniature surface with monitor bounds and window rectangles.

The active workspace uses a strong non-color-only outer marker.

### Window rectangle

Each rectangle shows as space allows:

- Solid resolved base color.
- App icon.
- Display title.
- App name or short extra line.
- Same-app instance marker such as `2/3`.
- Ambiguous or unsupported marker.

Visual states:

- The real active window uses a thick white rounded border and shadow.
- The last-active window in each inactive workspace uses a different, thinner marker.
- Other windows may be dimmed but stay readable.
- Color is never the only active, warning, or error signal.

<a id="overview-5"></a>
## OVERVIEW-5: MVP interaction

### Workspace and window selection

- Overview focus starts on the active workspace.
- `W`, `A`, `S`, and `D` move between the 3 by 3 cells.
- `Enter` on a workspace switches to it or enters its window-selection level.
- Inside a workspace, direction keys choose the nearest window in that direction by rectangle-center geometry.
- `Enter` on a window switches to its workspace and focuses it.
- `Escape` goes back one level and then closes the overview.
- Pointer and keyboard selection produce the same host command.
- Search and configuration keys are not active in the MVP.

### Basic window movement

- A window rectangle may be dragged to a different workspace cell.
- The UI keeps drag state local until a valid drop.
- A valid drop sends one host command that changes the workspace assignment.
- The host persists the move only under the identity rules in [`STATE-9`](SYNTHETIC_WORKSPACES_STATE.md#state-9).
- An ambiguous or session-only window may move for the current session without guessed persistent identity.
- A rejected drop restores the prior UI state and shows the returned reason.
- Moving or resizing inside one workspace preview is outside the MVP and belongs to [`OVERVIEW-6`](#overview-6).

<a id="overview-6"></a>
## OVERVIEW-6: Later drag, snap, and settings

This section is outside the current MVP.

### Workspace settings

Later keyboard commands must:

- Use one approved key to open settings for the selected workspace or window.
- Use one approved key to enter window move mode.
- Avoid navigation and command conflicts inside one router context.

Each workspace cell receives a toolbar on hover or keyboard focus:

- Dedicated drag handle for slot swapping.
- Edit custom name and color.
- Choose a layout.
- Reset name, color, and layout to current slot defaults.

Dragging a workspace starts only from its handle. A valid slot drop swaps the complete workspace identity according to decision `ST-D03` in [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2).

### Window movement and snap

- Dragging inside one workspace cell moves or resizes a freeform rectangle or chooses a template slot.
- Show candidate snap zones before drop.
- Apply one valid drop as one host transaction.
- A profiled window persists through its unique profile.
- Create an automatic profile only for a unique stable candidate.
- Show a session-only warning instead of saving a guessed assignment.

### Window settings

Window quick settings include:

- Display-only custom title that never changes the real application title.
- Display-title format using safe known fields.
- Custom icon with app-icon fallback.
- Solid base color.
- Same-app color preset.
- Advanced identity rule.
- Reset visual overrides.

### Color picker

- Reuse existing local color-picker behavior when useful.
- Show the selected color as a large blurred preview.
- Keep the exact hex value visible and editable.
- Keep text readable over light and dark colors.
- Save only a valid selected color.

<a id="overview-7"></a>
## OVERVIEW-7: Control Center

### MVP placeholder

For the MVP, the middle cell is present, focusable, and clearly named Control Center. It does not need search, launch, pin, or widget behavior.

### Later full Control Center

The collapsed middle cell may show:

- Search field.
- Current time and date.
- Active workspace name.
- Small list of pinned actions or launches.

Selecting it may expand the Control Center over the overview while keeping a clear Back action.

First planned search providers:

- Registered Haribol! actions.
- Workspace names and direction badges.
- Open managed windows.
- Manually saved quick-launch entries.

Users can enable or disable each provider.

Search results carry typed IDs. JavaScript never sends an arbitrary action or shell command string for execution.

### Quick-launch entries

A saved entry contains:

- Stable ID.
- Display name.
- Executable path.
- Separate argument array.
- Optional working directory.
- Optional icon.

The UI supports create, edit, delete, pin, unpin, and run. A host-side validator checks a record before save and again before launch. Deleting an entry removes stale pins.

The platform launcher accepts only a validated saved record, passes the executable separately where possible, and does not use a command shell. The Windows backend serializes the argument array with CreateProcess-compatible rules for spaces, empty values, embedded quotes, and trailing backslashes. Launch paths and arguments stay local and are absent from normal diagnostics.

Built-in widgets are clock/date and current-workspace status. Do not design a public widget API before a real third widget needs it.

<a id="overview-8"></a>
## OVERVIEW-8: One-Hand Control

This section is outside the current MVP.

The source keyboard shape is:

```text
Q W E R T
A S D F G
Z X C V B
```

The old notes suggest actions such as Quit, Window, Run, Top or Tile, App, Space, Drag, Find, Grid, Overlap, and Color. These labels are ideas, not an approved safe binding map.

Required behavior:

- Render a small keyboard overlay inside the overview.
- Show only actions valid for the current focus level.
- Make each shown key clickable.
- Highlight held physical keys.
- Read labels and actions from the active input-router mappings.
- Hide or dim actions that cannot run for the selected item.
- Show a short description on hover or focus.
- Keep destructive actions clearly separate and use existing confirmation rules.

The overlay follows real router contexts: `overview-space`, `overview-window`, `overview-move`, `overview-settings`, and `overview-search`. It must not keep a second action map.

<a id="overview-9"></a>
## OVERVIEW-9: WebView bridge

### MVP commands

- `GetWorkspaceOverviewState`
- `SwitchWorkspace`
- `FocusWorkspaceWindow`
- `MoveWorkspaceWindow`
- `CloseWorkspaceOverview`

### Later commands

- `SwapWorkspaceSlots`
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

Final names follow existing bridge style.

Bridge rules:

- Use JSON for structured input and output.
- Include a monotonic `modelRevision` in every full state and pushed update.
- Give each mutation a unique `requestId` and `basedOnRevision`.
- Return the same request ID and the resulting revision in success or error.
- Reject a stale mutation when it could overwrite newer host state.
- JavaScript ignores older revisions and rolls back only the optimistic change linked to a rejected request ID.
- Validate every slot ID, workspace ID, runtime record ID, profile ID, app-rule ID, quick-launch ID, and typed search result ID on the host.
- Never trust an HWND from JavaScript. Resolve a runtime record against the current cache.
- Return structured success or error data.
- Throttle event pushes and combine repeated geometry updates.
- Do not expose raw file execution or arbitrary action strings to WebView messages.

<a id="overview-10"></a>
## OVERVIEW-10: UI state and failure rules

- The host is the source of truth after every accepted or rejected mutation.
- UI drag and settings state stays local until a command is accepted.
- A failed command restores only the visual change linked to its `requestId`.
- A stale reply cannot undo a newer accepted change.
- A failed WebView command does not change persisted state.
- Opening or closing the overview cannot change the active application unexpectedly.
- Overview close always removes its router contexts.

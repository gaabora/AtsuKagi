# Synthetic Workspaces Input Specification

<a id="input-1"></a>
## INPUT-1: Ownership

This document is the only source of truth for synthetic workspace input behavior. It owns:

- Direction chords and their timing.
- CapsLock tap and legacy modifier arbitration.
- Input router contexts, priority, consumption, and pass-through.
- Physical held-key state and missed key-up repair.
- The later WinDrag router integration.

Workspace meaning is defined in [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2). Overview behavior is defined in [`OVERVIEW-3`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-3) through [`OVERVIEW-5`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-5).

<a id="input-2"></a>
## INPUT-2: Direction model

`CapsLock` is the workspace pseudo-modifier. The current slot bindings are:

| Slot | Default label | Direction suffix |
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

The router may store direction state as a four-bit mask:

| Direction | Bit |
|---|---|
| North | `1` |
| East | `2` |
| South | `4` |
| West | `8` |

Valid diagonal values are North East `3`, South East `6`, South West `12`, and North West `9`. North plus South and East plus West are invalid. A third direction is also invalid.

CapsLock must start the workspace session before an eligible suffix. Direction suffixes pressed after CapsLock may arrive in either order. A direction already held before CapsLock remains normal application input and is ignored by that session.

<a id="input-3"></a>
## INPUT-3: Input decisions

This table is the only place that tracks input decision status.

| ID | Status | MVP blocker | Decision or recommended result |
|---|---|---|---|
| `IN-D01` | Chosen | Yes | Use `CapsLock+W/A/S/D` for cardinal slots and two direction suffixes for diagonal slots. |
| `IN-D02` | Chosen | Yes | Use `CapsLock+Space` to toggle the overview. |
| `IN-D03` | Chosen | Yes | Use one app-owned router with a small Windows/AHK backend for managed keys and mouse triggers. |
| `IN-D04` | Chosen | Yes | A CapsLock press with no owned suffix should run the configured `SwitchKeyboardLayout()` action on release. |
| `IN-D05` | Chosen | Yes | Exact `Alt+CapsLock` and `Ctrl+CapsLock` chords should keep their current actions and follow the rules in [`INPUT-6`](#input-6). |
| `IN-D06` | Chosen | Yes | Expose `while-held` and `on-release` workspace switch modes in settings. `while-held` is the default and allows several direction gestures during one CapsLock hold. |
| `IN-D07` | Chosen | Yes | In `while-held` mode, a valid chord must stay unchanged for 100 ms before one switch. An invalid mask cancels only its pending timer. |
| `IN-D08` | Chosen | Yes | CapsLock starts the mode and must be pressed before a workspace suffix. Direction suffix order after CapsLock is independent. |
| `IN-D09` | Chosen | Yes | Consume CapsLock and both down/up events of a suffix that matches a Caps-mode action. An unbound non-modifier key passes through and cancels the CapsLock tap action. |
| `IN-D10` | Chosen | No | Shift is the default configurable WinDrag quick-position modifier. |

Implementation must not start beyond a safe prototype until every decision marked as an MVP blocker is chosen.

<a id="input-4"></a>
## INPUT-4: Router contract

### Current limit

The current app maps one AHK hotkey expression to one action. It supports normal modifiers and a native custom combination such as `CapsLock & W`, but it cannot represent `CapsLock+W+D` as one order-independent chord.

Normal `[HOTKEYS]` bindings keep the current binder except for input owned by the router while synthetic workspace input is enabled:

- Plain CapsLock and managed Alt or Ctrl CapsLock variants.
- CapsLock workspace suffixes.
- Router-managed Win plus mouse drag triggers after [`INPUT-8`](#input-8) is implemented.

The router reads the configured action for an owned binding and dispatches it through `App.RunAction()`. The normal binder skips that binding so an action cannot fire early or twice.

### Responsibilities

The router must:

- Normalize keyboard and mouse IDs.
- Track managed keys as physically down or up.
- Keep a fast held-key mask and separate masks for each active binding session.
- Repair state from physical key state after focus changes or missed key-up events.
- Keep an ordered context stack.
- Apply prefix and suffix ordering per binding.
- Prefer the most specific matching chord.
- Support prefix-release commits and stable-chord timer commits.
- Keep per-action and per-gesture guards so held input cannot repeat unintentionally.
- Ignore keyboard auto-repeat unless a binding enables it.
- Record every consumed key-down and consume its matching key-up.
- Keep backend release guards until consumed keys are physically up, even after a logical context closes.
- Support explicit pass-through bindings.
- Dispatch only through the central action dispatcher.
- Expose the active context, mappings, and held state to the overview.

### Contexts

| Context | Purpose |
|---|---|
| `workspace-system` | Overview toggle while the overview is closed or open |
| `workspace-layer` | CapsLock pseudo-modifier and direct workspace selection |
| `overview-space` | Workspace and Control Center selection |
| `overview-window` | Preview-window selection and activation |
| `overview-move` | Selected-window move or snap mode |
| `overview-settings` | Workspace and window quick settings |
| `overview-search` | Printable input pass-through to the WebView search field |
| `window-drag` | WinDrag start state and live modifier changes |
| `hotkey-recording` | Blocking workspace commands while another hotkey is recorded |

Managed-input priority is:

1. `hotkey-recording` and app suspension block all workspace bindings.
2. `workspace-system` cannot be hidden by overview subcontexts.
3. An active `workspace-layer` session owns its managed CapsLock suffixes.
4. The current overview subcontext or `window-drag` owns the remaining managed input.

Within one level, the most recently pushed context wins. Every context has clear entry, exit, ownership, and pass-through rules. Closing a context stops new ownership but does not remove release guards for keys that are still down.

`CapsLock+Space` is a `workspace-system` binding in both closed and open overview states. Hotkey recording blocks it. After opening, overview navigation stays disabled until all keys used to open it are physically released.

### Backend boundary

For the AHK version, the Windows backend should register suppressing wildcard down/up callbacks only for the small managed key set and only while an owning `HotIf` context is active. It may use physical `GetKeyState(..., "P")` reads to seed or repair state.

A permanent low-level hook is a fallback only if dynamic hotkeys cannot reliably observe or consume a required sequence. Core binding records and context behavior must not depend on which Windows backend is used.

The feasibility prototype passed the required physical-key checks on 2026-07-25. The MVP can use dynamic AHK callbacks; a permanent low-level hook is not required.

Example readable binding:

```json
{
  "id": "switch-workspace-ne",
  "context": "workspace-layer",
  "prefixKey": "CapsLock",
  "requiredSuffixKeys": ["W", "D"],
  "suffixOrder": "any",
  "trigger": "stable-hold",
  "stableMs": 100,
  "allowExtraManagedKeys": false,
  "consume": true,
  "repeat": false,
  "action": "SwitchSyntheticWorkspace(ne)"
}
```

The runtime form may use normalized key IDs or masks, but user-facing data should keep readable names.

<a id="input-5"></a>
## INPUT-5: CapsLock session

The chosen session model supports both switch modes from `IN-D06`.

Session state keeps:

- `ignoredPreheldSuffixes`: managed suffixes already down when CapsLock goes down.
- `heldDirectionMask`: eligible directions from this session that are still physically down.
- `currentValidDirectionMask`: the current cardinal or diagonal mask, or empty while the mask is invalid.
- `lastValidDirectionMask`: the newest valid mask for `on-release` mode.
- `pendingDirectionMask` and its 100 ms timer for `while-held` mode.
- `directionGestureArmed`: true when a new direction gesture may switch.
- `sessionMode`: unset, `direction`, `space`, or `legacy`.
- `isActionLocked`: true after Space or a legacy action runs.
- `tapCancelled`: true after any non-tap CapsLock use.
- Consumed keys and their backend release guards.

Session rules:

1. CapsLock down starts one `workspace-layer` session, provisionally consumes CapsLock, and snapshots pre-held suffixes.
2. A pre-held suffix is not part of the chord. Its key-up passes through because its key-down passed through.
3. The router always consumes the matching CapsLock up for an owned session.
4. The first accepted action family sets `sessionMode` to `direction`, `space`, or `legacy`.
5. Direction down/up events update `heldDirectionMask`.
6. A valid mask becomes `currentValidDirectionMask` and `lastValidDirectionMask`. In `while-held` mode, an armed new or changed valid mask starts or restarts the timer.
7. In `while-held` mode, an armed valid mask that stays unchanged for 100 ms switches once, clears its timer, and disarms the current gesture.
8. Keeping the same direction keys held after a switch cannot switch again.
9. Releasing every eligible direction key clears the pending timer and rearms the next gesture without requiring CapsLock release.
10. An opposite pair, third direction, or other invalid direction mask clears `currentValidDirectionMask` and cancels only the pending timer. A later valid mask starts a new timer only while the gesture is armed.
11. In `on-release` mode, direction chords do not switch while CapsLock is held. CapsLock release switches once to `lastValidDirectionMask`.
12. A direction session that never reaches a valid mask switches nothing and gives short feedback.
13. If Space is the first suffix, the router toggles the overview immediately, sets `isActionLocked`, and accepts no other Caps-mode action until CapsLock is released.
14. If direction mode started first, Space is consumed but does not toggle the overview or stop later direction gestures.
15. An accepted legacy chord dispatches once, sets `isActionLocked`, and accepts no other Caps-mode action until CapsLock is released.
16. An unbound non-modifier key passes through and sets `tapCancelled`.
17. A session with no accepted action and no `tapCancelled` runs the configured CapsLock tap action on release.
18. `isActionLocked` prevents a second Caps-mode action during the same hold.
19. Opening the overview starts a transition guard. Navigation starts only after every opening key is released.
20. Releasing CapsLock does not close an overview opened by `CapsLock+Space`.

<a id="input-6"></a>
## INPUT-6: Consumption, pass-through, and legacy chords

- An owned suffix is a key with an active binding in the current router context.
- CapsLock and an owned suffix are consumed for their complete down/up cycle when their action matches.
- An unbound non-modifier key passes through and cancels the CapsLock tap action.
- Extra unmanaged keys do not change an active direction match.
- Extra managed direction keys may make the current mask invalid and cancel its timer, but they do not invalidate the full CapsLock session.
- Every consumed key-down has a matching consumed key-up, including when a context changes before key-up.
- Keys that were already down before an owned session remain pass-through for both down and up.
- `W`, `A`, `S`, `D`, and `Space` reach the active application when no router context owns them.
- The router must not try to replay rejected input after suppressing it. Eligibility must be known before a suppressing callback runs.

Legacy `Alt+CapsLock` and `Ctrl+CapsLock` rules:

- An exact legacy chord works in either key order when it becomes complete before the first workspace suffix is accepted.
- The first eligible legacy chord dispatches once and sets `isActionLocked`.
- A legacy modifier held before CapsLock is not consumed, and its key-up also passes through.
- A legacy modifier pressed after CapsLock is consumed with a release guard.
- If both Alt and Ctrl are already down when CapsLock starts, neither exact legacy chord matches. The router sets `tapCancelled`, consumes CapsLock, and passes through both pre-held modifier key-up events.
- After a Space or legacy action locks the session, later Caps-bound keys cannot replace the result or dispatch a second action.

<a id="input-7"></a>
## INPUT-7: Lifecycle and repair

- Logical context cleanup and backend release-guard cleanup are separate operations.
- Closing any mode removes its logical context even after an error.
- Suspend, reload, app exit, session lock, backend restart, and hotkey recording transitions clear logical state safely.
- Consumed keys that remain physically down keep their release guards until key-up.
- Physical-state repair removes stale held bits after a missed key-up.
- Closing the overview cannot leave WASD suppressed.
- The input backend must have a clear unregister path for every callback or hook.

<a id="input-8"></a>
## INPUT-8: Later WinDrag integration

This section is outside the current MVP.

- Start WinDrag through a suppressing wildcard mouse binding enabled by a fast `HotIf` eligibility predicate.
- The predicate checks the required Win prefix, complete managed modifier set, configured mouse button, and target blocklist before AHK consumes mouse-down.
- If the predicate is false, native mouse down/up passes through. Do not replay rejected input.
- The accepted MVP-like binding for this later work uses the required Win prefix plus the configured quick-position modifier, recommended as Shift. Other managed modifiers reject the start unless a future binding allows them.
- Pass the normalized trigger button and initial held-key snapshot to WinDrag.
- Consume the handled mouse down/up pair with a release guard.
- Keep the quick-position modifier itself pass-through so its down/up events reach the active application.
- A pre-held quick-position modifier enables quick positioning at drag start.
- During dragging, WinDrag reads `InputRouter.GetHeldSnapshot()` or `InputRouter.IsKeyDown()` for live modifier changes.
- Remove the current rule that requires the modifier to be released once before it can activate.
- Validate that the required drag prefix and optional quick-position modifier are different keys.
- Stop depending on `A_ThisHotkey` when the router provides the trigger button.

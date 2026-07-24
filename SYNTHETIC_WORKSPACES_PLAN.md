# Synthetic Workspaces Plan

<a id="plan-1"></a>
## PLAN-1: Status

- This document is the entry point for the synthetic workspaces plan.
- The first implementation targets Windows and AutoHotkey.
- No implementation stage is complete yet.
- Current MVP scope and progress live in [`SYNTHETIC_WORKSPACES_MVP.md`](SYNTHETIC_WORKSPACES_MVP.md).
- The source direction comes from [`ROADMAP.md`](ROADMAP.md) and the `one-left` notes in [`TODO.txt`](TODO.txt).

<a id="plan-2"></a>
## PLAN-2: One source of truth

Each topic has one owning document. Edit a rule only in its owner. Other documents must link to the owning section instead of copying the rule.

| Topic | Owning document |
|---|---|
| Product goal, document ownership, shared architecture, delivery order, and deferred product work | This document |
| MVP scope, progress, and stage gates | [`SYNTHETIC_WORKSPACES_MVP.md`](SYNTHETIC_WORKSPACES_MVP.md) |
| Keyboard and mouse input, CapsLock sessions, router contexts, and WinDrag integration | [`SYNTHETIC_WORKSPACES_INPUT.md`](SYNTHETIC_WORKSPACES_INPUT.md) |
| Workspace and window state, switching, layouts, identity, persistence, and recovery | [`SYNTHETIC_WORKSPACES_STATE.md`](SYNTHETIC_WORKSPACES_STATE.md) |
| Overview UI, settings, Control Center, One-Hand Control, and WebView bridge | [`SYNTHETIC_WORKSPACES_OVERVIEW.md`](SYNTHETIC_WORKSPACES_OVERVIEW.md) |
| Manual and future automated verification | [`SYNTHETIC_WORKSPACES_TESTS.md`](SYNTHETIC_WORKSPACES_TESTS.md) |

Rules for this document set:

- Stable section IDs such as `INPUT-5` and `STATE-6` are link targets.
- A decision and its status live in the document that owns the affected behavior.
- The MVP document links to required sections and does not repeat their behavior.
- The tests document checks behavior but does not define new behavior.
- If a test and a specification disagree, fix the test or resolve the specification decision. Do not create a second rule.
- Do not hard-wrap Markdown text at a fixed line width.

<a id="plan-3"></a>
## PLAN-3: Product goal

Add eight synthetic workspaces around a central Control Center:

```text
North West    North        North East
West          Control      East
South West    South        South East
```

Synthetic workspaces do not use native Windows virtual desktops. Haribol! owns assignment, saved geometry, focus history, layout, overview, and switching behavior.

The first version must work well on Windows. Operating-system calls stay behind small interfaces so the behavior model and stored data can later move to C++ or Rust and receive macOS and Linux backends.

The exact runtime model and switch behavior are owned by [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2) through [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7).

<a id="plan-4"></a>
## PLAN-4: Shared architecture

The names below describe responsibilities. They do not require one class or file per row.

| Layer or role | Responsibility | Canonical details |
|---|---|---|
| `SyntheticWorkspaces` plugin | Public actions, simple settings, and service lifecycle | [`STATE-3`](SYNTHETIC_WORKSPACES_STATE.md#state-3) |
| `WorkspaceService` and `LayoutEngine` | Portable workspace rules, cached state, transactions, focus, layouts, and geometry math | [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2) through [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7) |
| `WorkspaceStateStore` and `WindowIdentityMatcher` | Portable validation, persisted state, matching, and ambiguity handling | [`STATE-8`](SYNTHETIC_WORKSPACES_STATE.md#state-8) through [`STATE-11`](SYNTHETIC_WORKSPACES_STATE.md#state-11) |
| `InputRouter` | Portable contexts, held state, chord matching, consumption records, and dispatch | [`INPUT-4`](SYNTHETIC_WORKSPACES_INPUT.md#input-4) through [`INPUT-7`](SYNTHETIC_WORKSPACES_INPUT.md#input-7) |
| Windows input backend | AHK hotkeys or hooks, physical key reads, and input suppression | [`INPUT-4`](SYNTHETIC_WORKSPACES_INPUT.md#input-4) |
| Windows window backend | Window discovery, events, geometry, stacking, focus, monitor data, covers, and icons | [`STATE-3`](SYNTHETIC_WORKSPACES_STATE.md#state-3) through [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7) |
| Platform persistence backend | Temporary-file write, flush, and safe replacement | [`STATE-11`](SYNTHETIC_WORKSPACES_STATE.md#state-11) |
| Platform launcher | Direct launch of validated saved entries without a command shell | [`OVERVIEW-7`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-7) |
| Overview host and frontend | WebView lifecycle, rendering, input contexts, validated commands, and UI-only drag state | [`OVERVIEW-3`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-3) through [`OVERVIEW-10`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-10) |

Portable workspace code must not call `WinGet*`, `WinMove`, `DllCall`, `GetKeyState`, read `A_ThisHotkey`, replace files directly, or launch shell command strings. Platform backends report missing capabilities instead of pretending an operation succeeded.

<a id="plan-5"></a>
## PLAN-5: Delivery order

1. Resolve blocking decisions and prove the two high-risk parts: CapsLock input handling and desktop-cover z-order.
2. Complete the linked stages in [`SYNTHETIC_WORKSPACES_MVP.md`](SYNTHETIC_WORKSPACES_MVP.md).
3. Run the MVP gate in [`TEST-2`](SYNTHETIC_WORKSPACES_TESTS.md#test-2) only when the user asks for implementation verification.
4. Plan later features from their canonical later sections. Do not copy them into a second checklist before their work starts.
5. Update public docs and complete the final DOX pass after the implementation works.

Build the MVP as useful vertical stages. Do not leave the input layer, model, or backend disconnected for several phases.

<a id="plan-6"></a>
## PLAN-6: Work outside the MVP

The scope boundary is owned only by [`MVP-9`](SYNTHETIC_WORKSPACES_MVP.md#mvp-9). This section does not keep a second list.

<a id="plan-7"></a>
## PLAN-7: Deferred product directions

These items are outside the current design:

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

<a id="plan-8"></a>
## PLAN-8: Existing code to reuse carefully

| Source | Use |
|---|---|
| `includes/AKApp.ahk` | Action catalog, central dispatch, logging, and error handling |
| `includes/AKGui.ahk` | WebView creation, callback registration, JSON injection, and script updates |
| `includes/HotkeyRecorder.ahk` | Reference for normalized Windows input handling, but not an always-running router |
| `plugins/WindowResizeDialog.ahk` | Reference for contextual wildcard WASD state and diagonal input |
| `plugins/WinDrag.ahk` | `SetWindowPos`, visible-frame, snap-zone, and neighboring-window ideas, but not private helpers |
| `plugins/WindowStash.ahk` | Monitor change, work-area, clamping, and invisible-border ideas |
| `plugins/WindowManager.ahk` | Window enumeration, visible-frame fallback, border highlighting, and WinEvent patterns |
| `plugins/ShellMessageHook.ahk` | Reference for create, destroy, and activate events; it is incomplete and needs repair before reuse |
| `lib/jsongo.ahk` | JSON conversion |
| Existing color picker and local icons | Generic UI behavior and assets, while the overview bridge stays separate from settings |

<a id="plan-9"></a>
## PLAN-9: Completion and document updates

- MVP progress is recorded only in [`SYNTHETIC_WORKSPACES_MVP.md`](SYNTHETIC_WORKSPACES_MVP.md).
- When an MVP step is complete, replace its unchecked marker with `✅`.
- When every MVP step and gate is complete, start the MVP document header with `# ✅ COMPLETED:`.
- When the full synthetic workspaces plan is complete, start this document header with `# ✅ COMPLETED:`.
- Update `README.md`, `ACTION_CATALOG.md`, plugin descriptors, settings, and `ROADMAP.md` only when related implementation exists.
- Update every affected `AGENTS.md` and Child DOX Index during the final DOX pass.

# Synthetic Workspaces MVP

<a id="mvp-1"></a>
## MVP-1: Purpose

This file is the only source for MVP scope, order, and progress. It does not define behavior. Every step links to the document that owns the rule.

The MVP is complete only when all required steps below are marked `✅` and the verification gate in [`TEST-2`](SYNTHETIC_WORKSPACES_TESTS.md#test-2) passes.

<a id="mvp-2"></a>
## MVP-2: Status rules

- Current status: Stage 0 decisions and feasibility are complete; Stage 1 workspace-engine implementation has not started.
- Use `[ ]` for work that has not started.
- Replace `[ ]` with `✅` only after the linked section is implemented.
- Do not copy details from linked sections into this file.
- If MVP scope changes, edit this file. If behavior changes, edit the linked owner document.

<a id="mvp-3"></a>
## MVP-3: Stage 0 - decisions and feasibility

- ✅ Resolve every MVP-blocking input decision in [`INPUT-3`](SYNTHETIC_WORKSPACES_INPUT.md#input-3).
- ✅ Resolve every MVP-blocking workspace and window decision in [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2).
- ✅ Resolve every MVP-blocking persistence decision in [`STATE-8`](SYNTHETIC_WORKSPACES_STATE.md#state-8).
- ✅ Resolve every MVP-blocking overview decision in [`OVERVIEW-2`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-2).
- ✅ Prove the managed CapsLock backend against [`TEST-3`](SYNTHETIC_WORKSPACES_TESTS.md#test-3).
- ✅ Prove the desktop-cover and z-order approach against [`TEST-4`](SYNTHETIC_WORKSPACES_TESTS.md#test-4).

<a id="mvp-4"></a>
## MVP-4: Stage 1 - workspace engine

- [ ] Implement the workspace model and invariants in [`STATE-2`](SYNTHETIC_WORKSPACES_STATE.md#state-2).
- [ ] Add the public plugin actions and lifecycle in [`STATE-3`](SYNTHETIC_WORKSPACES_STATE.md#state-3).
- [ ] Implement the runtime window cache and classification in [`STATE-4`](SYNTHETIC_WORKSPACES_STATE.md#state-4).
- [ ] Implement native events and reconciliation in [`STATE-5`](SYNTHETIC_WORKSPACES_STATE.md#state-5).
- [ ] Implement guarded switching, covers, focus restore, and emergency recovery in [`STATE-6`](SYNTHETIC_WORKSPACES_STATE.md#state-6).
- [ ] Implement the `freeform` geometry and monitor rules required by [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7).

Stage result: direct action calls can switch workspaces safely without keyboard bindings or overview UI.

<a id="mvp-5"></a>
## MVP-5: Stage 2 - workspace input

- [ ] Implement the direction model in [`INPUT-2`](SYNTHETIC_WORKSPACES_INPUT.md#input-2).
- [ ] Implement router ownership, contexts, and dispatch in [`INPUT-4`](SYNTHETIC_WORKSPACES_INPUT.md#input-4).
- [ ] Implement the CapsLock session in [`INPUT-5`](SYNTHETIC_WORKSPACES_INPUT.md#input-5).
- [ ] Implement consumption and pass-through behavior in [`INPUT-6`](SYNTHETIC_WORKSPACES_INPUT.md#input-6).
- [ ] Implement router cleanup and state repair in [`INPUT-7`](SYNTHETIC_WORKSPACES_INPUT.md#input-7).
- [ ] Connect the approved workspace actions only after Stage 1 switching is safe.

Stage result: the keyboard-only workspace version is useful and recoverable.

<a id="mvp-6"></a>
## MVP-6: Stage 3 - persistence and identity

- [ ] Implement the MVP identity behavior in [`STATE-9`](SYNTHETIC_WORKSPACES_STATE.md#state-9).
- [ ] Implement the persisted schema, validation, and default generator in [`STATE-10`](SYNTHETIC_WORKSPACES_STATE.md#state-10).
- [ ] Implement safe load, debounced save, and atomic replacement in [`STATE-11`](SYNTHETIC_WORKSPACES_STATE.md#state-11).

Stage result: stable assignments, geometry, focus history, and slot mapping survive restart without saving runtime handles.

<a id="mvp-7"></a>
## MVP-7: Stage 4 - minimal overview

- [ ] Implement the overview host, grid, and focus lifecycle in [`OVERVIEW-3`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-3).
- [ ] Implement the workspace and window display in [`OVERVIEW-4`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-4).
- [ ] Implement MVP selection, keyboard navigation, and basic window movement in [`OVERVIEW-5`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-5).
- [ ] Implement the MVP bridge commands and revision rules in [`OVERVIEW-9`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-9).
- [ ] Keep the center Control Center cell as the placeholder defined in [`OVERVIEW-7`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-7).

Stage result: users can see all eight workspaces, select a workspace or window, and move a window between workspaces.

<a id="mvp-8"></a>
## MVP-8: Stage 5 - integration and closeout

- [ ] Complete the MVP checks in [`TEST-2`](SYNTHETIC_WORKSPACES_TESTS.md#test-2).
- [ ] Finalize plugin descriptor settings and public action descriptions.
- [ ] Review and document the safe default bindings.
- [ ] Update the settings UI only for implemented global options.
- [ ] Update `README.md` and `ACTION_CATALOG.md`.
- [ ] Update `ROADMAP.md` only after the MVP works.
- [ ] Remove only code made obsolete by this implementation.
- [ ] Keep unrelated TODO and FIXME comments.
- [ ] Perform the final DOX pass.

<a id="mvp-9"></a>
## MVP-9: Explicitly outside the MVP

The following sections stay in the full plan but do not block MVP completion:

- [`INPUT-8`](SYNTHETIC_WORKSPACES_INPUT.md#input-8)
- The later layout templates in [`STATE-7`](SYNTHETIC_WORKSPACES_STATE.md#state-7)
- The advanced identity and visual-rule tools in [`STATE-9`](SYNTHETIC_WORKSPACES_STATE.md#state-9)
- [`OVERVIEW-6`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-6)
- The full feature set in [`OVERVIEW-7`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-7)
- [`OVERVIEW-8`](SYNTHETIC_WORKSPACES_OVERVIEW.md#overview-8)
- The related later checks in [`TEST-8`](SYNTHETIC_WORKSPACES_TESTS.md#test-8)

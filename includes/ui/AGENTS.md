# Settings Frontend

## Purpose

- Own the HTML, CSS, and JavaScript settings interface hosted by `AKGui.ahk`.

## Ownership

- `settings.html` and `settings.css` own the page shell and styling.
- `app.js` owns frontend startup and the global bridge entrypoint.
- `classes/` owns reusable settings controllers and renderers.
- `Pages/` owns page-level orchestration.
- `vendor/` owns bundled third-party frontend assets.

## Local Contracts

- Host calls must remain compatible with callbacks registered in `includes/AKGui.ahk`.
- Dynamic control IDs and `data-*` attributes are contracts shared by renderers, controllers, and page logic.
- The Plugins page exposes enable state and per-plugin log levels; enable changes require reload, while log-level changes apply immediately.
- New runtime-loaded frontend files must be represented in compiled-build resource directives in `Haribol!.ahk`.

## Work Guidance

- Prefer delegated event handling for dynamically rendered controls.
- Keep state serialization and rendering concerns in their existing classes.

## Verification

- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- [`classes/AGENTS.md`](classes/AGENTS.md): reusable frontend controllers, bridges, serializers, and renderers.
- [`Pages/AGENTS.md`](Pages/AGENTS.md): page-level settings behavior.
- [`vendor/AGENTS.md`](vendor/AGENTS.md): bundled third-party frontend files.

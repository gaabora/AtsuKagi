# Shared Libraries

## Purpose

- Own reusable AHK helpers, configuration parsing, notifications, JSON support, and bundled external libraries.

## Ownership

- Application-specific orchestration belongs in `includes/`.
- Feature-specific behavior belongs in `plugins/`.
- `WebViewToo-main/` is a vendored WebView dependency.

## Local Contracts

- Shared helpers must remain compatible with all callers and AutoHotkey v2.
- Avoid adding application state to general-purpose library modules.

## Work Guidance

- Match existing library APIs and keep changes narrowly scoped because these files have broad call surfaces.

## Verification

- Do not run automated tests under the current repository-wide user preference.

## Child DOX Index

- [`WebViewToo-main/AGENTS.md`](WebViewToo-main/AGENTS.md): bundled third-party WebView library and examples.

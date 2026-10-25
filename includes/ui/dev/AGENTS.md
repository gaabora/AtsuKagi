# Browser Settings Preview

## Purpose

- Run the real settings frontend in a browser without AutoHotkey.

## Ownership

- `server.ts` owns the Bun static server, development script injection, and file-change events.
- `fixtures.js` owns small example settings payloads and automation scenarios.
- `browser.js` owns `BrowserMockBridge`, preview controls, browser storage, and draft restore.

## Local Contracts

- Listen on `127.0.0.1:3000` and serve only files inside `includes/ui/`, including resolved symbolic links.
- Keep the original classic script order. Reload the page after UI file changes without bundling production scripts.
- Inject development scripts only into the server response, before `app.js`. Do not add them to packaged WebView resources.
- Use the same `SettingsPage` and controllers as the application through its optional host bridge parameter.
- Store mock data in scenario-specific `localStorage` keys and editor state in scenario-specific `sessionStorage` keys.
- Browser run, test, OSD, and window commands are simulations. Never call AHK, execute shell commands, or change real application files.
- Example payloads are UI fixtures, not a second scheduler or host validation implementation.
- Keep browser-only helpers out of the production controller lifecycle.

## Work Guidance

- Keep preview scope focused on Automations. Add other host methods only when a preview needs them.
- Restart the development server after changing `server.ts`.

## Verification

## Child DOX Index

- No child DOX files.

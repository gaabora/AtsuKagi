# DevTools AHK State Replay

This exports and imports the full AHK-provided UI state (including dynamic plugin pages), not just form values.

## Commands

```javascript
expAhk()
impAhk(payload)
```

## Source Browser (opened by AHK/WebView)

Run this in DevTools console:

```javascript
expAhk()
```

It prints one plain one-line command like:

```javascript
impAhk("{...full_state_json...}")
```

Copy that exact line.

## Target Browser (plain browser)

1. Open the same settings page with scripts loaded.
2. Paste the copied line and run it.

This recreates missing dynamic content (plugins/pages/actions) and applies full state.

## Notes

- `expAhk()` requires that state was previously applied from AHK at least once.
- If state is not captured yet, reopen settings from AHK first.

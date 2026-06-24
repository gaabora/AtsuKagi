# Test Sources

## Purpose

- Own Yunit-based test sources, test helpers, and the bundled Yunit framework.

## Ownership

- Tests should describe existing production contracts without introducing runtime dependencies.
- `Yunit/` is bundled third-party test infrastructure.
- `RunAllTests.ahk` runs all suites through Yunit stdout mode for CLI/task output.
- `RunAllTestsGui.ahk` opens each suite in Yunit window mode for manual GUI review.

## Local Contracts

- Do not run tests under the current repository-wide user preference.
- Keep temporary test artifacts out of tracked source.

## Work Guidance

- When test changes are requested, match the existing AutoHotkey v2 and Yunit style.
- Individual `*Tests.ahk` files should support direct windowed execution and `--cli` stdout execution.

## Verification

- Static inspection only unless the user replaces the repository-wide no-test instruction.

## Child DOX Index

- No child DOX files.
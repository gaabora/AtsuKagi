# WebViewToo Vendor Tree

## Purpose

- Own the bundled WebViewToo library, loader binaries, examples, and upstream sample assets.

## Ownership

- Treat this subtree as an external dependency.
- Application integration belongs in `includes/AKGui.ahk` and `includes/ui/`.

## Local Contracts

- Avoid edits unless the task explicitly targets the dependency.
- Preserve loader architecture paths under `Lib/32bit` and `Lib/64bit`.
- Keep upstream license material intact.

## Work Guidance

- Prefer adapting application integration over modifying vendor source.

## Verification

## Child DOX Index

- No child DOX files.

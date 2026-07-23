# TextLocaleManager Review and Layout Support Plan

## Goal

Make `TextLocaleManager` safe for standard US QWERTY and standard Russian first, then make its conversion core reusable for other direct-input keyboard layout pairs.

The first release target is intentionally small:

- Standard US QWERTY with exact KLID `00000409`.
- Standard Russian with exact KLID `00000419`.
- Mixed text such as `ghbdtn! руддщ` becomes `привет! hello`.
- The active layout follows the final converted text run.
- Unsupported, missing, or ambiguous layouts never change selected text.

## Reuse and Universal Support Answer

The plugin can become easy to reuse for other ordinary keyboard layout pairs by registering another mapping. A mapping must provide:

- Exact Windows layout identities it supports.
- User-facing names and aliases.
- Character-to-physical-key data for both sides.
- Characters that clearly identify each side.
- Known limits such as dead keys or AltGr.

Conceptual mapping record:

```text
Mapping ID: US-QWERTY-RU-STANDARD
Side A: EN, exact KLID 00000409, identifying characters
Side B: RU, exact KLID 00000419, identifying characters
Conversion: Side A character -> physical key -> Side B character
```

With this contract, adding a simple pair such as US QWERTY and Ukrainian should require a mapping plus tests. Clipboard and action code should not change.

This is reusable, but not universal for every Windows input method. Manual one-to-one mappings suit ordinary direct-input layouts. These cases need separate support or safe rejection:

- Japanese, Korean, and Chinese IME or composition input.
- Dead-key-heavy layouts.
- Complex AltGr layouts.
- Layouts where one key produces multiple characters.
- Application-managed composition state.

Generated mappings through Windows APIs can reduce manual work later, but they do not remove these limits.

## Current Working Tree Status

### ✅ Completed safety work

- Focused-control and active-window HWND resolution is fixed.
- `EN`, `ENG`, `RU`, and `RUS` aliases resolve explicitly.
- Empty layout input is separate from unknown layout names.
- Unknown layout names produce clear errors.
- Empty, ambiguous, and unchanged text is not pasted.
- Selected text is no longer written to debug output.
- `SwapTextLayout()` remains a pure converter.
- A no-argument action path and installed-pair list exist.
- Known-editor implicit line-copy protection exists.
- Basic EN/RU conversion and safe-skip tests exist.

### ✅ Phase A fixes implemented

- Exact configured KLIDs are combined with active HKLs without treating a language ID as a full layout ID.
- Standard US `00000409` and standard Russian `00000419` are the only layouts accepted by the current mapping.
- Dvorak, US International, Russian Typewriter, Russian Mnemonic, and unresolved same-language layouts are rejected safely.
- Automatic and explicit pairs require compatible installed layouts.
- The final layout record and target window are resolved before paste.
- Next-layout mode uses `INPUTLANGCHANGE_FORWARD`.
- Named switching uses the exact resolved active HKL.
- Detection checks clear characters across every mapping group.
- Descriptor parameters are optional together.
- The default action uses `SwitchSelectedTextLayout()`.
- Test fixtures do not read the real user registry.
- Static regression cases cover exact variants, missing targets, switching flags, exact HKLs, mapping groups, and automatic default selection.

### Accepted Phase A limitation

A known editor's implicit line copy looks the same as an intentional full-line selection. Clipboard text alone cannot distinguish them.

Phase A keeps the safer behavior: a complete selected line may be skipped in those editors. Better editor-specific detection remains later work.

## Target Internal Design

Keep the implementation small. New public classes are not required for the first pass. Plain records and focused private helpers are enough.

### Installed layout record

Store the exact Windows identity instead of only `EN := true`:

```text
canonical name
exact KLID
exact active HKL used for switching
display name
known aliases
```

Use `GetKeyboardLayoutList` as the source of active input identifiers. Registry data may be used only for exact KLID metadata. Never use a low 16-bit language ID as the full layout identity.

### Conversion mapping record

Each reusable mapping should contain:

```text
mapping ID
supported exact Side A layout IDs
supported exact Side B layout IDs
Side A and Side B conversion characters
Side A and Side B identifying characters
capability limits when needed
```

A matching language is not enough. The mapping must declare exact compatible layouts.

### Supported pair record

A supported pair should reference:

```text
conversion mapping
exact installed Side A layout record
exact installed Side B layout record
```

Do not rebuild a Windows layout ID later from a short name.

### Safe action workflow

`SwitchSelectedTextLayout()` should use this order:

```text
1. Choose an explicit or automatic mapping pair.
2. Resolve both exact installed layouts.
3. Resolve and validate the exact final switch target.
4. Copy selected text.
5. Skip empty or protected implicit-line-copy text.
6. Convert through the pure converter.
7. Skip ambiguous or unchanged output.
8. Paste converted text.
9. Switch using the already validated exact HKL.
```

No expected layout error should be possible after step 8.

## Implementation Plan

### ✅ Step 1: Support only exact standard EN/RU layouts

Goal: prevent variants from using an incompatible character map.

Tasks:

1. Enumerate active Windows input identifiers.
2. Keep exact installed layout records instead of support booleans.
3. Register the current map only for `00000409` and `00000419`.
4. Mark Dvorak, US International, Russian Typewriter, Russian Mnemonic, and other variants unsupported.
5. Show the exact layout ID and support result in `ShowUsersKeyboardLayouts()`.

Verify later when test execution is approved:

- Standard US and Russian create one pair.
- A language match with a different exact ID does not create a pair.
- The pair keeps the exact switching target.

### ✅ Step 2: Validate the complete operation before paste

Goal: never change text and then fail because the target layout is unavailable.

Tasks:

1. Make automatic and explicit pair selection resolve exact installed layouts.
2. Do not let explicit `EN,RU` bypass installation and compatibility checks.
3. Resolve the exact final target before `_putText()`.
4. Return safely when the pair or target is unavailable.
5. Keep direct `SwapTextLayout()` independent from installed layouts because it has no paste or switch side effect.

Verify later:

- Missing standard Russian means no paste and no switch.
- An unsupported variant means no paste and no switch.
- Target-resolution errors happen before visible text changes.

### ✅ Step 3: Correct next-layout and named-layout switching

Goal: use the documented Windows message contract.

Tasks:

1. With no argument, send `INPUTLANGCHANGE_FORWARD`.
2. For a named layout, use the exact installed HKL.
3. Keep unknown non-empty names as errors.
4. Keep focused-control then active-window target resolution.
5. Do not reduce named layouts to a low 16-bit language ID.

Verify later:

- Empty input requests the next layout.
- Named input switches to the exact installed layout.
- Unknown or uninstalled input never becomes next-layout behavior.

### ✅ Step 4: Make automatic pair selection the default

Goal: normal configuration should use the safe installed-pair path.

Tasks:

1. Change the shipped binding to `SwitchSelectedTextLayout()`.
2. Make both descriptor parameters optional together.
3. Update action documentation and examples.
4. Keep explicit pairs for users with several registered mappings.
5. Reject a single supplied parameter with a clear error.

Verify later:

- The shipped hotkey uses automatic pair selection.
- No supported pair means no paste and no switch.
- Explicit parameters select a compatible installed pair.

### ✅ Step 5: Separate detection from positional conversion

Goal: detect text reliably without changing the physical-key mapping format.

Tasks:

1. Build identifying sets from all mapping groups, not only group 1.
2. Treat a character as strong only when it clearly identifies one side.
3. Ignore whitespace and digits.
4. Let shared punctuation follow the surrounding detected run.
5. Include `ж`, `э`, `б`, and `ю`.
6. Preserve mixed-run conversion and return the final converted layout.
7. Return a status such as `converted`, `ambiguous`, or `unsupported` if it simplifies action decisions.

Possible later improvement:

- Score all strong characters when there is no clear run boundary.
- Use the current layout only as a final tie-breaker.

Verify later:

- Clear Russian characters in every group convert.
- Digits, spaces, and shared punctuation alone are skipped.
- `ghbdtn! руддщ` becomes `привет! hello` with final layout `EN`.
- Ambiguous punctuation follows a clear neighboring run.

### ✅ Step 6: Keep the editor line-copy guard as a documented limit

Goal: prevent accidental replacement when nothing was selected.

Tasks:

1. Keep the known-editor process list for the first stable version.
2. Document the intentional full-line selection limitation.
3. Isolate the list so it can become configuration later.
4. Do not add complex editor integration during EN/RU correctness work.

Verify later:

- No selection in a known editor does not paste at the cursor.
- Normal single-line and multi-line selections still convert.
- A complete selected line ending with a newline is deliberately skipped and documented.

### ✅ Step 7: Make tests independent from the real machine

Goal: test plugin behavior without reading the user's keyboard configuration.

Tasks:

1. Override or inject layout enumeration in test fixtures.
2. Test exact standard US/Russian records.
3. Test Dvorak, US International, Russian Typewriter, and Russian Mnemonic as unsupported.
4. Test missing target and pre-paste validation.
5. Test next-layout and exact named-layout message data through a spy or wrapper.
6. Test descriptor and default-action parity.
7. Keep tests static until repository instructions allow running them.

Verify later:

- Results do not depend on layouts installed on the developer machine.
- Every P1 and P2 behavior has a focused regression test.

### Step 8: Add reusable manual mapping registration

Goal: add a second direct-input pair without changing workflow code.

Tasks:

1. Move EN/RU data into one mapping record.
2. Store mappings in a collection keyed by mapping ID.
3. Match exact installed layouts to registered mappings.
4. Add a second small mapping to prove reuse.
5. Keep aliases in mapping metadata instead of pair-specific action branches.

Verify later:

- The second pair needs mapping data and tests only.
- Clipboard, orchestration, and switching code do not change.
- Unsupported mappings skip safely.

This step makes the plugin practically reusable by providing mappings.

### Step 9: Prototype generated mappings

Goal: reduce manual mapping work for ordinary direct-input layouts.

Candidate APIs:

- `GetKeyboardLayoutList` for active layout identifiers.
- `LoadKeyboardLayout` only when exact KLID resolution is required and its side effects are understood.
- `GetKeyboardLayout` for the current HKL.
- `VkKeyScanEx` for character to virtual-key and modifiers.
- `MapVirtualKeyEx` and `ToUnicodeEx` for physical key to output character.

Conversion bridge:

```text
source character -> source physical key/modifier -> target character
```

Tasks:

1. Generate standard EN/RU data behind a private helper.
2. Compare it with the trusted manual map.
3. Reject unsafe dead-key, composition, and multi-character cases.
4. Keep the manual map until generated output matches it.

Verify later:

- Generated EN/RU output matches manual output.
- Complex unsupported layouts return `unsupported` without changes.
- Public actions remain unchanged.

### Step 10: Add configuration only after reuse is proven

Possible descriptor settings:

- Default mapping when several pairs are supported.
- Minimum detection confidence if scoring is added.
- Whether to switch layout after conversion.
- Whether to show a notice when conversion is skipped.
- Known-editor implicit line-copy process list.

Do not add these settings before exact EN/RU and reusable registration are stable.

## Suggested Delivery Phases

### ✅ Phase A: Safe standard EN/RU

- Complete Steps 1 through 7.
- Support only exact standard US QWERTY and Russian.
- Do not claim variant support.

### Phase B: Reusable manual mapping plugin

- Complete Step 8.
- Prove reuse with one additional direct-input pair.
- Document the mapping contract.

### Phase C: Generated direct-input mappings

- Complete Step 9.
- Enforce unsupported-layout boundaries.

### Phase D: User configuration

- Add only settings proven useful by earlier phases.

## Non-goals For Phase A

- Do not support every Windows input method.
- Do not treat language IDs as exact layout IDs.
- Do not add a large external layout database.
- Do not redesign hotkeys.
- Do not refactor unrelated plugin infrastructure.
- Do not add complex editor integrations.

## Completion Criteria

Phase A is complete when:

- Exact standard US/Russian works reliably.
- Variants are rejected safely.
- No expected layout error can happen after paste.
- Next-layout switching uses the correct mode.
- Detection covers all clear mapped characters.
- Default configuration and descriptor use automatic pair selection.
- Tests are independent from real installed layouts.

The reusable manual-mapping milestone is complete when:

- Mapping identity, detection, and conversion data have a documented shape.
- At least two pairs use the same workflow.
- Adding the second pair requires no action or clipboard changes.

Describe the plugin as universal only after generated mapping support has clear tests and explicit limits. Until then, describe it as reusable for registered direct-input layout pairs.

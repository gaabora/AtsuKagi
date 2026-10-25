Read `DOX.md` before editing. This file is the repository-wide contract.

# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

- the app to be converted in later major version to crossplatform win/mac/linux app, probably in c++ or rust, so use wrappers for os-specific logic so the code is well reusable

- write in ASD-STE100 Simplified Technical English
- Use simple Russian in chat. Write repository documentation in simple English. Use practical examples and avoid fancy metaphors.
- no newlines between params in methods and conditions if line <200 symbols
- Never use one-letter variable names. Use `idx` for index variables.
- Use `this` when accessing class members from class methods.
- never ever use Em dash `—` but use `-` instead
- in C++ never create nameless namespace { ... } in the middle of code, use coresponding helper files
- Before you change code or documentation, briefly describe the planned changes. Make changes only after approval.
- do not build anything and run tests until asked, and no need to notify about that it in every response
- no need for backward compatibility, app is not yet released
- when implementing tasks from md todo/fixme/plan document, mark completed sections or steps with ✅ emoji, and when the entire doc is completed, make its main header start with "# ✅ COMPLETED: "
- do not do staging-unstaging/commiting until asked, user manages git himself. never push changes
- never hard-wrap text at a fixed line width
- never delete in code todo/fixme comments until they were implemented/fixed
- if summarizing a completed work iteration, also say very briefly what will be the next step/stage to complete and if something is required from user (like review unclear decisions in doc) then say what is expected to be done by user now
- never delete files/folders but rather move them to ./.deleted/ folder in workspace root

Write at about CEFR A2-B1 English.
If a word is uncommon for an English learner, replace it with a simpler one.
Never try to sound academic or professional. Clarity is more important than precision unless the technical term is absolutely necessary.

## Root Plan Index

- `SYNTHETIC_WORKSPACES_PLAN.md` is the entry point and source-of-truth map for all synthetic workspace planning documents.

---
name: download-router-rules
description: Use when building or testing arran4/download_router's lexer, DSL evaluator, per-file plan, review/selection and apply pipeline; keep planning side-effect-free.
---
# Downloads Router DSL and apply safety

**Source:** https://github.com/arran4/download_router ; read `README.md`, `SPEC.md` and `AGENTS.md` and the current issue #58 sequence before modifying a user-visible flow.

## Central invariant
The workflow is **scan → plan → review/select → apply → rescan**. Parsing/evaluation and planning must not mutate the filesystem; only explicitly selected actionable plans reach apply. Never replace the existing browser with a simplified mock screen or use a network/LLM as a mandatory core dependency.

## Development
1. For lexer/parser changes, preserve source locations in errors and a readable debug/AST representation where implemented. Errors are visible, never silently ignored.
2. Update the shipped canonical DSL example and its execution/conformance tests; a successful parser-only test is insufficient for altered evaluation semantics.
3. Evaluate rules independently for each file/directory/symlink entry. Keep `StopAction`, variable propagation, diagnostics and destination calculation consistent with the existing evaluator contract; inspect current implementation before claiming any action is supported.
4. Build a per-entry plan with changes and warnings; preserve individual opt-in/opt-out selection, handling of non-actionable files and counts in the apply button.
5. Only then apply selected plans, after collision/path-type/permission validation; report per-item partial failures and rescan. Test that unselected entries and rule previews leave disk untouched.
6. Use synthetic temp Downloads roots under /tmp for genuine disk operations, with symlinks, dirs, read-only files, collisions and changing/in-progress downloads.
7. Keep local/offline operation working without any GitHub sync or optional LLM classification.

## Verification
Run `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test`. Capture separate parse, evaluate, plan, selected apply and rescan evidence, with exact before/after directory snapshot. If Flutter is unavailable, leave implementation draft and say so.

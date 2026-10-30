---
name: rntocase-safe
description: Use when batch-renaming files with arran4/rntocase and validating safe previews, recursive include/exclude rules, collision handling and noninteractive application.
---
# Safe batch renaming with rntocase

**Source:** https://github.com/arran4/rntocase, including embedded skill at `internal/skill/embedded_skills/rntocase/SKILL.md`. This consolidates the upstream skill's useful behaviors, rather than inventing a new rename implementation.

## Workflow
1. Verify `rntocase help` and target subcommand help against installed CLI. Prefer explicit source paths over unquoted globs.
2. Always run `rntocase snake --dry-run <paths...>` or the desired case variant before any write. Inspect target names for duplicates, unexpected extensions, dotfiles and case-folding ambiguity.
3. Recursive mode is opt-in: `rntocase kebab --dry-run --recursive --include '*.jpg' --exclude '.git/**' ./assets`. Include/exclude filters are **doublestar path globs**, not regex. Exclusions win; file roots are relative to the source directories.
4. Recursive discovery selects regular files only; skips directory symlinks, explicit symlinks and directories themselves. Do not imply that directory renaming or symlink traversal is supported.
5. The preflight rejects destination collisions before altering the batch. If mutation fails midway, some earlier renames may have succeeded and the tool reports nonzero; inspect actual state before retrying. There is no built-in undo.
6. `--interactive` blocks automation: use a reviewed dry-run followed by a noninteractive invocation only with the user's authorization. For repositories under git, review `git status --short` afterward.
7. When editing the CLI itself, test same-name collisions, case-only renames, compound extensions, symlink exclusions and partial execution errors; prefer temporary synthetic dirs, never a real user's media library.

## Report
Show preview command, exact proposed changes, collisions rejected, applied changes, errors and follow-up diff. Do not claim a dry-run has renamed files.

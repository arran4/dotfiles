---
name: rntocase-safe
description: Use the arran4/rntocase CLI to preview, batch rename or recursively transform filename case, preserving compound extensions and checking collisions. Invoke for real file-renaming tasks, not just development of rntocase.
---
# rntocase — batch rename files by case

**Source:** https://github.com/arran4/rntocase, which also distributes a richer canonical agent skill under `internal/skill/embedded_skills/rntocase/SKILL.md`. This staging skill should be reconciled with that upstream skill before publishing both globally.

## Choose a transformation

```sh
rntocase snake --dry-run "My File.txt"
rntocase kebab --dry-run "Example Name.tar.gz"
rntocase camel --dry-run ./*.md
rntocase constant --dry-run ./*.go
rntocase delimited --delimiter _ --dry-run "Some Name.txt"
rntocase help
```

Subcommands include `acronym`, `camel`, `constant`, `darwin`, `delimited`, `dot`, `kebab`, `lower`, `lowerleading`, `pascal`, `reverse`, `snake`, `title`, `upper`, `upperleading`, `trim`. Use `rntocase <subcommand> --help` to confirm custom flags rather than assuming the same options everywhere. Normal renaming acts on the filename's stem, preserving ordinary and recognized compound extensions (e.g. `.tar.gz`). Dotfile behavior should be previewed explicitly.

## Structured recursive previews

```sh
rntocase snake --dry-run --json --recursive ./assets
rntocase kebab --dry-run -R --include '*.jpg' --exclude '.git/**' ./photos
```

`-R`/`--recursive` deliberately opts into traversal. Doublestar include/exclude globs are relative to supplied directory roots; exclusions win. Recursive mode visits regular files only, not directory renames, symlink targets or symlink directories. Do not infer POSIX regexp semantics from these globs.

A robust agent workflow is **discover → dry-run → inspect proposed renames → request/confirm permission → apply → inspect filesystem**. `--json` makes the preview suitable for comparison or a scripted review. A successful dry-run does not authorize writes; do not run `--interactive` in an automated/headless session.

## Before applying

1. Check for duplicates, collisions with existing destination files, case-insensitive filesystem collisions, extension surprises and paths with spaces. The CLI preflights the full discovered batch before starting.
2. On a repository checkout, inspect `git status --short` to detect unrelated changes and compare intended diffs.
3. Only after approval, repeat the same command without `--dry-run` (and usually without `--json` unless machine-readable results are needed).
4. There is no built-in undo. An unexpected failure midway through execution can leave a **partial batch** despite successful preflight; re-list actual paths and do not blindly retry or assume rollback.
5. Never rename a user's real photo collection or source checkout merely to test the skill. Reproduce in a temporary synthetic directory under `/tmp`.

## When developing rntocase

The source already embeds a `rntocase` skill. Prefer improving that canonical content upstream rather than indefinitely maintaining a divergent one. Validate full generated CLI/help and regressions for recursive traversal, `--json`, collision preflight, compound extensions and partial failures with the repository's tests.

**Report:** source paths, chosen case command, dry-run/JSON results, authorization before applying, final renames and any partial failures.

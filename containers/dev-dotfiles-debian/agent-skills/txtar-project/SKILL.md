---
name: txtar-project
description: Use when developing or invoking arran4/txtar's extended CLI for creating, editing, listing or extracting TXTAR fixture archives; distinguish it from golang.org/x/exp/cmd/txtar.
---
# Arran's TXTAR editor and archive CLI

**Source:** https://github.com/arran4/txtar. The module currently declares `module txtar` and builds a CLI under `cmd/txtar`; do **not** infer that the README's example `github.com/username/txtar` Go install path is valid.

## Do not confuse the two tools
The upstream Go experimental `golang.org/x/exp/cmd/txtar` uses `txtar --list` / `--extract` reading stdin. Arran's own CLI has **subcommands** `create`, `list`, `extract`, `add`, `append`, `delete`, `cat`, `comment`, `description`. Both might install an executable called `txtar`; use `txtar help` or compile to a separate explicit path before relying on syntax. Review dotfiles #510 before any global install to avoid clobbering the other binary.

## Workflow
1. Start by identifying which executable/version and source repository is under test. In the checked-out source, use `go run ./cmd/txtar help`.
2. Prefer `txtar list <archive>` and `txtar cat <archive> <path>` (verify flags/help) to inspect contents without writing.
3. For create/edit workflows, work on a **copy** under /tmp and inspect diff before overwriting an archive. Use the CLI's explicit `create`, `add`, `append`, `delete`, `comment` actions only after verifying current syntax.
4. For extraction, list/validate all destination paths, prevent parent-directory and absolute-path traversal and reject unintended symlink resolution. Extract into a fresh isolated /tmp directory, not a repo root or home.
5. Keep leading TXTAR comment, marker lines (`-- path --`), ordering and exact text where format tests depend on them. TXTAR is not binary tar/zip and does not encode arbitrary POSIX modes.
6. When developing this repo, generated `cmd/txtar/*.go` files are owned by `gosubc`; change definition source then regenerate using the project's invocation. Test round-trip, comments, relative paths and no-write failure paths.
7. Record Go toolchain version from `go.mod`, tests actually executed and any missing build dependencies; do not assert a README's installation path is working without compiling it.

## Output
Provide original archive and requested operation, exact command run, file-level diff, contents after operation and regression tests. Never confuse this CLI with the pinned upstream binary in dotfiles #510.

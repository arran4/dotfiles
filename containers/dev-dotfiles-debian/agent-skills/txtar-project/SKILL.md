---
name: txtar-project
description: Use arran4/txtar's extended text archive CLI to inspect, create, modify, list, extract, append and delete named fixture files. This CLI differs from golang.org/x/exp/cmd/txtar; detect the installed executable before choosing syntax.
---
# txtar — full-featured TXTAR archive CLI

**Source:** https://github.com/arran4/txtar. Its Go module currently declares `module txtar` and `go 1.25.3`; the README's `github.com/username/txtar` install example is a placeholder, **not an installable canonical module path**. In the checked-out project use `go run ./cmd/txtar help`; do not install an arbitrary latest version into a shared container.

## Distinguish the executable first

Two different CLIs can occupy the name `txtar`:

- This project: **subcommands** `txtar create`, `list`, `extract`, `cat`, `add`, `append`, `delete`, `comment`, `description`.
- Go experimental `golang.org/x/exp/cmd/txtar`: **flag mode** `txtar --list < archive.txtar`, `txtar --extract < archive.txtar`. Dotfiles PR #510 currently proposes that version under the same executable name.

Start with `command -v txtar` and `txtar help`. If ambiguous, run the checked-out project with `go run ./cmd/txtar` or a separately named binary. Do not pass the experimental CLI's stdin/flag syntax to this tool. Do not assume the Debian container's older Go compiler can build this project.

## Task → command examples

```sh
# Look without changing files
txtar list tests/case.txtar
txtar cat tests/case.txtar
txtar cat -t tests/case.txtar input/main.go

# Create from a file tree; the archive bytes go to stdout
txtar create -r testdata/synthetic > /tmp/case.txtar

# Extract into a fresh isolated directory, not a source checkout
mkdir -p /tmp/txtar-extracted
txtar extract -d /tmp/txtar-extracted /tmp/case.txtar

# Work on a copy of an existing archive
cp tests/case.txtar /tmp/case-edit.txtar
txtar add /tmp/case-edit.txtar /tmp/new-file.txt
txtar delete /tmp/case-edit.txtar old-name.txt
txtar comment --comment 'Regression for missing provider' /tmp/case-edit.txtar
txtar description --replace /tmp/case-edit.txtar 'Updated explanatory text'
```

Check `txtar help <command>` against the installed version for argument order and exact archive member path semantics. **Flags precede positional arguments** in the generated subcommand parser. `cat` without `-t` displays the archive; `cat -t` extracts contained file text. `create` supports `--recursive`/`-r`, `--trim`, `--name`, `--depth` and optional `--follow` symlink traversal. `extract` supports `--dir`/`-d` and `--verbose`. `add`/`append`/ `delete` mutate the named archive; `comment` and `description` edit different metadata surfaces—confirm actual effect before overwriting.

## Safety and regression tests

1. Treat archive member paths as untrusted: reject absolute/parent-traversal members, variable expansion and symlink escapes. Inspect `txtar list` and extract only into a fresh temporary root.
2. Do not enable `--follow` merely to populate a TXTAR: following symlinks can bring unrelated or private files into a fixture. Preserve archive text markers (`-- file --`), ordering, leading comments and test-relevant newlines when round-tripping.
3. Editing an archive can change golden outputs. Compare source versus result with `git diff --no-index` or a copy; then run the **consumer's** TXTAR regression harness. Format-level round trips alone do not prove application behavior.
4. This repository uses `gosubc` to generate `cmd/txtar/*.go`. Change source CLI definitions and regenerate rather than hand editing generated command files.
5. For txtar itself, exercise its unit/CLI tests (`go test ./...`) and focused TXTAR fixtures for create, extract, list, comment and failure behavior; report toolchain and runtime limitations.

**Result:** identify which TXTAR executable was used, exact command/version, input archive paths, changes, relevant regression tests and any overlap with dotfiles #510.

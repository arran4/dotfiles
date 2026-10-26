---
name: arran-txtar
description: Use when inspecting, creating, editing, extracting, or debugging Go TXTAR regression fixtures (.txt or .txtar archives with -- filename -- markers). Prefer the installed txtar CLI and isolated tests rather than ad hoc parsers. Not for binary archive formats.
---

# TXTAR regression fixtures

TXTAR is a human-editable, diffable collection of text files, commonly used as Go multi-file regression input. Its file markers are `-- relative/path --` on their own lines. The file extension alone does not identify a TXTAR.

## Inspect first

1. Determine whether the supplied text uses TXTAR file markers and preserve any leading comment/preamble.
2. Confirm the CLI exists with `command -v txtar`; if absent, report the missing prerequisite instead of quietly inventing a parser.
3. List embedded files without writing anything: `txtar --list < path/to/fixture.txt`.
4. Read the source archive and inspect paths. Never trust an archive supplied by an untrusted source.

## Edit safely

1. Create a new empty directory under `/tmp` for extraction. `txtar --extract` writes and overwrites files; **never extract into a source checkout or home** unless the user expressly asks for it.
2. Avoid `--unsafe` entirely. Reject absolute or parent-traversal paths, embedded environment-variable expansions, and symlinks in the extraction destination. The CLI's default path checks do not replace filesystem isolation.
3. Use `txtar --extract < fixture.txt` from inside the temporary extraction directory. Capture the archive's leading comment from standard output.
4. Make focused edits to files and/or comment. Repackage with `txtar relative/files... < comment.txt > revised.txt`. The create command reads its comment from stdin; use `/dev/null` for no comment to avoid interactive blocking.
5. Compare the original and generated archive (including ordering, comments, marker spelling, final newlines) and explain any intentional normalization. Avoid adding binary content, modes or symlinks to TXTAR.
6. Run the repository's actual regression tests that consume the TXTAR fixture, preferably in isolated build/workspace conditions. Do not claim a format-level round trip proves application behaviour.

## CI and diagnostics

- In the Debian container, use `/usr/local/bin/dev-dotfiles-test-txtar` for a smoke test of installed CLI behaviour.
- When malformed or adversarial inputs are being tested, preserve the source TXTAR exactly and keep separate expected-output fixtures; don't silently normalize the regression case.
- For generated fixtures, modify the generator rather than repeatedly patching generated archives.

## Output

Identify changed fixture paths, reason for changes, commands/tests actually run, and any unsupported assumptions or security issues. Do not use `--unsafe` or override a failing extraction check.

---
name: g2-overlay
description: Use when running arran4/g2 for Gentoo overlay maintenance, manifests, ebuild QA, metadata, package indexing or static overlay sites; consult real CLI help and avoid unsafe Manifest reconciliation.
---
# Operate g2 on Gentoo overlays

**Source:** https://github.com/arran4/g2 ; current executable is `g2` and source invocation is `go run ./cmd/g2` when modifying g2 itself. Check `g2 help` and the canonical `doc/g2.1.md` before relying on examples. The upstream embedded skill is outdated and lacks YAML frontmatter.

## Workflows
- Inspect an ebuild first with `g2 ebuild explain <file>`, `g2 ebuild check <file>`, and `g2 ebuild deps <file>` where applicable. Distinguish structural checks from a real Gentoo/Portage build.
- Verify repository Manifest entries with `g2 manifest verify .`. `g2 manifest verify --fix` and `--clean` can write; only use them after reviewing the affected paths and complete source resolution. Missing or unresolved distfiles must stop destructive cleanup, not remove arbitrary entries.
- For manual distfiles `g2 manifest upsert-from-url <url> <filename> <manifestFileOrDir>` writes checksums; verify authoritative URL and distfile version before invoking.
- For site changes use `g2 overlay site generate -out <dir> .` and serve with `g2 site serve -port 8080 .`. Browser verification should use localhost HTTP; `file://` does not resolve directory indexes equivalently.
- For source changes, `go run ./cmd/g2 ...` is preferred over building an ad-hoc g2 binary. Verify `g2 lint` and `g2 dev` command availability against the checked-out CLI, not old documentation.
- Avoid TUI-only operations such as interactive world browsing in headless sessions.

## Repository-specific invariants
1. `arrans_overlay/current.config` governs builder-owned ebuilds; g2 does not override the generator source-of-truth. Do not directly modify generated ebuilds to compensate for workflow-builder bugs.
2. G2's site templates must remain overlay-agnostic. Keep `GenericPageContext` in sync between site server and static generator; do not hardcode Gentoo GitHub URLs into reusable templates.
3. When adding/changing g2 CLI commands, update `readme.md` and maintained man-page source `doc/g2.1.md`; do not commit generated md2man output.
4. Anonymize person and email fixtures. Use `testdata/` and report no-network/offline limitations.

## Completion
List exact CLI help consulted, commands executed, paths changed, before/after Manifest evidence, and whether testing was merely structural or a real Portage environment build.

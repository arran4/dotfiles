---
name: g2-overlay
description: Operate arran4/g2's real Gentoo overlay CLI for ebuild parsing/maintenance, repository and changed-package linting, Manifest/cache verification, USE flags, package search, site generation, masks and pipelines. Choose the smallest appropriate command.
---
# g2 — Gentoo overlay operations

**Purpose:** prefer a narrow, verifiable `g2` command over reimplementing Portage metadata inspection with shell, grep, or ad hoc scripts. Source: https://github.com/arran4/g2; command reference: `g2 help`, maintained `doc/g2.1.md` and `readme.md`. g2 changes rapidly: inspect the installed version's help.

## Task → concrete CLI

| Need | Typical command | Side effects |
| --- | --- | --- |
| What lint checks are available? | `g2 lint list` or `g2 lint list -format json` | Read only |
| Lint an entire overlay | `g2 lint repo .` | Read only |
| Lint a named ebuild package | `g2 lint package . app-misc/foo` | Read only |
| Lint matching package atoms | `g2 lint query . '>=app-misc/foo-1.0'` | Read only |
| Lint packages changed in Git | `g2 lint changed --base origin/main .` | Read only |
| Inspect a single ebuild | `g2 ebuild explain pkg.ebuild`; `g2 ebuild as-json pkg.ebuild` | Read only |
| Check a single ebuild | `g2 ebuild check pkg.ebuild` | Read only; narrower than full lint |
| Extract dependency or field data | `g2 ebuild deps pkg.ebuild`; `g2 ebuild query pkg.ebuild --key SRC_URI --format lines` | Read only |
| Verify a Manifest | `g2 manifest verify .` | Read only without fix/clean |
| Determine next revision filename | `g2 ebuild next-revision <ebuildDir> <version>` | Read only |
| Inspect generated md5-cache | `g2 cache verify --mode=ci` | Read only; may report skipped master checks |
| Inspect mask/unmask rules | `g2 masks audit --format json` | Read only |
| Preview an overlay website | `g2 overlay site generate -out /tmp/g2-site .`; `g2 site serve -port 8080 /tmp/g2-site` | Writes only output dir; localhost server |

When CLI help disagrees with this table, prefer the current CLI. In the g2 source checkout, invoke `go run ./cmd/g2 ...` as its AGENTS.md requests.

## Linting is a first-class engine

`g2 lint` is **not merely** the structural `g2 ebuild check` shortcut. Its registered checks cover ebuilds, eclasses, metadata, md5-cache, news and profiles, plus optional layout checks; `pkgcheck` is an additional source when available. Prefer:

```sh
g2 lint list -format json
g2 lint changed --base origin/main -format github-actions .
g2 lint repo -format json -fail-severity error .
g2 lint package -only-source g2 . app-misc/foo
g2 lint -enable-layout-lint -upstream-repo-path /path/to/gentoo .
```

`-severity` controls displayed severity, whereas `-fail-severity` controls the failure threshold (default warning). `-only-source`, `-only-tag`, `-disable-rule` and `-ignore-tag` help investigate noise; do not suppress rules to obtain a green CI without documenting why. The Git-changed lint includes working-tree, index and untracked packages and diffs commits against explicit `--base` or upstream; no upstream means local changes only. Read `g2 lint changed --help` before choosing refs. Layout checking may need explicit upstream data and must not silently require online API calls.

## Verify first; repair only with permission

```sh
g2 manifest verify .
g2 cache verify --mode=ci
g2 pkg-desc-index verify .
```

`--mode=ci` cache verification can **skip** checks when masters/eclasses are unavailable; skipped is not verified. For complete checks provide the necessary `--master-repo`/repository configuration or use `g2 cache verify --mode=strict` on a configured Gentoo system. Cache generation can require actual Portage evaluation of dynamic metadata; the parser must not pretend it evaluated shell/eclass functions.

Commands that **mutate** include `g2 manifest verify --fix`, `--clean`, `g2 cache generate/reconcile/clean`, `g2 pkg-desc-index generate`, `g2 use discover`, `g2 overlay ebuild install`, `g2 metadata`, `g2 masks mask/unmask/reset` and `g2 ebuild init`. Check `git status`, upstream sources, current.config ownership and authorization before running. Do not clean a Manifest when DIST resolution is incomplete; g2's conservative behavior is itself part of the contract. Use `g2 manifest upsert-from-url <URL> <distfile> <Manifest-or-directory>` only for confirmed artifacts.

## Other genuinely useful operations

- `g2 package search` and `g2 package index-overlay` are for discovery/indexing; check their subcommand help instead of parsing all ebuild files manually.
- `g2 masks audit` distinguishes required, redundant/shadowed and indeterminate unmask entries; **re-audit after each manual removal** rather than deleting every flagged rule at once.
- `g2 use desc-list`/`local-desc-list` inspect USE descriptions; edits require explicit approval.
- `g2 pipeline '...'` supports `get(url)`, JSON/XML/RSS/Atom extraction, XPath, regex, links, `first`/`last` and strict `single` cardinality; use `-s KEY=value` substitution for a reusable upstream release extraction. Validate `single` to reject missing/ambiguous results, never silently pick the first release.
- Static-site output from `g2 overlay site generate` can be verified with `g2 site serve` over localhost; `file://` directory browsing is not equivalent.

## Result

For each operation report command/version, overlay root, affected package/atom, lint findings or skipped master context, any files changed and the actual verification level (structural g2 check, full g2 lint, Portage metadata evaluation, or real package build). Repository-specific rules belong in its `AGENTS.md`.

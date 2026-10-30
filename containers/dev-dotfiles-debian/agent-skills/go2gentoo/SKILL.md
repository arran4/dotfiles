---
name: go2gentoo
description: Use when generating Gentoo overlays from Go modules using arran4/go2gentoo, and testing its in-process GOPROXY/MVS resolver and reproducible module archives.
---
# go2gentoo: pure-Go overlay generation

**Source:** https://github.com/arran4/go2gentoo ; check AGENTS.md/readme.md and actual CLI help. Binary name: `go2gentoo-overlay`.

## Generation
- Initialize a new configuration with `go2gentoo-overlay init -project <name> -o <configdir>`.
- Generate an **entirely new** overlay with `go2gentoo-overlay generate -config <configdir> -o <empty-output-dir>`; use an empty /tmp directory for dogfood rather than mutating an installed overlay.
- Config may pin projects by `Tag` in `go-projects.csv`. Confirm Go module path and version are not confused with provider repository URL; use GOPROXY for ordinary public modules.

## Hard invariants
1. **Production resolver and generator are in-process Go.** Do not call external `go`, `git`, `gh`, `curl` or provider CLIs from production module resolution. External tools may serve as test oracles in isolated tests only.
2. Preserve canonical proxy artifacts `.info`, `.mod`, `.zip`; never silently rebuild archives from GitHub tarballs.
3. Apply Minimal Version Selection and graph pruning, including root module `replace` and `exclude`; dependency module replace directives do not apply as though they were roots.
4. Respect `GOPROXY`, `GOPRIVATE`, `GONOPROXY`, `GONOSUMDB`, `GOSUMDB`; raw commits outside supported proxy resolution must report unsupported rather than secretly invoking git.
5. Avoid modifying normal caller Go module caches. Keep separate module-cache and fixture transport under /tmp.
6. Test output with offline Portage install/build and canonical module checksum verification. A generated ebuild tree is not equivalent to tested installation.

## Completion
Include Go/module versions, graph decisions, source proxy, checksum policy, generated overlay path, offline build results and actual tests. Never claim an untested generated overlay is release-ready.

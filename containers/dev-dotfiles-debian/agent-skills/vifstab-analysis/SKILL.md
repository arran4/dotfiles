---
name: vifstab-analysis
description: Use when inspecting fstab or boot/block-device validation with arran4/vifstab; preserve unknown-versus-false distinctions and avoid modifying live mounts or firmware state.
---
# vifstab safe validation

**Source:** https://github.com/arran4/vifstab ; check CLI help and AGENTS.md for current features before invoking commands on a live system.

## Principles
1. Default to **read-only**, synthetic fixtures or copied `/etc/fstab` under /tmp when investigating a parser, editor, diagram, UEFI or validation rule. Never write a real host fstab, reload mounts or edit UEFI variables without a specific authorization and rollback plan.
2. The live-system API is `internal/rules/api.go` (`rules.API`, `rules.ActualFS`, `OSProvider`, `BlockDeviceInventory` and its `Resolve` method). Reuse this abstraction rather than hard-coding probes in the CLI.
3. For validation, put reusable policy in `internal/rules` and rule families (`builtin`, `core`, `kernel`, `options`); keep `internal/editor`, `internal/format`, `internal/diagram`, `internal/uefi`, `internal/systemd`, `internal/rcs` responsible for their existing domains.
4. **Unknown is not false**. Permission-denied block information, unreadable efivars, unmounted filesystems and incomplete inventory remain unknown/unavailable, not definite absence. Output should retain provenance and diagnostics.
5. Do not turn read-only inspection into direct block-device reads or filesystem mounts unless the feature explicitly supports it and the user requested it. No implicit privilege escalation.
6. For kernel option changes (such as ext4 mount options), verify behavior against the *target kernel* source and documentation, and distinguish deprecated, ignored, invalid and removed.
7. When adding a rule, use synthetic/injected testdata, including TXTAR diagrams under `cmd/vifstab/testdata/diagram`, plus focused negative/unknown cases.

## Acceptance
Report input source and kernel version, rules evaluated, proved mismatches versus unknowns, tests and any operation that would mutate system state. Always propose a safe manual confirmation path before real repairs.

---
name: overlay-workflow-builder
description: Use when authoring or debugging arran4/arrans_overlay_workflow_builder configs, generated GitHub Actions and generated Gentoo ebuilds; distinguishes source current.config from output and validates complete TXTAR snapshots.
---
# Overlay workflow builder

**Source:** https://github.com/arran4/arrans_overlay_workflow_builder and consuming overlay https://github.com/arran4/arrans_overlay. Read each AGENTS.md and verify actual command syntax with CLI help; the README may lag current implementation.

## Source-to-output contract
- In arrans_overlay, `current.config` is authoritative for builder-managed packages. Generated workflow YAML, generated ebuild and Manifest are outputs: don't hand-patch them as the permanent fix.
- Configuration distinguishes GitHub binary/AppImage releases and non-GitHub Web Binary sources. For Web Binary, require `TagsCommand`; `DownloadBaseUrl` constructs the source URL. Avoid assuming GitHub release APIs exist for every source.
- Inspect configurations for Category, EbuildName, upstream URL, architecture-specific Binary/Document mappings, dependencies, license, and semantic/prerelease workarounds before generation.
- Workarounds are not general string-substitutions; verify the intended version mapping against concrete release names and output artifacts.
- Running a preview/dry-run must not touch published ebuilds, destination workflows, or existing user data, even temporarily. Use a disposable output directory under /tmp for comparison. Never assume partial-write transactionality exists until the relevant implementation and tests prove it.
- Regeneration is followed by a precise diff review of emitted `uses:` action versions, schedules, paths, binary names, and ebuild content. Validate action-major versions against upstream when network is available.

## Tests
1. Every template and workaround needs at least one end-to-end `.txtar` scenario with a **complete** `expected.yaml`, not a fragment or a single assertion.
2. For one-off parsing/helper conditions use focused unit tests and fixtures under `testdata/`, not oversized TXTAR snapshots.
3. Inject unstable timestamps and cron values into fixtures. For a rollback/error-path case, make failure occur *after* earlier output and verify unchanged pre-existing files, not just nonzero exit status.
4. Confirm the consumer's g2 compatibility for generated metadata and manifests in a real supporting environment when required; do not pretend Debian package checks validate Portage.

## Completion
Report config origin, generator invocation, exact changed generated outputs, TXTAR cases and test results, and any unverified publication risks. Do not run scheduled release workflows or write to the consuming overlay without the user's instruction.

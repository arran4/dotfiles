---
name: flutter4gentoo
description: Use when generating, previewing or updating Gentoo overlays for Flutter Linux apps with arran4/flutter4gentoo; handle pinned g2, transactional updates and distinct generation vs Portage acceptance.
---
# flutter4gentoo overlay generation

**Source:** https://github.com/arran4/flutter4gentoo; read README and current `flutter4gentoo generate --help`/`update --help` before changes.

## Toolchain contract
- The generator runs as a native Linux executable, with no Flutter SDK needed; source development needs Dart >=3.11.0 <4.0.0.
- The native generator currently depends on **g2 v0.0.103** available on PATH even without `--verify`; check the release's pinned checksum rather than blindly installing latest.
- Generation resolves Flutter SDK/engine and app/pub revisions and uses network access; generated ebuilds must be validated separately in Gentoo. Generator arm64 support does *not* imply application ebuild support for arm64: current engine artifacts target Linux x64.

## Safe workflow
1. `flutter4gentoo init --config-dir config` creates example YAML only in a new/empty directory; replace the placeholder upstream before generating.
2. `flutter4gentoo generate --config-dir config --output-dir /tmp/new-overlay --dry-run` validates *local YAML only*, not upstream, network availability, versions or Gentoo buildability.
3. `flutter4gentoo generate --config-dir config --output-dir /tmp/new-overlay --verify` creates an overlay in an empty destination; generation failure may leave partial files. Do not reuse failed partial output without inspection.
4. `flutter4gentoo update --config-dir config --output-dir /tmp/overlay --verify` stages generation in sibling paths, preserves nonowned files, removes obsolete generated files and rolls back on failure. Keep `.flutter4gentoo_index.json` as ownership metadata; never assume all files are owned by the generator.
5. In containerized update tests, mount the **parent** destination and update a child path; a bind-mounted target cannot be replaced by the staging rename. Run as the host's UID/GID with pre-created writable directories; avoid privileged mode and recursive host chown.
6. Verify generated manifests, g2 cache/lint and actual Gentoo package compilation separately. CI-only Flutter SDK ebuild is not a supported system installation; review upstream issues #7 and #22 before claiming production package readiness.
7. For source development run `dart pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, `dart test` and `bash tool/build_native.sh` when relevant. Pin SDK version and check generated `testdata/golden.ebuild` diffs.

## Completion
Report generator version, g2 version, config source, revisions resolved, dry-run versus generate/update outcome, ownership/transaction behavior, g2 checks and any real Gentoo build evidence. Do not call YAML-only preview an end-to-end validation.

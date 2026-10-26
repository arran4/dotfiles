---
name: arran-flutter-migration
description: Plan and validate Flutter/Dart SDK migrations, generated ebuilds and Flutter web or desktop build compatibility; use when upgrading Flutter versions or dependent plugins and toolchains.
---

# Flutter/Dart migration validation

1. Record current Flutter channel/commit, Dart version, package constraints and target platforms. Determine whether the repository pins Flutter, Dart or both and whether generated output comes from a separate generator.
2. Compare proposed SDK changes with actual upstream compatibility requirements and breaking changes. Use authoritative release notes where network access is available.
3. Prefer a clean isolated SDK/cache per revision. Avoid polluting successive generator runs with reused caches or cross-version `pub` state.
4. Run `flutter doctor -v`, `flutter pub get`, `dart analyze`, and relevant unit/widget tests; build affected targets when suitable toolchains are available. Note unsupported host platforms.
5. For generated Gentoo ebuilds, test the exact Dart/Flutter revision and check manifests, sources and dependencies in a Gentoo/Portage environment.
6. For UI changes, add browser-level verification if the app can be run headlessly; tests must assert meaningful behaviour rather than screenshots alone.
7. Report changes required in SDK pin, dependencies, generated files and CI. Separate toolchain breakage from project regressions; do not mark migration complete on analysis alone.

Keep CI generic and update the generator, not just generated output.

---
name: arran-generated-code
description: Verify generator-owned source files, regenerated output and reproducibility; use for generated workflows, ebuilds, Dart SDK metadata, manifests or code where direct edits will be overwritten.
---

# Generated-code maintenance

1. Identify which files are source, generator implementation, templates and generated output. Search repository README, AGENTS.md and CI definitions before changing anything.
2. Reproduce generation in a clean isolated workspace. Record toolchain versions, upstream revision, inputs, arguments, locale and environment. Do not silently fetch unpinned resources.
3. Capture the first output, run generation again from equivalent clean inputs, and compare bytes. Check that a successive run in the same workspace also remains deterministic, to expose stale caches and contamination.
4. Fix defects at the generator/template/source level rather than applying an ephemeral patch to produced files.
5. Validate output semantics, not just textual stability: run actionlint on generated workflows, package checks on generated ebuilds, or language-specific compilation as appropriate.
6. Check file-path filters so generated ebuilds, manifests, workflow files and their templates trigger the correct generic CI. Never add issue-specific workflow names merely to validate an individual fix.
7. Separate modifications from unavoidable environment differences. If upstream sources or credentials are unavailable, explain what could not be reproduced.

## Report
List generator source, invocation, input version, generated artifacts, first/second run diff, validation commands and any remaining drift.

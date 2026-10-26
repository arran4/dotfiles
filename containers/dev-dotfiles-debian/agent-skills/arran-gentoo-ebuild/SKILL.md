---
name: arran-gentoo-ebuild
description: Review or repair Gentoo overlay ebuilds, manifests, generated ebuild files, Portage metadata, and reproducible generator workflows; use for arrans_overlay or ebuild QA tasks.
---

# Gentoo overlay QA

## Procedure
1. Identify the overlay package category, ebuild revision, manifest, eclasses, upstream distfiles, generated sources, and the repository's governing AGENTS.md.
2. Distinguish generator-owned files from hand-authored files. For generated output, fix the generator and verify deterministic regeneration on a clean checkout twice.
3. Use an actual Gentoo/Portage environment (a pinned Gentoo container or VM) rather than assuming Debian `apt` can validate ebuild semantics. Record Portage/eclass versions and configured repositories.
4. Run `pkgcheck scan` and `pkgdev manifest` or equivalent supported checks. Validate metadata, SLOT, KEYWORDS, LICENSE, REQUIRED_USE, USE flags, dependency atoms, EAPI, SRC_URI and distfile digests where applicable.
5. Validate install phase and relevant build/compile smoke test in Gentoo. Distinguish upstream failures, missing keywords, stale tarballs and generator defects.
6. Avoid editing manifests alone if a generator or distfile change is the real cause. Ensure CI checks are generic and path-scoped where appropriate.
7. Report exact Gentoo environment, commands, checked package versions, deviations, and blocked tests.

## Output
- Specific ebuild defects and fixes.
- Generated/hand-authored boundaries, QA evidence, and PR readiness.

Do not mark a package build as verified if only syntax or metadata checks were run.

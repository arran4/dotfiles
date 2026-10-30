---
name: arran-release-safety
description: Use when reviewing or changing Arran's GitHub Actions/GoReleaser releases, manual version tags, GHCR image aliases or published artifacts; preserve release safety, stable-tag monotonicity and one-owner publishing.
---
# Release-safe Go and GHCR workflows

**Reference implementation:** https://github.com/arran4/dotfiles with `.github/workflows/ci.yml`, `.github/scripts/release_aliases.sh`, `.github/scripts/test_release_safety.sh`. The pattern also applies to Go projects using GoReleaser, but always inspect their actual release pipeline before transferring assumptions.

## Establish the mode
1. Identify trigger (`pull_request`, `push` on main, test tag, stable version tag, prerelease or manual dispatch), source ref, workflow run and target version. Different modes must not silently publish as a side effect.
2. A green PR image build is not evidence that any version tag, GitHub release, GHCR image or Homebrew package was published. Confirm the actual release job and resulting artifact URL.
3. Do not bypass ShellCheck, secret scan or project-required verification to force a release. Distinguish real test failures, quota-blocked jobs and skipped jobs.

## Safe tagging and image publication
- Tags must be derived from the intended ref, not an untrusted/default version string. Avoid duplicate version jobs and races between release modes.
- Publish only once from the designated release owner/job; serialise version/tag publication. Do not cancel a release already publishing in order to start a newer run.
- GHCR stable aliases (`latest`, `vX`, `vX.Y`) move only for the **newest applicable stable version**, never backwards when an older patch or minor version is published after a newer one.
- Prerelease and test tags must never advance the stable aliases. Parse remote tags carefully, ignore annotated dereference entries, and fail closed on missing/invalid remote tag listings.
- A Docker build must use the same canonical Dockerfile as the published image, unless the repo explicitly defines separate artifacts. Do not infer a changed `:latest` from a merged commit.

## Verify before recommending publish
- Run the repository's release-safety test, e.g. `bash .github/scripts/test_release_safety.sh` where present. This exercises alias ordering, invalid ref handling and workflow job relationships **offline**.
- Validate workflow YAML and any generation source using available actionlint plus the repo's own tests. For a generated workflow, change the generator and regenerate, not just YAML.
- Run `goreleaser check` or the repository's pinned alternative if installed, and inspect resulting archives/checksums on a test tag. Never install a new release tool version without checking project policy.
- Inspect real post-publication release URLs, downloadable artifacts and install instructions. A successful workflow dispatch is not itself a successful release.

## Report
State exact branch/tag, checked head SHA, workflow run links, release version, artifacts tested, monotonically moving aliases, and which checks were actually run. Leave PRs draft when release safety cannot be verified; never trigger a release merely to test a draft skill.

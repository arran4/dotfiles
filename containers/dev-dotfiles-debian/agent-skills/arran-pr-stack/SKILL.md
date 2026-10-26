---
name: arran-pr-stack
description: Plan, create, restack, or review dependent GitHub pull requests; use when there are multiple related changes that must remain independently reviewable and must not overwrite another agent's commits.
---

# Safe stacked PRs

## Procedure
1. Map each issue to the smallest coherent functional change; avoid doc-only PRs without a distinct need. Prefer one issue per PR, except where one functional change legitimately resolves multiple issues.
2. For each PR record: source branch, target branch, base/head SHA, associated issue, expected files, and required predecessor.
3. Before editing, fetch remotes and verify branch ownership and current head. Never assume an earlier head SHA is still current.
4. Create commits with appropriate tests and issue-closing keywords such as `Fixes #123` only when they truly resolve the referenced issue.
5. Preserve clean ancestry with `git merge-base`, `git log --graph`, `git range-diff`, and `git rev-list`. Prefer safe fast-forward updates; if history rewriting is necessary, explain the impact and require explicit permission for branches owned by another agent.
6. Ensure each PR's diff includes only its intended logical change. After predecessor merges, retarget/restack remaining PRs and verify no commits vanished.
7. Verify relevant tests and CI on actual heads. Record whether checks are pending, failed, skipped or unavailable due to quota.
8. Keep unfinished PRs draft; mark ready only once implementation and required validation are complete or when user explicitly instructs it.

## Output
- Dependency diagram and PR URLs.
- Branch/SHA ledger, tests run, merge sequence, and any required manual actions.

Do not merge without instruction. Do not silently push to a Jules/Codex session branch that may be rewritten.

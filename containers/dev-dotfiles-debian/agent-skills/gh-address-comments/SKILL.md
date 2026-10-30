---
name: gh-address-comments
description: Retrieve and address review threads and issue comments on the current GitHub PR with the bundled Python and gh helpers. Use for actionable review work, including fork PRs.
metadata:
  short-description: Address GitHub PR review comments
---

# Address PR review comments

**Executable:** `scripts/fetch_comments.py` queries GitHub with `gh api graphql` and emits JSON (conversation comments, review summaries and review threads). It resolves the **base repository** and PR number from `gh pr view --json number,url`, including fork PRs. This is a locally adapted version of the upstream `gh-address-comments` skill.

## Invoke

1. Check `gh auth status` and `gh pr view --json number,url` from the current repository. If authentication or API access is missing, report that limitation instead of repeatedly attempting a login.
2. From the installed skill's directory, run `python3 scripts/fetch_comments.py`. If keeping the output for inspection, redirect it to a temporary JSON file under `/tmp`; avoid printing secrets or private review content into shared logs.
3. Focus on `review_threads` with `isResolved=false`; use `isOutdated` and comment dates to identify obsolete observations. Include actionable top-level comments and change-request reviews, not just inline threads.
4. For every current, clear request, locate the target code, implement the smallest appropriate fix, run relevant tests and report which thread/comment was addressed. Do not prompt the user to select numbered comments when they asked to address the whole review.
5. Ask the user only when a comment represents an unresolved design trade-off, incompatible requirements, absent authorization or an ambiguous requested behavior. Cite the specific PR comment/thread in the question.
6. Push changes to the existing PR branch when authorized to work on it; recheck CI and the review after the push. Resolve review threads **only after** verifying the correction, and never mark another reviewer's request as resolved merely to clean the UI.

## Notes and limits

- The helper requires the PR associated with the current checkout. It does not accept an arbitrary PR URL; use the target branch checkout or query GitHub manually when working across repos.
- GraphQL paginates top-level comments, reviews and threads; individual thread comments are currently limited to their first 100.
- Fork-based PRs are queried under their **base repository**, not the contributor's fork.
- Respect the agent's actual network/security permissions; Codex-only `sandbox_permissions` flags from upstream do not apply universally to agy.
- If GitHub reports missing scopes, point to `gh auth login` or `gh auth refresh` but do not assume an interactive login is possible in an agent container.

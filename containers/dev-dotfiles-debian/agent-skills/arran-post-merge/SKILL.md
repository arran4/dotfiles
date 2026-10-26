---
name: arran-post-merge
description: Review a repository immediately after merging a PR, reconcile related issues and PRs, identify genuine follow-up work, and produce one ready-to-paste next Jules prompt.
---

# Post-merge reconciliation

## Procedure
1. Confirm the merged PR number, merge SHA, effective default branch, and files actually merged. Read linked issues, dependent PRs, recent commits and CI on the merged result.
2. Read the repository's AGENTS.md and applicable issue-triage rules; consult https://arran4.github.io/blog/post/2026/044-jules-management/ when relevant.
3. Inspect current open issues and PRs for now-completed work, stale descriptions, duplicated work, blockers, regressions and remaining scope.
4. Separate **administrative reconciliation** (status comments, links, labels, stale text) from **new engineering findings** (observed defects, missing tests, regressions). Do not invent new issues to represent work already covered.
5. Apply safe, factual administrative updates only when authorized. For new issues, require specific evidence, reproduction/acceptance criteria, deduplication and compliance with user gating rules.
6. Prioritize the single highest-value next task, including dependencies and tests.
7. Produce a fully copyable new Jules session prompt linking exact issues and acceptance criteria.

## Output
- For each existing issue/PR worth changing: URL, current status, proposed update, reason, admin versus discovered work.
- Newly warranted issues (or why none).
- One recommended next action and complete Jules prompt.

Do not equate merged status with tests passing; verify post-merge CI independently.

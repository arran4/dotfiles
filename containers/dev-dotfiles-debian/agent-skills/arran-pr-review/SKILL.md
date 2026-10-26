---
name: arran-pr-review
description: Review a GitHub pull request or commit for correctness, regressions, missing tests, and merge readiness; use when asked for a PR review or follow-up commit assessment, not when asked to implement a feature.
---

# Evidence-based GitHub PR review

## Inputs
- PR URL/number (or commit URL) and any user-specified areas of concern.
- Repository review rules from AGENTS.md and project documentation.

## Procedure
1. Use `gh pr view <PR> --json title,body,isDraft,baseRefName,headRefName,headRefOid,mergeStateStatus,url` and `gh pr diff <PR>` to obtain the current head and complete diff. Confirm a referenced commit still exists in the head history.
2. Inspect touched files and relevant callers, dependencies, tests, documentation, generated artifacts, and CI workflow paths. Compare intended behaviour to the base branch; do not merely summarize changed lines.
3. Run focused feasible tests locally. Record exact commands, environment, and exit status. Never infer a test passed from the presence of a workflow.
4. Use `gh pr checks <PR>` and inspect associated run/job logs before assigning causes. Distinguish successful, failing, pending, unavailable, and quota-limited CI.
5. Rank actionable findings by severity. Each finding must give the file/line or precise code path, triggering conditions, observed or reasoned effect, and minimal correction. Clearly label unverified risks as hypotheses.
6. When reviewing a new commit on an existing PR, inspect what changed since the previously reviewed commit and reassess open findings; do not post duplicate feedback.
7. Give a conclusion: ready for review, needs changes, or cannot determine. Draft/undraft only when expressly requested; don't merge without instruction.

## Output
- Findings first (severity, location, reproduction/evidence, proposed fix).
- Tests and CI checked, including limitations.
- Remaining risks and one recommended next action.
- If there are no findings, say so and identify meaningful verification gaps.

Never push to an agent-owned branch to address review feedback without coordination; prefer an actionable PR comment or an explicitly requested patch.

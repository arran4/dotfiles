---
name: arran-ci-diagnostics
description: Investigate failing, skipped, pending, or quota-blocked GitHub Actions checks; use when asked why a workflow failed, whether a fix worked, or how to harden CI.
---

# GitHub Actions diagnostics

## Procedure
1. Identify repository, workflow, run ID, job ID, head SHA, and event trigger. Read `.github/workflows/` and any generated-workflow source before changing a workflow.
2. Inspect `gh run view <id> --json status,conclusion,event,headSha,workflowName,jobs,url` and `gh run view <id> --log-failed`; retrieve job logs via `gh api` when needed. Do not mistake a missing log for a passing test.
3. Classify the failure: code/test, dependency/toolchain, generator drift, workflow configuration, missing permissions, unavailable secrets, runner infrastructure, cancelled job, or billing/quota exhaustion.
4. Find a reproducible local or container test. Keep generated CI generic rather than adding issue-specific workflows; validate YAML with actionlint if available, and inspect least-privilege permissions.
5. For a generator-owned file, fix its source and regenerate output; verify two consecutive generations produce identical results.
6. For quota exhaustion, report that testing was not performed; identify which checks can run locally and which remain unverified. Do not bypass mandatory checks or report success.
7. Re-run or request a rerun only when authorized and worthwhile. Report tested head SHA, checks, log links, and any unresolved environmental limits.

## Output
- Root cause and evidence (with direct run/job links).
- Smallest sustainable fix, plus test commands.
- CI outcome and clear distinction between passed, blocked, and not run.

Avoid pushing directly to branches owned by a separate ongoing agent session without coordination.

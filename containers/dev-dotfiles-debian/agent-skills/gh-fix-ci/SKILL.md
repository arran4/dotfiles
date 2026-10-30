---
name: "gh-fix-ci"
description: "Use when a user asks to debug or fix failing GitHub PR checks that run in GitHub Actions; use `gh` to inspect checks and logs, summarize failure context, draft a fix plan, and implement when the user has requested a fix, otherwise report and propose a plan. Treat external providers (for example Buildkite) as out of scope and report only the details URL."
---


# Gh Pr Checks Plan Fix

## Overview

Use gh to locate failing PR checks, fetch GitHub Actions logs for actionable failures, summarize the failure snippet, then fix actionable defects when the user requested a fix; otherwise report findings and propose a plan.
- If a plan-oriented skill (for example `create-plan`) is available, use it; otherwise draft a concise plan inline and request approval before implementing.

Prereq: authenticate with the standard GitHub CLI once (for example, run `gh auth login`), then confirm with `gh auth status` (repo + workflow scopes are typically required).

## Inputs

- `repo`: path inside the repo (default `.`)
- `pr`: PR number or URL (optional; defaults to current branch PR)
- `gh` authentication for the repo host

## Quick start

- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "<number-or-url>"`
- Add `--json` if you want machine-friendly output for summarization.

## Workflow

1. Verify gh authentication.
   - Run `gh auth status` in the repo.
   - If unauthenticated, ask the user to run `gh auth login` (ensuring repo + workflow scopes) before proceeding.
2. Resolve the PR.
   - Prefer the current branch PR: `gh pr view --json number,url`.
   - If the user provides a PR number or URL, use that directly.
3. Inspect failing checks (GitHub Actions only).
   - Preferred: run the bundled script (handles gh field drift and job-log fallbacks):
     - `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "<number-or-url>"`
     - Add `--json` for machine-friendly output.
   - Manual fallback:
     - `gh pr checks <pr> --json name,state,bucket,link,startedAt,completedAt,workflow`
       - If a field is rejected, rerun with the available fields reported by `gh`.
     - For each failing check, extract the run id from `detailsUrl` and run:
       - `gh run view <run_id> --json name,workflowName,conclusion,status,url,event,headBranch,headSha`
       - `gh run view <run_id> --log`
     - If the run log says it is still in progress, fetch job logs directly:
       - `gh api "/repos/<owner>/<repo>/actions/jobs/<job_id>/logs" > "<path>"`
4. Scope non-GitHub Actions checks.
   - If `detailsUrl` is not a GitHub Actions run, label it as external and only report the URL.
   - Do not attempt Buildkite or other providers; keep the workflow lean.
5. Summarize failures for the user.
   - Provide the failing check name, run URL (if any), and a concise log snippet.
   - Call out missing logs explicitly.
6. Decide whether to change code.
   - If the user requested diagnosis only, report the cause, reproduction and suggested fixes without pushing.
   - If the user requested a fix, work on that PR branch, use an isolated worktree when another agent may be editing it, and implement the smallest supported correction. Keep it in the existing PR rather than asking to open a duplicate PR.
7. Verify locally and recheck GitHub CI after pushing the fix.
   - Report exact changed files, commands and their results; distinguish pending/quota-blocked jobs from failing checks.
8. Preserve review state.
   - Keep an unverified PR draft; move it to ready for review once the fix is verified, leaving blockers documented if external checks remain.
   - After changes, suggest re-running the relevant tests and `gh pr checks` to confirm.

## Bundled Resources

### scripts/inspect_pr_checks.py

Fetch failing PR checks, pull GitHub Actions logs, and extract a failure snippet. Exits non-zero when failures remain so it can be used in automation.

Usage examples:
- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "123"`
- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "https://github.com/org/repo/pull/123" --json`
- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --max-lines 200 --context 40`

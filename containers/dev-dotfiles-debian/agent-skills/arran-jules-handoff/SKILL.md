---
name: arran-jules-handoff
description: Prepare complete handoff instructions or review comments for Google Jules working on GitHub issues or PRs; use when delegating, following up, or avoiding conflicting pushes to a Jules-owned branch.
---

# Jules handoff and follow-up

## Procedure
1. Read the repository's AGENTS.md, applicable issues/PRs, previous review comments, commits, CI status, and current head SHA.
2. Consult the user's Jules management guidance when applicable: https://arran4.github.io/blog/post/2026/044-jules-management/ . Do not assume an external document's rules without reading it.
3. Decide whether this is a fresh Jules session, continuation of an existing Jules PR, or an isolated review. Avoid duplicate sessions and conflicting changes.
4. Produce one scoped objective with explicit repository/branch/issue URLs, current head, acceptance criteria, files likely involved, tests to run, and exactly what must not be changed.
5. If Jules owns the active PR branch, provide change requests in PR comments. When implementation detail is needed, put a fenced unified diff patch in the comment rather than pushing competing commits; rebase the patch against the current head first.
6. Require fixes to the generator source when affected files are generated. Preserve generic CI and use resolving commit/PR keywords for issues actually resolved.
7. Request a final report of changed commits, commands run with results, workflow URLs, unresolved risks, and PR draft/readiness status.

## Output
- A copy-ready complete prompt or precise PR comment.
- Any blockers or evidence that require a user decision.

Never claim Jules has started work merely because a prompt was prepared; never force-push a Jules-owned branch without explicit direction.

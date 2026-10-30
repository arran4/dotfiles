---
name: gobookmarks-scenarios
description: Use for arran4/gobookmarks browser repros, template verification and TXTAR-backed scenario servers; choose isolated template rendering versus real-router scenario testing and avoid exposing synthetic login fixtures.
---
# gobookmarks test and scenario harness

**Source:** https://github.com/arran4/gobookmarks; consult repository AGENTS.md and current CLI help. Invoke the checked-out binary or `go run ./cmd/gobookmarks` as supported by its build.

## Pick the smallest real verification seam
- Template-only change: `gobookmarks test verification template -serve :8081 complex` renders with the real template loader, functions, escaping and URL generation without a full production stack. **Flags precede** the template range.
- Whole handler/router/login/navigation workflow: `gobookmarks scenario validate cmd/gobookmarks/scenarios/complex-bookmarks.txtar`, then `gobookmarks scenario serve cmd/gobookmarks/scenarios/complex-bookmarks.txtar`. Use `--port :8081` as appropriate, checking actual flag position from help.
- `scenario apply` is a disposable rehearsal, not an operation on the production database. Prefer `scenario serve` to exercise login and pages through the real router.
- Synthetic credentials and fixture tokens do not provide real account security; bind the server to loopback, never 0.0.0.0 for untrusted networks, and never use real user data.
- For browser screenshots, use a disposable browser profile; verify behaviour (login, redirect, cache invalidation, links), not only static appearance.

## Regression requirements
1. Extend the TXTAR scenario that represents the bug; use realistic auth-provider and storage-provider selection, test fixture external requests only when declared.
2. Preserve separation of the request-scoped `CoreData` cache across actors, providers and references. A screenshot alone will not test stale data or cross-user leakage.
3. Always distinguish `test verification template`, disposable `scenario apply`, and live `scenario serve`.
4. Report fixture path, port, commands, expected and observed route, login setup and browser/test evidence. Close the server and clean only resources created for the test.

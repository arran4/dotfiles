---
name: goa4web-sqlc
description: Use for arran4/goa4web database schema/migration, sqlc query, authorization and caching changes; coordinates query naming, code generation, migration sequencing and holistic Go verification.
---
# goa4web database and query changes

**Source:** https://github.com/arran4/goa4web ; read AGENTS.md and `specs/query_naming.md` and `specs/permissions.md` before modifying protected queries.

## Database workflow
1. Query source is `internal/db/*.sql`; change there then run `sqlc generate`. Never hand-edit generated `*.sql.go`. Callers should depend on generated `db.Querier` through `CoreData`, not bypass middleware/caching with direct database access.
2. Every schema change creates a **new numbered migration**, rather than editing an already deployed migration.
3. Synchronize `database/schema.mysql.sql`, migration `schema_version`, `handlers/constants.go` `ExpectedSchemaVersion`, and role grants in `database/seed.sql` when changed.
4. Read protected-query naming/authorization rules: user-facing queries use `For<Role>` with actor ID and SQL grant predicate; administrative queries begin `Admin`; internal trusted queries begin `System`. An unqualified Get/List is only safe for authorization-neutral data.
5. When modifying one permission predicate, audit all matching For<Role> queries and web/API/search/feed/notification paths to prevent alternate-access bypasses.
6. CLI/config behavior resolves flags, then config file, then environment, then defaults. Check `runtimeconfig.GenerateRuntimeConfig` rather than assuming conventional precedence.
7. Prefer injected or in-memory FS tests for normal application tests; use a real DB only in explicitly scoped integration cases. Run `go test ./...` (the repository's full supported suite).

## Acceptance
Include SQL source diffs, generated sqlc artifacts, additive migration and schema/version consistency checks, auth-negative cases and alternate-handler paths, real tests run, and CI status. Specs describe existing behavior; only change `specs/` when explicitly requested.

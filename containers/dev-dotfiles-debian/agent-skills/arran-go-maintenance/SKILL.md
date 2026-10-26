---
name: arran-go-maintenance
description: Investigate Go dependency vulnerabilities, accidental transitive dependencies, module upgrades, and build/test regressions; use when maintaining Go projects or addressing Dependabot alerts.
---

# Conservative Go maintenance

## Procedure
1. Identify module root, Go version, affected packages and declared dependencies. Capture `go env GOVERSION GOMOD GOWORK` and `go list -m all`.
2. Use `go mod why -m <module>`, `go mod graph`, and `go list -deps` to determine why a dependency is present and whether affected code is reachable. Do not assume a flagged module is imported at runtime.
3. Check authoritative advisories and patched versions, accounting for indirect and test-only dependencies; use `govulncheck ./...` if available and report its limitations.
4. Prefer the smallest viable dependency change or eliminating an unnecessary dependency without functionality loss. Avoid blanket `go get -u ./...` unless explicitly requested.
5. Run `go mod tidy`, `go test ./...`, `go vet ./...`, and focused race/coverage/staticcheck checks when relevant. Test with the repository's supported Go versions.
6. Confirm no unexpected go.mod/go.sum churn, license change, generated-file drift or API regression.
7. Prepare one focused PR per real fix, with resolving keywords for linked issues and exact tests/CI evidence.

## Output
- Why the dependency exists, vulnerable call path where supported, options, chosen minimal change, and verification results.

Never claim that upgrading a transitive module completely eliminates vulnerability without validating the resolved module graph and relevant call paths.

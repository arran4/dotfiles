---
name: arran-files-federation
description: Exercise federated sharing and encrypted multi-server behaviour in arran4/files; use when reviewing People, Follow, Clone, Join, Mirror, policy, wallet, offline retry or server discovery functionality.
---

# Files federation acceptance

1. Read repository AGENTS.md and the current acceptance/dogfood documentation before preparing scenarios; distinguish implemented behaviour from roadmap proposals.
2. Build isolated HTTPS servers with separate identities and profiles, wallets, storage and network addresses. Use disposable test fixtures, never a real user's personal collections or credentials.
3. Test each relationship independently: Follow feed visibility; Clone copied policy/covenant; Join mutual policy-governed membership; Mirror one-way/no write. Avoid conflating join and mirror semantics.
4. Cover permitted and denied discovery, invitation/acceptance, scoped auto-add, replicated signed policy snapshots, revocations, and source selection among valid endpoints when supported by the current implementation.
5. For encrypted media, verify actual decrypted payload equality (e.g. image pixels), not only HTTP status or item counts. Verify a denied actor cannot fetch content.
6. Exercise peer restart, offline operation, queued retries, wallet persistence and revoked-grant propagation as supported. Note any case deliberately deferred by the product roadmap.
7. Capture server logs, browser traces and test reports under /tmp with secrets redacted; clean up only resources created by this test.
8. Give a matrix of cases with pass/fail/skip, exact commands, versions, environment and evidence. A successful two-server startup is not proof of successful federation.

Coordinate browser-level UI cases with arran-container-dogfood instead of duplicating container setup scripts.

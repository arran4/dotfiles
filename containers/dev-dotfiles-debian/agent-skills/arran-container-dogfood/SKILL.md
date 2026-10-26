---
name: arran-container-dogfood
description: Set up reproducible Docker/Podman dogfood environments and end-to-end tests, especially two-server Files federation and browser workflows; use when testing real deployments safely.
---

# Container dogfood and reproducers

## Procedure
1. Inspect project Dockerfiles, Compose files, network topology, storage and security requirements before starting resources. Use unique test namespaces and temporary files under `/tmp` unless the user requests retained artifacts.
2. Keep host credentials, home directories and host container-engine sockets out of test containers. Use isolated volumes and narrowly scoped test tokens, never live production accounts.
3. Report whether nested Docker/Podman is enabled and the associated privilege mode. Do not silently turn on privileged mode to make a test pass.
4. Start the smallest representative environment, recording image digests, ports, TLS mode, database/volume names and test fixtures.
5. For Files federation, cover two independent servers and profiles, policy-controlled discovery, invite acceptance, Join replication, Mirror denial, encrypted media download, restart/wallet recovery and offline retries where applicable.
6. Capture reproducible failure artifacts and logs to `/tmp`; scrub tokens and personal data before sharing. Prefer Playwright for browser acceptance tests when provisioned.
7. Always clean up only resources created by the test. Preserve existing volumes and external containers, and never run blanket prune commands.
8. State which scenarios passed, failed, were skipped, or require host privileges unavailable to the runner.

## Output
- Reproduction command, environment manifest, case-by-case results, evidence/log paths and next fix.

Do not claim an end-to-end test passed based solely on unit tests or successful container startup.

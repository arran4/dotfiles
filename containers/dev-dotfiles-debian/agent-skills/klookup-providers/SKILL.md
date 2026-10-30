---
name: klookup-providers
description: Use when implementing or migrating KLookup search providers between native Qt plugins and its manifest-based JavaScript/process provider API, including pagination, auth and contract tests.
---
# KLookup provider development and migration

**Source:** https://github.com/arran4/klookup. Provider manifest schema: `schemas/provider_package.schema.json`; protocol schema: `schemas/provider_v1_protocol.schema.json`. Native plugin examples live under `providers/`; JavaScript execution is in `src/jsprovider.cpp`. Read current docs and schema, not only the README.

## Runtime choice
- Native Qt/KF6 plugin: use when native integration or libraries are genuinely required.
- JavaScript package (`runtime: "javascript"`): suitable for simple/fast-moving HTTP-backed providers; prefer reuse of the host API rather than raw Qt networking.
- Process package (`runtime: "process"`): reserve for external executable integrations with a demonstrated need.
Do not convert every existing plugin to JavaScript merely for consistency.

## Provider contract
1. Package manifest must declare `id`, `name`, `version`, `runtime`, `entry`; review `permissions.origins`, `permissions.secrets`, and capabilities for pagination, details, content, hierarchy and authentication.
2. Implement only capabilities the provider actually supports. Confirm response matching to request IDs, cursor/continuation behavior, and cancellation/error paths against Provider API v1 fixtures.
3. `QJSEngine` executes **inside the application process, not a security sandbox**. Scripts must be explicitly trusted; network origin restrictions, secrets access, resource limits and cancellation rely on host-service enforcement. Never claim an untrusted script is isolated.
4. Avoid credentials in logs/tests; use synthetic fixture requests/responses. Preserve upstream attribution/licensing for API data.
5. For provider discovery issues enable `QT_LOGGING_RULES="klookup.plugins.debug=true"`; for KRunner activation, log `klookup.runner.warning=true`. Check installed service and DBus path from README.

## Build and verification
The repository requires the shared KDE/KF6 rootfs (`.jules/bootstrap.sh`, `.jules/run.sh`), **not Docker**. Use configured CMake/Ninja, build and `ctest` there; install `libkf6runner-dev` in the rootfs when required. Test missing permissions, authentication refresh, cancellation, pagination and malformed response. Do not treat a successful provider load as proof of correct query results.

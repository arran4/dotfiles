---
name: arran-cpp-hardening
description: Investigate C and C++ crashes, undefined behaviour, memory corruption or input-validation bugs; use for C++ libraries, parsers and security-sensitive file readers.
---

# C/C++ regression hardening

1. Identify failing input, owning source path and project build system. Minimize the reproducer before modifying production code.
2. Build a clean debug configuration with warnings enabled and ASan/UBSan when available. Capture compiler version and command line. Avoid asserting sanitizers are meaningful if an external dependency was not instrumented.
3. Investigate ownership, integer bounds, null pointers, recursion limits, iterator invalidation, zero-width loops, signed conversions and stale error propagation as relevant to the observed failure.
4. Prefer the smallest fix preserving existing successful behaviour. Add negative and edge-case tests including malformed inputs, repeated calls and platform boundary conditions.
5. Run focused tests, then full unit tests, sanitizer tests and clang-format / clang-tidy where configured. Separate reproducible regressions from speculative problems.
6. Review resource limits and failure-path cleanup; avoid adding broad global caps without considering valid workloads.
7. Report reproducer, root cause, tests and residual risk with precise source references. When using a generated source, fix its generator.

Never describe a sanitizer run as passing if it was skipped or suppressed.

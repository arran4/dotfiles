---
name: browser-intent-ipc
description: Use when modifying cross-application browser intent/selection IPC shared between arran4/which_browser and arran4/kbrowserselect; maintain framing, authentication, version negotiation and regression fixtures across both.
---
# Browser intent IPC conformance

**Sources:** https://github.com/arran4/which_browser and https://github.com/arran4/kbrowserselect. These are separate implementations with a shared evolving contract, **not** identical apps.

## Procedure
1. Read the relevant AGENTS.md and current IPC schema/fixtures in both repositories before changing one side. Check corresponding issue groups: which_browser #320–#323; kbrowserselect #199–#202.
2. Document the exact envelope/version, message-kind, framing length, capability/ack/error, routing/forwarding, auth token and loop-prevention field that is affected.
3. Implement changes against both sides where relevant, but keep two independent PRs in the respective repositories (only after approved migration). Never rename/retire a protocol field in one app without defining backwards compatibility for the other.
4. For KBrowserSelect verify bounded framing, per-user socket access and loopback HTTP-token protections; do not expose an unprotected control endpoint to other users or a network interface.
5. For which_browser run the repository's pinned Flutter SDK setup and `flutter test`; inspect `which_browser` `AGENTS.md` for the exact Flutter version rather than using latest.
6. Add protocol fixtures covering new and old peers, malformed sizes, duplicate/unknown kinds, replay/loop metadata and partial/truncated frames.
7. Test cross-platform constraints explicitly. A Linux IPC passing test is not proof that Windows desktop intent routing works.

## Completion
Give an IPC compatibility matrix, implementation-specific changes, tests from both projects and explicit issues/PR dependencies. Do not merge a breaking one-sided protocol update.

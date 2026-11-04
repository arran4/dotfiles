---
name: playwright
description: Use installed Playwright CLI to interact with a real browser from Codex or agy, including navigation, snapshots, screenshots, forms, traces and UI regressions.
---

# Playwright CLI — browser automation

**Tool:** `playwright-cli`, already installed globally in the Debian development image. Use `playwright-cli --help` to verify its current command surface. This is an interactive browser tool, not the `@playwright/test` framework.

## Start with a real page

```sh
playwright-cli open http://127.0.0.1:8080
playwright-cli snapshot
# Use a reference from that actual snapshot for the next action:
playwright-cli click e5
playwright-cli snapshot
playwright-cli screenshot
playwright-cli close
```

Replace `e5` with an element reference from the most recent snapshot. After navigation or a DOM update, take another snapshot. Named sessions can be selected via `PLAYWRIGHT_CLI_SESSION=feature-check`.

## Installation and prerequisites

- The Debian image provides the CLI, Linux browser dependencies and Chromium headless shell, shared at `/opt/playwright-browsers`. Use the direct `playwright-cli` command from either Codex or agy; no Codex-specific `~/.codex/skills` path or runtime `npx --yes` download is required.
- If running outside that image, check `command -v playwright-cli`. Respect the host's package-management policy; the official `playwright-cli install-browser` operation can install browsers if missing, but may download binaries and system packages.
- Browser snapshots and screenshots need a launched browser. `playwright-cli --help` only proves executable availability. Headed mode (`--headed`) additionally requires a GUI and is not covered by container smoke tests.

## Workflow

1. Start the target's local server or authorized URL; use a disposable browser session for testing.
2. `open`, `snapshot`, interact using fresh element refs, and `snapshot` again.
3. For UI bugs, capture a screenshot and console/network output or a trace as appropriate.
4. Close the browser. Save artifacts only under `/tmp` or an explicitly requested output path, not in the repository by default.
5. Report the exact URL, browser mode, interactions, actual observations and any missing capabilities.

See `references/cli.md` and `references/workflows.md`. Avoid revealing cookies, tokens and private browser state in CI artifacts.

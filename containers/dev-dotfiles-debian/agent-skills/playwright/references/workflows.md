# Playwright CLI Workflows

Use `playwright-cli` directly and snapshot often. Save artifacts in a task-specific `/tmp` directory unless the user asks for an output folder.

## Standard interaction loop

```bash
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli click e3
playwright-cli snapshot
```

## Form submission

```bash
playwright-cli open https://example.com/form --headed
playwright-cli snapshot
playwright-cli fill e1 "user@example.com"
playwright-cli fill e2 "password123"
playwright-cli click e3
playwright-cli snapshot
playwright-cli screenshot
```

## Data extraction

```bash
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli eval "document.title"
playwright-cli eval "el => el.textContent" e12
```

## Debugging and inspection

Capture console messages and network activity after reproducing an issue:

```bash
playwright-cli console warning
playwright-cli network
```

Record a trace around a suspicious flow:

```bash
playwright-cli tracing-start
# reproduce the issue
playwright-cli tracing-stop
playwright-cli screenshot
```

## Sessions

Use sessions to isolate work across projects:

```bash
playwright-cli --session marketing open https://example.com
playwright-cli --session marketing snapshot
playwright-cli --session checkout open https://example.com/checkout
```

Or set the session once:

```bash
export PLAYWRIGHT_CLI_SESSION=checkout
playwright-cli open https://example.com/checkout
```

## Configuration file

The CLI loads `.playwright/cli.config.json` automatically if present. Use `--config` to point at a specific file.

Minimal example:

```json
{
  "browser": {
    "launchOptions": {
      "headless": false
    },
    "contextOptions": {
      "viewport": { "width": 1280, "height": 720 }
    }
  }
}
```

## Troubleshooting

- If an element ref fails, run `playwright-cli snapshot` again and retry.
- If the page looks wrong, re-open with `--headed` and resize the window.
- If a flow depends on prior state, use a named `--session`.

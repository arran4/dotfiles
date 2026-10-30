# Playwright CLI Reference

Use `playwright-cli` directly. The image provides the executable globally; this reference is not tied to `$CODEX_HOME` or agy's home directory.

## Core

```bash
playwright-cli open https://example.com
playwright-cli close
playwright-cli snapshot
playwright-cli click e3
playwright-cli dblclick e7
playwright-cli type "search terms"
playwright-cli press Enter
playwright-cli fill e5 "user@example.com"
playwright-cli drag e2 e8
playwright-cli hover e4
playwright-cli select e9 "option-value"
playwright-cli upload ./document.pdf
playwright-cli check e12
playwright-cli uncheck e12
playwright-cli eval "document.title"
playwright-cli eval "el => el.textContent" e5
playwright-cli dialog-accept
playwright-cli dialog-accept "confirmation text"
playwright-cli dialog-dismiss
playwright-cli resize 1920 1080
```

## Navigation

```bash
playwright-cli go-back
playwright-cli go-forward
playwright-cli reload
```

## Keyboard

```bash
playwright-cli press Enter
playwright-cli press ArrowDown
playwright-cli keydown Shift
playwright-cli keyup Shift
```

## Mouse

```bash
playwright-cli mousemove 150 300
playwright-cli mousedown
playwright-cli mousedown right
playwright-cli mouseup
playwright-cli mouseup right
playwright-cli mousewheel 0 100
```

## Save as

```bash
playwright-cli screenshot
playwright-cli screenshot e5
playwright-cli pdf
```

## Tabs

```bash
playwright-cli tab-list
playwright-cli tab-new
playwright-cli tab-new https://example.com/page
playwright-cli tab-close
playwright-cli tab-close 2
playwright-cli tab-select 0
```

## DevTools

```bash
playwright-cli console
playwright-cli console warning
playwright-cli network
playwright-cli run-code "await page.waitForTimeout(1000)"
playwright-cli tracing-start
playwright-cli tracing-stop
```

## Sessions

Use a named session to isolate work:

```bash
playwright-cli --session todo open https://demo.playwright.dev/todomvc
playwright-cli --session todo snapshot
```

Or set an environment variable once:

```bash
export PLAYWRIGHT_CLI_SESSION=todo
playwright-cli open https://demo.playwright.dev/todomvc
```

#!/bin/sh
# Run a real headless browser against a local HTML page, as a non-root user.
set -eu
command -v playwright-cli >/dev/null 2>&1
tmp=$(mktemp -d /tmp/dev-playwright.XXXXXX)
pid=
cleanup() {
  PLAYWRIGHT_CLI_SESSION=dev-dotfiles-playwright-test playwright-cli close >/dev/null 2>&1 || true
  if [ -n "$pid" ]; then kill "$pid" >/dev/null 2>&1 || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT HUP INT TERM
printf '%s\n' '<!doctype html><title>Agent browser smoke</title><h1>Agent browser smoke</h1>' > "$tmp/index.html"
python3 -m http.server 28765 --bind 127.0.0.1 --directory "$tmp" > "$tmp/server.log" 2>&1 &
pid=$!
ready=0
for n in 1 2 3 4 5 6 7 8; do
  if curl -fsS http://127.0.0.1:28765/index.html >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then cat "$tmp/server.log" >&2; exit 1; fi
(
  cd "$tmp"
  export PLAYWRIGHT_CLI_SESSION=dev-dotfiles-playwright-test
  playwright-cli open http://127.0.0.1:28765/index.html
  playwright-cli snapshot > snapshot.txt
  grep -Fq 'Agent browser smoke' snapshot.txt
  playwright-cli screenshot > screenshot.txt
  playwright-cli close
)
echo 'Playwright browser smoke passed.'

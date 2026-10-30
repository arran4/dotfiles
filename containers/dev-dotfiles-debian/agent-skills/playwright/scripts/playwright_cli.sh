#!/bin/sh
# Compatibility wrapper for scripts referencing the bundled skill path.
# The image supplies the CLI globally; do not download a new npm version per call.
set -eu
if ! command -v playwright-cli >/dev/null 2>&1; then
  echo 'Playwright CLI is not installed; use the configured package manager.' >&2
  exit 127
fi
exec playwright-cli "$@"

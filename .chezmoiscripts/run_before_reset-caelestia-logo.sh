#!/bin/sh
set -eu

# Before chezmoi applies its externals, we must clean up our managed modification
# to Caelestia's logo.svg so that git doesn't refuse to update or report a dirty tree.
QS_DIR="${HOME}/.config/quickshell"

if [ -d "$QS_DIR/.git" ]; then
    # We only care about resetting the logo file if it was modified.
    git -C "$QS_DIR" restore assets/logo.svg 2>/dev/null || true
fi

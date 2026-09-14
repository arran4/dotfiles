#!/bin/sh
set -eu

# Before chezmoi applies its externals, we must clean up our managed modification
# to Caelestia's logo.svg so that git doesn't refuse to update or report a dirty tree.
QS_DIR="${HOME}/.config/quickshell"

if [ ! -d "$QS_DIR/.git" ]; then
    # Fresh install, checkout does not exist yet
    exit 0
fi

if ! git -C "$QS_DIR" restore assets/logo.svg >/dev/null 2>&1; then
    echo "Error: Failed to restore Caelestia logo fallback. Upstream path may have changed or file is missing." >&2
    exit 1
fi

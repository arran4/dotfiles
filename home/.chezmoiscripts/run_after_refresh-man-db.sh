#!/bin/sh
set -eu

# Rebuild the user-local manual index after chezmoi has installed man pages.
man_dir="$HOME/.local/share/man"

if command -v makewhatis >/dev/null 2>&1 && [ -d "$man_dir" ]; then
  makewhatis "$man_dir"
fi

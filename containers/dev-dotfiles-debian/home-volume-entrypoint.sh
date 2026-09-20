#!/bin/sh
set -eu

/usr/local/bin/dev-dotfiles-home-seed
exec /usr/local/bin/dev-dotfiles-entrypoint "$@"

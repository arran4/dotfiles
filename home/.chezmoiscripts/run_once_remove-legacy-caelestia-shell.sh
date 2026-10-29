#!/bin/sh
set -eu

qs_dir="${HOME}/.config/quickshell"

if [ ! -d "$qs_dir/.git" ]; then
  exit 0
fi

origin=$(git -C "$qs_dir" remote get-url origin 2>/dev/null || true)
case "$origin" in
  https://github.com/caelestia-dots/shell.git|https://github.com/caelestia-dots/shell|git@github.com:caelestia-dots/shell.git)
    ;;
  *)
    echo "Leaving $qs_dir untouched: it is not the legacy Caelestia checkout (origin: ${origin:-unknown})." >&2
    exit 0
    ;;
esac

if [ -n "$(git -C "$qs_dir" status --porcelain --untracked-files=all)" ]; then
  echo "Refusing to remove legacy Caelestia checkout at $qs_dir because it has local changes." >&2
  echo "Preserve or discard those changes, then rerun chezmoi apply." >&2
  exit 1
fi

rm -rf -- "$qs_dir"
echo "Removed legacy Caelestia shell checkout from $qs_dir; the shell is package-manager owned now."

#!/bin/sh
set -eu

config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
quick_commands="$HOME/.config/konsolequickcommandsconfig"

chezmoi_bin="${CHEZMOI:-}"
if [ -z "$chezmoi_bin" ]; then
  if command -v chezmoi >/dev/null 2>&1; then
    chezmoi_bin="$(command -v chezmoi)"
  elif [ -x ./bin/chezmoi ]; then
    chezmoi_bin="./bin/chezmoi"
  else
    echo "chezmoi executable not found" >&2
    exit 1
  fi
fi

if [ ! -f "$config" ]; then
  echo "chezmoi config was not generated at $config" >&2
  exit 1
fi

if [ "$(grep -F -c 'exclude = ["scripts"]' "$config")" -lt 2 ]; then
  echo "chezmoi diff/status are not both excluding scripts" >&2
  exit 1
fi

if grep -F 'include "{{ $themePath }}"' dot_gtkrc-2.0.tmpl >/dev/null; then
  echo "GTK2 template still emits KDE-owned theme include lines" >&2
  exit 1
fi

if "$chezmoi_bin" managed | grep -F -x '.config/konsolequickcommandsconfig' >/dev/null; then
  echo "Konsole Quick Commands should be script-owned on Linux" >&2
  exit 1
fi

if [ ! -s "$quick_commands" ]; then
  echo "Konsole Quick Commands were not installed" >&2
  exit 1
fi

grep -F -q '[system][chezmoi update apply init]' "$quick_commands"

"$chezmoi_bin" apply
grep -F -q '[system][chezmoi update apply init]' "$quick_commands"

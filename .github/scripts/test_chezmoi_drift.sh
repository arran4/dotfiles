#!/bin/sh
set -eu

config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
quick_commands="$HOME/.config/konsolequickcommandsconfig"

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

if chezmoi managed | grep -F -x '.config/konsolequickcommandsconfig' >/dev/null; then
  echo "Konsole Quick Commands should be script-owned on Linux" >&2
  exit 1
fi

if [ ! -s "$quick_commands" ]; then
  echo "Konsole Quick Commands were not installed" >&2
  exit 1
fi

grep -F -q '[system][chezmoi update apply init]' "$quick_commands"

chezmoi apply
grep -F -q '[system][chezmoi update apply init]' "$quick_commands"

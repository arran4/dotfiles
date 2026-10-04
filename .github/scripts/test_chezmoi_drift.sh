#!/bin/sh
set -eu

config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"

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

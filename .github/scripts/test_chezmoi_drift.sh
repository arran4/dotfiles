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

gtk2_tmpl="home/dot_gtkrc-2.0.tmpl"
if [ ! -f "$gtk2_tmpl" ]; then
  gtk2_tmpl="dot_gtkrc-2.0.tmpl"
fi

if grep -F 'include "{{ $themePath }}"' "$gtk2_tmpl" >/dev/null; then
  echo "GTK2 template still emits KDE-owned theme include lines" >&2
  exit 1
fi

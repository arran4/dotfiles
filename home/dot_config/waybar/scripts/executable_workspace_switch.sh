#!/bin/sh
# Switch workspaces for Waybar
# Usage: workspace_switch.sh next|prev
cmd="$1"
if command -v swaymsg >/dev/null 2>&1; then
  if [ "$cmd" = "prev" ]; then
    swaymsg workspace prev
  else
    swaymsg workspace next
  fi
elif command -v hyprctl >/dev/null 2>&1; then
  if [ "$cmd" = "prev" ]; then
    hyprctl dispatch workspace e-1
  else
    hyprctl dispatch workspace e+1
  fi
fi


#!/bin/sh
# Show current workspace index and total number of workspaces
if command -v swaymsg >/dev/null 2>&1; then
  ws=$(swaymsg -t get_workspaces)
  current=$(echo "$ws" | jq -r '.[] | select(.focused).num')
  total=$(echo "$ws" | jq -r length)
elif command -v hyprctl >/dev/null 2>&1; then
  ws=$(hyprctl -j workspaces)
  current=$(echo "$ws" | jq -r '.[] | select(.focused or .active).id')
  total=$(echo "$ws" | jq -r length)
else
  exit 0
fi
printf "%d/%d" "$current" "$total"


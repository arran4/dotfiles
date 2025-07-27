#!/bin/sh
# Show current workspace index and total number of workspaces
ws=$(swaymsg -t get_workspaces)
current=$(echo "$ws" | jq -r '.[] | select(.focused).num')
total=$(echo "$ws" | jq -r length)
printf "%d/%d" "$current" "$total"


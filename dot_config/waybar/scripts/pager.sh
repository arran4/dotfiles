#!/bin/sh
# Show current workspace index and total number of workspaces
workspaces=$(swaymsg -t get_workspaces)
current=$(echo "$workspaces" | jq '.[] | select(.focused).num')
total=$(echo "$workspaces" | jq length)
printf "%d/%d" "$current" "$total"


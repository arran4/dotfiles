#!/bin/sh
set -eu

# Container policy: choose Neon on every start, including persistent homes.
# Change only the model; preserve onboarding, trust, and other user settings.
settings_dir="$HOME/.gemini/antigravity-cli"
settings="$settings_dir/settings.json"

# Do not follow links to files or directories outside the managed home.
if [ -L "$HOME/.gemini" ] || [ -L "$settings_dir" ] || [ -L "$settings" ]; then
  echo 'Refusing to update Antigravity settings through a symlink' >&2
  exit 1
fi
if [ ! -f "$settings" ] || ! jq -e 'type == "object"' "$settings" >/dev/null; then
  echo "Antigravity settings must be an existing JSON object: $settings" >&2
  exit 1
fi

# Avoid writing to a persistent volume when the requested model is active.
if jq -e '.model == "Orchestrator (Neon)"' "$settings" >/dev/null; then
  exit 0
fi

umask 077
temporary=$(mktemp "$settings_dir/.settings.json.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
jq '.model = "Orchestrator (Neon)"' "$settings" > "$temporary"
mv -f -- "$temporary" "$settings"
trap - EXIT HUP INT TERM

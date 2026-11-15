#!/bin/sh
# Apply the container default only if no model was explicitly selected.
# A seeded home is persistent: preserve the user's model and other settings.
set -eu

settings=${DEV_AGY_SETTINGS_PATH:-"$HOME/.gemini/antigravity-cli/settings.json"}
[ -f "$settings" ] || exit 0
[ ! -L "$settings" ] || {
  echo "Skipping symlinked Agy settings: $settings" >&2
  exit 0
}

if ! jq -e 'type == "object"' "$settings" >/dev/null 2>&1; then
  echo "Skipping malformed Agy settings: $settings" >&2
  exit 0
fi

# Empty or absent model means no explicit choice; everything else is
# preserved, including models selected through /model and /effort.
if jq -e 'has("model") and (.model != null and .model != "")' "$settings" >/dev/null; then
  exit 0
fi

tmp=$(mktemp "$(dirname "$settings")/.agy-settings.XXXXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM
jq '.model = "Gemini 4 Hydrogen (High)"' "$settings" > "$tmp"
chmod 0600 "$tmp"
mv -f -- "$tmp" "$settings"
trap - EXIT HUP INT TERM

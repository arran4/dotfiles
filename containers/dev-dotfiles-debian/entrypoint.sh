#!/bin/sh
set -eu

# Fresh named volumes can be owned by root depending on the container engine.
# Persistent-volume invocations opt into fixing only the mount-point roots.
# This is deliberately not automatic so the normal bind-mounted workflow can
# never chown a host checkout or host credential directory.
if [ "${DEV_VOLUME_INIT:-0}" = "1" ]; then
  uid=$(id -u)
  gid=$(id -g)

  for path in \
    /workspace \
    "$HOME/.codex" \
    "$HOME/.gemini" \
    "$HOME/.config/gh" \
    "$HOME/.config/glab-cli"
  do
    if [ -e "$path" ]; then
      sudo chown "$uid:$gid" "$path"
    fi
  done
elif [ "${DEV_AGY_VOLUME_INIT:-0}" = "1" ] && [ -e "$HOME/.gemini" ]; then
  # The bind-mounted workflow still uses a named volume for Antigravity state.
  # Initialise only that mount so host checkouts and credential directories are
  # never chowned by this narrower mode.
  sudo chown "$(id -u):$(id -g)" "$HOME/.gemini"
fi

unset DEV_VOLUME_INIT DEV_AGY_VOLUME_INIT

# Keep account-based Antigravity authentication inside the persisted .gemini
# volume instead of trying to depend on a desktop keyring in the container.
export GEMINI_FORCE_FILE_STORAGE="${GEMINI_FORCE_FILE_STORAGE:-true}"

# Antigravity only activates GEMINI_API_KEY when modelProvider is explicitly
# set to "gemini". Keep that provider selection in the persisted .gemini volume
# while the host key is being passed through, and remove only our managed value
# if the key is no longer supplied.
agy_dir="$HOME/.gemini/antigravity-cli"
agy_settings="$agy_dir/settings.json"
agy_provider_marker="$agy_dir/.dev-agent-gemini-provider"

if [ -n "${GEMINI_API_KEY:-}" ]; then
  mkdir -p "$agy_dir"
  tmp=$(mktemp "$agy_dir/.settings.json.XXXXXX")

  if [ -s "$agy_settings" ] && jq -e 'type == "object"' "$agy_settings" >/dev/null 2>&1; then
    jq '.modelProvider = "gemini"' "$agy_settings" > "$tmp"
  else
    printf '%s\n' '{"modelProvider":"gemini"}' > "$tmp"
  fi

  chmod 600 "$tmp"
  mv "$tmp" "$agy_settings"
  : > "$agy_provider_marker"
elif [ -e "$agy_provider_marker" ]; then
  if [ -s "$agy_settings" ] && jq -e 'type == "object"' "$agy_settings" >/dev/null 2>&1; then
    tmp=$(mktemp "$agy_dir/.settings.json.XXXXXX")
    jq 'del(.modelProvider)' "$agy_settings" > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$agy_settings"
  fi
  rm -f "$agy_provider_marker"
fi

exec /usr/bin/zsh -l "$@"

#!/bin/sh
set -eu

uid=$(id -u)
gid=$(id -g)

# Fresh named volumes can be owned by root depending on the container engine.
# Persistent-volume invocations opt into fixing only the mount-point roots.
# This is deliberately not automatic so the normal bind-mounted workflow can
# never chown a host checkout or host credential directory.
if [ "${DEV_VOLUME_INIT:-0}" = "1" ]; then
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

  unset DEV_VOLUME_INIT
fi

# The ordinary checkout workflow bind-mounts /workspace from the host but uses
# named volumes for forge CLI state. Initialise only those credential/config
# volumes so we never chown the bind-mounted repository.
if [ "${DEV_FORGE_VOLUME_INIT:-0}" = "1" ]; then
  for path in \
    "$HOME/.config/gh" \
    "$HOME/.config/glab-cli"
  do
    if [ -e "$path" ]; then
      sudo chown "$uid:$gid" "$path"
    fi
  done

  unset DEV_FORGE_VOLUME_INIT
fi

exec /usr/bin/zsh -l "$@"

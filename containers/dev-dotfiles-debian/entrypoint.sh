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

  unset DEV_VOLUME_INIT
fi

exec /usr/bin/zsh -l "$@"

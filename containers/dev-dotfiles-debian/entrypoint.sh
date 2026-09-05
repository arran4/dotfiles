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

if [ -n "${DEV_BOOTSTRAP_GH_TOKEN:-}" ]; then
  # Only bootstrap if the configuration directory is uninitialized/empty
  if [ ! -d "$HOME/.config/gh" ] || [ -z "$(ls -A "$HOME/.config/gh" 2>/dev/null)" ]; then
    mkdir -p "$HOME/.config/gh"
    echo "$DEV_BOOTSTRAP_GH_TOKEN" | gh auth login --with-token || true
  fi
  unset DEV_BOOTSTRAP_GH_TOKEN
fi

if [ -n "${DEV_BOOTSTRAP_GLAB_TOKEN:-}" ]; then
  if [ ! -d "$HOME/.config/glab-cli" ] || [ -z "$(ls -A "$HOME/.config/glab-cli" 2>/dev/null)" ]; then
    mkdir -p "$HOME/.config/glab-cli"
    echo "$DEV_BOOTSTRAP_GLAB_TOKEN" | glab auth login --stdin || true
  fi
  unset DEV_BOOTSTRAP_GLAB_TOKEN
fi

exec /usr/bin/zsh -l "$@"

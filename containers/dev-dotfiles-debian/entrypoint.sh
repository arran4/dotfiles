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

# Opt-in Docker-in-Docker mode runs a daemon that belongs to this container.
# Never fall through to a socket that may have been bind-mounted from the host:
# remove the expected socket first and fail if the mount cannot be removed.
if [ "${DEV_DIND:-0}" = "1" ]; then
  export DOCKER_HOST=unix:///var/run/docker.sock
  dind_log=${DEV_DIND_LOG:-/tmp/dev-dotfiles-dockerd.log}

  if [ -e /var/run/docker.sock ] || [ -S /var/run/docker.sock ]; then
    if ! sudo rm -f /var/run/docker.sock; then
      echo "DEV_DIND=1 requires a private Docker socket; do not mount the host Docker socket" >&2
      exit 1
    fi
  fi
  sudo rm -f /var/run/docker.pid
  : > "$dind_log"

  sudo dockerd \
    --host=unix:///var/run/docker.sock \
    --group "$(id -gn)" \
    >"$dind_log" 2>&1 &
  dockerd_pid=$!

  attempts=0
  while ! docker info >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if ! kill -0 "$dockerd_pid" 2>/dev/null || [ "$attempts" -ge 60 ]; then
      echo "nested Docker daemon failed to become ready" >&2
      cat "$dind_log" >&2 || true
      exit 1
    fi
    sleep 1
  done
fi

exec /usr/bin/zsh -l "$@"

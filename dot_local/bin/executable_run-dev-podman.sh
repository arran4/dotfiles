#!/bin/sh
set -eu

# Linux-only launcher for the locally built, versioned project-home image.
if [ "$(uname -s)" != Linux ]; then
  echo 'This launcher supports Linux only.' >&2
  exit 1
fi
if [ "$#" -ne 0 ]; then
  echo 'Configure the launcher with SANDBOX_NAME and DEV_* environment variables; see HOME-VOLUME.md.' >&2
  exit 2
fi
command -v podman >/dev/null 2>&1 || { echo 'podman is required.' >&2; exit 1; }

workspace=$(pwd -P)
raw=${SANDBOX_NAME:-$(basename "$workspace")}
name=$(printf '%s' "$raw" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//')
name=${name:-default-project}
container="dev-agent-${name}-trial"
image=${DEV_IMAGE:-dev-dotfiles-home-volume:trial}
workspace_mode=${DEV_WORKSPACE_MODE:-bind}
home_mode=${DEV_HOME_MODE:-volume}
dind=${DEV_DIND:-0}
dind_persist=${DEV_DIND_PERSIST:-0}

case "$image" in
  ghcr.io/arran4/dev-dotfiles-debian:*) echo 'The published image does not support DEV_HOME_VOLUME_INIT; build the home-volume trial image first.' >&2; exit 2 ;;
esac
case "$workspace_mode" in bind|volume|container) ;; *) echo 'DEV_WORKSPACE_MODE must be bind, volume or container.' >&2; exit 2 ;; esac
case "$home_mode" in volume|container) ;; *) echo 'DEV_HOME_MODE must be volume or container.' >&2; exit 2 ;; esac
case "$dind:$dind_persist" in 0:0|1:0|1:1) ;; *) echo 'DEV_DIND and DEV_DIND_PERSIST must be 0 or 1; persistence requires DEV_DIND=1.' >&2; exit 2 ;; esac

# A stopped named container keeps its old image and writable filesystem.
# Never delete it implicitly: an unmapped workspace might contain the only copy.
if podman container exists "$container"; then
  if [ "$(podman inspect --format '{{.State.Running}}' "$container")" = true ]; then
    echo "Container $container is already running; use podman exec -it $container zsh to open another shell." >&2
    exit 1
  fi
  echo "Resuming $container; to use a rebuilt image, back up writable-layer data and recreate the container explicitly." >&2
  exec podman start -ai --detach-keys='' "$container"
fi

set -- run -it --name "$container" --restart=no --detach-keys='' \
  --userns=keep-id:uid=1000,gid=1000 --hostname "agent-sandbox-${name}" \
  --env DEV_HOME_VOLUME_INIT=1 --workdir /workspace

if [ "$home_mode" = volume ]; then
  set -- "$@" --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user"
fi
case "$workspace_mode" in
  bind) set -- "$@" --mount "type=bind,src=${workspace},dst=/workspace,rw" ;;
  volume) set -- "$@" --env DEV_VOLUME_INIT=1 --mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace" ;;
  container) ;;
esac
if [ "$dind" = 1 ]; then
  set -- "$@" --privileged --env DEV_DIND=1
  if [ "$dind_persist" = 1 ]; then
    set -- "$@" --mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"
  fi
fi
exec podman "$@" "$image"

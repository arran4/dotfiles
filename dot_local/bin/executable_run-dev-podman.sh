#!/bin/sh
set -eu

# Linux-only launcher. Published images use legacy volumes; the home-volume
# prototype is opt-in until its entrypoint is part of the published image.
if [ "$(uname -s)" != Linux ]; then
  echo 'This launcher supports Linux only.' >&2
  exit 1
fi
if [ "$#" -ne 0 ]; then
  echo 'Configure the launcher with SANDBOX_NAME and DEV_* environment variables; see containers/dev-dotfiles-debian/README.md.' >&2
  exit 2
fi
command -v podman >/dev/null 2>&1 || { echo 'podman is required.' >&2; exit 1; }

workspace=$(pwd -P)
raw=${SANDBOX_NAME:-$(basename "$workspace")}
name=$(printf '%s' "$raw" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//')
name=${name:-default-project}
image=${DEV_IMAGE:-ghcr.io/arran4/dev-dotfiles-debian:latest}
workspace_mode=${DEV_WORKSPACE_MODE:-bind}
home_mode=${DEV_HOME_MODE:-volume}
dind=${DEV_DIND:-0}
dind_persist=${DEV_DIND_PERSIST:-0}

case "$image" in
  ghcr.io/arran4/dev-dotfiles-debian:*) layout=legacy; container="dev-agent-${name}" ;;
  *) layout=trial; container="dev-agent-${name}-trial" ;;
esac
case "$workspace_mode" in bind|volume|container) ;; *) echo 'DEV_WORKSPACE_MODE must be bind, volume or container.' >&2; exit 2 ;; esac
case "$home_mode" in volume|container) ;; *) echo 'DEV_HOME_MODE must be volume or container.' >&2; exit 2 ;; esac
case "$dind:$dind_persist" in 0:0|1:0|1:1) ;; *) echo 'DEV_DIND and DEV_DIND_PERSIST must be 0 or 1; persistence requires DEV_DIND=1.' >&2; exit 2 ;; esac
if [ "$layout" = legacy ] && [ "$home_mode" != volume ]; then
  echo 'DEV_HOME_MODE=container requires a home-volume image selected via DEV_IMAGE.' >&2
  exit 2
fi

# A stopped container may contain the only copy of an unmapped workspace.
# Resume it before checking the image: restarting does not need an image pull.
if podman container exists "$container"; then
  if [ "$(podman inspect --format '{{.State.Running}}' "$container")" = true ]; then
    echo "Container $container is already running; use podman exec -it $container zsh to open another shell." >&2
    exit 1
  fi
  echo "Resuming $container; to use a newer image, back up writable-layer data and recreate the container explicitly." >&2
  exec podman start -ai --detach-keys='' "$container"
fi

# Offline use succeeds with an existing local image. Only the published image
# may be pulled automatically; an explicitly selected trial must be built first.
if ! podman image exists "$image"; then
  if [ "$layout" = legacy ]; then
    if ! podman pull "$image"; then
      echo "Could not obtain published development image $image. Check network access and registry permissions; existing containers and volumes were not changed." >&2
      exit 1
    fi
  else
    echo "Development image $image is missing locally. Build/select the home-volume image first; see containers/dev-dotfiles-debian/README.md. Existing containers and volumes were not changed." >&2
    exit 1
  fi
fi

set -- run -it --name "$container" --restart=no --detach-keys='' \
  --userns=keep-id:uid=1000,gid=1000 --hostname "agent-sandbox-${name}" \
  --workdir /workspace

if [ "$layout" = trial ]; then
  set -- "$@" --env DEV_HOME_VOLUME_INIT=1
  if [ "$home_mode" = volume ]; then
    set -- "$@" --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user"
  fi
else
  # The currently published image cannot seed a mounted /home/user. Keep its
  # existing per-project agent and forge volumes and container name intact.
  set -- "$@" --env DEV_FORGE_VOLUME_INIT=1 \
    --mount "type=volume,src=dev-agent-${name}-codex,dst=/home/user/.codex" \
    --mount "type=volume,src=dev-agent-${name}-agy,dst=/home/user/.gemini" \
    --mount "type=volume,src=dev-agent-${name}-gh,dst=/home/user/.config/gh" \
    --mount "type=volume,src=dev-agent-${name}-glab,dst=/home/user/.config/glab-cli"
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

#!/bin/sh
set -eu

# Linux-only launcher. Published tags may contain either the historical
# per-agent layout or the newer versioned home seed. Inspect the local image
# instead of assuming that a mutable tag identifies its contents.
if [ "$(uname -s)" != Linux ]; then
  echo 'This launcher supports Linux only.' >&2
  exit 1
fi
if [ "$#" -ne 0 ]; then
  echo 'Configure the launcher with SANDBOX_NAME and DEV_* environment variables; see containers/dev-dotfiles-debian/README.md.' >&2
  exit 2
fi
command -v docker >/dev/null 2>&1 || { echo 'docker is required.' >&2; exit 1; }

workspace=$(pwd -P)
raw=${SANDBOX_NAME:-$(basename "$workspace")}
name=$(printf '%s' "$raw" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//')
name=${name:-default-project}
image=${DEV_IMAGE:-ghcr.io/arran4/dev-dotfiles-debian:latest}
workspace_mode=${DEV_WORKSPACE_MODE:-bind}
home_mode=${DEV_HOME_MODE:-volume}
new_home=${DEV_NEW_HOME:-0}
dind=${DEV_DIND:-0}
dind_persist=${DEV_DIND_PERSIST:-0}
host_gateway=${DEV_DOCKER_HOST_GATEWAY:-0}

case "$image" in ghcr.io/arran4/dev-dotfiles-debian:*) published=1 ;; *) published=0 ;; esac
case "$workspace_mode" in bind|volume|container) ;; *) echo 'DEV_WORKSPACE_MODE must be bind, volume or container.' >&2; exit 2 ;; esac
case "$home_mode" in volume|container) ;; *) echo 'DEV_HOME_MODE must be volume or container.' >&2; exit 2 ;; esac
case "$new_home" in 0|1) ;; *) echo 'DEV_NEW_HOME must be 0 or 1.' >&2; exit 2 ;; esac
case "$dind:$dind_persist" in 0:0|1:0|1:1) ;; *) echo 'DEV_DIND and DEV_DIND_PERSIST must be 0 or 1; persistence requires DEV_DIND=1.' >&2; exit 2 ;; esac
case "$host_gateway" in 0|1) ;; *) echo 'DEV_DOCKER_HOST_GATEWAY must be 0 or 1.' >&2; exit 2 ;; esac

# A stopped container can contain the only copy of an unmapped workspace.
# Resume an existing sandbox before any image pull. A published home sandbox
# takes precedence over an old published sandbox; DEV_NEW_HOME=1 explicitly
# bypasses an existing legacy container without deleting or importing it.
resume() {
  container=$1
  if docker container inspect "$container" >/dev/null 2>&1; then
    if [ "$(docker inspect --format '{{.State.Running}}' "$container")" = true ]; then
      echo "Container $container is already running; use docker exec -it $container zsh to open another shell." >&2
      exit 1
    fi
    echo "Resuming $container; to use a newer image, back up writable-layer data and recreate the container explicitly." >&2
    exec docker start -ai "$container"
  fi
}
if [ "$published" = 1 ]; then
  resume "dev-agent-${name}-home"
  if [ "$new_home" = 0 ]; then resume "dev-agent-${name}"; fi
else
  resume "dev-agent-${name}-trial"
fi

# Offline use succeeds with an already available image. Only the published
# image is pulled automatically; custom trial images must exist locally.
if ! docker image inspect "$image" >/dev/null 2>&1; then
  if [ "$published" = 1 ]; then
    if ! docker pull "$image"; then
      echo "Could not obtain published development image $image. Check network access and registry permissions; existing containers and volumes were not changed." >&2
      exit 1
    fi
  else
    echo "Development image $image is missing locally. Build/select the home-volume image first; see containers/dev-dotfiles-debian/README.md. Existing containers and volumes were not changed." >&2
    exit 1
  fi
fi

# Old :latest layers have no seed, and must keep their historical mounts.
# A new published image opts into the home layout via its build-time label.
seed_label=$(docker image inspect --format '{{index .Config.Labels "io.github.arran4.dev-dotfiles.home-seed"}}' "$image")
if [ "$seed_label" = 1 ]; then
  if [ "$published" = 1 ]; then layout=home; container="dev-agent-${name}-home"; home_volume="dev-agent-${name}-project-home"
  else layout=trial; container="dev-agent-${name}-trial"; home_volume="dev-agent-${name}-home"
  fi
else
  if [ "$published" != 1 ]; then
    echo "Image $image does not advertise versioned home initialization; refusing to mount /home/user over unseeded image contents." >&2
    exit 1
  fi
  if [ "$new_home" = 1 ]; then
    echo "Image $image does not support the versioned home layout. Pull a released home-seed image before using DEV_NEW_HOME=1." >&2
    exit 1
  fi
  layout=legacy
  container="dev-agent-${name}"
  if [ "$home_mode" != volume ]; then
    echo 'DEV_HOME_MODE=container requires a home-seed image; the cached published image uses legacy volumes.' >&2
    exit 2
  fi
fi

set -- run -it --name "$container" --restart=no \
  --hostname "agent-sandbox-${name}" --workdir /workspace

if [ "$layout" != legacy ]; then
  set -- "$@" --env DEV_HOME_VOLUME_INIT=1
  if [ "$home_mode" = volume ]; then
    set -- "$@" --mount "type=volume,src=${home_volume},dst=/home/user"
  fi
else
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
if [ "$host_gateway" = 1 ]; then
  set -- "$@" --add-host host.docker.internal:host-gateway
fi
if [ "$dind" = 1 ]; then
  set -- "$@" --privileged --env DEV_DIND=1
  if [ "$dind_persist" = 1 ]; then
    set -- "$@" --mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"
  fi
fi
exec docker "$@" "$image"

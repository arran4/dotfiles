#!/bin/sh
set -eu

# One canonical Dockerfile produces the development image. Inspect its actual
# labels after pulling, rather than trusting a potentially stale local tag.
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
new_home=${DEV_NEW_HOME:-0}
dind=${DEV_DIND:-0}
dind_persist=${DEV_DIND_PERSIST:-0}
pull_mode=${DEV_PULL_MODE:-}

case "$image" in ghcr.io/arran4/dev-dotfiles-debian:*) published=1 ;; *) published=0 ;; esac
case "$workspace_mode" in bind|volume|container) ;; *) echo 'DEV_WORKSPACE_MODE must be bind, volume or container.' >&2; exit 2 ;; esac
case "$home_mode" in volume|container) ;; *) echo 'DEV_HOME_MODE must be volume or container.' >&2; exit 2 ;; esac
case "$new_home" in 0|1) ;; *) echo 'DEV_NEW_HOME must be 0 or 1.' >&2; exit 2 ;; esac
case "$dind:$dind_persist" in 0:0|1:0|1:1) ;; *) echo 'DEV_DIND and DEV_DIND_PERSIST must be 0 or 1; persistence requires DEV_DIND=1.' >&2; exit 2 ;; esac
case "$pull_mode" in
  '') if [ "$published" = 1 ]; then pull_mode=always; else pull_mode=never; fi ;;
  always|missing|never) ;;
  *) echo 'DEV_PULL_MODE must be always, missing or never.' >&2; exit 2 ;;
esac

# Resume existing sandboxes before inspecting/pulling an image: a container
# writable layer may contain the only copy of a project checkout. Pulling an
# image would not update an existing container. An existing seeded home takes
# precedence. An explicit new home bypasses a legacy sandbox, without
# modifying or migrating it.
resume() {
  container=$1
  if podman container exists "$container"; then
    if [ "$(podman inspect --format '{{.State.Running}}' "$container")" = true ]; then
      echo "Container $container is already running; use podman exec -it $container zsh to open another shell." >&2
      exit 1
    fi
    echo "Resuming $container; to use a newer image, back up writable-layer data and recreate the container explicitly." >&2
    exec podman start -ai --detach-keys='' "$container"
  fi
}
resume "dev-agent-${name}-home"
if [ "$new_home" = 0 ]; then resume "dev-agent-${name}"; fi

# New sandboxes use the latest published image by default, even when :latest
# exists locally. Local development images remain local unless explicitly
# opted into registry pulls. DEV_PULL_MODE=missing permits offline cache use.
if [ "$pull_mode" = always ] || { [ "$pull_mode" = missing ] && ! podman image exists "$image"; }; then
  if ! podman pull "$image"; then
    echo "Could not pull development image $image. Check network access and registry permissions; use DEV_PULL_MODE=missing to permit a cached image. Existing containers and volumes were not changed." >&2
    exit 1
  fi
fi
if ! podman image exists "$image"; then
  echo "Development image $image is missing locally. Build it from containers/dev-dotfiles-debian/Dockerfile, select a published image, or enable registry pulls with DEV_PULL_MODE=always; existing state was not changed." >&2
  exit 1
fi

# The published home-seed capability is labelled at build time. A historical
# local image without it must use its historical per-agent volume layout.
seed_label=$(podman image inspect --format '{{index .Config.Labels "io.github.arran4.dev-dotfiles.home-seed"}}' "$image")
if [ "$seed_label" = 1 ]; then
  layout=home
  container="dev-agent-${name}-home"
else
  if [ "$published" != 1 ]; then
    echo "Image $image has no versioned home seed; select an image built from the canonical Dockerfile." >&2
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

set -- run -it --name "$container" --restart=no --detach-keys='' \
  --userns=keep-id:uid=1000,gid=1000 --hostname "agent-sandbox-${name}" \
  --workdir /workspace

if [ "$layout" = home ]; then
  set -- "$@" --env DEV_HOME_VOLUME_INIT=1
  if [ "$home_mode" = volume ]; then
    set -- "$@" --mount "type=volume,src=dev-agent-${name}-project-home,dst=/home/user"
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
if [ "$dind" = 1 ]; then
  set -- "$@" --privileged --env DEV_DIND=1
  if [ "$dind_persist" = 1 ]; then
    set -- "$@" --mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"
  fi
fi
exec podman "$@" "$image"

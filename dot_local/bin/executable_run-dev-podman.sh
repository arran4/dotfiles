#!/bin/sh
set -eu

# One canonical Dockerfile produces the development image. Inspect its actual
# labels after pulling, rather than trusting a potentially stale local tag.
if [ "$(uname -s)" != Linux ]; then
  echo 'This launcher supports Linux only.' >&2
  exit 1
fi
podman_security=${DEV_PODMAN_SECURITY:-nested}
container_persist=${DEV_CONTAINER_PERSIST:-0}
workspace_mode=${DEV_WORKSPACE_MODE:-bind}
home_mode=${DEV_HOME_MODE:-volume}

usage() {
  echo 'Usage: run-dev-podman.sh [--podman-security=nested|unconfined|privileged|off] [--persist-container|--ephemeral-container] [--no-home-volume] [--no-workspace-mount]' >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --podman-security=*) podman_security=${1#*=} ;;
    --persist-container) container_persist=1 ;;
    --ephemeral-container) container_persist=0 ;;
    --no-home-volume) home_mode=container ;;
    --no-workspace-mount) workspace_mode=container ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
  shift
done
case "$podman_security" in
  nested|unconfined|privileged|off) ;;
  *) echo 'Podman security must be nested, unconfined, privileged or off.' >&2; exit 2 ;;
esac
case "$container_persist" in
  0|1) ;;
  *) echo 'DEV_CONTAINER_PERSIST must be 0 or 1.' >&2; exit 2 ;;
esac
command -v podman >/dev/null 2>&1 || { echo 'podman is required.' >&2; exit 1; }

detect_host_timezone() {
  if [ -n "${DEV_TZ:-}" ]; then
    printf '%s\n' "$DEV_TZ"
    return
  fi
  if [ -n "${TZ:-}" ]; then
    printf '%s\n' "$TZ"
    return
  fi
  if [ -r /etc/timezone ]; then
    timezone=$(head -n 1 /etc/timezone 2>/dev/null || true)
    if [ -n "$timezone" ]; then
      printf '%s\n' "$timezone"
      return
    fi
  fi
  if [ -L /etc/localtime ]; then
    localtime=$(readlink -f /etc/localtime 2>/dev/null || true)
    case "$localtime" in
      /usr/share/zoneinfo/*)
        printf '%s\n' "${localtime#/usr/share/zoneinfo/}"
        return
        ;;
    esac
  fi
  printf '%s\n' 'Australia/Melbourne'
}
container_tz=$(detect_host_timezone)

workspace=$(pwd -P)
raw=${SANDBOX_NAME:-$(basename "$workspace")}
name=$(printf '%s' "$raw" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//')
name=${name:-default-project}
image=${DEV_IMAGE:-ghcr.io/arran4/dev-dotfiles-debian:latest}
new_home=${DEV_NEW_HOME:-0}
dind=${DEV_DIND:-1}
dind_persist=${DEV_DIND_PERSIST:-0}
podman_persist=${DEV_PODMAN_PERSIST:-0}
pull_mode=${DEV_PULL_MODE:-}

case "$image" in ghcr.io/arran4/dev-dotfiles-debian:*) published=1 ;; *) published=0 ;; esac
case "$workspace_mode" in bind|volume|container) ;; *) echo 'DEV_WORKSPACE_MODE must be bind, volume or container.' >&2; exit 2 ;; esac
case "$home_mode" in volume|container) ;; *) echo 'DEV_HOME_MODE must be volume or container.' >&2; exit 2 ;; esac
case "$new_home" in 0|1) ;; *) echo 'DEV_NEW_HOME must be 0 or 1.' >&2; exit 2 ;; esac
case "$dind:$dind_persist" in 0:0|1:0|1:1) ;; *) echo 'DEV_DIND and DEV_DIND_PERSIST must be 0 or 1; persistence requires DEV_DIND=1.' >&2; exit 2 ;; esac
case "$podman_persist" in 0|1) ;; *) echo 'DEV_PODMAN_PERSIST must be 0 or 1.' >&2; exit 2 ;; esac
case "$pull_mode" in
  '') if [ "$published" = 1 ]; then pull_mode=always; else pull_mode=never; fi ;;
  always|missing|never) ;;
  *) echo 'DEV_PULL_MODE must be always, missing or never.' >&2; exit 2 ;;
esac

# New containers are disposable by default. Existing stopped containers may
# contain writable-layer state from the previous retained-container default, so
# never delete them implicitly. Persistence is an explicit opt-in.
handle_existing_container() {
  container=$1
  if podman container exists "$container"; then
    if [ "$(podman inspect --format '{{.State.Running}}' "$container")" = true ]; then
      echo "Container $container is already running; use podman exec -it $container zsh to open another shell." >&2
      exit 1
    fi
    if [ "$container_persist" = 1 ]; then
      echo "Resuming persistent container $container." >&2
      exec podman start -ai --detach-keys='' "$container"
    fi
    echo "Stopped container $container exists from a persistent session. Remove it explicitly without removing named volumes, or rerun with --persist-container (DEV_CONTAINER_PERSIST=1) to resume it." >&2
    exit 1
  fi
}
# Both image layouts now use one predictable outer-container name. Historical
# seeded containers used -home; they may contain writable-layer state, so do
# not rename or replace them without an explicit user action.
container="dev-agent-${name}"
old_container="${container}-home"
if podman container exists "$old_container"; then
  echo "Existing old-named container $old_container detected. Resolve it explicitly before relaunching: ensure $container is unused, then run 'podman rename $old_container $container'. The named home volume is unaffected; no container was changed." >&2
  exit 1
fi
if [ "$new_home" = 1 ] && podman container exists "$container"; then
  echo "DEV_NEW_HOME=1 cannot bypass the existing $container under the unified naming scheme. Rename the old container explicitly or choose another SANDBOX_NAME. No container was changed." >&2
  exit 1
fi
handle_existing_container "$container"

# Only prune after an actual image ID change, not merely a successful
# no-op pull. Remember updates deferred by the once-per-24-hour limit.
image_updated=0
if [ "$pull_mode" = always ] || { [ "$pull_mode" = missing ] && ! podman image exists "$image"; }; then
  image_id_before=$(podman image inspect --format '{{.Id}}' "$image" 2>/dev/null || true)
  if ! podman pull "$image"; then
    echo "Could not pull development image $image. Check network access and registry permissions; use DEV_PULL_MODE=missing to permit a cached image. Existing containers and volumes were not changed." >&2
    exit 1
  fi
  image_id_after=$(podman image inspect --format '{{.Id}}' "$image" 2>/dev/null || true)
  if [ -n "$image_id_after" ] && [ "$image_id_before" != "$image_id_after" ]; then
    image_updated=1
  fi
fi
if ! podman image exists "$image"; then
  echo "Development image $image is missing locally. Build it from containers/dev-dotfiles-debian/Dockerfile, select a published image, or enable registry pulls with DEV_PULL_MODE=always; existing state was not changed." >&2
  exit 1
fi

# Prune dangling images across this user's rootless Podman store after a real
# pull update, at most once every 24 hours across all project launchers.
# Keep a pending marker when an update arrives during the cooldown, so a
# subsequent launcher invocation can complete deferred maintenance.
# No containers, named images, or volumes are explicitly pruned.
prune_updated_images() {
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dev-dotfiles-debian"
  pending_file="$state_dir/podman-prune-pending"
  last_file="$state_dir/podman-prune-last"
  if [ "$image_updated" != 1 ] && [ ! -f "$pending_file" ]; then
    return
  fi
  if ! command -v flock >/dev/null 2>&1; then
    echo 'Skipping Podman image prune: flock is unavailable.' >&2
    return
  fi
  if ! (umask 077; mkdir -p "$state_dir"); then
    echo "Skipping Podman image prune: cannot create $state_dir." >&2
    return
  fi
  if ! (
    flock 9 || exit 1
    if [ "$image_updated" = 1 ]; then
      : > "$pending_file" || exit 1
    fi
    [ -f "$pending_file" ] || exit 0
    now=$(date +%s) || exit 1
    last=$(cat "$last_file" 2>/dev/null || true)
    case "$last" in
      ''|*[!0-9]*) last=0 ;;
    esac
    if [ "$last" -gt 0 ] && [ "$now" -ge "$last" ] && [ $((now - last)) -lt 86400 ]; then
      exit 0
    fi
    # Record the attempt before pruning: even a failed or interrupted prune
    # must not be retried repeatedly within the same 24-hour window.
    printf '%s\n' "$now" > "$last_file" || exit 1
    if podman image prune -f; then
      rm -f "$pending_file" || exit 1
    else
      echo 'Podman image prune failed; pending cleanup will be retried after 24 hours.' >&2
    fi
  ) 9>"$state_dir/podman-prune.lock"; then
    echo 'Could not record Podman prune state; the launcher will continue.' >&2
  fi
}
prune_updated_images

seed_label=$(podman image inspect --format '{{index .Config.Labels "io.github.arran4.dev-dotfiles.home-seed"}}' "$image")
if [ "$seed_label" = 1 ]; then
  layout=home
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
  if [ "$home_mode" != volume ]; then
    echo 'DEV_HOME_MODE=container requires a home-seed image; the cached published image uses legacy volumes.' >&2
    exit 2
  fi
fi

set -- run -it --name "$container" --detach-keys=''
if [ "$container_persist" = 1 ]; then
  set -- "$@" --restart=no
else
  set -- "$@" --rm
fi
set -- "$@" \
  --userns=keep-id:uid=1000,gid=1000 --hostname "agent-sandbox-${name}" \
  --workdir /workspace \
  --env DEV_LAUNCHER_COMMAND=run-dev-podman.sh \
  --env DEV_OUTER_ENGINE=podman \
  --env DEV_CONTAINER_NAME="$container" \
  --env DEV_CONTAINER_PERSIST="$container_persist" \
  --env TZ="$container_tz" \
  --env DEV_PODMAN_SECURITY="$podman_security" \
  --env DEV_DIND="$dind" \
  --env DEV_DIND_PERSIST="$dind_persist"

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
if [ "$podman_persist" = 1 ]; then
  set -- "$@" --env DEV_PODMAN_VOLUME_INIT=1 \
    --mount "type=volume,src=dev-agent-${name}-podman,dst=/var/lib/dev-podman"
fi
case "$podman_security" in
  nested|unconfined)
    if [ ! -c /dev/fuse ]; then
      echo 'Nested Podman requires host /dev/fuse. Enable FUSE or use --podman-security=off to launch without nested-Podman support.' >&2
      exit 1
    fi
    # Private rootless Podman, no host runtime socket. Leave AppArmor intact
    # unless unconfined is explicitly requested for a host that needs it.
    set -- "$@" --device /dev/fuse --security-opt seccomp=unconfined \
      --security-opt label=disable --security-opt unmask=ALL
    if [ "$podman_security" = unconfined ]; then
      set -- "$@" --security-opt apparmor=unconfined
    fi ;;
  privileged) set -- "$@" --privileged ;;
  off) ;;
esac
if [ "$dind" = 1 ]; then
  set -- "$@" --privileged
  if [ "$dind_persist" = 1 ]; then
    set -- "$@" --mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"
  fi
fi
exec podman "$@" "$image"

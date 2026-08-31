#!/bin/sh
set -eu

IMAGE=${DEV_DOTFILES_IMAGE:-ghcr.io/arran4/dev-dotfiles-debian:latest}
ENGINE=${CONTAINER_ENGINE:-}
ACTION=run

usage() {
  cat <<'USAGE'
Usage:
  persistent-dev.sh [--engine podman|docker] NAME
  persistent-dev.sh [--engine podman|docker] destroy NAME

Creates or resumes an isolated development container backed only by named
container volumes. No host directory or host credential files are mounted.

Environment:
  CONTAINER_ENGINE     Override automatic podman/docker selection.
  DEV_DOTFILES_IMAGE   Override the image to run.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --engine)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      ENGINE=$2
      shift 2
      ;;
    destroy)
      ACTION=destroy
      shift
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 1 ] || { usage >&2; exit 2; }
NAME=$1

case "$NAME" in
  ''|[!A-Za-z0-9]*|*[!A-Za-z0-9_.-]*)
    echo "invalid name: $NAME (start with a letter or digit; then use letters, digits, '.', '_' or '-')" >&2
    exit 2
    ;;
esac

if [ -z "$ENGINE" ]; then
  if command -v podman >/dev/null 2>&1; then
    ENGINE=podman
  elif command -v docker >/dev/null 2>&1; then
    ENGINE=docker
  else
    echo "neither podman nor docker is available" >&2
    exit 127
  fi
fi

case "$ENGINE" in
  podman|docker) ;;
  *)
    echo "unsupported container engine: $ENGINE" >&2
    exit 2
    ;;
esac

CONTAINER="dev-agent-$NAME"
PREFIX="dev-agent-$NAME"
WORKSPACE_VOLUME="$PREFIX-workspace"
CODEX_VOLUME="$PREFIX-codex"
AGY_VOLUME="$PREFIX-agy"
GH_VOLUME="$PREFIX-gh"
GLAB_VOLUME="$PREFIX-glab"

if [ "$ACTION" = destroy ]; then
  "$ENGINE" rm -f "$CONTAINER" >/dev/null 2>&1 || true
  "$ENGINE" volume rm \
    "$WORKSPACE_VOLUME" \
    "$CODEX_VOLUME" \
    "$AGY_VOLUME" \
    "$GH_VOLUME" \
    "$GLAB_VOLUME" >/dev/null 2>&1 || true
  exit 0
fi

if "$ENGINE" container inspect "$CONTAINER" >/dev/null 2>&1; then
  running=$("$ENGINE" inspect -f '{{.State.Running}}' "$CONTAINER")
  if [ "$running" = true ]; then
    exec "$ENGINE" exec -it "$CONTAINER" /usr/bin/zsh -l
  fi
  exec "$ENGINE" start -ai "$CONTAINER"
fi

set -- run -it \
  --name "$CONTAINER" \
  --hostname "$CONTAINER" \
  --workdir /workspace \
  --mount "type=volume,src=$WORKSPACE_VOLUME,dst=/workspace" \
  --mount "type=volume,src=$CODEX_VOLUME,dst=/home/user/.codex" \
  --mount "type=volume,src=$AGY_VOLUME,dst=/home/user/.gemini" \
  --mount "type=volume,src=$GH_VOLUME,dst=/home/user/.config/gh" \
  --mount "type=volume,src=$GLAB_VOLUME,dst=/home/user/.config/glab-cli"

if [ "$ENGINE" = podman ]; then
  set -- "$@" --userns=keep-id:uid=1000,gid=1000
fi

exec "$ENGINE" "$@" \
  --entrypoint /bin/sh \
  "$IMAGE" \
  -c 'set -eu
uid=$(id -u)
gid=$(id -g)
sudo chown "$uid:$gid" \
  /workspace \
  /home/user/.codex \
  /home/user/.gemini \
  /home/user/.config/gh \
  /home/user/.config/glab-cli
exec /usr/bin/zsh -l'

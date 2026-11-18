#!/bin/sh
set -eu
usage() {
  echo 'Usage: clean-dev-agent-caches.sh (--all | --project NAME) [--apply]'
  echo 'Dry-run unless --apply is given. All Podman containers must be stopped before deletion.'
}
scope= project= apply=no
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      [ -z "$scope" ] || { usage >&2; exit 2; }
      scope=all ;;
    --project)
      [ -z "$scope" ] && [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      scope=project; project=$2; shift ;;
    --project=*)
      [ -z "$scope" ] || { usage >&2; exit 2; }
      scope=project; project=${1#*=} ;;
    --apply) apply=yes ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done
[ -n "$scope" ] || { usage >&2; exit 2; }
if [ "$scope" = project ]; then
  case "$project" in
    ''|*[!a-z0-9-]*|-*|*-) echo 'Project must be a normalized lowercase slug.' >&2; exit 2 ;;
  esac
fi
command -v podman >/dev/null 2>&1 || { echo 'podman is required.' >&2; exit 1; }
bounded() {
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 3s 90s "$@"
  else
    "$@"
  fi
}
graph_root=$(bounded podman info --format '{{.Store.GraphRoot}}') || {
  echo 'Cannot read Podman GraphRoot.' >&2; exit 1
}
case "$graph_root" in /*) graph_root=$(printf '%s' "$graph_root" | sed 's:/$::') ;;
  *) echo 'Invalid GraphRoot.' >&2; exit 1 ;;
esac
if [ "$apply" = yes ]; then
  running=$(bounded podman ps --format '{{.ID}}') || {
    echo 'Cannot inspect active Podman containers.' >&2; exit 1
  }
  [ -z "$running" ] || {
    echo 'Stop all rootless Podman containers before cleanup.' >&2; exit 1
  }
fi
volumes=$(bounded podman volume ls --format '{{.Name}}') || {
  echo 'Cannot list Podman volumes.' >&2; exit 1
}
matched=0
while IFS= read -r volume; do
  case "$volume" in dev-agent-*-project-home) ;; *) continue ;; esac
  if [ "$scope" = project ] && [ "$volume" != "dev-agent-$project-project-home" ]; then
    continue
  fi
  matched=$((matched + 1))
  mountpoint=$(bounded podman volume inspect "$volume" --format '{{.Mountpoint}}') || {
    echo "Skipping $volume: cannot inspect mountpoint." >&2
    continue
  }
  if [ "$mountpoint" != "$graph_root/volumes/$volume/_data" ]; then
    echo "Skipping $volume: unexpected mountpoint." >&2
    continue
  fi
  echo "== $volume ($apply) =="
  if ! bounded podman unshare sh -c '
    set -eu
    root=$1 action=$2
    [ -d "$root" ] && [ ! -L "$root" ] || {
      echo "Skipping missing or symlinked volume root." >&2; exit 1
    }
    for rel in .cache/go-build .cache/pip .cache/uv .cache/yarn .npm/_cacache; do
      case "$rel" in
        .cache/*) parent="$root/.cache" ;;
        .npm/*) parent="$root/.npm" ;;
      esac
      if [ -L "$parent" ]; then
        echo "Skipping symlinked parent: $parent" >&2; continue
      fi
      target="$root/$rel"
      if [ -L "$target" ]; then
        echo "Skipping symlinked cache: $target" >&2; continue
      fi
      [ -d "$target" ] || continue
      du -shx -- "$target" 2>/dev/null || echo "Size unavailable: $rel"
      if [ "$action" = yes ]; then
        rm -rf -- "$target"
        echo "Removed $rel"
      else
        echo "Would remove $rel"
      fi
    done
  ' sh "$mountpoint" "$apply"; then
    echo "Failed/timed out processing $volume; cache may be partly cleared." >&2
  fi
done <<EOF
$volumes
EOF
[ "$matched" -gt 0 ] || echo 'No matching project-home volumes found.'
if [ "$apply" = yes ]; then
  echo 'Cleanup attempted. Check Btrfs allocation separately.'
else
  echo 'Dry-run only. Nothing deleted; add --apply to clear the listed caches.'
fi

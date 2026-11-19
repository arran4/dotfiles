#!/bin/sh
set -eu

# Invoked only when the launcher requests a separate anonymous cache mount.
# Never repair permissions in the persistent home or a host bind mount.
[ "${DEV_CACHE_VOLUME_INIT:-0}" = 1 ] || exit 0
cache_dir="${HOME:?}/.cache"
if [ ! -d "$cache_dir" ] || [ -L "$cache_dir" ]; then
  echo "Missing or symlinked disposable cache directory: $cache_dir" >&2
  exit 1
fi
if ! mountpoint -q -- "$cache_dir"; then
  echo "Refusing cache ownership changes: $cache_dir is not a mountpoint." >&2
  exit 1
fi

uid=$(id -u)
gid=$(id -g)
if [ "$(stat -c '%u:%g' -- "$cache_dir")" != "$uid:$gid" ]; then
  sudo chown -- "$uid:$gid" "$cache_dir"
fi
if [ ! -w "$cache_dir" ]; then
  sudo chmod u+rwx -- "$cache_dir"
fi
if [ ! -w "$cache_dir" ]; then
  echo "Cache volume is not writable by UID:GID $uid:$gid: $cache_dir" >&2
  exit 1
fi

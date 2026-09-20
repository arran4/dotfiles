#!/bin/sh
set -eu

# Explicit opt-in: never unpack a home archive into an accidental host-home bind.
if [ "${DEV_HOME_VOLUME_INIT:-0}" != "1" ]; then
  echo 'Project home volume requires DEV_HOME_VOLUME_INIT=1' >&2
  exit 1
fi

archive=${DEV_HOME_SEED_ARCHIVE:-/usr/local/share/dev-dotfiles-debian/home-seed.tar}
marker="$HOME/.dev-dotfiles-home-initialized"

if [ -e "$marker" ]; then
  exit 0
fi

if [ ! -f "$archive" ]; then
  echo "Home seed archive is missing: $archive" >&2
  exit 1
fi

# Only the mount-point root may need ownership repair for a fresh named volume.
# Do not recursively chown persisted state (or a host checkout).
uid=$(id -u)
gid=$(id -g)
if [ "$(stat -c %u "$HOME")" != "$uid" ] || [ "$(stat -c %g "$HOME")" != "$gid" ]; then
  sudo chown "$uid:$gid" "$HOME"
fi

# An overlay extraction replaces paths present in the image's seed but never
# removes volume-only paths. Rerunning after an interrupted extraction is safe;
# the marker is only written once tar has completed successfully.
tar -C "$HOME" --no-same-owner --no-overwrite-dir -xf "$archive"
umask 077
: > "$marker"

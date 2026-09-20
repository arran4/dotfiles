#!/bin/sh
set -eu

# Explicit opt-in: never unpack a home archive into an accidental host-home bind.
if [ "${DEV_HOME_VOLUME_INIT:-0}" != "1" ]; then
  echo 'Project home volume requires DEV_HOME_VOLUME_INIT=1' >&2
  exit 1
fi

archive=${DEV_HOME_SEED_ARCHIVE:-/usr/local/share/dev-dotfiles-debian/home-seed.tar}
version_file=${DEV_HOME_SEED_VERSION_FILE:-/usr/local/share/dev-dotfiles-debian/home-seed-version}
marker="$HOME/.dev-dotfiles-seed-version"

# Only the mount-point root may need ownership repair for a fresh named volume.
# Do not recursively chown persisted state (or a host checkout).
uid=$(id -u)
gid=$(id -g)
if [ "$(stat -c %u "$HOME")" != "$uid" ] || [ "$(stat -c %g "$HOME")" != "$gid" ]; then
  sudo chown "$uid:$gid" "$HOME"
fi

if [ ! -f "$version_file" ]; then
  echo "Home seed version file is missing: $version_file" >&2
  exit 1
fi
seed_version=$(cat "$version_file")
if [ -z "$seed_version" ] || [ "$(printf '%s\n' "$seed_version" | wc -l)" -ne 1 ]; then
  echo "Home seed version is empty or invalid: $version_file" >&2
  exit 1
fi

# The version is set at image build time. Never infer it from a mutable runtime
# image tag such as latest. A matching version means a restart needs no writes.
if [ -f "$marker" ] && [ "$(cat "$marker")" = "$seed_version" ]; then
  exit 0
fi

if [ ! -f "$archive" ]; then
  echo "Home seed archive is missing: $archive" >&2
  exit 1
fi

# An overlay extraction replaces paths present in the new image's seed but
# never removes volume-only paths. This also refreshes matching config files
# that a user has edited. Runtime-only auth/credentials must stay out of the
# build-time archive. If extraction fails, leave the previous version in place
# so the next start retries it.
echo "Applying home seed version $seed_version"
tar -C "$HOME" --no-same-owner --no-overwrite-dir -xf "$archive"

# Record the version atomically only after a successful extraction. A crash
# before the rename causes the next start to retry the overlay.
umask 077
temporary_marker="$marker.tmp.$$"
trap 'rm -f "$temporary_marker"' EXIT HUP INT TERM
printf '%s\n' "$seed_version" > "$temporary_marker"
mv -f -- "$temporary_marker" "$marker"
trap - EXIT HUP INT TERM

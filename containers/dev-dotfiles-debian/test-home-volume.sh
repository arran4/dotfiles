#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
seed_script="$here/home-volume-seed.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/seed/.config" "$tmp/home/.config"
printf 'image config\n' > "$tmp/seed/.config/example"
printf 'initial history\n' > "$tmp/seed/.zsh_history"
printf 'old config\n' > "$tmp/home/.config/example"
printf 'keep this\n' > "$tmp/home/only-in-volume"
tar -C "$tmp/seed" -cf "$tmp/seed.tar" .

seed_home() {
  HOME="$tmp/home" DEV_HOME_VOLUME_INIT=1 \
    DEV_HOME_SEED_ARCHIVE="$tmp/seed.tar" sh "$seed_script"
}

if HOME="$tmp/home" DEV_HOME_SEED_ARCHIVE="$tmp/seed.tar" \
  sh "$seed_script" > "$tmp/no-opt-in.log" 2>&1; then
  echo 'Seeding unexpectedly succeeded without opt-in' >&2
  exit 1
fi
seed_home
test "$(cat "$tmp/home/.config/example")" = 'image config'
test "$(cat "$tmp/home/only-in-volume")" = 'keep this'
test "$(cat "$tmp/home/.zsh_history")" = 'initial history'
test -f "$tmp/home/.dev-dotfiles-home-initialized"

# The marker protects credentials and user-edited config on subsequent starts.
printf 'user config\n' > "$tmp/home/.config/example"
seed_home
test "$(cat "$tmp/home/.config/example")" = 'user config'

# A failed/incomplete first extraction has no marker: re-running overlays
# matching paths without removing the rest of the volume.
rm "$tmp/home/.dev-dotfiles-home-initialized"
printf 'stale config\n' > "$tmp/home/.config/example"
seed_home
test "$(cat "$tmp/home/.config/example")" = 'image config'
test "$(cat "$tmp/home/only-in-volume")" = 'keep this'

echo 'Home volume seed tests passed.'

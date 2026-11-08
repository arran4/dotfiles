#!/bin/sh
# Refresh image-managed Antigravity plugins without overwriting user-owned files.
set -eu

source_dir=${DEV_PLUGINS_SOURCE:-/usr/local/share/dev-dotfiles-debian/agent-plugins}
plugins_home=${DEV_AGY_PLUGINS_HOME:-"$HOME/.gemini/config/plugins"}
state_dir=${DEV_PLUGINS_STATE_DIR:-"$HOME/.local/state/dev-dotfiles-debian/managed-plugins"}
legacy_skills_home=${DEV_AGY_SKILLS_HOME:-"$HOME/.gemini/antigravity-cli/skills"}
legacy_state_dir=${DEV_SKILLS_STATE_DIR:-"$HOME/.local/state/dev-dotfiles-debian/managed-skills"}

[ -d "$source_dir" ] || exit 0
mkdir -p "$plugins_home" "$state_dir"

fingerprint() (
  cd "$1"
  find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d ' ' -f 1
)

for source in "$source_dir"/*; do
  [ -f "$source/plugin.json" ] || continue
  name=${source##*/}
  case "$name" in
    ''|*[!a-z0-9-]*)
      printf 'Skipping invalid managed plugin directory: %s\n' "$name" >&2
      continue ;;
  esac

  destination="$plugins_home/$name"
  state="$state_dir/$name.sha256"
  image_hash=$(fingerprint "$source")
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    if [ ! -f "$state" ]; then
      printf 'Preserving user-installed plugin: %s\n' "$destination" >&2
      continue
    fi
    if [ ! -d "$destination" ] || [ -L "$destination" ]; then
      printf 'Preserving non-directory plugin override: %s\n' "$destination" >&2
      continue
    fi
    current_hash=$(fingerprint "$destination")
    if [ "$current_hash" != "$(cat "$state")" ]; then
      printf 'Preserving modified managed plugin: %s\n' "$destination" >&2
      continue
    fi
    if [ "$current_hash" = "$image_hash" ]; then
      continue
    fi
  fi

  # Stage a complete copy before replacing anything in the persistent home.
  staging=$(mktemp -d "$plugins_home/.$name.tmp.XXXXXX")
  if ! cp -R "$source/." "$staging/"; then
    rm -rf -- "$staging"
    exit 1
  fi
  if [ -d "$destination" ]; then
    rm -rf -- "$destination"
  fi
  mv -- "$staging" "$destination"
  printf '%s\n' "$image_hash" > "$state"
done

# Migrated gosubc is loaded as a native plugin. Retire the old managed skill
# only after a verified image-owned plugin is present. Preserve unknown, edited,
# or symlinked legacy skills; deleting them would discard user work.
plugin="$plugins_home/arran4-gosubc"
plugin_state="$state_dir/arran4-gosubc.sha256"
if [ -d "$plugin" ] && [ ! -L "$plugin" ] && [ -f "$plugin_state" ] &&
   [ "$(fingerprint "$plugin")" = "$(cat "$plugin_state")" ]; then
  legacy="$legacy_skills_home/gosubc"
  legacy_state="$legacy_state_dir/gosubc.sha256"
  if [ -e "$legacy" ] || [ -L "$legacy" ]; then
    if [ -f "$legacy_state" ] && [ -d "$legacy" ] && [ ! -L "$legacy" ] &&
       [ "$(fingerprint "$legacy")" = "$(cat "$legacy_state")" ]; then
      rm -rf -- "$legacy"
      rm -f -- "$legacy_state"
      printf 'Retired image-managed legacy gosubc skill\n'
    else
      printf 'Preserving user-owned or modified legacy gosubc skill: %s\n' "$legacy" >&2
    fi
  fi
fi

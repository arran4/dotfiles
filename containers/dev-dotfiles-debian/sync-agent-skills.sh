#!/bin/sh
# Refresh only image-managed agy CLI skills. Never replace unknown or edited user skills.
set -eu
source_dir=${DEV_SKILLS_SOURCE:-/usr/local/share/dev-dotfiles-debian/agent-skills}
skills_home=${DEV_AGY_SKILLS_HOME:-"$HOME/.gemini/antigravity-cli/skills"}
state_dir=${DEV_SKILLS_STATE_DIR:-"$HOME/.local/state/dev-dotfiles-debian/managed-skills"}

[ -d "$source_dir" ] || exit 0
mkdir -p "$skills_home" "$state_dir"

fingerprint() (
  cd "$1"
  find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -d ' ' -f 1
)

for source in "$source_dir"/*; do
  [ -f "$source/SKILL.md" ] || continue
  name=${source##*/}
  case "$name" in
    ''|*[!a-z0-9-]*)
      printf 'Skipping invalid managed skill directory: %s\n' "$name" >&2
      continue ;;
  esac

  destination="$skills_home/$name"
  state="$state_dir/$name.sha256"
  image_hash=$(fingerprint "$source")

  if [ -e "$destination" ] || [ -L "$destination" ]; then
    if [ ! -f "$state" ]; then
      printf 'Preserving existing user skill: %s\n' "$destination" >&2
      continue
    fi
    if [ ! -d "$destination" ] || [ -L "$destination" ]; then
      printf 'Preserving non-directory managed skill override: %s\n' "$destination" >&2
      continue
    fi
    current_hash=$(fingerprint "$destination")
    if [ "$current_hash" != "$(cat "$state")" ]; then
      printf 'Preserving modified managed skill: %s\n' "$destination" >&2
      continue
    fi
    if [ "$current_hash" = "$image_hash" ]; then
      continue
    fi
    rm -rf -- "$destination"
  fi
  mkdir -p "$destination"
  cp -R "$source/." "$destination/"
  printf '%s\n' "$image_hash" > "$state"
done

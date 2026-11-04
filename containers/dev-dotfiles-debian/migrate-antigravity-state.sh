#!/bin/sh
set -eu

# Recover files misprojected to Codex by the old chezmoi configuration.
# Never replace the authoritative Antigravity state or follow symlinked roots.
legacy="$HOME/.codex/antigravity-cli"
current="$HOME/.gemini/antigravity-cli"

if [ ! -d "$legacy" ] || [ -L "$HOME/.codex" ] || [ -L "$legacy" ] ||
  [ -L "$HOME/.gemini" ] || [ -L "$current" ]; then
  exit 0
fi

for relative in settings.json cache/onboarding.json antigravity-oauth-token; do
  source_file="$legacy/$relative"
  destination="$current/$relative"

  # Do not follow link-backed cache directories or source files.
  if [ ! -f "$source_file" ] || [ -L "$source_file" ]; then
    continue
  fi
  case "$relative" in
    cache/*)
      if [ -L "$legacy/cache" ] || [ -L "$current/cache" ]; then
        continue
      fi
      ;;
  esac

  if [ -e "$destination" ] || [ -L "$destination" ]; then
    # Only discard obsolete copies when the active file is byte-identical.
    # Different files remain available for manual reconciliation.
    if [ -f "$destination" ] && [ ! -L "$destination" ] &&
      cmp -s -- "$source_file" "$destination"; then
      rm -- "$source_file"
    fi
    continue
  fi

  mkdir -p -- "$(dirname -- "$destination")"
  # Debian coreutils: -n ensures an existing destination is never overwritten.
  (umask 077; mv -n -- "$source_file" "$destination")
  if [ ! -e "$source_file" ]; then
    chmod 0600 -- "$destination"
  fi
done

# Remove only emptied legacy directories, never unknown files/state.
rmdir -- "$legacy/cache" 2>/dev/null || :
rmdir -- "$legacy" 2>/dev/null || :

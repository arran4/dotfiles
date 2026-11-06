#!/bin/sh
set -eu

# Transitional migration, prior to chezmoi replacing ~/.gitconfig.
# Copy non-public HTTPS credential/URL sections into a machine-local file.
# Hostnames are read only from the existing Git config, never the source.

case "$(uname -s)" in
  Linux|Darwin) ;;
  *) exit 0 ;;
esac

previous="${HOME}/.gitconfig"
local_config="${HOME}/.config/git/config.local"
[ -f "$previous" ] || exit 0
command -v awk >/dev/null 2>&1 || exit 0

[ ! -L "$local_config" ] || {
  echo 'Git migration: refusing symlinked local configuration' >&2
  exit 1
}
[ ! -e "$local_config" ] || [ -f "$local_config" ] || {
  echo 'Git migration: local configuration is not a regular file' >&2
  exit 1
}

umask 077
source_local=/dev/null
if [ -f "$local_config" ]; then
  source_local="$local_config"
fi
scratch="$(mktemp "${TMPDIR:-/tmp}/chezmoi-git-migrate.XXXXXXXX")"
trap 'rm -f "$scratch"' EXIT HUP INT TERM

# Reading the destination first prevents duplicate sections on retries.
# Match the entire Git section header; never overwrite local overrides.
awk '
  function public_host(host) {
    return host == "github.com" || host == "gist.github.com" ||
      host == "gitlab.com" || host == "dev.azure.com" ||
      host == "git.assembla.com" ||
      host == "source.developers.google.com"
  }
  FILENAME == ARGV[1] {
    if ($0 ~ /^\[(credential|url)[[:space:]]+"https:\/\//)
      exists[$0] = 1
    next
  }
  /^\[/ {
    keep = 0
    if ($0 ~ /^\[(credential|url)[[:space:]]+"https:\/\//) {
      host = $0
      sub(/^\[(credential|url)[[:space:]]+"https:\/\//, "", host)
      sub(/[\/"].*$/, "", host)
      if (!public_host(host) && !exists[$0] && index(host, "@") == 0) {
        keep = 1
        kind = ($0 ~ /^\[credential/) ? "credential" : "url"
      }
    }
  }
  keep && /^\[/ { print; next }
  keep {
    # Never carry arbitrary credential values (passwords, tokens, inline
    # helpers, private comments) from legacy Git configurations into the new
    # file. Transfer only known, non-secret host settings and rewrite keys.
    line = $0
    sub(/^[[:space:]]*/, "", line)
    key = tolower(line)
    sub(/[[:space:]]*=.*/, "", key)
    if (kind == "credential" &&
        (key == "usehttppath" || key == "gitlabauthmodes" ||
         key == "provider")) print
    else if (kind == "url" &&
             (key == "insteadof" || key == "pushinsteadof") &&
             line !~ /https?:\/\/[^\/[:space:]]+@/) print
  }
' "$source_local" "$previous" > "$scratch"

[ -s "$scratch" ] || exit 0
install -d -m 700 "${HOME}/.config/git"
if [ -e "$local_config" ]; then
  chmod 600 "$local_config"
  if [ -s "$local_config" ]; then
    case "$(tail -c 1 "$local_config" 2>/dev/null || true)" in
      "") ;;
      *) printf '\n' >> "$local_config" ;;
    esac
  fi
else
  : > "$local_config"
fi
# The captured data stays local and is never printed to stdout.
cat "$scratch" >> "$local_config"
chmod 600 "$local_config"
echo 'Migrated machine-specific Git settings into the local include'

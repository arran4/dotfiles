#!/bin/sh
set -eu

# Download nonsecret Git host defaults from an authenticated private GitHub
# repository. This does not touch machine-specific config.local overrides.
if [ "$#" -gt 1 ]; then
  echo 'Usage: sync-private-git-hosts.sh [OWNER/PRIVATE_REPO]' >&2
  exit 2
fi

command -v gh >/dev/null 2>&1 || {
  echo 'Git host bootstrap requires the GitHub CLI (gh).' >&2
  exit 127
}
command -v git >/dev/null 2>&1 || {
  echo 'Git host bootstrap requires git.' >&2
  exit 127
}

repo="${1:-${DOTFILES_GIT_HOSTS_REPO:-}}"
if [ -z "$repo" ]; then
  # Conventional default: authenticated user/private-git-hosts.
  if ! owner="$(gh api --hostname github.com user --jq .login 2>/dev/null)"; then
    echo 'Authenticate gh first (gh auth login), or specify OWNER/PRIVATE_REPO.' >&2
    exit 1
  fi
  repo="$owner/private-git-hosts"
fi
if ! printf '%s\n' "$repo" | LC_ALL=C grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
  echo 'Expected a private GitHub repository in OWNER/REPO form.' >&2
  exit 2
fi

umask 077
scratch="$(mktemp "${TMPDIR:-/tmp}/dotfiles-git-hosts.XXXXXXXX")"
trap 'rm -f "$scratch"' EXIT HUP INT TERM

# The private file is never printed or used as an unauthenticated URL.
if ! gh api --hostname github.com \
  --header 'Accept: application/vnd.github.raw+json' \
  "repos/$repo/contents/git/hosts.defaults" > "$scratch" 2>/dev/null; then
  echo 'Could not retrieve Git host defaults from the private repository.' >&2
  echo 'Check gh auth status and that git/hosts.defaults exists and is accessible.' >&2
  exit 1
fi
if [ ! -s "$scratch" ] || ! git config --file "$scratch" --list >/dev/null 2>&1; then
  echo 'Private Git host defaults are empty or not valid Git configuration.' >&2
  exit 1
fi
# Only allow host URL rewrites and nonsecret credential-provider settings;
# reject inline credential helpers, includes, credential-bearing URLs, etc.
if LC_ALL=C grep -Eq 'https?://[^/[:space:]]+@' "$scratch"; then
  echo 'Private Git host defaults contain credential-bearing URL syntax.' >&2
  exit 1
fi
if [ -z "$(git config --file "$scratch" --list --name-only)" ]; then
  echo 'Private Git host defaults have no supported settings.' >&2
  exit 1
fi
if ! git config --file "$scratch" --list --name-only | while IFS= read -r name; do
  case "$name" in
    credential.https://*.usehttppath|credential.https://*.gitlabauthmodes|credential.https://*.provider|\
    url.https://*.insteadof|url.https://*.pushinsteadof) ;;
    *) echo 'Private Git host defaults contain an unsupported key.' >&2; exit 1 ;;
  esac
done; then
  exit 1
fi

base="${HOME:?HOME must be set}/.config/git"
target="$base/hosts.defaults"
if [ -L "$base" ] || [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
  echo 'Refusing a symlink or nonregular Git host defaults destination.' >&2
  exit 1
fi
install -d -m 700 "$base"
if [ -f "$target" ] && cmp -s "$scratch" "$target"; then
  chmod 600 "$target"
  echo 'Private Git host defaults already match; nothing changed.'
  exit 0
fi
# Use a same-directory temp file for atomic replacement with 0600 permissions.
newfile="$(mktemp "$base/.hosts.defaults.XXXXXXXX")"
trap 'rm -f "$scratch" "$newfile"' EXIT HUP INT TERM
cat "$scratch" > "$newfile"
chmod 600 "$newfile"
mv -f "$newfile" "$target"
echo 'Installed private Git host defaults; machine-local overrides preserved.'

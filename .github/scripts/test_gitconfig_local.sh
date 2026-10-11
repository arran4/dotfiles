#!/bin/sh
set -eu

# The CI workflow applies chezmoi before running this regression test.
template="dot_gitconfig.tmpl"
rendered="${HOME}/.gitconfig"
include_line='  path = ~/.config/git/config.local'

for file in "$template" "$rendered"; do
  [ -f "$file" ] || { echo "Missing $file" >&2; exit 1; }
  count="$(grep -Fxc "$include_line" "$file" || true)"
  [ "$count" -eq 1 ] || {
    echo "$file: expected one unconditional local Git include, found $count" >&2
    exit 1
  }
done

# Only known public providers belong in the shared template's URL and
# credential sections. A self-hosted server belongs in the local include.
hosts="$(sed -nE 's/^\[(credential|url) "https:\/\/([^\/"]+).*/\2/p' "$template")"
for host in $hosts; do
  case "$host" in
    github.com|gist.github.com|gitlab.com|dev.azure.com|git.assembla.com|source.developers.google.com) ;;
    *) echo "Machine-specific host in public Git template" >&2; exit 1 ;;
  esac
done

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

# Simulate separate user/root homes without needing actual root credentials.
for account in user root; do
  home="$temp_dir/$account"
  mkdir -p "$home/.config/git"
  cp "$rendered" "$home/.gitconfig"

  # A missing local file must never break the shared Git configuration.
  result="$(HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" \
    GIT_CONFIG_NOSYSTEM=1 git config --global --includes --get init.defaultBranch)"
  [ "$result" = main ] || { echo "Git config failed without local include" >&2; exit 1; }

  cat > "$home/.config/git/config.local" <<'LOCAL'
[alias]
  local-only = status --short
[credential "https://git.example.invalid"]
  useHttpPath = true
LOCAL

  result="$(HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" \
    GIT_CONFIG_NOSYSTEM=1 git config --global --includes --get alias.local-only)"
  [ "$result" = 'status --short' ] || {
    echo "Git ignored the private include for $account" >&2
    exit 1
  }

  result="$(HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" \
    GIT_CONFIG_NOSYSTEM=1 git config --global --includes \
    --get-urlmatch credential.useHttpPath https://git.example.invalid/team/project.git)"
  [ "$result" = true ] || {
    echo "Git ignored URL-scoped private settings for $account" >&2
    exit 1
  }
done

echo "Shared Git config safely loads machine-local overrides for both accounts"

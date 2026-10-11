#!/bin/sh
set -eu

migration_script=".chezmoiscripts/run_once_before_migrate_private_git_hosts.sh"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

for identity in user root; do
  home="$temporary/$identity"
  mkdir -p "$home/.config/git"
  cat > "$home/.gitconfig" <<'OLD'
[user]
  name = Example
[credential "https://git.priv.example.invalid"]
  gitLabAuthModes = pat
  # comment
[url "https://git.priv.example.invalid/"]
  insteadOf = "git@git.priv.example.invalid:"
  insteadOf = "ssh://git@git.priv.example.invalid/"
[credential "https://github.com"]
  useHttpPath = true
[url "https://gitlab.com/"]
  insteadOf = "git@gitlab.com:"
OLD

  HOME="$home" sh "$migration_script"
  local_file="$home/.config/git/config.local"
  [ -f "$local_file" ] || { echo 'Missing local config' >&2; exit 1; }
  [ "$(grep -c '^\[credential "https://git.priv.example.invalid"\]' "$local_file")" -eq 1 ]
  [ "$(grep -c '^\[url "https://git.priv.example.invalid/"\]' "$local_file")" -eq 1 ]
  ! grep -q 'gitlab.com\|github.com' "$local_file"
  [ "$(stat -c '%a' "$local_file")" = 600 ]

  HOME="$home" sh "$migration_script"
  [ "$(grep -c '^\[credential "https://git.priv.example.invalid"\]' "$local_file")" -eq 1 ]
  [ "$(grep -c '^\[url "https://git.priv.example.invalid/"\]' "$local_file")" -eq 1 ]
  git config -f "$local_file" --get-urlmatch credential.gitLabAuthModes \
    'https://git.priv.example.invalid/team/project' | grep -qx pat

  cat >> "$home/.gitconfig" <<'EXTRA'
[credential "https://another.priv.example.invalid"]
  useHttpPath = true
EXTRA
  git config -f "$local_file" --add \
    'credential.https://another.priv.example.invalid.useHttpPath' false
  HOME="$home" sh "$migration_script"
  [ "$(git config -f "$local_file" --get-urlmatch credential.useHttpPath \
    'https://another.priv.example.invalid/repo')" = false ]
done

mkdir -p "$temporary/fresh"
HOME="$temporary/fresh" sh "$migration_script"
[ ! -e "$temporary/fresh/.config/git/config.local" ]
echo 'Migration tests passed'

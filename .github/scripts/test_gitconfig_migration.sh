#!/bin/sh
set -eu

migration_script="home/.chezmoiscripts/run_once_before_migrate_private_git_hosts.sh"
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
  password = illustrative-token-must-not-copy
  helper = !echo illustrative-token-must-not-copy
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
  grep -q 'gitlab.com\|github.com' "$local_file" && exit 1
  grep -q 'illustrative-token-must-not-copy' "$local_file" && exit 1
  grep -q '^  helper =' "$local_file" && exit 1
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

# Test migration when local config lacks a trailing newline
no_newline_home="$temporary/no_newline"
mkdir -p "$no_newline_home/.config/git"
printf '[user]\n  name = Existing' > "$no_newline_home/.config/git/config.local"
cat > "$no_newline_home/.gitconfig" <<'OLD'
[credential "https://git.nonl.example.invalid"]
  useHttpPath = true
OLD
HOME="$no_newline_home" sh "$migration_script"
git config -f "$no_newline_home/.config/git/config.local" --get user.name | grep -qx Existing
git config -f "$no_newline_home/.config/git/config.local" --get-urlmatch credential.useHttpPath \
  'https://git.nonl.example.invalid/repo' | grep -qx true

# Test migration when old ~/.gitconfig lacks a trailing newline
no_nl_old_home="$temporary/no_nl_old"
mkdir -p "$no_nl_old_home/.config/git"
printf '[url "https://git.oldnonl.example.invalid/"]\n  insteadOf = git@git.oldnonl.example.invalid:' > "$no_nl_old_home/.gitconfig"
HOME="$no_nl_old_home" sh "$migration_script"
git config -f "$no_nl_old_home/.config/git/config.local" --get \
  'url.https://git.oldnonl.example.invalid/.insteadOf' | grep -qx 'git@git.oldnonl.example.invalid:'

mkdir -p "$temporary/fresh"
HOME="$temporary/fresh" sh "$migration_script"
[ ! -e "$temporary/fresh/.config/git/config.local" ]
echo 'Migration tests passed'

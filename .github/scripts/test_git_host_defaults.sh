#!/bin/sh
set -eu

script="home/dot_local/bin/executable_sync-private-git-hosts.sh"
testdir="$(mktemp -d)"
trap 'rm -rf "$testdir"' EXIT HUP INT TERM
mkdir -p "$testdir/bin" "$testdir/user" "$testdir/root"

cat > "$testdir/bin/gh" <<'MOCK'
#!/bin/sh
case "$*" in
  *'user --jq .login'*) printf '%s\n' example-user ;;
  *'repos/example-user/private-git-hosts/contents/git/hosts.defaults'*|*'repos/other/private-hosts/contents/git/hosts.defaults'*)
    if [ "${GH_FAIL:-}" = 1 ]; then exit 1; fi
    cat "$GH_FIXTURE"
    ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$testdir/bin/gh"

cat > "$testdir/defaults" <<'GIT'
[credential "https://git.example.invalid"]
  useHttpPath = true
  gitLabAuthModes = pat
[url "https://git.example.invalid/"]
  insteadOf = git@git.example.invalid:
  insteadOf = ssh://git@git.example.invalid/
GIT

export PATH="$testdir/bin:$PATH" GH_FIXTURE="$testdir/defaults"
for account in user root; do
  home="$testdir/$account"
  HOME="$home" sh "$script" >/dev/null
  defaults="$home/.config/git/hosts.defaults"
  [ -f "$defaults" ] || exit 1
  [ "$(stat -c '%a' "$defaults")" = 600 ] || exit 1
  [ ! -e "$home/.config/git/config.local" ] || exit 1

  cat > "$home/.gitconfig" <<'LOCALGIT'
[include]
  path = ~/.config/git/hosts.defaults
[include]
  path = ~/.config/git/config.local
LOCALGIT
  [ "$(HOME="$home" git config --global --includes --get-urlmatch credential.useHttpPath 'https://git.example.invalid/repo')" = true ]

  cat > "$home/.config/git/config.local" <<'OVERRIDE'
[credential "https://git.example.invalid"]
  useHttpPath = false
OVERRIDE
  [ "$(HOME="$home" git config --global --includes --get-urlmatch credential.useHttpPath 'https://git.example.invalid/repo')" = false ]
  original="$(cat "$home/.config/git/config.local")"
  HOME="$home" sh "$script" other/private-hosts >/dev/null
  [ "$(cat "$home/.config/git/config.local")" = "$original" ]

  before="$(sha256sum "$defaults" | cut -d' ' -f1)"
  HOME="$home" GH_FAIL=1 sh "$script" other/private-hosts >/dev/null 2>&1 && exit 1
  [ "$(sha256sum "$defaults" | cut -d' ' -f1)" = "$before" ]

  echo '[include]' > "$testdir/defaults"
  HOME="$home" sh "$script" >/dev/null 2>&1 && exit 1
  [ "$(sha256sum "$defaults" | cut -d' ' -f1)" = "$before" ]

  cat > "$testdir/defaults" <<'GIT'
[credential "https://git.example.invalid"]
  useHttpPath = true
  gitLabAuthModes = pat
[url "https://git.example.invalid/"]
  insteadOf = git@git.example.invalid:
GIT
  printf '\n[credential "https://git.example.invalid"]\n  helper = !arbitrary-command\n' >> "$testdir/defaults"
  HOME="$home" sh "$script" >/dev/null 2>&1 && exit 1
  [ "$(sha256sum "$defaults" | cut -d' ' -f1)" = "$before" ]

  cat > "$testdir/defaults" <<'GIT'
[credential "https://git.example.invalid"]
  useHttpPath = true
  gitLabAuthModes = pat
[url "https://git.example.invalid/"]
  insteadOf = git@git.example.invalid:
  insteadOf = ssh://git@git.example.invalid/
GIT
done

HOME="$testdir/user" sh "$script" '../bad-path' >/dev/null 2>&1 && exit 1
echo 'Private Git host defaults bootstrap tests passed'

#!/bin/sh
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
helper="$here/cache-volume-init.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/home/.cache" "$tmp/outside"
printf 'credentials\n' > "$tmp/home/credentials"
printf 'untouched\n' > "$tmp/outside/secret"
cat > "$tmp/bin/mountpoint" <<'MOCK'
#!/bin/sh
[ "$1" = -q ] && [ "$2" = -- ] || exit 2
[ "$3" = "$HOME/.cache" ] && [ "${TEST_MOUNTED:-0}" = 1 ]
MOCK
cat > "$tmp/bin/stat" <<'MOCK'
#!/bin/sh
if [ "${TEST_WRONG_OWNER:-0}" = 1 ]; then
  echo '9999:9999'
else
  exec /usr/bin/stat "$@"
fi
MOCK
cat > "$tmp/bin/sudo" <<'MOCK'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_SUDO_LOG"
MOCK
chmod +x "$tmp/bin/"*
PATH="$tmp/bin:$PATH"
export PATH
export TEST_SUDO_LOG="$tmp/sudo-log"
export HOME="$tmp/home"
sh -n "$helper"
: > "$TEST_SUDO_LOG"

# A seed build or persistent cache mode must leave the home unchanged.
DEV_CACHE_VOLUME_INIT=0 sh "$helper"
test ! -s "$TEST_SUDO_LOG"

# Do not modify a regular .cache directory inside the named volume.
if DEV_CACHE_VOLUME_INIT=1 TEST_MOUNTED=0 sh "$helper" > "$tmp/output" 2>&1; then
  echo 'Expected non-mount cache to be rejected' >&2
  exit 1
fi
test ! -s "$TEST_SUDO_LOG"
test -f "$HOME/credentials"

# Only repair the root of a verified mount, never recursively chown home.
DEV_CACHE_VOLUME_INIT=1 TEST_MOUNTED=1 TEST_WRONG_OWNER=1 sh "$helper"
grep -Fx "chown -- $(id -u):$(id -g) $HOME/.cache" "$TEST_SUDO_LOG" >/dev/null
test "$(wc -l < "$TEST_SUDO_LOG")" -eq 1
test -f "$HOME/credentials"

# Symlinks, including ones to elsewhere on the host, must be rejected.
rm -rf "$HOME/.cache"
ln -s "$tmp/outside" "$HOME/.cache"
: > "$TEST_SUDO_LOG"
if DEV_CACHE_VOLUME_INIT=1 TEST_MOUNTED=1 sh "$helper" > "$tmp/output" 2>&1; then
  echo 'Expected symlinked cache to be rejected' >&2
  exit 1
fi
test ! -s "$TEST_SUDO_LOG"
test -f "$tmp/outside/secret"
printf 'Cache volume init tests passed.\n'

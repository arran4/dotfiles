#!/bin/sh
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
helper="$root/home/dot_local/bin/executable_clean-dev-agent-caches.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/store/volumes" "$tmp/protected"
for name in dev-agent-one-project-home dev-agent-two-project-home; do
  m="$tmp/store/volumes/$name/_data"
  mkdir -p "$m/.cache/go-build" "$m/.cache/pip" "$m/.go/pkg/mod/cache/download" "$m/.config/gh"
  echo generated > "$m/.cache/go-build/file"
  echo generated > "$m/.cache/pip/file"
  echo important > "$m/.go/pkg/mod/cache/download/file"
  echo secret > "$m/.config/gh/hosts.yml"
done
ln -s "$tmp/protected" "$tmp/store/volumes/dev-agent-one-project-home/_data/.npm"
cat > "$tmp/bin/podman" <<'MOCK'
#!/bin/sh
set -eu
case "$1:$2" in
  info:--format) echo "$TEST_STORE" ;;
  volume:ls)
    printf '%s\n' dev-agent-one-project-home dev-agent-two-project-home unrelated-volume ;;
  volume:inspect)
    if [ "${TEST_BAD_MOUNT:-0}" = 1 ]; then
      echo /outside/volumes/dev-agent-one-project-home/_data
    else
      echo "$TEST_STORE/volumes/$3/_data"
    fi ;;
  ps:--format) [ "${TEST_RUNNING:-0}" = 1 ] && echo running-container || : ;;
  unshare:sh) shift; exec "$@" ;;
  *) echo "Unexpected Podman mock call: $*" >&2; exit 1 ;;
esac
MOCK
chmod +x "$tmp/bin/podman"
export TEST_STORE="$tmp/store"
PATH="$tmp/bin:$PATH"
export PATH
sh -n "$helper"
if "$helper" >/dev/null 2>&1; then exit 1; fi
if "$helper" --project '../one' >/dev/null 2>&1; then exit 1; fi
"$helper" --all > "$tmp/dry"
grep -F 'Would remove .cache/go-build' "$tmp/dry" >/dev/null
test -f "$tmp/store/volumes/dev-agent-one-project-home/_data/.cache/go-build/file"
if TEST_RUNNING=1 "$helper" --all --apply >/dev/null 2>&1; then exit 1; fi
test -f "$tmp/store/volumes/dev-agent-one-project-home/_data/.cache/go-build/file"
"$helper" --project one --apply > "$tmp/apply"
test ! -e "$tmp/store/volumes/dev-agent-one-project-home/_data/.cache/go-build"
test ! -e "$tmp/store/volumes/dev-agent-one-project-home/_data/.cache/pip"
test -f "$tmp/store/volumes/dev-agent-one-project-home/_data/.config/gh/hosts.yml"
test -f "$tmp/store/volumes/dev-agent-one-project-home/_data/.go/pkg/mod/cache/download/file"
test -L "$tmp/store/volumes/dev-agent-one-project-home/_data/.npm"
test -f "$tmp/store/volumes/dev-agent-two-project-home/_data/.cache/go-build/file"
TEST_BAD_MOUNT=1 "$helper" --all --apply > "$tmp/unsafe" 2>&1
test -f "$tmp/store/volumes/dev-agent-two-project-home/_data/.cache/go-build/file"
"$helper" --all --apply > "$tmp/all"
test ! -e "$tmp/store/volumes/dev-agent-two-project-home/_data/.cache/go-build"
test -f "$tmp/store/volumes/dev-agent-two-project-home/_data/.config/gh/hosts.yml"
printf 'Project-home cache cleanup tests passed.\n'

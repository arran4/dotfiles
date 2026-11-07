#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
hook="$repo_root/home/.chezmoiscripts/run_after_refresh-man-db.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

sh -n "$hook"
mkdir -p "$tmp/bin" "$tmp/empty"
home="$tmp/home with spaces"
man_dir="$home/.local/share/man"
log="$tmp/makewhatis.log"

cat > "$tmp/bin/makewhatis" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" >> "$MAKEWHATIS_LOG"
STUB
chmod +x "$tmp/bin/makewhatis"

# Skip when the local man directory is not installed.
HOME="$home" PATH="$tmp/bin" MAKEWHATIS_LOG="$log" /bin/sh "$hook"
[ ! -e "$log" ] || fail 'ran without a manual directory'

mkdir -p "$man_dir/man1"
# Skip when makewhatis is unavailable.
HOME="$home" PATH="$tmp/empty" MAKEWHATIS_LOG="$log" /bin/sh "$hook"
[ ! -e "$log" ] || fail 'ran without makewhatis'

# Pass the full home-relative path as a single argument.
HOME="$home" PATH="$tmp/bin" MAKEWHATIS_LOG="$log" /bin/sh "$hook"
[ "$(cat "$log")" = "$man_dir" ] || fail 'unexpected makewhatis arguments'

# A failing makewhatis must fail the chezmoi apply, not silently succeed.
printf '%s\n' '#!/bin/sh' 'exit 23' > "$tmp/bin/makewhatis"
chmod +x "$tmp/bin/makewhatis"
if HOME="$home" PATH="$tmp/bin" MAKEWHATIS_LOG="$log" /bin/sh "$hook"; then
  fail 'ignored makewhatis failure'
fi

printf '%s\n' 'man-db hook tests passed'

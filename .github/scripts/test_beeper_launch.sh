#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
launcher="$repo_root/home/dot_local/bin/executable_beeper-launch"
sh -n "$launcher"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/home/bin"
export HOME="$tmp/home"
export BEEPER_TEST_LOG="$tmp/launch.log"
export PATH="$tmp/bin:/usr/bin:/bin"

cat > "$tmp/bin/flatpak" <<'SH'
#!/bin/sh
case "$1" in
  info)
    [ "$2" = "--user" ] && [ "$3" = "com.automattic.Beeper" ] || exit 9
    [ "${FLATPAK_INSTALLED:-0}" = 1 ]
    ;;
  run)
    [ "$2" = "--user" ] && [ "$3" = "com.automattic.Beeper" ] || exit 9
    printf 'flatpak:%s\n' "$4" >> "$BEEPER_TEST_LOG"
    [ "${FLATPAK_RUN_FAIL:-0}" != 1 ]
    ;;
  *) exit 9 ;;
esac
SH
cat > "$tmp/bin/beeper-appimage" <<'SH'
#!/bin/sh
printf 'appimage:%s\n' "$1" >> "$BEEPER_TEST_LOG"
SH
cat > "$tmp/bin/beeper" <<'SH'
#!/bin/sh
printf 'beeper:%s\n' "$1" >> "$BEEPER_TEST_LOG"
SH
cat > "$tmp/bin/notify-send" <<'SH'
#!/bin/sh
printf 'notify\n' >> "$BEEPER_TEST_LOG"
SH
chmod +x "$tmp/bin"/*

# Prefer the FlatPark per-user app even if legacy binaries also exist.
FLATPAK_INSTALLED=1 sh "$launcher" one
grep -Fqx 'flatpak:one' "$BEEPER_TEST_LOG"
! grep -q '^appimage:' "$BEEPER_TEST_LOG"

# Missing Flatpak should use the legacy AppImage.
: > "$BEEPER_TEST_LOG"
FLATPAK_INSTALLED=0 sh "$launcher" two
grep -Fqx 'appimage:two' "$BEEPER_TEST_LOG"

# An installed Flatpak whose launch fails should also use the fallback.
: > "$BEEPER_TEST_LOG"
FLATPAK_INSTALLED=1 FLATPAK_RUN_FAIL=1 sh "$launcher" three
grep -Fqx 'flatpak:three' "$BEEPER_TEST_LOG"
grep -Fqx 'appimage:three' "$BEEPER_TEST_LOG"

# Fall back to the other legacy executable if the AppImage command is absent.
mv "$tmp/bin/beeper-appimage" "$tmp/old-appimage"
: > "$BEEPER_TEST_LOG"
FLATPAK_INSTALLED=0 sh "$launcher" four
grep -Fqx 'beeper:four' "$BEEPER_TEST_LOG"

# Support the previously ignored ~/bin/beeper path even if it is not on PATH.
mv "$tmp/bin/beeper" "$tmp/home/bin/beeper"
: > "$BEEPER_TEST_LOG"
FLATPAK_INSTALLED=0 sh "$launcher" five
grep -Fqx 'beeper:five' "$BEEPER_TEST_LOG"

# No installed app or legacy fallback must fail visibly.
rm "$tmp/home/bin/beeper"
: > "$BEEPER_TEST_LOG"
if FLATPAK_INSTALLED=0 sh "$launcher" six >"$tmp/stdout" 2>"$tmp/stderr"; then
  echo 'Beeper launcher unexpectedly succeeded without an installation' >&2
  exit 1
fi
grep -Fq 'Beeper unavailable' "$tmp/stderr"
grep -Fqx 'notify' "$BEEPER_TEST_LOG"
echo 'Beeper launcher fallback tests passed.'

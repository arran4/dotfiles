#!/bin/sh
# Test the installed arran4/txtar CLI (subcommands, not upstream Go flags).
# Creates no persistent test output and needs no network or credentials.
set -eu
command -v txtar >/dev/null 2>&1 || { echo "txtar missing" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/source/nested" "$tmp/unpacked"
printf '%s\n' 'a fixture line' > "$tmp/source/nested/test.txt"
(
  cd "$tmp"
  txtar create -r source > example.txtar
  txtar list example.txtar > listing
)
grep -Eq 'source/nested/test.txt$' "$tmp/listing"
txtar cat -t "$tmp/example.txtar" source/nested/test.txt > "$tmp/cat.txt"
cmp "$tmp/source/nested/test.txt" "$tmp/cat.txt"
txtar extract -d "$tmp/unpacked" "$tmp/example.txtar"
cmp "$tmp/source/nested/test.txt" "$tmp/unpacked/source/nested/test.txt"
txtar comment --comment "fixture comment" "$tmp/example.txtar"
txtar comment "$tmp/example.txtar" | grep -Fq "fixture comment"
# The current CLI warns and skips unsafe relative member names; it does not
# return an error for each skipped entry. Verify no path escapes this test root.
printf '%s\n' '-- ../escaped.txt --' 'escape attempt' > "$tmp/unsafe.txtar"
txtar extract -d "$tmp/unpacked" "$tmp/unsafe.txtar" 2>"$tmp/warnings"
grep -Fq 'unsafe path' "$tmp/warnings"
test ! -e "$tmp/escaped.txt"
echo 'arran4/txtar CLI smoke test passed.'

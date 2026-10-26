#!/bin/sh
# Exercise the actual pinned txtar executable; no credentials/network needed.
set -eu
command -v txtar >/dev/null 2>&1 || { echo "txtar missing" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/source/nested" "$tmp/unpacked"
printf '%s\n' 'a fixture line' > "$tmp/source/nested/test.txt"
printf '%s\n' 'fixture comment' > "$tmp/comment"
(
  cd "$tmp"
  txtar source < comment > example.txtar
  txtar --list < example.txtar > listing
)
grep -Fxq 'source/nested/test.txt' "$tmp/listing"
(
  cd "$tmp/unpacked"
  txtar --extract < "$tmp/example.txtar" > "$tmp/extracted-comment"
)
cmp "$tmp/source/nested/test.txt" "$tmp/unpacked/source/nested/test.txt"
grep -Fq 'fixture comment' "$tmp/extracted-comment"
# Parent traversal must fail without --unsafe and must never create the target.
printf '%s\n' '-- ../escaped.txt --' 'escape attempt' > "$tmp/unsafe.txtar"
if (
  cd "$tmp/unpacked"
  txtar --extract < "$tmp/unsafe.txtar" > /dev/null 2>&1
); then
  echo "txtar accepted a parent traversal archive" >&2
  exit 1
fi
test ! -e "$tmp/escaped.txt"
echo 'TXTAR CLI smoke test passed.'

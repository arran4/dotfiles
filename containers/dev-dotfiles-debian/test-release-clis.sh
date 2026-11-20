#!/bin/sh
# Offline functional smoke tests of the four Go-installed CLI binaries.
# Run both after installation and as an unprivileged user during home seeding.
set -eu

for tool in gosubc g2 header rntocase; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "missing developer CLI: $tool" >&2
    exit 1
  }
done

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

# Actual built-in generator operation; no target Go project or downloads.
gosubc template layout > "$tmp/gosubc-layout"
test -s "$tmp/gosubc-layout"

# Registered g2 lint rules should be discoverable and machine readable.
g2 lint list -format json > "$tmp/g2-lint.json"
jq -e 'type == "array" and length > 0' "$tmp/g2-lint.json" >/dev/null

# Offline rule discovery must work without fetching a live website.
header lint-rule-lists > "$tmp/header-lists"
header lint-rules > "$tmp/header-rules"
grep -Fq 'Available Lint Lists:' "$tmp/header-lists"
grep -Fq 'Available Lint Rules:' "$tmp/header-rules"

# A preview must not rename the actual source path.
printf 'safe input\n' > "$tmp/Example File.txt"
rntocase snake --dry-run "$tmp/Example File.txt" > "$tmp/rename-preview"
test -f "$tmp/Example File.txt"
test ! -e "$tmp/example_file.txt"

# Check the locally built txtar CLI without a separate test script.
command -v txtar >/dev/null 2>&1 || { echo "txtar missing" >&2; exit 1; }
mkdir -p "$tmp/source/nested" "$tmp/unpacked"
printf "%s\n" "a fixture line" > "$tmp/source/nested/test.txt"
(
  cd "$tmp"
  txtar create -r source > example.txtar
  txtar list example.txtar > listing
)
grep -Eq "source/nested/test.txt$" "$tmp/listing"
txtar cat -t "$tmp/example.txtar" source/nested/test.txt > "$tmp/cat.txt"
cmp "$tmp/source/nested/test.txt" "$tmp/cat.txt"
txtar extract -d "$tmp/unpacked" "$tmp/example.txtar"
cmp "$tmp/source/nested/test.txt" "$tmp/unpacked/source/nested/test.txt"
txtar comment --comment "fixture comment" "$tmp/example.txtar"
txtar comment "$tmp/example.txtar" | grep -Fq "fixture comment"
# Unsafe parent paths are currently skipped with warnings, not necessarily errors.
printf "%s\n" "-- ../escaped.txt --" "escape attempt" > "$tmp/unsafe.txtar"
txtar extract -d "$tmp/unpacked" "$tmp/unsafe.txtar" 2>"$tmp/warnings"
grep -Fq "unsafe path" "$tmp/warnings"
test ! -e "$tmp/escaped.txt"
echo 'Development CLI smoke tests passed.'

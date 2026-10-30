#!/bin/sh
# Install one released Go CLI from an exact release/version, not from @latest.
# Usage: install-release-cli <gosubc|g2|header|rntocase> <X.Y.Z>
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <gosubc|g2|header|rntocase> <X.Y.Z>" >&2
  exit 2
fi

tool=$1
version=$2
case "$tool" in
  gosubc) repo=go-subcommand ;;
  g2|header|rntocase) repo=$tool ;;
  *) echo "unsupported release tool: $tool" >&2; exit 2 ;;
esac
case "$version" in
  ''|*[!0-9.]*) echo "invalid release version: $version" >&2; exit 2 ;;
esac

arch=$(dpkg --print-architecture)
case "$arch" in
  amd64|arm64) ;;
  *) echo "no published $tool release for architecture: $arch" >&2; exit 1 ;;
esac

asset="${tool}_${version}_linux_${arch}.tar.gz"
base="https://github.com/arran4/${repo}/releases/download/v${version}"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
cd "$tmp"

curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
  --output "$asset" "$base/$asset"
curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
  --output checksums.txt "$base/checksums.txt"

# Fail closed if no unambiguous published checksum matches the exact asset.
awk -v name="$asset" '$2 == name && length($1) == 64 && $1 ~ /^[[:xdigit:]]+$/ {print}' \
  checksums.txt > expected.sha256
if [ "$(wc -l < expected.sha256)" -ne 1 ]; then
  echo "missing or ambiguous checksum for $asset" >&2
  exit 1
fi
sha256sum --check expected.sha256

# Extract only the named executable. Do not unpack arbitrary archive members
# into /usr/local/bin or trust tar paths beyond the expected root-level binary.
tar -tzf "$asset" > members.txt
awk -v name="$tool" '$0 == name || $0 == "./" name {print}' members.txt > binary-members.txt
if [ "$(wc -l < binary-members.txt)" -ne 1 ]; then
  echo "expected one root-level $tool executable in $asset" >&2
  exit 1
fi
member=$(cat binary-members.txt)
tar -xOzf "$asset" "$member" > "$tool"
test -s "$tool"
install -m 0755 "$tool" "/usr/local/bin/$tool"
command -v "$tool"

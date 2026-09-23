#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
initializer="$here/antigravity-settings.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
home="$tmp/home"
settings="$home/.gemini/antigravity-cli/settings.json"

# A fresh home gets only the expected workspace trust settings.
HOME="$home" sh "$initializer"
cat > "$tmp/expected.json" <<'EOF'
{
  "trustedWorkspaces": [
    "/workspace"
  ]
}
EOF
cmp "$tmp/expected.json" "$settings"
test "$(stat -c %a "$settings")" = 600

# Existing custom settings are preserved verbatim across repeated starts.
printf '{"trustedWorkspaces":["/another/path"],"otherSetting":true}\n' > "$settings"
cp "$settings" "$tmp/custom.json"
HOME="$home" sh "$initializer"
cmp "$tmp/custom.json" "$settings"

# Do not follow an existing dangling symlink to create or replace a target.
rm "$settings"
ln -s "$tmp/missing.json" "$settings"
HOME="$home" sh "$initializer"
test -L "$settings"
test ! -e "$tmp/missing.json"

# The built home archive must not carry settings that overlay a persistent home.
grep -Fq -- "--exclude='./.gemini/antigravity-cli/settings.json'" "$here/Dockerfile"

echo 'Antigravity settings initialization tests passed.'

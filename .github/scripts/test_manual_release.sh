#!/usr/bin/env bash
# Exercise tag preparation and the real release wrapper against local Git repos.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
cleanup() {
  local status=$?
  if [[ $status != 0 && -f "$tmp/log" ]]; then
    cat "$tmp/log" >&2
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/work/dot_local/bin"
cp "$root/dot_local/bin/executable_gh-release.sh" "$tmp/work/dot_local/bin/"

# Substitute only git-tag-inc's external interface. The integration check can
# also run with the real installed binary via RELEASE_TEST_REAL_TAG_INC=true.
if [[ ${RELEASE_TEST_REAL_TAG_INC:-false} != true ]]; then
  cat > "$tmp/bin/git-tag-inc" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
preview=false
repeating=false
for arg in "$@"; do
  case "$arg" in
    -print-version-only|-dry) preview=true ;;
    -repeating) repeating=true ;;
    patch) ;;
    *) echo "Unexpected argument: $arg" >&2; exit 1 ;;
  esac
done
if [[ $repeating == false ]] && git tag --points-at HEAD | grep -q '^v'; then
  echo "Hash is the same for this and previous tag: (v0.2.45)"
  exit 1
fi
last=$(git tag -l 'v0.2.*' --sort=-version:refname | head -1)
next="v0.2.$((${last##*.} + 1))"
if [[ $preview == true ]]; then
  echo "$next"
else
  git tag "$next"
fi
SH
  chmod +x "$tmp/bin/git-tag-inc"
fi
export PATH="$tmp/bin:$PATH"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
git init --bare -q "$tmp/origin.git"
cd "$tmp/work"
git init -q
git config user.name 'Release test'
git config user.email 'release-test@example.invalid'
git remote add origin "$tmp/origin.git"
git add .
git commit -qm initial
git tag -am v0.2.45 v0.2.45
git push -q origin HEAD --tags
export RELEASE_MODE=release-patch RELEASE_VERSION_OVERRIDE="" FORCE_RELEASE=false
export GITHUB_OUTPUT="$tmp/output"

prepare() {
  : > "$GITHUB_OUTPUT"
  bash "$root/.github/scripts/prepare_release_tag.sh" > "$tmp/log" 2>&1
}

expect_tag() {
  local tag=$1
  grep -Fxq "tag=$tag" "$GITHUB_OUTPUT"
  [[ $(git --git-dir="$tmp/origin.git" rev-parse "refs/tags/$tag^{commit}") == "$(git rev-parse HEAD)" ]]
}

prepare
grep -Fxq 'tag=' "$GITHUB_OUTPUT"
[[ $(git tag -l | wc -l) == 1 ]]
echo 'PASS unchanged source skips by default'

FORCE_RELEASE=true prepare
expect_tag v0.2.46
[[ $(git rev-parse 'v0.2.45^{commit}') == "$(git rev-parse 'v0.2.46^{commit}')" ]]
echo 'PASS forced release creates and pushes a new tag on the same commit'

FORCE_RELEASE=true prepare
expect_tag v0.2.47
echo 'PASS a second forced release advances again'

if FORCE_RELEASE=true RELEASE_VERSION_OVERRIDE=0.2.46 prepare; then
  echo 'FAIL force accepted an existing override' >&2; exit 1
fi
if FORCE_RELEASE=true RELEASE_VERSION_OVERRIDE=invalid prepare; then
  echo 'FAIL force accepted an invalid override' >&2; exit 1
fi
echo 'PASS force preserves duplicate and invalid override rejection'

RELEASE_VERSION_OVERRIDE=0.2.50 FORCE_RELEASE=true prepare
expect_tag v0.2.50
echo 'PASS force supports an explicit new version'

git commit --allow-empty -qm changed
prepare
expect_tag v0.2.51
echo 'PASS a changed commit releases normally'

cat > "$tmp/origin.git/hooks/pre-receive" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$tmp/origin.git/hooks/pre-receive"
if FORCE_RELEASE=true prepare; then
  echo 'FAIL rejected tag push reported success' >&2; exit 1
fi
[[ ! -s "$GITHUB_OUTPUT" ]]
[[ -z $(git tag -l v0.2.52) ]]
echo 'PASS push failure prevents dispatch output and cleans up the new local tag'

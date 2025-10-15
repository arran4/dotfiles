#!/bin/sh
set -eux

prerelease_flag=""
for arg in "$@"; do
  case "$arg" in
    test|alpha|beta|rc)
      prerelease_flag="--prerelease"
      break
      ;;
  esac
done

version=$(git-tag-inc -print-version-only "$@")
if [ "${version}" = "" ]; then
  echo failed to generate version
  exit 1
fi
git-tag-inc "$@"
git push --tags
if [ -n "$prerelease_flag" ]; then
  gh release create "$version" --generate-notes "$prerelease_flag"
else
  gh release create "$version" --generate-notes
fi


#!/bin/sh
set -eux

version=$(git-tag-inc -print-version-only "$@")
if [ "${version}" = "" ]; then
  echo failed to generate version
  exit 1
fi
git-tag-inc "$@"
git push --tags
gh release create "$version" --generate-notes


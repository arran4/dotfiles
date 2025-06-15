#!/bin/sh
set -eu

version=$(git-tag-inc "$@" -print-version-only)
git-tag-inc "$@"
gh release create "$version" --generate-notes


#!/bin/sh
set -eux

prerelease_flag=""
git_tag_inc_args=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    test|alpha|beta|rc)
      prerelease_flag="--prerelease"
      ;;
  esac
  if [ -z "$git_tag_inc_args" ]; then
    git_tag_inc_args="$1"
  else
    git_tag_inc_args="$git_tag_inc_args $1"
  fi
  shift
done

if [ -n "$git_tag_inc_args" ]; then
  # shellcheck disable=SC2086
  set -- $git_tag_inc_args
else
  set --
fi

version=$(git-tag-inc -print-version-only "$@")
if [ "${version}" = "" ]; then
  echo failed to generate version
  exit 1
fi

git-tag-inc "$@"

if ! git push --tags; then
  echo "Retrying git push --tags after failure" >&2
  if ! git push --tags; then
    echo "Second git push --tags attempt failed; removing tag $version" >&2
    git tag -d "$version"
    exit 1
  fi
fi

if [ -n "$prerelease_flag" ]; then
  gh release create "$version" --generate-notes "$prerelease_flag"
else
  gh release create "$version" --generate-notes
fi


#!/bin/sh
set -eux

git_tag_inc_args=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    test|alpha|beta|rc)
      # Handled by GitHub Actions
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

version=$(git-tag-inc -print-version-only "$@" 2>&1) || ret=$?
if [ "${ret:-0}" -ne 0 ] || [ -z "${version}" ]; then
  # Retry with dry run to surface diagnostic information
  full_out=$(git-tag-inc -dry "$@" 2>&1) || true
  if echo "$full_out" | grep -q "Hash is the same for this and previous tag"; then
    existing_tag=$(echo "$full_out" | grep -o '(v[^)]*)' | tr -d '()')
    echo "Already released as ${existing_tag:-an existing tag}. Skipping."
    exit 0
  else
    echo "failed to generate version: $full_out" >&2
    exit 1
  fi
fi
git-tag-inc "$@"

if ! git push origin "$version"; then
  echo "Retrying git push origin \"$version\" after failure" >&2
  if ! git push origin "$version"; then
    echo "Second git push origin \"$version\" attempt failed; removing tag $version" >&2
    git tag -d "$version"
    exit 1
  fi
fi

# Script now solely computes the tag and pushes it.
# GitHub Actions CI is the sole owner of GitHub Release creation.

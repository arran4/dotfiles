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

discussion_arg=""
repo_info=$(gh repo view --json owner,name,hasDiscussionsEnabled --jq '.owner.login + " " + .name + " " + (.hasDiscussionsEnabled|tostring)' || echo "")

if [ -n "$repo_info" ]; then
  owner=$(echo "$repo_info" | cut -d' ' -f1)
  name=$(echo "$repo_info" | cut -d' ' -f2)
  enabled=$(echo "$repo_info" | cut -d' ' -f3)

  if [ "$enabled" = "true" ]; then
    categories=$(gh api graphql -F owner="$owner" -F name="$name" -f query='
      query($owner: String!, $name: String!) {
        repository(owner: $owner, name: $name) {
          discussionCategories(first: 10) {
            nodes {
              name
            }
          }
        }
      }' --jq '.data.repository.discussionCategories.nodes[].name')

    if echo "$categories" | grep -q "^Announcements$"; then
      discussion_arg="--discussion-category Announcements"
    elif echo "$categories" | grep -q "^General$"; then
      discussion_arg="--discussion-category General"
    fi
  fi
fi

if [ -n "$prerelease_flag" ]; then
  # shellcheck disable=SC2086
  gh release create "$version" --generate-notes "$prerelease_flag" $discussion_arg
else
  # shellcheck disable=SC2086
  gh release create "$version" --generate-notes $discussion_arg
fi


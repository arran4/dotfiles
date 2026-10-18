#!/usr/bin/env bash
# Select safe, moving GHCR aliases for a stable release tag.
# Run immediately before promotion, inside the serialized GHCR alias job.
set -euo pipefail

stable_tag_re='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

# Arguments: release tag, raw output from "git ls-remote --tags origin".
# Output: zero or more alias names, one per line. Unexpected input fails closed.
moving_aliases() {
  local release_tag=$1 refs=$2 major minor line sha ref tag
  local -a stable_tags=() major_tags=() minor_tags=()

  # Prerelease/test tags cannot move stable image aliases.
  [[ $release_tag =~ $stable_tag_re ]] || return 0
  major=${BASH_REMATCH[1]}
  minor=${BASH_REMATCH[2]}

  while IFS= read -r line; do
    [[ -n $line ]] || continue
    if [[ $line != *$'\t'* ]]; then
      printf 'Invalid remote tag listing\n' >&2
      return 1
    fi
    sha=${line%%$'\t'*}
    ref=${line#*$'\t'}
    if [[ ! $sha =~ ^[[:xdigit:]]+$ || $ref != refs/tags/* ]]; then
      printf 'Invalid remote tag reference\n' >&2
      return 1
    fi
    tag=${ref#refs/tags/}
    [[ $tag != *'^{}' ]] || continue
    [[ $tag =~ $stable_tag_re ]] || continue
    stable_tags+=("$tag")
    if [[ $tag == "v${major}."* ]]; then
      major_tags+=("$tag")
      if [[ $tag == "v${major}.${minor}."* ]]; then
        minor_tags+=("$tag")
      fi
    fi
  done <<< "$refs"

  if [[ ${#minor_tags[@]} -eq 0 ]]; then
    printf 'Release tag %s is absent from remote stable tags\n' "$release_tag" >&2
    return 1
  fi
  local found=false
  for tag in "${minor_tags[@]}"; do
    [[ $tag != "$release_tag" ]] || found=true
  done
  if [[ $found != true ]]; then
    printf 'Release tag %s is absent from remote stable tags\n' "$release_tag" >&2
    return 1
  fi

  # GNU sort -V compares components numerically, without shell integer overflow.
  local newest_minor newest_major newest_global
  newest_minor=$(printf '%s\n' "${minor_tags[@]}" | LC_ALL=C sort -V | tail -n 1)
  newest_major=$(printf '%s\n' "${major_tags[@]}" | LC_ALL=C sort -V | tail -n 1)
  newest_global=$(printf '%s\n' "${stable_tags[@]}" | LC_ALL=C sort -V | tail -n 1)

  [[ $release_tag != "$newest_minor" ]] || printf 'v%s.%s\n' "$major" "$minor"
  [[ $release_tag != "$newest_major" ]] || printf 'v%s\n' "$major"
  [[ $release_tag != "$newest_global" ]] || printf 'latest\n'
}

main() {
  if [[ $# -ne 1 ]]; then
    printf 'Usage: bash %s <release-tag>\n' "$0" >&2
    return 2
  fi
  local refs
  if ! refs=$(git ls-remote --tags origin); then
    printf 'Could not retrieve remote Git tags; aliases unchanged\n' >&2
    return 1
  fi
  moving_aliases "$1" "$refs"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi

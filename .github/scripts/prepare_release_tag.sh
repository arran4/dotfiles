#!/usr/bin/env bash
# Called under the workflow's serialized version-tag creation job.
set -euo pipefail

tag=""
override_version=${RELEASE_VERSION_OVERRIDE:-}
force_release=${FORCE_RELEASE:-false}

case "$force_release" in
  true|false) ;;
  *) echo "Invalid FORCE_RELEASE: $force_release" >&2; exit 1 ;;
esac

if [[ -n "$override_version" ]]; then
  tag="v${override_version#v}"
  if ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc|test)\.[0-9]+)?$ ]]; then
    echo "Invalid release version override format: $tag" >&2
    exit 1
  fi
  if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    echo "Tag $tag already exists!" >&2
    exit 1
  fi
  git tag "$tag"
  git push origin "$tag"
else
  rel_type=${RELEASE_MODE#release-}
  tag_args=()
  if [[ "$force_release" == true ]]; then
    # Permit a new version on the same commit, without allowing backwards
    # versions or overwriting existing tags (unlike git-tag-inc's -force).
    tag_args+=(-repeating)
  fi
  tag_args+=("$rel_type")

  tag="$(git-tag-inc -print-version-only "${tag_args[@]}" 2>&1)" || ret=$?
  if [[ "${ret:-0}" -ne 0 ]]; then
    full_out="$(git-tag-inc -dry "${tag_args[@]}" 2>&1)" || true
    if [[ "$force_release" == false ]] && grep -q "Hash is the same for this and previous tag" <<< "$full_out"; then
      existing_tag=$(grep -oP '\(v[^\)]+\)' <<< "$full_out" | tr -d '()')
      echo "Already released as ${existing_tag:-an existing tag}. Skipping tag creation. Enable force_release to refresh bundled tools."
      tag=""
    else
      echo "Failed to compute release tag: $full_out" >&2
      exit 1
    fi
  fi

  if [[ -n "$tag" ]]; then
    release_script="./home/dot_local/bin/executable_gh-release.sh"
    if [[ ! -x "$release_script" ]]; then
      release_script="./dot_local/bin/executable_gh-release.sh"
    fi
    "$release_script" "${tag_args[@]}"
  fi
fi

echo "tag=$tag" >> "$GITHUB_OUTPUT"

#!/usr/bin/env bash
# Offline tests for GHCR alias monotonicity and CI release safety.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=.github/scripts/release_aliases.sh
source "$script_dir/release_aliases.sh"
workflow="$script_dir/../workflows/ci.yml"
passed=0

assert_eq() {
  local name=$1 expected=$2 actual=$3
  if [[ $actual != "$expected" ]]; then
    printf 'FAIL %s: expected [%s], got [%s]\n' "$name" "$expected" "$actual" >&2
    return 1
  fi
  passed=$((passed + 1))
  printf 'PASS %s\n' "$name"
}

refs_for() {
  local tag
  for tag in "$@"; do
    printf 'deadbeef\trefs/tags/%s\n' "$tag"
  done
}

expect_aliases() {
  local name=$1 release=$2 expected=$3 refs actual
  shift 3
  refs=$(refs_for "$@")
  actual=$(moving_aliases "$release" "$refs")
  assert_eq "$name" "$expected" "$actual"
}

expect_error() {
  local name=$1 release=$2 refs=$3
  if moving_aliases "$release" "$refs" >/dev/null 2>&1; then
    printf 'FAIL %s: expected an error\n' "$name" >&2
    return 1
  fi
  passed=$((passed + 1))
  printf 'PASS %s\n' "$name"
}

expect_aliases "latest stable" "v0.2.42" $'v0.2\nv0\nlatest' "v0.2.41" "v0.2.42"
expect_aliases "older patch does not roll back" "v0.2.41" "" "v0.2.41" "v0.2.42"
expect_aliases "older minor gets only own minor alias" "v0.2.42" "v0.2" "v0.2.42" "v0.3.1"
expect_aliases "older major gets only own major aliases" "v1.2.0" $'v1.2\nv1' "v1.2.0" "v2.0.0"
expect_aliases "numeric version ordering" "v0.2.9" "" "v0.2.9" "v0.2.10"
expect_aliases "prerelease never moves aliases" "v0.2.43-rc.1" "" "v0.2.43-rc.1"
expect_aliases "test tag never moves aliases" "test-5" "" "test-5"
expect_aliases "malformed tag never moves aliases" "v01.2.3" "" "v01.2.3"
expect_aliases "extra version segment never moves aliases" "v0.2.3.4" "" "v0.2.3.4"
expect_aliases "ignore annotated tag dereference" "v0.2.42" $'v0.2\nv0\nlatest' "v0.2.42" "v0.2.42^{}"
expect_error "missing remote tag fails closed" "v0.2.43" "$(refs_for v0.2.42)"
expect_error "unexpected remote response fails closed" "v0.2.43" "not a ref"
expect_error "no remote tags fails closed" "v0.2.43" ""

job_body() {
  local name=$1
  awk -v name="$name" '
    $0 == "  " name ":" { found=1; next }
    found && /^  [a-z][a-z0-9-]*:/ { exit }
    found { print }
  ' "$workflow"
}

assert_has() {
  local name=$1 content=$2 needle=$3
  if ! grep -Fq -- "$needle" <<< "$content"; then
    printf 'FAIL %s: missing [%s]\n' "$name" "$needle" >&2
    return 1
  fi
  passed=$((passed + 1))
  printf 'PASS %s\n' "$name"
}

for job in manual-release-tag package-dotfiles docker-release; do
  body=$(job_body "$job")
  assert_has "$job needs successful ShellCheck" "$body" "needs.shell-check.result == 'success'"
  assert_has "$job needs successful Gitleaks" "$body" "needs.gitleaks.result == 'success'"
done

body=$(job_body docker-release)
assert_has "image metadata disables automatic latest" "$body" "latest=false"
assert_has "image version comes from release ref" "$body" "type=raw,value=\${{ github.ref_name }}"
assert_has "image release job serialized" "$body" "queue: max"
assert_has "image release not cancelled" "$body" "cancel-in-progress: false"
assert_has "alias selection happens before push" "$body" "aliases=\"\$(bash .github/scripts/release_aliases.sh \"\$RELEASE_TAG\")\""
assert_has "image tags use computed safe aliases" "$body" "steps.image_tags.outputs.tags"
assert_has "image version always included" "$body" "\"\$IMAGE\" \"\$RELEASE_TAG\""
assert_eq "one publishing build/push action" "1" "$(grep -Fc -- 'uses: docker/build-push-action@v6' <<< "$body")"
if grep -q '^  publish-image-aliases:' "$workflow"; then
  printf 'FAIL: obsolete alias-promotion job remains\n' >&2
  exit 1
fi

body=$(job_body manual-release-tag)
assert_has "tag creation queued" "$body" "queue: max"
assert_has "tag creation not cancelled" "$body" "cancel-in-progress: false"

front=$(sed '/^jobs:$/,$d' "$workflow")
assert_has "release runs isolated from CI cancellation" "$front" "format('release-{0}', github.run_id)"
assert_has "publish-tag included in release routing" "$front" "inputs.mode == 'publish-tag'"
assert_has "CI cancellation preserved" "$front" "cancel-in-progress: \${{ !("

body=$(job_body shell-check)
assert_has "Bash release tests run in CI" "$body" "bash .github/scripts/test_release_safety.sh"

printf 'All %d release safety assertions passed\n' "$passed"

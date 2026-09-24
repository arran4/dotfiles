#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/project"

# Fake the container CLI; no daemon, registry, image or credentials are used.
cat > "$tmp/bin/container-mock" <<'MOCK'
#!/bin/sh
set -eu
printf '%s %s\n' "${0##*/}" "$*" >> "$MOCK_LOG"
case "$1:$2" in
  container:exists|container:inspect)
    case "${3:-}" in
      *-home) [ "${MOCK_HOME_CONTAINER:-0}" = 1 ] ;;
      *) [ "${MOCK_LEGACY_CONTAINER:-0}" = 1 ] ;;
    esac
    exit $? ;;
  image:exists|image:inspect)
    if [ "${3:-}" = '--format' ]; then
      printf '%s\n' "${MOCK_SEED_LABEL:-<no value>}"
      exit 0
    fi
    if [ "${MOCK_IMAGE_PRESENT:-1}" = 1 ]; then
      exit 0
    fi
    if [ -f "$MOCK_PULLED_IMAGE" ] && [ "$(cat "$MOCK_PULLED_IMAGE")" = "${3:-}" ]; then
      exit 0
    fi
    exit 1 ;;
  inspect:*) printf '%s\n' "${MOCK_RUNNING:-false}"; exit 0 ;;
  pull:*)
    [ "${MOCK_PULL_FAIL:-0}" != 1 ] || exit 1
    printf '%s\n' "$2" > "$MOCK_PULLED_IMAGE"
    exit 0 ;;
  run:*) printf '%s\n' "$@"; exit 0 ;;
  start:*) exit 0 ;;
esac
printf 'Unexpected container command: %s\n' "$*" >&2
exit 1
MOCK
chmod +x "$tmp/bin/container-mock"
ln -s container-mock "$tmp/bin/podman"
ln -s container-mock "$tmp/bin/docker"
export PATH="$tmp/bin:$PATH"
export MOCK_LOG="$tmp/calls"
export MOCK_PULLED_IMAGE="$tmp/pulled-image"
# The ordinary layout tests run without host /dev/fuse. Nested-mode tests
# separately exercise argument generation and failure on unsupported hosts.
export DEV_PODMAN_SECURITY=off
cd "$tmp/project"

assert_line() { grep -Fx -- "$1" "$tmp/output" >/dev/null || { echo "Missing argument: $1" >&2; exit 1; }; }
assert_absent() { if grep -Fx -- "$1" "$tmp/output" >/dev/null; then echo "Unexpected argument: $1" >&2; exit 1; fi; }
assert_call() { grep -F -- "$1" "$MOCK_LOG" >/dev/null || { echo "Missing call: $1" >&2; exit 1; }; }
assert_no_call() { if grep -F -- "$1" "$MOCK_LOG" >/dev/null; then echo "Unexpected call: $1" >&2; exit 1; fi; }

for engine in podman docker; do
  launcher="$root/dot_local/bin/executable_run-dev-${engine}.sh"
  sh -n "$launcher"
  rm -f "$MOCK_PULLED_IMAGE"

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_call "$engine pull ghcr.io/arran4/dev-dotfiles-debian:latest"
  assert_line 'ghcr.io/arran4/dev-dotfiles-debian:latest'
  assert_line 'dev-agent-check-home'
  assert_line 'DEV_HOME_VOLUME_INIT=1'
  assert_line 'type=volume,src=dev-agent-check-project-home,dst=/home/user'
  assert_absent 'DEV_FORGE_VOLUME_INIT=1'
  assert_absent 'type=volume,src=dev-agent-check-gh,dst=/home/user/.config/gh'
  assert_absent '--privileged'
  assert_absent '--device'

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 DEV_PULL_MODE=missing SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_no_call "$engine pull "

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 DEV_PULL_MODE=never SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_no_call "$engine pull "

  : > "$MOCK_LOG"
  SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_line 'dev-agent-check'
  assert_line 'DEV_FORGE_VOLUME_INIT=1'
  assert_line 'type=volume,src=dev-agent-check-gh,dst=/home/user/.config/gh'
  assert_absent 'DEV_HOME_VOLUME_INIT=1'
  assert_absent 'type=volume,src=dev-agent-check-project-home,dst=/home/user'

  : > "$MOCK_LOG"
  MOCK_LEGACY_CONTAINER=1 MOCK_SEED_LABEL=1 SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_call "$engine start -ai"
  assert_no_call "$engine pull "
  assert_no_call "$engine run "

  : > "$MOCK_LOG"
  MOCK_LEGACY_CONTAINER=1 MOCK_SEED_LABEL=1 DEV_NEW_HOME=1 SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_line 'dev-agent-check-home'
  assert_line 'type=volume,src=dev-agent-check-project-home,dst=/home/user'
  assert_no_call "$engine start "
  assert_absent 'type=volume,src=dev-agent-check-gh,dst=/home/user/.config/gh'

  : > "$MOCK_LOG"
  if DEV_NEW_HOME=1 SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected old image to reject DEV_NEW_HOME=1' >&2; exit 1
  fi
  grep -F 'does not support the versioned home layout' "$tmp/error" >/dev/null
  assert_no_call "$engine run "

  : > "$MOCK_LOG"
  MOCK_HOME_CONTAINER=1 MOCK_IMAGE_PRESENT=0 SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"
  assert_call "$engine start -ai"
  assert_no_call "$engine pull "

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 SANDBOX_NAME=check DEV_IMAGE=dev-dotfiles-local:dev "$launcher" > "$tmp/output"
  assert_no_call "$engine pull "
  assert_line 'dev-dotfiles-local:dev'
  assert_line 'dev-agent-check-home'
  assert_line 'DEV_HOME_VOLUME_INIT=1'
  assert_line 'type=volume,src=dev-agent-check-project-home,dst=/home/user'
  assert_absent 'DEV_FORGE_VOLUME_INIT=1'

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 DEV_HOME_MODE=container SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_line 'DEV_HOME_VOLUME_INIT=1'
  assert_absent 'type=volume,src=dev-agent-check-project-home,dst=/home/user'

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 DEV_WORKSPACE_MODE=volume SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_line 'type=volume,src=dev-agent-check-workspace,dst=/workspace'
  assert_line 'DEV_VOLUME_INIT=1'

  : > "$MOCK_LOG"
  rm -f "$MOCK_PULLED_IMAGE"
  MOCK_SEED_LABEL=1 MOCK_IMAGE_PRESENT=0 SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_call "$engine pull ghcr.io/arran4/dev-dotfiles-debian:latest"
  assert_line 'type=volume,src=dev-agent-check-project-home,dst=/home/user'

  : > "$MOCK_LOG"
  if MOCK_IMAGE_PRESENT=0 MOCK_PULL_FAIL=1 SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected published-image pull failure' >&2; exit 1
  fi
  assert_call "$engine pull ghcr.io/arran4/dev-dotfiles-debian:latest"
  grep -F 'Could not pull development image' "$tmp/error" >/dev/null
  assert_no_call "$engine run "

  : > "$MOCK_LOG"
  if MOCK_IMAGE_PRESENT=0 DEV_IMAGE=dev-dotfiles-local:dev SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected unavailable local-image failure' >&2; exit 1
  fi
  grep -F 'Build it from containers/dev-dotfiles-debian/Dockerfile' "$tmp/error" >/dev/null
  assert_no_call "$engine pull "

  : > "$MOCK_LOG"
  rm -f "$MOCK_PULLED_IMAGE"
  if MOCK_IMAGE_PRESENT=0 DEV_PULL_MODE=never SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected DEV_PULL_MODE=never to reject missing image' >&2; exit 1
  fi
  assert_no_call "$engine pull "
  assert_no_call "$engine run "

  : > "$MOCK_LOG"
  if DEV_IMAGE=dev-dotfiles-local:dev SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected unseeded custom image to be rejected' >&2; exit 1
  fi
  grep -F 'has no versioned home seed' "$tmp/error" >/dev/null
  assert_no_call "$engine run "

  # Default nested security needs a real /dev/fuse host device.
  if [ ! -c /dev/fuse ]; then
    : > "$MOCK_LOG"
    if DEV_PODMAN_SECURITY=nested MOCK_SEED_LABEL=1 "$launcher" > "$tmp/output" 2> "$tmp/error"; then
      echo 'Expected nested Podman mode to reject missing /dev/fuse' >&2; exit 1
    fi
    grep -F 'requires host /dev/fuse' "$tmp/error" >/dev/null
    assert_no_call "$engine run "
  fi

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 DEV_PODMAN_SECURITY=privileged DEV_PODMAN_PERSIST=1 "$launcher" > "$tmp/output"
  assert_line '--privileged'
  assert_line 'DEV_PODMAN_VOLUME_INIT=1'
  assert_line 'type=volume,src=dev-agent-project-podman,dst=/var/lib/dev-podman'
  assert_absent 'type=volume,src=dev-agent-project-docker,dst=/var/lib/docker'

  : > "$MOCK_LOG"
  MOCK_SEED_LABEL=1 DEV_PODMAN_SECURITY=off "$launcher" --podman-security=privileged > "$tmp/output"
  assert_line '--privileged'

  : > "$MOCK_LOG"
  if "$launcher" --podman-security=invalid > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected invalid Podman security mode to be rejected' >&2; exit 1
  fi
  grep -F 'Podman security must be' "$tmp/error" >/dev/null
  assert_no_call "$engine run "

done
printf 'Development launcher tests passed.\n'

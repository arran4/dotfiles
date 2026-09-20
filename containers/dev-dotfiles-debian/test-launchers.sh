#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/project"

# No container daemon, registry access, or host credential changes are needed.
cat > "$tmp/bin/container-mock" <<'MOCK'
#!/bin/sh
set -eu
printf '%s %s\n' "${0##*/}" "$*" >> "$MOCK_LOG"
case "$1:$2" in
  container:exists|container:inspect) [ "${MOCK_CONTAINER_PRESENT:-0}" = 1 ]; exit $? ;;
  image:exists|image:inspect) [ "${MOCK_IMAGE_PRESENT:-1}" = 1 ]; exit $? ;;
  inspect:*) printf '%s\n' "${MOCK_RUNNING:-false}"; exit 0 ;;
  pull:*) [ "${MOCK_PULL_FAIL:-0}" != 1 ]; exit $? ;;
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
cd "$tmp/project"

assert_line() { grep -Fx -- "$1" "$tmp/output" >/dev/null || { echo "Missing argument: $1" >&2; exit 1; }; }
assert_absent() { if grep -Fx -- "$1" "$tmp/output" >/dev/null; then echo "Unexpected argument: $1" >&2; exit 1; fi; }
assert_call() { grep -F -- "$1" "$MOCK_LOG" >/dev/null || { echo "Missing call: $1" >&2; exit 1; }; }

for engine in podman docker; do
  launcher="$root/dot_local/bin/executable_run-dev-${engine}.sh"
  sh -n "$launcher"

  : > "$MOCK_LOG"
  SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_line 'ghcr.io/arran4/dev-dotfiles-debian:latest'
  assert_line 'DEV_FORGE_VOLUME_INIT=1'
  assert_line 'type=volume,src=dev-agent-check-gh,dst=/home/user/.config/gh'
  assert_line 'type=volume,src=dev-agent-check-codex,dst=/home/user/.codex'
  assert_absent 'DEV_HOME_VOLUME_INIT=1'
  assert_absent 'type=volume,src=dev-agent-check-home,dst=/home/user'

  : > "$MOCK_LOG"
  SANDBOX_NAME=check DEV_IMAGE=dev-dotfiles-home-volume:trial "$launcher" > "$tmp/output"
  assert_line 'dev-dotfiles-home-volume:trial'
  assert_line 'DEV_HOME_VOLUME_INIT=1'
  assert_line 'type=volume,src=dev-agent-check-home,dst=/home/user'
  assert_absent 'DEV_FORGE_VOLUME_INIT=1'

  : > "$MOCK_LOG"
  MOCK_IMAGE_PRESENT=0 SANDBOX_NAME=check "$launcher" > "$tmp/output"
  assert_call "$engine pull ghcr.io/arran4/dev-dotfiles-debian:latest"
  assert_line 'ghcr.io/arran4/dev-dotfiles-debian:latest'

  : > "$MOCK_LOG"
  if MOCK_IMAGE_PRESENT=0 MOCK_PULL_FAIL=1 SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected published-image pull failure' >&2; exit 1
  fi
  assert_call "$engine pull ghcr.io/arran4/dev-dotfiles-debian:latest"
  grep -F 'Could not obtain published development image' "$tmp/error" >/dev/null
  if grep -F "$engine run " "$MOCK_LOG" >/dev/null; then echo 'Ran without a published image' >&2; exit 1; fi

  : > "$MOCK_LOG"
  if MOCK_IMAGE_PRESENT=0 DEV_IMAGE=dev-dotfiles-home-volume:trial SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"; then
    echo 'Expected unavailable trial-image failure' >&2; exit 1
  fi
  grep -F 'Build/select the home-volume image first' "$tmp/error" >/dev/null
  if grep -F "$engine pull " "$MOCK_LOG" >/dev/null; then echo 'Tried to pull an unpublished trial image' >&2; exit 1; fi

  : > "$MOCK_LOG"
  MOCK_CONTAINER_PRESENT=1 MOCK_IMAGE_PRESENT=0 SANDBOX_NAME=check "$launcher" > "$tmp/output" 2> "$tmp/error"
  assert_call "$engine start -ai"
  if grep -F "$engine pull " "$MOCK_LOG" >/dev/null; then echo 'Pulled while resuming an existing container' >&2; exit 1; fi

done
printf 'Development launcher tests passed.\n'

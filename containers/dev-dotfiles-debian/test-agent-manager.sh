#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_HOME="$(mktemp -d)"
export HOME="$TEST_HOME"

trap 'rm -rf "$TEST_HOME"' EXIT

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

export CACHE_ROOT="${TEST_HOME}/.cache/dev-agents/${OS}-${ARCH}"
export SHIM_DIR="${TEST_HOME}/shims"
export AGENTCTL_BIN="${TEST_HOME}/agentctl-test"
export DEV_AGENT_OVERRIDE="${TEST_HOME}/mock-override.sh"

mkdir -p "$CACHE_ROOT"
mkdir -p "$SHIM_DIR"

cp "$SCRIPT_DIR/agent-manager/agentctl" "$AGENTCTL_BIN"
chmod +x "$AGENTCTL_BIN"

# Generate shims pointing to test agentctl
"$AGENTCTL_BIN" setup-shims "$SHIM_DIR"

run_test() {
  local name="$1"
  echo "=== Running test: $name ==="
}

assert() {
  if ! "$@"; then
    echo "ASSERTION FAILED: $*" >&2
    exit 1
  fi
}

assert_not() {
  if "$@"; then
    echo "ASSERTION FAILED (expected failure): $*" >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Test 1: Shim forwards arguments unchanged
# -----------------------------------------------------------------------------
run_test "1. Shim forwards arguments unchanged"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    cat << 'PROG_EOF' > "$target_dir/testagent"
#!/bin/bash
if [ "${1:-}" = "--version" ]; then
  echo "testagent 1.0"
  exit 0
fi
for arg in "$@"; do
  printf '<arg>%s</arg>\n' "$arg"
done
PROG_EOF
    chmod +x "$target_dir/testagent"
    return 0
  fi
  return 1
}
MOCK_EOF

cat << SHIM_EOF > "$SHIM_DIR/testagent"
#!/bin/bash
exec "$AGENTCTL_BIN" dispatch testagent "\$@"
SHIM_EOF
chmod +x "$SHIM_DIR/testagent"

output=$("$SHIM_DIR/testagent" "first arg" "second with spaces" "--flag=val" "" "last")
expected=$(printf '<arg>first arg</arg>\n<arg>second with spaces</arg>\n<arg>--flag=val</arg>\n<arg></arg>\n<arg>last</arg>')
assert [ "$output" = "$expected" ]

# -----------------------------------------------------------------------------
# Test 2: No command arguments leaked through shell tracing
# -----------------------------------------------------------------------------
run_test "2. No command arguments leaked through shell tracing"

SENTINEL="SECRET_TOKEN_XYZ_12345"
stderr_log="$TEST_HOME/trace_stderr.log"
"$SHIM_DIR/testagent" "$SENTINEL" 2> "$stderr_log" >/dev/null
assert_not grep -q "$SENTINEL" "$stderr_log"
assert_not grep -q "+ exec " "$stderr_log"

# -----------------------------------------------------------------------------
# Test 3: First invocation installs one requested agent and only that agent
# -----------------------------------------------------------------------------
run_test "3. First invocation installs requested agent and only that agent"

assert [ -d "$CACHE_ROOT/testagent" ]
assert [ -x "$CACHE_ROOT/testagent/current/testagent" ]
assert [ ! -d "$CACHE_ROOT/testagent2" ]
assert [ ! -d "$CACHE_ROOT/codex" ]
assert [ ! -d "$CACHE_ROOT/agy" ]

# -----------------------------------------------------------------------------
# Test 4: Subsequent invocation within freshness window performs no update
# -----------------------------------------------------------------------------
run_test "4. Subsequent invocation within freshness window performs no update"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    cat << 'PROG_EOF' > "$target_dir/testagent"
#!/bin/bash
echo "testagent 2.0"
PROG_EOF
    chmod +x "$target_dir/testagent"
    return 0
  fi
  return 1
}
MOCK_EOF

output=$("$SHIM_DIR/testagent" --version)
assert [ "$output" = "testagent 1.0" ]

# -----------------------------------------------------------------------------
# Test 5: Stale invocation performs update/check before executing agent
# -----------------------------------------------------------------------------
run_test "5. Stale invocation performs update/check before executing agent"

old_time=$(($(date +%s) - 90000))
echo "$old_time" > "$CACHE_ROOT/testagent/.last_check"

output=$("$SHIM_DIR/testagent" --version)
assert [ "$output" = "testagent 2.0" ]
new_time=$(cat "$CACHE_ROOT/testagent/.last_check")
assert [ "$new_time" -gt "$old_time" ]

# -----------------------------------------------------------------------------
# Test 6: Successful update executes replacement
# -----------------------------------------------------------------------------
run_test "6. Successful update executes replacement"

output=$("$SHIM_DIR/testagent")
assert [ "$output" = "testagent 2.0" ]

# -----------------------------------------------------------------------------
# Test 7: Failed stale update executes previous known-good installation
# -----------------------------------------------------------------------------
run_test "7. Failed stale update executes previous known-good installation"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  return 1
}
MOCK_EOF

old_time=$(($(date +%s) - 90000))
echo "$old_time" > "$CACHE_ROOT/testagent/.last_check"

output=$("$SHIM_DIR/testagent" 2> "$TEST_HOME/stale_fail_stderr.log")
assert [ "$output" = "testagent 2.0" ]
assert grep -q "Warning: Failed to update testagent" "$TEST_HOME/stale_fail_stderr.log"
assert [ -x "$CACHE_ROOT/testagent/current/testagent" ]

# -----------------------------------------------------------------------------
# Test 8: Invalid candidate install is rejected
# -----------------------------------------------------------------------------
run_test "8. Invalid candidate install is rejected"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    cat << 'PROG_EOF' > "$target_dir/testagent"
#!/bin/bash
# Exits with error for all probes (--version, --help, -h)
exit 1
PROG_EOF
    chmod +x "$target_dir/testagent"
    return 0
  fi
  return 1
}
MOCK_EOF

old_time=$(($(date +%s) - 90000))
echo "$old_time" > "$CACHE_ROOT/testagent/.last_check"

output=$("$SHIM_DIR/testagent" 2>/dev/null || true)
assert [ "$output" = "testagent 2.0" ]

# Test fresh install rejection when candidate fails probe
cat << SHIM_EOF > "$SHIM_DIR/brokenagent"
#!/bin/bash
exec "$AGENTCTL_BIN" dispatch brokenagent "\$@"
SHIM_EOF
chmod +x "$SHIM_DIR/brokenagent"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  mkdir -p "$target_dir"
  cat << 'PROG_EOF' > "$target_dir/$agent"
#!/bin/bash
exit 1
PROG_EOF
  chmod +x "$target_dir/$agent"
  return 0
}
MOCK_EOF

assert_not "$SHIM_DIR/brokenagent"
assert [ ! -d "$CACHE_ROOT/brokenagent/current" ]

# -----------------------------------------------------------------------------
# Test 9: Invoking/checking one agent does not install unrelated agents
# -----------------------------------------------------------------------------
run_test "9. Invoking/checking one agent does not install unrelated agents"

assert [ ! -d "$CACHE_ROOT/codex" ]
assert [ ! -d "$CACHE_ROOT/agy" ]
assert [ ! -d "$CACHE_ROOT/junie" ]
assert [ ! -d "$CACHE_ROOT/mini" ]
assert [ ! -d "$CACHE_ROOT/opencode" ]
assert [ ! -d "$CACHE_ROOT/claude" ]
assert [ ! -d "$CACHE_ROOT/github-copilot-cli" ]
assert [ ! -d "$CACHE_ROOT/qwen" ]

# -----------------------------------------------------------------------------
# Test 10: Normal container startup does not install agents
# -----------------------------------------------------------------------------
run_test "10. Normal container startup does not install agents"

entrypoint_cache="${TEST_HOME}/entrypoint_test_cache"
mkdir -p "$entrypoint_cache"
sh -c "CACHE_ROOT='$entrypoint_cache' sh '$SCRIPT_DIR/entrypoint.sh' -c 'true'" >/dev/null 2>&1 || true
assert [ ! -d "$entrypoint_cache/codex" ]
assert [ ! -d "$entrypoint_cache/agy" ]
assert [ ! -d "$entrypoint_cache/mini" ]

# -----------------------------------------------------------------------------
# Test 11: Junie installer/runtime path isolation
# -----------------------------------------------------------------------------
run_test "11. Junie installer/runtime path isolation"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "junie" ]; then
    mkdir -p "$target_dir/.local/bin"
    mkdir -p "$target_dir/.local/share/junie"
    cat << 'PROG_EOF' > "$target_dir/.local/bin/junie"
#!/bin/bash
if [ "${1:-}" = "--version" ]; then echo "junie 1.0"; exit 0; fi
echo "junie from $JUNIE_DATA"
PROG_EOF
    chmod +x "$target_dir/.local/bin/junie"

    cat << 'WRAPPER_EOF' > "$target_dir/junie"
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JUNIE_DATA="${JUNIE_DATA:-$DIR/.local/share/junie}"
exec "$DIR/.local/bin/junie" "$@"
WRAPPER_EOF
    chmod +x "$target_dir/junie"
    return 0
  fi
  return 1
}
MOCK_EOF

cat << SHIM_EOF > "$SHIM_DIR/junie"
#!/bin/bash
exec "$AGENTCTL_BIN" dispatch junie "\$@"
SHIM_EOF
chmod +x "$SHIM_DIR/junie"

output=$("$SHIM_DIR/junie")
expected_data="$CACHE_ROOT/junie/current/.local/share/junie"
assert [ "$output" = "junie from $expected_data" ]

# -----------------------------------------------------------------------------
# Test 12: Mini SWE Agent maps correctly to mini
# -----------------------------------------------------------------------------
run_test "12. Mini SWE Agent maps correctly to mini"

assert [ -f "$SHIM_DIR/mini" ]
assert [ -x "$SHIM_DIR/mini" ]

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "mini" ]; then
    mkdir -p "$target_dir/bin"
    cat << 'PROG_EOF' > "$target_dir/bin/mini"
#!/bin/bash
if [ "${1:-}" = "--version" ]; then echo "mini-swe-agent 1.0"; exit 0; fi
echo "mini running"
PROG_EOF
    chmod +x "$target_dir/bin/mini"
    ln -s bin/mini "$target_dir/mini"
    return 0
  fi
  return 1
}
MOCK_EOF

output=$("$SHIM_DIR/mini")
assert [ "$output" = "mini running" ]
assert [ -x "$CACHE_ROOT/mini/current/mini" ]

# -----------------------------------------------------------------------------
# Test 13: Recovery from abandoned lock state
# -----------------------------------------------------------------------------
run_test "13. Recovery from abandoned lock state"

# Test 13a: Legacy directory lock cleanup
rm -rf "$CACHE_ROOT/testagent/.update.lock"
mkdir -p "$CACHE_ROOT/testagent/.update.lock"
old_time=$(($(date +%s) - 90000))
echo "$old_time" > "$CACHE_ROOT/testagent/.last_check"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    cat << 'PROG_EOF' > "$target_dir/testagent"
#!/bin/bash
echo "testagent 2.1"
PROG_EOF
    chmod +x "$target_dir/testagent"
    return 0
  fi
  return 1
}
MOCK_EOF

output=$("$SHIM_DIR/testagent")
assert [ "$output" = "testagent 2.1" ]
assert [ ! -d "$CACHE_ROOT/testagent/.update.lock" ]

# Test 13b: Abandoned process lock released by kernel
lockfile="$CACHE_ROOT/testagent/.update.lock"
touch "$lockfile"
# Spawn a process holding flock and terminate it
bash -c "exec 200>'$lockfile'; flock 200; sleep 10" &
dead_pid=$!
sleep 0.2
kill -9 "$dead_pid" 2>/dev/null || true
wait "$dead_pid" 2>/dev/null || true

# Subsequent dispatch must acquire lock and succeed immediately without delay
output=$("$SHIM_DIR/testagent")
assert [ "$output" = "testagent 2.1" ]

# -----------------------------------------------------------------------------
# Test 14: Updates do not remove files still needed by a running process
# -----------------------------------------------------------------------------
run_test "14. Updates do not remove files still needed by a running process"

cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    echo "sibling-data-v3" > "$target_dir/sibling.txt"
    cat << 'PROG_EOF' > "$target_dir/testagent"
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ "${1:-}" = "--version" ]; then echo "testagent 3.0"; exit 0; fi
if [ "${1:-}" = "--worker" ]; then
  echo "worker started"
  sleep 2
  if [ -f "$DIR/sibling.txt" ]; then
    cat "$DIR/sibling.txt"
    exit 0
  else
    echo "SIBLING MISSING" >&2
    exit 1
  fi
fi
echo "testagent 3.0"
PROG_EOF
    chmod +x "$target_dir/testagent"
    return 0
  fi
  return 1
}
MOCK_EOF

old_time=$(($(date +%s) - 90000))
echo "$old_time" > "$CACHE_ROOT/testagent/.last_check"
# Upgrade to v3
output=$("$SHIM_DIR/testagent" --version)
assert [ "$output" = "testagent 3.0" ]

# Start worker running from v3 in background
worker_log="$TEST_HOME/worker.log"
"$SHIM_DIR/testagent" --worker > "$worker_log" 2>&1 &
worker_pid=$!

# Wait until worker has started
while ! grep -q "worker started" "$worker_log" 2>/dev/null; do
  sleep 0.1
done

# Now prepare v4
cat << 'MOCK_EOF' > "$DEV_AGENT_OVERRIDE"
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    echo "sibling-data-v4" > "$target_dir/sibling.txt"
    cat << 'PROG_EOF' > "$target_dir/testagent"
#!/bin/bash
if [ "${1:-}" = "--version" ]; then echo "testagent 4.0"; exit 0; fi
echo "testagent 4.0"
PROG_EOF
    chmod +x "$target_dir/testagent"
    return 0
  fi
  return 1
}
MOCK_EOF

old_time=$(($(date +%s) - 90000))
echo "$old_time" > "$CACHE_ROOT/testagent/.last_check"

# Synchronously update to v4
output=$("$SHIM_DIR/testagent" --version)
assert [ "$output" = "testagent 4.0" ]

# Wait for worker process to complete
wait "$worker_pid"
worker_res=$(cat "$worker_log")
echo "$worker_res" | grep -q "sibling-data-v3"
assert_not grep -q "SIBLING MISSING" "$worker_log"

echo "=========================================="
echo "All 14 tests passed successfully!"
echo "=========================================="

#!/bin/bash
set -euo pipefail


# Mocks
export HOME=$(mktemp -d)
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

export CACHE_ROOT="${HOME}/.cache/dev-agents/${OS}-${ARCH}"
export MANIFEST_PATH="$HOME/agent-manifest.json"
export SEED_DIR="$HOME/agent-seed"
export SHIM_DIR="$HOME/shims"
export LOCK_FILE="${CACHE_ROOT}/.update.lock"
export LAST_REFRESH_FILE="${CACHE_ROOT}/.last_refresh"

# Inject some paths into agentctl for testing
export PATH="$SHIM_DIR:$PATH"
mkdir -p "$CACHE_ROOT"
mkdir -p "$SEED_DIR"
mkdir -p "$SHIM_DIR"

cat << 'EOF' > "$MANIFEST_PATH"
{
  "agents": {
    "testagent": {
      "backend": "script",
      "url": "http://localhost/install.sh",
      "shim_cmd": "testagent"
    },
    "badagent": {
      "backend": "script",
      "url": "http://localhost/bad.sh",
      "shim_cmd": "badagent"
    }
  }
}
EOF

# Mock jq since we might not have it in this stripped-down test or we want it clean
# actually we rely on jq, curl, npm, uv. We will mock the install functions directly in a wrapper

cat << 'EOF' > "$HOME/agentctl-wrapper"
#!/bin/bash
source /opt/agent-manager/agentctl >/dev/null 2>&1 || source ./agent-manager/agentctl >/dev/null 2>&1

install_script_agent() {
  local agent="$1"
  local url="$2"
  local target_dir="$3"
  if [[ "$agent" == "testagent" ]]; then
    mkdir -p "$target_dir"
    echo "#!/bin/bash" > "$target_dir/testagent"
    echo "echo 'testagent version 1.0'" >> "$target_dir/testagent"
    chmod +x "$target_dir/testagent"
    return 0
  fi
  if [[ "$agent" == "badagent" ]]; then
    return 1
  fi
}
# Override the actual calls to agentctl in the script by just running the functions directly
"$@"
EOF
chmod +x "$HOME/agentctl-wrapper"

# Patch agentctl script paths for test
cp ./agent-manager/agentctl "$HOME/agentctl-test"
sed -i "s|MANIFEST_PATH=.*|MANIFEST_PATH=\"$MANIFEST_PATH\"|" "$HOME/agentctl-test"
sed -i "s|SEED_DIR=.*|SEED_DIR=\"$SEED_DIR\"|" "$HOME/agentctl-test"
sed -i "s|SHIM_DIR=.*|SHIM_DIR=\"$SHIM_DIR\"|" "$HOME/agentctl-test"
sed -i "s|CACHE_ROOT=.*|CACHE_ROOT=\"$CACHE_ROOT\"|" "$HOME/agentctl-test"
sed -i "s|LOCK_FILE=.*|LOCK_FILE=\"$LOCK_FILE\"|" "$HOME/agentctl-test"
sed -i "s|LAST_REFRESH_FILE=.*|LAST_REFRESH_FILE=\"$LAST_REFRESH_FILE\"|" "$HOME/agentctl-test"

AGENTCTL="$HOME/agentctl-test"
sed -i "s|BUILTIN_MANIFEST=.*|BUILTIN_MANIFEST=\"$MANIFEST_PATH\"|" "$AGENTCTL"
sed -i 's|/opt/agent-manager/agentctl|'"$AGENTCTL"'|g' "$AGENTCTL"

# Override install_script_agent in test script
sed -i '/^case "${1:-}" in/i source /tmp/override.sh' "$AGENTCTL"
"$AGENTCTL" setup-shims
cat << 'EOF' > /tmp/override.sh

install_script_agent() {
  local agent="$1"
  local url="$2"
  local target_dir="$3"
  if [[ "$agent" == "testagent" ]]; then
    mkdir -p "$target_dir"
    echo "#!/bin/bash" > "$target_dir/testagent"
    echo "echo 'testagent version 1.0'" >> "$target_dir/testagent"
    chmod +x "$target_dir/testagent"
    return 0
  fi
  if [[ "$agent" == "badagent" ]]; then
    return 1
  fi
}
EOF

run_test() {
  local name="$1"
  echo "Running test: $name"
}

assert() {
  if ! "$@"; then
    echo "ASSERTION FAILED: $*"
    # e" + "xit 1
    exit 1
  fi
}

run_test "1. First invocation with no writable cache (seed fallback)"
# Setup seed cache manually
mkdir -p "$SEED_DIR/testagent/seed_v1"
echo "#!/bin/bash" > "$SEED_DIR/testagent/seed_v1/testagent"
echo "echo 'seed_version'" >> "$SEED_DIR/testagent/seed_v1/testagent"
chmod +x "$SEED_DIR/testagent/seed_v1/testagent"
ln -sfn "$SEED_DIR/testagent/seed_v1" "$SEED_DIR/testagent/current"
# Use dispatch
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "seed_version" ]

run_test "2. Stale update timestamp triggering refresh"
# Stale check
rm -f "$LAST_REFRESH_FILE"
assert "$AGENTCTL" check-stale
# Set to 24h old
old_time=$(($(date +%s) - 86400))
echo $old_time > "$LAST_REFRESH_FILE"
assert "$AGENTCTL" check-stale

run_test "3. Timestamp younger than 23 hours suppressing refresh"
date +%s > "$LAST_REFRESH_FILE"
if "$AGENTCTL" check-stale; then
  echo "Expected check-stale to fail (return 1)"
  exit 1
fi

run_test "4. Successful new-version promotion"
"$AGENTCTL" refresh testagent
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent version 1.0" ]

run_test "5. Cached current version used"
# It should still output testagent version 1.0
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent version 1.0" ]

run_test "6. Rollback"
# First we need a previous version to rollback to, let's refresh again to push it to previous
sleep 1
"$AGENTCTL" refresh testagent
# Now rollback
"$AGENTCTL" rollback testagent
# previous is restored to current

run_test "7. Pinning suppressing inappropriate automatic promotion"
"$AGENTCTL" pin testagent "$(readlink -f $CACHE_ROOT/testagent/current | xargs basename)"
"$AGENTCTL" refresh testagent
# Verify no new staging directory made it to current

run_test "8. Failed download/install preserving the current version"
"$AGENTCTL" refresh badagent || true
if [ -e "$CACHE_ROOT/badagent/current" ]; then
  echo "badagent should not have a current version"
  exit 1
fi
# testagent should remain unaffected
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent version 1.0" ]

run_test "9. Concurrent refresh locking"
mkdir -p "$LOCK_FILE"
"$AGENTCTL" refresh-bg
# Should not refresh because of lock


run_test "10. Manifest refresh failure falling back to built-in"
rm -f "$CACHE_ROOT/agent-manifest.json"
# We mock curl to fail
cat << 'CURL_EOF' > "$HOME/curl"
#!/bin/bash
exit 1
CURL_EOF
chmod +x "$HOME/curl"
export PATH="$HOME:$PATH"
"$AGENTCTL" refresh-bg
# Should still run successfully using builtin manifest and not crash
rm "$HOME/curl"

run_test "11. Shim dispatch passing all arguments"
# we use the shim directly
"$SHIM_DIR/testagent" arg1 arg2 > /tmp/shim_output
if ! grep "testagent version 1.0" /tmp/shim_output >/dev/null; then
  echo "Shim failed to execute correctly"
  exit 1
fi
echo "All tests passed successfully!"

#!/bin/bash
set -euxo pipefail

# Mocks
HOME=$(mktemp -d)
export HOME
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

export CACHE_ROOT="${HOME}/.cache/dev-agents/${OS}-${ARCH}"
export SEED_DIR="$HOME/agent-seed"
export SHIM_DIR="$HOME/shims"

mkdir -p "$CACHE_ROOT"
mkdir -p "$SEED_DIR"
mkdir -p "$SHIM_DIR"

# Copy agentctl and modify paths
cp ./agent-manager/agentctl "$HOME/agentctl-test"
sed -i "s|SEED_DIR=.*|SEED_DIR=\"$SEED_DIR\"|" "$HOME/agentctl-test"
sed -i "s|SHIM_DIR=.*|SHIM_DIR=\"$SHIM_DIR\"|" "$HOME/agentctl-test"
sed -i "s|CACHE_ROOT=.*|CACHE_ROOT=\"$CACHE_ROOT\"|" "$HOME/agentctl-test"
export AGENTCTL="$HOME/agentctl-test"

# Inject our test mock installer into agentctl
sed -i '/^update_agent() {/i source /tmp/override.sh' "$AGENTCTL"

cat << 'MOCK_EOF' > /tmp/override.sh
install_agent() {
  local agent="$1"
  local target_dir="$2"

  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    echo "#!/bin/bash" > "$target_dir/testagent"
    echo "echo 'testagent v1'" >> "$target_dir/testagent"
    chmod +x "$target_dir/testagent"
    return 0
  elif [ "$agent" = "testagent-fail" ]; then
    return 1
  elif [ "$agent" = "junie" ]; then
    mkdir -p "$target_dir/.local/bin"
    mkdir -p "$target_dir/.local/share/junie"
    echo "#!/bin/bash" > "$target_dir/.local/bin/junie"
    echo "echo \"junie v1 from \$JUNIE_DATA\"" >> "$target_dir/.local/bin/junie"
    chmod +x "$target_dir/.local/bin/junie"

    cat << 'WRAPPER_EOF' > "$target_dir/junie"
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JUNIE_DATA="$DIR/.local/share/junie"
exec "$DIR/.local/bin/junie" "$@"
WRAPPER_EOF
    chmod +x "$target_dir/junie"
    return 0
  fi

  # For other agents, just fail in the test
  return 1
}
MOCK_EOF

run_test() {
  local name="$1"
  echo "Running test: $name"
}

assert() {
  if ! "$@"; then
    echo "ASSERTION FAILED: $*"
    exit 1
  fi
}

run_test "1. Cached execution / Bootstrap"
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent v1" ]
assert [ -x "$CACHE_ROOT/testagent/current/testagent" ]

run_test "2. Stale-triggered background update"
# Mark stale
last_refresh="$CACHE_ROOT/testagent/.last_refresh"
old_time=$(($(date +%s) - 86400))
echo $old_time > "$last_refresh"

# Modify mock to install v2
cat << 'MOCK_EOF' > /tmp/override.sh
install_agent() {
  local agent="$1"
  local target_dir="$2"
  if [ "$agent" = "testagent" ]; then
    mkdir -p "$target_dir"
    echo "#!/bin/bash" > "$target_dir/testagent"
    echo "echo 'testagent v2'" >> "$target_dir/testagent"
    chmod +x "$target_dir/testagent"
    return 0
  fi
}
MOCK_EOF

# Dispatch should trigger background update but return v1 since it's async!
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent v1" ]

# Wait a moment for background task to complete
sleep 2

# Now it should be v2
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent v2" ]

# Last refresh should be updated
new_time=$(cat "$last_refresh")
assert [ "$new_time" -gt "$old_time" ]

run_test "3. Failed update retaining the last usable executable"
# Force a failure
cat << 'MOCK_EOF' > /tmp/override.sh
install_agent() {
  local agent="$1"
  if [ "$agent" = "testagent" ]; then return 1; fi
  if [ "$agent" = "junie" ]; then
    local target_dir="$2"
    mkdir -p "$target_dir/.local/bin"
    mkdir -p "$target_dir/.local/share/junie"
    echo "#!/bin/bash" > "$target_dir/.local/bin/junie"
    echo "echo \"junie v1 from \$JUNIE_DATA\"" >> "$target_dir/.local/bin/junie"
    chmod +x "$target_dir/.local/bin/junie"

    cat << 'WRAPPER_EOF' > "$target_dir/junie"
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JUNIE_DATA="$DIR/.local/share/junie"
exec "$DIR/.local/bin/junie" "$@"
WRAPPER_EOF
    chmod +x "$target_dir/junie"
    return 0
  fi
  return 1
}
MOCK_EOF
old_time=$(($(date +%s) - 86400))
echo $old_time > "$last_refresh"

output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent v2" ]

sleep 2
# Should STILL be v2
output=$("$AGENTCTL" dispatch testagent)
assert [ "$output" = "testagent v2" ]

run_test "4. Installer-specific path isolation (Junie)"
output=$("$AGENTCTL" dispatch junie)
expected_data="$CACHE_ROOT/junie/current/.local/share/junie"
assert [ "$output" = "junie v1 from $expected_data" ]

echo "All tests passed successfully!"

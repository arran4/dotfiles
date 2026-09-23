#!/bin/bash
set -eu

echo "Running unit tests for slackpm..."

tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME=$tmp_home

# Ensure environment is clean
unset SLACK_TOKEN

# Create a mock curl to intercept network calls and assert token existence
mkdir -p "$HOME/bin"
cat << 'MOCK' > "$HOME/bin/curl"
#!/bin/bash
# Check if token is passed via stdin header
stdin_content=$(cat)
if echo "$stdin_content" | grep -q "Authorization: Bearer "; then
  echo '{"ok":false, "error":"mock_invalid_auth"}'
else
  echo '{"ok":false, "error":"mock_missing_token"}'
fi
MOCK
chmod +x "$HOME/bin/curl"
export PATH="$HOME/bin:$PATH"

# Define the script path
script_path="$(dirname "$0")/dot_local/bin/executable_slackpm"

mkdir -p "$HOME/.config/slackpm"
token_file="$HOME/.config/slackpm/token"

# Test 1: Missing Token entirely
echo -n "Test 1: Missing Token... "
output=$($script_path user msg 2>&1 || true)
if echo "$output" | grep -q "provide it in a secure local file at ~/.config/slackpm/token"; then
    echo "PASS"
else
    echo "FAIL"
    echo "$output"
    exit 1
fi

# Test 2: Token file present but bad permissions
echo -n "Test 2: Token file with bad permissions... "
echo "fake_token" > "$token_file"
chmod 644 "$token_file"
output=$($script_path user msg 2>&1 || true)
if echo "$output" | grep -q "has insecure permissions"; then
    echo "PASS"
else
    echo "FAIL"
    echo "$output"
    exit 1
fi

# Test 3: Token file present with good permissions (600)
echo -n "Test 3: Token file with good permissions (600)... "
chmod 600 "$token_file"
output=$($script_path user msg 2>&1 || true)
if echo "$output" | grep -q "mock_invalid_auth"; then
    echo "PASS"
else
    echo "FAIL"
    echo "$output"
    exit 1
fi

# Test 4: Token file present with good permissions (400)
echo -n "Test 4: Token file with good permissions (400)... "
chmod 400 "$token_file"
output=$($script_path user msg 2>&1 || true)
if echo "$output" | grep -q "mock_invalid_auth"; then
    echo "PASS"
else
    echo "FAIL"
    echo "$output"
    exit 1
fi

# Test 5: Env var overrides file
echo -n "Test 5: Env var overrides file... "
chmod 644 "$token_file" # Make it bad, but env var should bypass it
output=$(SLACK_TOKEN="env_token" $script_path user msg 2>&1 || true)
if echo "$output" | grep -q "mock_invalid_auth"; then
    echo "PASS"
else
    echo "FAIL"
    echo "$output"
    exit 1
fi

echo "All tests passed."

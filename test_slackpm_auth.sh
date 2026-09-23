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
stdin_content=$(cat)
echo "$stdin_content" >> "$HOME/mock_curl_stdin.log"
echo "$*" >> "$HOME/mock_curl_args.log"

if echo "$stdin_content" | grep -q "Authorization: Bearer VALID_FAKE_TOKEN"; then
    if echo "$*" | grep -q "VALID_FAKE_TOKEN"; then
        echo '{"ok":false, "error":"token_leaked_in_argv"}'
    else
        echo '{"ok":true, "members":[{"id":"U123","name":"user"}], "channel":{"id":"C123"}}'
    fi
elif echo "$stdin_content" | grep -q "Authorization: Bearer ENV_FAKE_TOKEN"; then
    if echo "$*" | grep -q "ENV_FAKE_TOKEN"; then
        echo '{"ok":false, "error":"token_leaked_in_argv"}'
    else
        echo '{"ok":true, "members":[{"id":"U123","name":"user"}], "channel":{"id":"C123"}}'
    fi
else
    echo '{"ok":false, "error":"mock_missing_or_invalid_token"}'
fi
MOCK
chmod +x "$HOME/bin/curl"
export PATH="$HOME/bin:$PATH"

# Define the script path
script_path="$(dirname "$0")/dot_local/bin/executable_slackpm"

mkdir -p "$HOME/.config/slackpm"
token_file="$HOME/.config/slackpm/token"

# Test 1: Missing Token entirely
echo -n "Test 1: Missing Token entirely... "
rm -f "$HOME/mock_curl_stdin.log" "$HOME/mock_curl_args.log"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Should have exited non-zero"
    exit 1
else
    if echo "$output" | grep -q "provide it in a secure local file at ~/.config/slackpm/token"; then
        if [ -f "$HOME/mock_curl_args.log" ]; then
            echo "FAIL: Curl was called"
            exit 1
        fi
        echo "PASS"
    else
        echo "FAIL: Usage output incorrect"
        echo "$output"
        exit 1
    fi
fi

# Test 2: Token file is a symlink
echo -n "Test 2: Token file is a symlink... "
rm -f "$HOME/mock_curl_stdin.log" "$HOME/mock_curl_args.log"
touch "$HOME/.config/slackpm/real_token"
ln -s "$HOME/.config/slackpm/real_token" "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Should have exited non-zero"
    exit 1
else
    if echo "$output" | grep -q "cannot be a symlink"; then
        if [ -f "$HOME/mock_curl_args.log" ]; then
            echo "FAIL: Curl was called"
            exit 1
        fi
        echo "PASS"
    else
        echo "FAIL: Did not reject symlink"
        echo "$output"
        exit 1
    fi
fi
rm -f "$token_file" "$HOME/.config/slackpm/real_token"

# Test 3: Token file with bad permissions
echo -n "Test 3: Token file with bad permissions... "
rm -f "$HOME/mock_curl_stdin.log" "$HOME/mock_curl_args.log"
echo "VALID_FAKE_TOKEN" > "$token_file"
chmod 644 "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Should have exited non-zero"
    exit 1
else
    if echo "$output" | grep -q "insecure permissions"; then
        if [ -f "$HOME/mock_curl_args.log" ]; then
            echo "FAIL: Curl was called"
            exit 1
        fi
        echo "PASS"
    else
        echo "FAIL: Did not reject bad permissions"
        echo "$output"
        exit 1
    fi
fi

# Test 4: Token file with good permissions (600)
echo -n "Test 4: Token file with good permissions (600)... "
rm -f "$HOME/mock_curl_stdin.log" "$HOME/mock_curl_args.log"
chmod 600 "$token_file"
if output=$($script_path user msg 2>&1); then
    if echo "$output" | grep -q "Sending private message to:"; then
        echo "PASS"
    else
        echo "FAIL: Unexpected output"
        echo "$output"
        exit 1
    fi
else
    echo "FAIL: Exited non-zero"
    echo "$output"
    exit 1
fi

# Test 5: Env var overrides file
echo -n "Test 5: Env var overrides file... "
rm -f "$HOME/mock_curl_stdin.log" "$HOME/mock_curl_args.log"
chmod 644 "$token_file" # Bad perms but env should bypass
if output=$(SLACK_TOKEN="ENV_FAKE_TOKEN" $script_path user msg 2>&1); then
    if echo "$output" | grep -q "Sending private message to:"; then
        echo "PASS"
    else
        echo "FAIL: Unexpected output"
        echo "$output"
        exit 1
    fi
else
    echo "FAIL: Exited non-zero"
    echo "$output"
    exit 1
fi

echo "All tests passed."

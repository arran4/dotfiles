#!/bin/bash
set -eu

echo "Running unit tests for slackpm..."

tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
export HOME=$tmp_home

unset SLACK_TOKEN

mkdir -p "$HOME/bin"
cat << 'MOCK' > "$HOME/bin/curl"
#!/bin/bash
stdin_content=$(cat)
echo "$stdin_content" >> "$HOME/mock_curl_stdin.log"
echo "$*" >> "$HOME/mock_curl_args.log"

if [ "$stdin_content" = "Authorization: Bearer VALID_FAKE_TOKEN" ] || [ "$stdin_content" = "Authorization: Bearer ENV_FAKE_TOKEN" ]; then
    if echo "$*" | grep -q "VALID_FAKE_TOKEN" || echo "$*" | grep -q "ENV_FAKE_TOKEN"; then
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
script_path="${script_dir}/dot_local/bin/executable_slackpm"

mkdir -p "$HOME/.config/slackpm"
token_file="$HOME/.config/slackpm/token"

assert_curl_called() {
    local expected_calls=$1
    if [ ! -f "$HOME/mock_curl_args.log" ]; then
        if [ "$expected_calls" -eq 0 ]; then return 0; else return 1; fi
    fi
    local actual_calls
    actual_calls=$(wc -l < "$HOME/mock_curl_args.log")
    if [ "$actual_calls" -ne "$expected_calls" ]; then return 1; else return 0; fi
}

run_test() {
    rm -f "$HOME/mock_curl_stdin.log" "$HOME/mock_curl_args.log"
}

# Test 1: Missing Token
run_test
echo -n "Test 1: Missing Token entirely... "
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Exited 0"
    exit 1
else
    if echo "$output" | grep -q "provide it in a secure local file at ~/.config/slackpm/token"; then
        if assert_curl_called 0; then
            echo "PASS"
        else
            echo "FAIL: Curl called"
            exit 1
        fi
    else
        echo "FAIL: Missing usage"
        exit 1
    fi
fi

# Test 2: Symlink
run_test
echo -n "Test 2: Token file is a symlink... "
touch "$HOME/.config/slackpm/real_token"
ln -s "$HOME/.config/slackpm/real_token" "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Exited 0"
    exit 1
else
    if echo "$output" | grep -q "cannot be a symlink"; then
        if assert_curl_called 0; then
            echo "PASS"
        else
            echo "FAIL: Curl called"
            exit 1
        fi
    else
        echo "FAIL: Did not reject symlink"
        exit 1
    fi
fi
rm -f "$token_file" "$HOME/.config/slackpm/real_token"

# Test 3: Bad permissions
run_test
echo -n "Test 3: Token file with bad permissions... "
printf "VALID_FAKE_TOKEN\n" > "$token_file"
chmod 644 "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Exited 0"
    exit 1
else
    if echo "$output" | grep -q "insecure permissions"; then
        if assert_curl_called 0; then
            echo "PASS"
        else
            echo "FAIL: Curl called"
            exit 1
        fi
    else
        echo "FAIL: Did not reject bad permissions"
        exit 1
    fi
fi

# Test 4: Good permissions (600)
run_test
echo -n "Test 4: Token file with good permissions (600)... "
chmod 600 "$token_file"
if output=$($script_path user msg 2>&1); then
    if echo "$output" | grep -q "VALID_FAKE_TOKEN"; then
        echo "FAIL: Token leaked to output"
        exit 1
    fi
    if assert_curl_called 3; then
        echo "PASS"
    else
        echo "FAIL: Curl not called 3 times"
        exit 1
    fi
else
    echo "FAIL: Exited non-zero"; echo "output: $output"
    exit 1
fi

# Test 5: Env var overrides
run_test
echo -n "Test 5: Env var overrides file... "
chmod 644 "$token_file"
if output=$(SLACK_TOKEN="ENV_FAKE_TOKEN" $script_path user msg 2>&1); then
    if echo "$output" | grep -q "ENV_FAKE_TOKEN" || echo "$output" | grep -q "VALID_FAKE_TOKEN"; then
        echo "FAIL: Token leaked to output"
        exit 1
    fi
    if assert_curl_called 3; then
        echo "PASS"
    else
        echo "FAIL: Curl not called 3 times"
        exit 1
    fi
else
    echo "FAIL: Exited non-zero"; echo "output: $output"
    exit 1
fi

# Test 6: Empty token file
run_test
echo -n "Test 6: Empty token file... "
: > "$token_file"
chmod 600 "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Exited 0"
    exit 1
else
    if echo "$output" | grep -q "is empty"; then
        if assert_curl_called 0; then
            echo "PASS"
        else
            echo "FAIL: Curl called"
            exit 1
        fi
    else
        echo "FAIL: Did not report empty file error"
        exit 1
    fi
fi

# Test 7: Multi-line token file
run_test
echo -n "Test 7: Multi-line token file... "
printf "VALID_FAKE_TOKEN
extra_line" > "$token_file"
chmod 600 "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Exited 0"
    exit 1
else
    if echo "$output" | grep -q "multiple lines"; then
        if assert_curl_called 0; then
            echo "PASS"
        else
            echo "FAIL: Curl called"
            exit 1
        fi
    else
        echo "FAIL: Did not report multi-line error"
        exit 1
    fi
fi

# Test 8: Trailing whitespace
run_test
echo -n "Test 8: Token with trailing space... "
printf "VALID_FAKE_TOKEN " > "$token_file"
chmod 600 "$token_file"
if output=$($script_path user msg 2>&1); then
    echo "FAIL: Exited 0"
    exit 1
else
    if echo "$output" | grep -q "whitespace"; then
        if assert_curl_called 0; then
            echo "PASS"
        else
            echo "FAIL: Curl called"
            exit 1
        fi
    else
        echo "FAIL: Did not report whitespace error"
        exit 1
    fi
fi

echo "All tests passed."

#!/bin/bash

# Function to check if a command exists
exists() {
  command -v "$1" >/dev/null 2>&1
}

# Determine browser to use
BROWSER_CMD=""

# 1. Check command line argument
if [ -n "$1" ]; then
  BROWSER_CMD="$1"
# 2. Check BROWSER environment variable
elif [ -n "$BROWSER" ]; then
  BROWSER_CMD="$BROWSER"
fi

# Resolve aliases or verify existence if a specific browser was requested
if [ -n "$BROWSER_CMD" ]; then
  if [[ "$BROWSER_CMD" == "chrome" ]]; then
    if exists "google-chrome"; then
      BROWSER_CMD="google-chrome"
    elif exists "google-chrome-stable"; then
      BROWSER_CMD="google-chrome-stable"
    elif exists "chromium"; then
      BROWSER_CMD="chromium"
    else
      # Unset BROWSER_CMD if 'chrome' alias cannot be resolved.
      BROWSER_CMD=""
    fi
  fi
else
  # 3. Auto-detection (Konqueror -> Firefox -> Chrome -> xdg-open)
  for browser in konqueror firefox google-chrome google-chrome-stable chromium xdg-open; do
    if exists "$browser"; then
      BROWSER_CMD="$browser"
      break
    fi
  done
fi

if [ -z "$BROWSER_CMD" ]; then
  echo "Error: No suitable browser found." >&2
  exit 1
fi

urlencode() {
  local LC_ALL=C
  local string="$1"
  local length="${#string}"
  local i c
  for (( i = 0; i < length; i++ )); do
    c="${string:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
      ' ') printf '+' ;;
      *) printf '%%%02X' "'$c" ;;
    esac
  done
}

# Generate URL
# We capture the output of playerctl. If it fails, the query will be empty.
QUERY=$(playerctl metadata --format '{{ artist }} - {{ title }}. Song lyrics, meaning, context and analysis' -p spotify 2>/dev/null)
METADATA=$(urlencode "$QUERY")
URL="https://grok.com/?q=$METADATA"

# Execute
"$BROWSER_CMD" "$URL"

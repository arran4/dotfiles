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
  if exists "konqueror"; then
    BROWSER_CMD="konqueror"
  elif exists "firefox"; then
    BROWSER_CMD="firefox"
  elif exists "google-chrome"; then
    BROWSER_CMD="google-chrome"
  elif exists "google-chrome-stable"; then
    BROWSER_CMD="google-chrome-stable"
  elif exists "chromium"; then
    BROWSER_CMD="chromium"
  elif exists "xdg-open"; then
    BROWSER_CMD="xdg-open"
  fi
fi

if [ -z "$BROWSER_CMD" ]; then
  echo "Error: No suitable browser found." >&2
  exit 1
fi

# Generate URL
# We capture the output of playerctl. If it fails, the query will be empty.
METADATA=$(playerctl metadata --format '{{ artist }} - {{ title }}. Song lyrics, meaning, context and analysis' -p spotify 2>/dev/null | sed 's/ /+/g')
URL="https://grok.com/?q=$METADATA"

# Execute
"$BROWSER_CMD" "$URL"

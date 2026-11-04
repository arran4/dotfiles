#!/bin/sh
set -eu

if ! command -v go-playerctl >/dev/null 2>&1; then
  echo "Error: go-playerctl is not installed." >&2
  exit 127
fi

url=$(go-playerctl metadata xesam:url 2>/dev/null || true)

case "$url" in
  http://*|https://*)
    ;;
  "")
    echo "Error: current media does not expose a shareable URL." >&2
    exit 1
    ;;
  *)
    echo "Error: current media URL is not an HTTP(S) URL: $url" >&2
    exit 1
    ;;
esac

if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$url" | wl-copy
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$url" | xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  printf '%s' "$url" | xsel --clipboard --input
else
  echo "Error: no supported clipboard utility found (wl-copy, xclip, or xsel)." >&2
  exit 127
fi

printf '%s\n' "$url"

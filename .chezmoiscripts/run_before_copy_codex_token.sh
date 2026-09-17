#!/bin/sh
set -eu

SRC="$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
DST="$HOME/.codex/antigravity-cli/antigravity-oauth-token"

if [ -f "$SRC" ]; then
  if [ ! -f "$DST" ] || ! cmp -s "$SRC" "$DST"; then
    mkdir -p "$(dirname "$DST")"
    cp "$SRC" "$DST"
  fi
  chmod 600 "$DST"
fi

#!/bin/sh
if [ -f "$HOME/.gemini/antigravity-cli/antigravity-oauth-token" ] && [ ! -f "$HOME/.codex/antigravity-cli/antigravity-oauth-token" ]; then
    mkdir -p "$HOME/.codex/antigravity-cli"
    cp "$HOME/.gemini/antigravity-cli/antigravity-oauth-token" "$HOME/.codex/antigravity-cli/antigravity-oauth-token"
    chmod 600 "$HOME/.codex/antigravity-cli/antigravity-oauth-token"
fi

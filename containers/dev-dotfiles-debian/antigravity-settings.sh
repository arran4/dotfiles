#!/bin/sh
set -eu

# Initialize only the missing Antigravity CLI settings. This runs after the
# home seed on each container start, so existing user settings and persisted
# authentication/conversation state are left untouched.
settings="$HOME/.gemini/antigravity-cli/settings.json"
if [ -e "$settings" ] || [ -L "$settings" ]; then
  exit 0
fi

mkdir -p "$(dirname "$settings")"
(
  umask 077
  cat > "$settings" <<'EOF'
{
  "trustedWorkspaces": [
    "/workspace"
  ]
}
EOF
)

#!/bin/sh
set -e

# Determine git user email
email=$(git config --get user.email || true)
if [ -z "$email" ]; then
  exit 0
fi

# Check for gpg executable
if ! command -v gpg >/dev/null 2>&1; then
  exit 0
fi

# Check if a secret key already exists for this email
if gpg --list-secret-keys "$email" >/dev/null 2>&1; then
  exit 0
fi

name=$(git config --get user.name || echo "$email")

gpg --batch --generate-key <<KEY
Key-Type: default
Subkey-Type: default
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%no-protection
%commit
KEY


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

if gpg --version | grep -q "EDDSA"; then
  gpg --batch --generate-key <<KEY || true
Key-Type: eddsa
Key-Curve: ed25519
Subkey-Type: ecdh
Subkey-Curve: cv25519
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%no-protection
%commit
KEY
else
  gpg --batch --default-new-key-algo rsa4096 --generate-key <<KEY || true
Key-Type: rsa
Key-Length: 4096
Subkey-Type: rsa
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%no-protection
%commit
KEY
fi


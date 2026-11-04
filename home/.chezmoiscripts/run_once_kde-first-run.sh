#!/bin/sh

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kdesurc --group super-user-command --key super-user-command sudo
fi


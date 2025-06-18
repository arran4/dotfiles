#!/bin/sh

# Apply macOS defaults for Dock, Finder and screenshots

if [ "$(uname)" != "Darwin" ]; then
  echo "Not macOS. Skipping macOS defaults."
  exit 0
fi

printf "Apply macOS defaults now? [y/N] "
read -r answer
case "$answer" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Skipping macOS defaults."
    exit 0
    ;;
esac

# Dock: auto hide and disable recent apps
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false

# Finder: show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Save screenshots to a dedicated directory
screenshots_dir="${HOME}/Screenshots/mac defaults"
mkdir -p "$screenshots_dir"
defaults write com.apple.screencapture location "$screenshots_dir"

# Restart affected services
killall Dock Finder SystemUIServer >/dev/null 2>&1 || true

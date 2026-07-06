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
defaults write com.apple.finder QuitMenuItem -bool true

# Finder: disable window animations and Get Info animations
defaults write com.apple.finder DisableAllAnimations -bool true

# Finder: show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Set Documents as the default location for new Finder windows
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Documents/"

# Save screenshots to a dedicated directory
screenshots_dir="${HOME}/Screenshots/mac defaults"
mkdir -p "$screenshots_dir"
defaults write com.apple.screencapture location "$screenshots_dir"

# Restart affected services
killall Dock Finder SystemUIServer >/dev/null 2>&1 || true

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

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

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

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Automatically open a new Finder window when a volume is mounted
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

# Ensure parent dictionaries exist in com.apple.finder.plist
for domain in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
  /usr/libexec/PlistBuddy -c "Add :${domain} dict" "$HOME/Library/Preferences/com.apple.finder.plist" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Add :${domain}:IconViewSettings dict" "$HOME/Library/Preferences/com.apple.finder.plist" 2>/dev/null
done

set_finder_pref() {
  /usr/libexec/PlistBuddy -c "Add :$1 $2 $3" "$HOME/Library/Preferences/com.apple.finder.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :$1 $3" "$HOME/Library/Preferences/com.apple.finder.plist"
}

# Show item info near icons on the desktop and in other icon views
set_finder_pref "DesktopViewSettings:IconViewSettings:showItemInfo" "bool" "true"
set_finder_pref "FK_StandardViewSettings:IconViewSettings:showItemInfo" "bool" "true"
set_finder_pref "StandardViewSettings:IconViewSettings:showItemInfo" "bool" "true"

# Show item info to the right of the icons on the desktop
set_finder_pref "DesktopViewSettings:IconViewSettings:labelOnBottom" "bool" "false"

# Enable snap-to-grid for icons on the desktop and in other icon views
set_finder_pref "DesktopViewSettings:IconViewSettings:arrangeBy" "string" "grid"
set_finder_pref "FK_StandardViewSettings:IconViewSettings:arrangeBy" "string" "grid"
set_finder_pref "StandardViewSettings:IconViewSettings:arrangeBy" "string" "grid"

# Increase grid spacing for icons on the desktop and in other icon views
set_finder_pref "DesktopViewSettings:IconViewSettings:gridSpacing" "integer" "100"
set_finder_pref "FK_StandardViewSettings:IconViewSettings:gridSpacing" "integer" "100"
set_finder_pref "StandardViewSettings:IconViewSettings:gridSpacing" "integer" "100"

# Restart affected services
killall Dock Finder SystemUIServer >/dev/null 2>&1 || true

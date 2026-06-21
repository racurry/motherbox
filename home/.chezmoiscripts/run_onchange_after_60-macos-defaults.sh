#!/bin/bash
# macOS user defaults — all non-privileged, idempotent `defaults write` calls.
#
# Run by chezmoi during `chezmoi apply`. run_onchange re-runs only when this
# file's content changes, so the killall lines below (which restart Dock/Finder)
# don't fire on every apply. The one setting that needs root (ambient light
# sensor, in /Library/Preferences) lives in scripts/setup/macos.sh instead.
set -euo pipefail

echo "==> macOS: global defaults"

echo "Always show scrollbars"
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

echo "Expand save panels by default"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

echo "Expand print panel by default"
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

echo "Automatically quit printer app when jobs complete"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

echo "Disable close-windows-on-quit"
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true

echo "==> macOS: keyboard and input"

echo "Setting fast key repeat"
defaults write -g InitialKeyRepeat -int 15
echo "Setting key repeat speed"
defaults write -g KeyRepeat -int 2

echo "Disabling press-and-hold for special characters"
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

echo "Enabling full keyboard access for all controls"
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "Disabling automatic spelling correction"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

echo "Disabling smart quotes"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

echo "Disabling smart dashes"
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

echo "Disabling auto-capitalization"
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

echo "Disabling auto period substitution"
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

echo "Enabling text replacement globally"
defaults write -g WebAutomaticTextReplacementEnabled -bool true

echo "==> macOS: Dock and Spaces"

echo "Clearing persistent apps from Dock"
defaults write com.apple.dock persistent-apps -array

echo "Show only open applications in Dock"
defaults write com.apple.dock static-only -bool true

echo "Automatically hide Dock"
defaults write com.apple.dock autohide -bool true

echo "Position Dock on left"
defaults write com.apple.dock orientation -string "left"

echo "Setting Dock icon size"
defaults write com.apple.dock tilesize -int 36

echo "Disable dock bouncing"
defaults write com.apple.dock no-bouncing -bool true

echo "Disable automatically rearranging Spaces"
defaults write com.apple.dock mru-spaces -bool false

echo "Speed up Mission Control animations"
defaults write com.apple.dock expose-animation-duration -float 0.1

echo "Configure hot corners"
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-bl-modifier -int 0

echo "Restarting Dock to apply changes"
killall Dock 2>/dev/null || true

echo "==> macOS: Finder"

echo "Show all filename extensions"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "Set Finder new window target to Documents"
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Documents/"

echo "Show hidden files"
defaults write com.apple.finder AppleShowAllFiles -bool true

echo "Show status bar"
defaults write com.apple.finder ShowStatusBar -bool true

echo "Show path bar"
defaults write com.apple.finder ShowPathbar -bool true

echo "Show icons for drives and media on Desktop"
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

echo "Disable extension change warning"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

echo "Disable empty Trash warning"
defaults write com.apple.finder WarnOnEmptyTrash -bool false

echo "Reveal ~/Library"
chflags nohidden "${HOME}/Library"

echo "Restarting Finder"
killall Finder 2>/dev/null || true

echo "==> macOS: miscellaneous"

echo "Ensure Screenshots directory exists"
mkdir -p "${HOME}/Screenshots"

echo "Set screenshot location"
defaults write com.apple.screencapture location "${HOME}/Screenshots"

echo "Disable screenshot thumbnails"
defaults write com.apple.screencapture show-thumbnail -bool false

echo "Use PNG for screenshots"
defaults write com.apple.screencapture type -string "png"

echo "Set screensaver"
defaults -currentHost write com.apple.screensaver moduleDict -dict \
    path -string "/System/Library/Screen Savers/Flurry.saver" \
    moduleName -string "Flurry" \
    type -int 0

echo "Disable screensaver idle timeout"
defaults -currentHost write com.apple.screensaver idleTime -int 0

echo "Set alert sound to Submarine"
defaults write .GlobalPreferences com.apple.sound.beep.sound "/System/Library/Sounds/Submarine.aiff"

echo "Show battery percentage"
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true

echo "Refresh settings"
killall "SystemUIServer" 2>/dev/null || true
killall "TextInputMenuAgent" 2>/dev/null || true

echo "Done"

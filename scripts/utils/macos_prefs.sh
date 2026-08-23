#!/bin/bash
# macOS preferences — idempotent `defaults write` calls, root and user level.
#
# Triggered by chezmoi via home/.chezmoiscripts/run_onchange_after_60-macos-defaults.sh.tmpl
# whenever this file changes; also run directly by `mother setup` while the
# sudo timestamp is fresh. Safe to run by hand at any time.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: macos_prefs.sh [OPTIONS]

Apply macOS preferences: system-level settings that require root, then
user-level defaults (global, keyboard, Dock, Finder, screenshots, etc.).
Idempotent; restarts Dock/Finder/SystemUIServer to apply changes.

Dock defaults are read from
$XDG_CONFIG_HOME/motherbox/macos_prefs.conf (or
~/.config/motherbox/macos_prefs.conf) when that file exists. Command-line
options override the managed configuration.

OPTIONS:
  --dock-position POSITION  Set Dock position: left, bottom, or right
  --dock-autohide BOOLEAN   Turn Dock hiding on or off: true or false
  -h, --help                Show this help
EOF
}

dock_position="left"
dock_autohide="true"
dock_config="${XDG_CONFIG_HOME:-${HOME}/.config}/motherbox/macos_prefs.conf"

if [[ -f "$dock_config" ]]; then
    # This is a chezmoi-managed shell fragment containing only Dock defaults.
    # shellcheck source=/dev/null
    source "$dock_config"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
    --dock-position)
        [[ $# -ge 2 ]] || {
            echo "Missing value for --dock-position" >&2
            exit 1
        }
        dock_position="$2"
        shift 2
        ;;
    --dock-position=*)
        dock_position="${1#*=}"
        shift
        ;;
    --dock-autohide)
        [[ $# -ge 2 ]] || {
            echo "Missing value for --dock-autohide" >&2
            exit 1
        }
        dock_autohide="$2"
        shift 2
        ;;
    --dock-autohide=*)
        dock_autohide="${1#*=}"
        shift
        ;;
    -h | --help | help)
        show_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        echo >&2
        show_help >&2
        exit 1
        ;;
    esac
done

case "$dock_position" in
left | bottom | right) ;;
*)
    echo "Invalid Dock position: $dock_position (expected left, bottom, or right)" >&2
    exit 1
    ;;
esac

case "$dock_autohide" in
true | false) ;;
*)
    echo "Invalid Dock autohide value: $dock_autohide (expected true or false)" >&2
    exit 1
    ;;
esac

# ==========================================================================
# Root-required preferences — first, so any sudo prompt happens up front.
# ==========================================================================

echo "==> macOS: system preferences (root)"

# Writes a system preference in /Library/Preferences (owned by root/_hidd) and
# read by the HID daemon, so it requires root.
echo "Disable automatic display brightness adjustment"
/usr/bin/sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false

# ==========================================================================
# User-level preferences
# ==========================================================================

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

echo "Disabling 'Turn Dock hiding on/off' shortcut (Option-Command-D)"
# Symbolic hotkey 52 = "Turn Dock hiding on/off". Parameters are the default
# binding (ascii 'd', keycode 2, Cmd+Opt modifiers); enabled=false turns it off.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 52 '
<dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
        <key>type</key><string>standard</string>
        <key>parameters</key>
        <array>
            <integer>100</integer>
            <integer>2</integer>
            <integer>1572864</integer>
        </array>
    </dict>
</dict>'

echo "Reloading symbolic hotkey settings"
# Makes the hotkey change take effect without logging out. activateSettings is
# part of a private Apple framework (SystemAdministration) with no public API
# contract, so it may move or disappear in any macOS release. The `|| true`
# keeps that from breaking the script; worst case the change waits for the
# next logout/restart to apply.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

echo "==> macOS: Dock and Spaces"

echo "Clearing persistent apps from Dock"
defaults write com.apple.dock persistent-apps -array

echo "Show only open applications in Dock"
defaults write com.apple.dock static-only -bool true

echo "Set Dock autohide to $dock_autohide"
defaults write com.apple.dock autohide -bool "$dock_autohide"

echo "Position Dock on $dock_position"
defaults write com.apple.dock orientation -string "$dock_position"

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

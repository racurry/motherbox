#!/bin/bash
set -euo pipefail

# The one macOS setting that needs root: it writes a system preference in
# /Library/Preferences (owned by root/_hidd), read by the HID daemon. Every
# other macOS default is non-privileged and lives in chezmoi
# (home/.chezmoiscripts/run_onchange_after_60-macos-defaults.sh).

echo "Disable automatic display brightness adjustment"
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false

echo "Done"

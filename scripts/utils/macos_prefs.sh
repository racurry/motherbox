#!/bin/bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: macos_prefs_sudo.sh [--help]

Apply macOS preferences that require root.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

# Writes a system preference in /Library/Preferences (owned by root/_hidd) and
# read by the HID daemon, so it requires root.

echo "Disable automatic display brightness adjustment"
/usr/bin/sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false

echo "Done"

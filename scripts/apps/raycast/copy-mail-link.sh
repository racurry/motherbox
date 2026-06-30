#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Copy Mail Link
# @raycast.mode silent
# @raycast.icon ✉️
# @raycast.packageName Mail

# Copies a message:// deep link to the message selected in Mail.app.
# Delegates to the standalone AppleScript so the logic lives in one place.

url=$(osascript "$HOME/.config/motherbox/scripts/utils/copy-mail-link.applescript") || exit 1
echo "Copied: $url"

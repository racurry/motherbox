#!/usr/bin/env bash
# Per-machine nightly maintenance.
#
# Invoked at 2:00 AM by the launchd agent
# net.aaroncurry.motherbox.nightly-maintenance, installed on every machine by
# chezmoi (see home/Library/LaunchAgents/ and the 50-launchagents apply hook).
# The agent passes the chezmoi machine name as its sole argument; this script
# branches on it so each machine runs only its own steps. A machine with no
# branch here is a successful no-op.
#
# Usage: maintenance.sh <machine>
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
machine="${1:-}"

if [[ "$machine" == "mini" ]]; then
    # Prerequisite — obsidian-headless installed and logged in:
    #   npm install -g obsidian-headless
    #   ob login
    #   ob sync-setup --vault Memex --path ~/Notes/Memex
    echo "==> Syncing Obsidian vault..."
    osascript "$DIR/quit-obsidian.applescript"
    ob sync --path ~/Notes/Memex

    echo "==> Restarting Claude Desktop..."
    osascript "$DIR/restart-claude-desktop.applescript"
fi

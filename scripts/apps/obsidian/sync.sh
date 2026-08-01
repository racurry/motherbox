#!/bin/bash
# Sync the Obsidian vault headlessly. Obsidian holds a lock on the vault while
# running, so quit it first.
#
# Requires a one-time login per machine:
#   ob login
#   ob sync-setup --vault Memex --path ~/Notes/Memex
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

osascript "$REPO/scripts/utils/quit-obsidian.applescript"
ob sync --path ~/Notes/Memex

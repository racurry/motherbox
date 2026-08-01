#!/bin/bash
# Restart Claude Desktop.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

osascript "$REPO/scripts/utils/restart-claude-desktop.applescript"

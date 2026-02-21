#!/bin/bash
# PreToolUse hook: block /tmp and /var/tmp, enforce ./tmp instead
set -euo pipefail

input=$(cat)

if echo "$input" | grep -qE '[ "]/tmp/|[ "]/tmp"' || echo "$input" | grep -qE '[ "]/var/tmp/|[ "]/var/tmp"'; then
    echo "Do not use /tmp or /var/tmp. Use ./tmp relative to cwd instead (create with mkdir -p ./tmp if needed)." >&2
    exit 2
fi

exit 0

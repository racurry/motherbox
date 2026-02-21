#!/bin/bash
# PreToolUse hook (Bash only): block fully qualified cwd paths, enforce relative paths
set -euo pipefail

input=$(cat)

# Extract just the command field to avoid false positives from the description field
command=$(echo "$input" | jq -r '.tool_input.command // empty')
if [[ -z "$command" ]]; then
    exit 0
fi

cwd="$PWD"

# Commands that legitimately need absolute paths
if echo "$command" | grep -qE '^(docker|docker-compose|podman)\b'; then
    exit 0
fi

# Check if the command contains a fully qualified path under or at the current directory
if echo "$command" | grep -qE "(${cwd}/|${cwd}( |\$))"; then
    echo "Do not use fully qualified paths for files in the current directory. Use relative paths instead (e.g., ./script.py not $cwd/script.py)." >&2
    exit 2
fi

exit 0

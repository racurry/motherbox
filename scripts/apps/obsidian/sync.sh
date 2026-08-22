#!/bin/bash
# Keep the Memex vault synchronized with Obsidian Sync.
#
# Requires one-time setup on the Mac mini:
#   ob login
#   ob sync-setup --vault Memex --path ~/Notes/Memex
set -euo pipefail

VAULT="$HOME/Notes/Memex"

show_help() {
    cat <<'EOF'
Usage: sync.sh [--help]

Run continuous bidirectional Obsidian Headless Sync for ~/Notes/Memex.
Configuration sync is disabled so Obsidian Desktop can use the same local
folder without Headless Sync changing its plugins or settings. Desktop's Sync
core plugin must remain disabled on this Mac.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
"") ;;
*)
    printf "Unknown option: %s\n\n" "$1" >&2
    show_help
    exit 1
    ;;
esac

if [[ ! -d "$VAULT/.obsidian" ]]; then
    printf 'Obsidian vault is not configured at %s\n' "$VAULT" >&2
    printf 'Run: mise exec -- ob sync-setup --vault Memex --path %s\n' "$VAULT" >&2
    exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
    printf 'mise is required to run the managed obsidian-headless CLI\n' >&2
    exit 1
fi

mise exec -- ob sync-config \
    --path "$VAULT" \
    --mode bidirectional \
    --configs "" \
    --device-name "Mac mini headless"

exec mise exec -- ob sync --path "$VAULT" --continuous

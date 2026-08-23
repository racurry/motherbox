#!/bin/bash
# Keep the Memex vault synchronized with Obsidian Sync.
#
# Requires one-time setup:
#   ob login
#   ob sync-setup --vault Memex --path ~/Notes/Memex
set -euo pipefail

VAULT="$HOME/Notes/Memex"

show_help() {
    cat <<'EOF'
Usage: sync.sh [--help]

Run continuous bidirectional Obsidian Headless Sync for ~/Notes/Memex.
Obsidian Desktop's Sync core plugin must remain disabled wherever this runner
is active.
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
    printf 'Run: ob sync-setup --vault Memex --path %s\n' "$VAULT" >&2
    exit 1
fi

if ! command -v ob >/dev/null 2>&1; then
    printf 'The managed obsidian-headless CLI was not found on PATH\n' >&2
    exit 1
fi

exec ob sync --path "$VAULT" --continuous

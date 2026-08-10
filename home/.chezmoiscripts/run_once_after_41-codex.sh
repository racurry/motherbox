#!/bin/bash
# Layer 1 — Codex CLI bootstrap.
#
# Run by chezmoi during `chezmoi apply`, after mise. Thin hook: the real logic
# lives in scripts/apps/codex/install.sh so it can also be run by hand. run_once
# performs initial setup; Codex checks for standalone updates after that.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: run_once_after_41-codex.sh [--help]

Bootstrap the standalone Codex CLI during the first chezmoi apply.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
"")
    ;;
*)
    printf "Unknown option: %s\n\n" "$1" >&2
    show_help >&2
    exit 1
    ;;
esac

echo "==> Layer 1: Codex CLI"
"$CHEZMOI_WORKING_TREE/scripts/apps/codex/install.sh"

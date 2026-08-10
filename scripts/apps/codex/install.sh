#!/bin/bash

# Codex CLI bootstrap/update — official standalone installer.
# Runnable by hand, by mother, or by the chezmoi run_once hook.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: install.sh [--help]

Install or update the Codex CLI with OpenAI's official standalone installer.
The installer owns Codex under ~/.codex and exposes it at ~/.local/bin/codex.
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

echo "==> Installing/updating Codex CLI"
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

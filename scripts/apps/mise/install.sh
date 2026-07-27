#!/bin/bash

# Install the runtimes and global tools declared in the managed mise config.
# Runnable by hand, by mother, or by the chezmoi onchange hook.
#
# Install is additive — removing a tool from the config does NOT uninstall it;
# run `mise prune` deliberately for that.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: install.sh [--help]

Install every runtime and global tool declared in the mise config
(~/.config/mise/config.toml, plus any config in the current directory).
Idempotent; additive — it never uninstalls. Use `mise prune` for that.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

# mise is installed by brew; it may not be on PATH outside an interactive shell.
if ! command -v mise >/dev/null 2>&1; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

exec mise install

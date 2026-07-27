#!/bin/bash

# Claude Code CLI bootstrap — native installer, per docs/tool-responsibility.md.
# Runnable by hand, by mother, or by the chezmoi run_once hook.
#
# Only ever installs a missing CLI: Claude Code self-updates after the initial
# install, so re-running this on a machine that already has it is a no-op.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: install.sh [--help]

Install the Claude Code CLI with the official native installer. No-op when
`claude` is already on PATH — the CLI self-updates from there.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

if command -v claude >/dev/null 2>&1; then
    echo "==> Claude Code already installed; skipping"
    exit 0
fi

echo "==> Installing Claude Code"
curl -fsSL https://claude.ai/install.sh | bash

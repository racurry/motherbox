#!/bin/bash
# Codex (desktop app) - OpenAI Codex coding agent in a native macOS app
# Installs the Codex desktop app via Homebrew cask.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage the Codex desktop app installation.

COMMANDS:
    setup       Install Codex desktop app via Homebrew
    help        Show this help message

NOTES:
    - Settings sync via your OpenAI account
    - For the CLI version, see apps/codex-cli
EOF
}

do_setup() {
    print_heading "Setting up Codex desktop app"
    require_command brew
    brew install --cask codex-app
    log_success "Codex desktop app setup complete"
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup)
            command="$1"
            shift
            ;;
        *)
            if shift_count=$(check_global_flag "$@"); then
                shift "$shift_count"
            else
                log_warn "Ignoring unknown argument: $1"
                shift
            fi
            ;;
        esac
    done

    case "${command}" in
    setup)
        do_setup
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

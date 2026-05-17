#!/bin/bash
# Comet - Perplexity's web browser
# Installs Comet via Homebrew cask.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage Comet (Perplexity) browser installation.

COMMANDS:
    setup       Install Comet via Homebrew
    help        Show this help message

NOTES:
    - Sign in with your Perplexity account to sync
    - No local configuration needed
EOF
}

do_setup() {
    print_heading "Setting up Comet (Perplexity browser)"
    require_command brew
    brew install --cask comet
    log_success "Comet setup complete"
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

#!/bin/bash
# Figma - Collaborative design tool
# Installs Figma desktop app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage Figma desktop app installation.

COMMANDS:
    setup       Install Figma via Homebrew
    help        Show this help message

NOTES:
    - All preferences sync via Figma account (cloud-based)
    - No local configuration needed
EOF
}

do_setup() {
    print_heading "Setting up Figma"

    ensure_brew_package figma figma cask

    log_success "Figma setup complete"
    log_info "Sign in to your Figma account to sync preferences"
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
            # Check if it's a global flag from run/setup.sh
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

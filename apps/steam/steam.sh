#!/bin/bash
# Steam - Video game digital distribution service
# Installs Steam via Homebrew cask

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage Steam installation.

COMMANDS:
    setup       Install Steam via Homebrew
    help        Show this help message

NOTES:
    - Requires Rosetta 2 on Apple Silicon Macs
    - All preferences sync via Steam account (cloud-based)
    - No local configuration needed
EOF
}

do_setup() {
    print_heading "Setting up Steam"
    require_command brew
    require_rosetta
    brew install --cask steam
    log_success "Steam setup complete"
    log_info "Sign in to your Steam account to sync preferences and games"
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

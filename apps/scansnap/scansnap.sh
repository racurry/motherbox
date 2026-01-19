#!/bin/bash
# ScanSnap Home - Fujitsu scanner software
# Installs ScanSnap Home via Homebrew cask

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage ScanSnap Home installation.

COMMANDS:
    setup       Install ScanSnap Home via Homebrew
    help        Show this help message

NOTES:
    - Requires Rosetta 2 on Apple Silicon Macs
    - Profiles sync via ScanSnap Cloud or manual export/import
    - No local configuration files to sync
EOF
}

do_setup() {
    print_heading "Setting up ScanSnap Home"
    require_command brew
    require_rosetta
    brew install --cask fujitsu-scansnap-home
    log_success "ScanSnap Home setup complete"
    log_info "Connect your ScanSnap device and launch the app to complete setup"
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

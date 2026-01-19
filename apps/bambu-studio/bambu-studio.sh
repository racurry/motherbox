#!/bin/bash
# Bambu Studio - 3D printing slicer software
# Installs Bambu Studio via Homebrew cask

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage Bambu Studio installation.

COMMANDS:
    setup       Install Bambu Studio via Homebrew
    help        Show this help message

NOTES:
    - Preferences sync via Bambu Cloud account
    - Printer/filament profiles stored in ~/Library/Application Support/BambuStudio/
EOF
}

do_setup() {
    print_heading "Setting up Bambu Studio"
    require_command brew
    brew install --cask bambu-studio
    log_success "Bambu Studio setup complete"
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

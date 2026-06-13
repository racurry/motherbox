#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="direnv"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Symlink direnv library files (use_nvm.sh) to ~/.config/direnv/lib/

Commands:
    setup       Run full setup (symlink library files)
    help        Show this help message (also: -h, --help)
EOF
}

do_setup() {
    print_heading "Setting up direnv library files"

    require_command direnv

    local target_dir="${HOME}/.config/direnv/lib"
    mkdir -p "${target_dir}"

    link_file "${SCRIPT_DIR}/use_nvm.sh" "${target_dir}/use_nvm.sh" "${APP_NAME}"

    log_success "direnv library setup complete"
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

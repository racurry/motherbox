#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="git"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Symlink git configuration files to home directory.

Files managed:
    .gitconfig            Main git configuration
    .gitignore_global     Global gitignore patterns
    .gitconfig_galileo    Galileo git config (if present)
    .gitconfig_firsthand  Firsthand git config (if present)

Commands:
    setup       Run full setup (primary entry point)
    help        Show this help message (also: -h, --help)
EOF
}

do_setup() {
    print_heading "Setting up git configuration"

    link_home_dotfile "${SCRIPT_DIR}/.gitconfig" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.gitignore_global" "${APP_NAME}"

    # Link work-specific configs if present
    if [[ -f "${SCRIPT_DIR}/.gitconfig_galileo" ]]; then
        link_home_dotfile "${SCRIPT_DIR}/.gitconfig_galileo" "${APP_NAME}"
    fi
    if [[ -f "${SCRIPT_DIR}/.gitconfig_firsthand" ]]; then
        link_home_dotfile "${SCRIPT_DIR}/.gitconfig_firsthand" "${APP_NAME}"
    fi

    log_info "Git configuration complete"
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

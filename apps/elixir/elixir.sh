#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="elixir"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Set up Elixir and Phoenix development environment.

Commands:
    setup       Run full setup (install Phoenix generator)
    help        Show this help message (also: -h, --help)
EOF
}

install_phoenix() {
    print_heading "Installing Phoenix generator"

    require_command mix

    log_info "Installing phx_new archive via mix"
    mix archive.install hex phx_new --force
    log_success "Phoenix generator installed"
}

do_setup() {
    install_phoenix
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        setup)
            command="setup"
            shift
            ;;
        help | --help | -h)
            show_help
            exit 0
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

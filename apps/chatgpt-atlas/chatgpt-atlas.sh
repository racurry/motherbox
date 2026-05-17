#!/bin/bash
# ChatGPT Atlas - OpenAI's web browser
# Installs ChatGPT Atlas via Homebrew cask.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage ChatGPT Atlas browser installation.

COMMANDS:
    setup       Install ChatGPT Atlas via Homebrew
    help        Show this help message

NOTES:
    - Sign in with your OpenAI account to sync
    - No local configuration needed
EOF
}

do_setup() {
    print_heading "Setting up ChatGPT Atlas"
    require_command brew
    brew install --cask chatgpt-atlas
    log_success "ChatGPT Atlas setup complete"
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

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="zsh"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Symlink zsh configuration files to home directory.

Files managed:
    .zshrc        - Main zsh configuration
    .galileorc    - Galileo work-specific zsh config
    .firsthandrc  - Firsthand work-specific zsh config

Commands:
    setup       Run full setup (symlink configuration files)
    help        Show this help message (also: -h, --help)
EOF
}

do_setup() {
    print_heading "Setting up zsh configuration"

    link_home_dotfile "${SCRIPT_DIR}/.zshrc" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.galileorc" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.firsthandrc" "${APP_NAME}"

    # Set MOTHERBOX_ROOT in ~/.local.zshrc for use in PATH and aliases
    local repo_root
    repo_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    local local_zshrc="$HOME/.local.zshrc"

    # Create file if it doesn't exist
    touch "$local_zshrc"

    # Update or add MOTHERBOX_ROOT
    if grep -q '^export MOTHERBOX_ROOT=' "$local_zshrc" 2>/dev/null; then
        sed -i '' "s|^export MOTHERBOX_ROOT=.*|export MOTHERBOX_ROOT=\"${repo_root}\"|" "$local_zshrc"
        log_info "Updated MOTHERBOX_ROOT in ~/.local.zshrc"
    else
        # Ensure file ends with newline before appending
        [[ -s "$local_zshrc" && $(tail -c1 "$local_zshrc" | wc -l) -eq 0 ]] && echo >>"$local_zshrc"
        echo "export MOTHERBOX_ROOT=\"${repo_root}\"" >>"$local_zshrc"
        log_info "Added MOTHERBOX_ROOT to ~/.local.zshrc"
    fi

    log_success "Zsh configuration complete"
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

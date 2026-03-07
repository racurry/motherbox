#!/bin/bash
# Ghostty terminal emulator
# Installs Ghostty and links configuration files to ~/.config/ghostty/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

GHOSTTY_CONFIG_DIR="${HOME}/.config/ghostty"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Install and configure Ghostty terminal.

Commands:
    setup       Run full setup (primary entry point)
    show        Display current Ghostty configuration
    help        Show this help message (also: -h, --help)

What this script does:
    - Installs Ghostty via Homebrew cask if not present
    - Links config from this repo to ~/.config/ghostty/
    - Creates config directory if it doesn't exist

Configuration files:
    - config: Main configuration file
EOF
}

do_setup() {
    print_heading "Setting up Ghostty"

    # Install via Homebrew (cask)
    ensure_brew_package ghostty ghostty cask

    # Create config directory if needed
    if [[ ! -d "${GHOSTTY_CONFIG_DIR}" ]]; then
        log_info "Creating Ghostty config directory"
        mkdir -p "${GHOSTTY_CONFIG_DIR}"
    fi

    # Link configuration files
    if [[ -f "${SCRIPT_DIR}/config" ]]; then
        link_file "${SCRIPT_DIR}/config" "${GHOSTTY_CONFIG_DIR}/config" "ghostty"
    else
        log_info "No config found in ${SCRIPT_DIR}"
        log_info "Create config to have it linked during setup"
    fi

    log_success "Ghostty configuration complete"
}

do_show() {
    print_heading "Current Ghostty Settings"

    echo "Config directory: ${GHOSTTY_CONFIG_DIR}"
    if [[ -d "${GHOSTTY_CONFIG_DIR}" ]]; then
        echo "  Status: exists"
        echo ""
        echo "Configuration files:"
        ls -la "${GHOSTTY_CONFIG_DIR}/" 2>/dev/null || echo "  (empty)"
    else
        echo "  Status: not created"
    fi

    echo ""
    if [[ -f "${GHOSTTY_CONFIG_DIR}/config" ]]; then
        echo "config preview (first 20 lines):"
        head -20 "${GHOSTTY_CONFIG_DIR}/config"
    fi
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup | show)
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
    show)
        do_show
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

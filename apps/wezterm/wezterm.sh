#!/bin/bash
# WezTerm terminal emulator
# Installs WezTerm and links configuration files to ~/.config/wezterm/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

WEZTERM_CONFIG_DIR="${HOME}/.config/wezterm"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Configure WezTerm terminal settings.

Commands:
    setup       Run full setup (primary entry point)
    show        Display current WezTerm configuration
    help        Show this help message (also: -h, --help)

What this script does:
    - Installs WezTerm via Homebrew cask if not present
    - Links wezterm.lua from this repo to ~/.config/wezterm/
    - Creates config directory if it doesn't exist

Configuration files:
    - wezterm.lua: Main configuration file (Lua)
EOF
}

do_setup() {
    print_heading "Setting up WezTerm"

    # Install via Homebrew (cask)
    ensure_brew_package wezterm wezterm cask

    # Create config directory if needed
    if [[ ! -d "${WEZTERM_CONFIG_DIR}" ]]; then
        log_info "Creating WezTerm config directory"
        mkdir -p "${WEZTERM_CONFIG_DIR}"
    fi

    # Link configuration files
    if [[ -f "${SCRIPT_DIR}/wezterm.lua" ]]; then
        link_file "${SCRIPT_DIR}/wezterm.lua" "${WEZTERM_CONFIG_DIR}/wezterm.lua" "wezterm"
    else
        log_info "No wezterm.lua found in ${SCRIPT_DIR}"
        log_info "Create wezterm.lua to have it linked during setup"
    fi

    log_success "WezTerm configuration complete"
}

do_show() {
    print_heading "Current WezTerm Settings"

    echo "Config directory: ${WEZTERM_CONFIG_DIR}"
    if [[ -d "${WEZTERM_CONFIG_DIR}" ]]; then
        echo "  Status: exists"
        echo ""
        echo "Configuration files:"
        ls -la "${WEZTERM_CONFIG_DIR}/" 2>/dev/null || echo "  (empty)"
    else
        echo "  Status: not created"
    fi

    echo ""
    if [[ -f "${WEZTERM_CONFIG_DIR}/wezterm.lua" ]]; then
        echo "wezterm.lua preview (first 20 lines):"
        head -20 "${WEZTERM_CONFIG_DIR}/wezterm.lua"
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

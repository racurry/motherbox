#!/bin/bash
# KeyCastr - Keystroke visualizer for screencasts and presentations
# Installs KeyCastr and configures recommended defaults

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

DOMAIN="io.github.keycastr"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage KeyCastr installation and configuration.

COMMANDS:
    setup       Install KeyCastr and configure defaults
    show        Display current KeyCastr settings
    help        Show this help message

NOTES:
    - Requires Input Monitoring permission (System Settings > Privacy & Security)
    - Settings stored in ~/Library/Preferences/io.github.keycastr.plist
    - Position can be adjusted by dragging the display overlay
EOF
}

do_setup() {
    print_heading "Setting up KeyCastr"

    ensure_brew_package keycastr keycastr cask

    # Configure recommended defaults
    log_info "Configuring KeyCastr defaults"

    # Enable automatic updates
    defaults write "${DOMAIN}" SUAutomaticallyUpdate -bool true
    defaults write "${DOMAIN}" SUEnableAutomaticChecks -bool true

    # Disable sending profile info to update server
    defaults write "${DOMAIN}" SUSendProfileInfo -bool false

    # Show menu bar icon (makes it easy to toggle on/off)
    defaults write "${DOMAIN}" displayIcon -bool true

    # Use default visualizer (more customizable than Svelte)
    defaults write "${DOMAIN}" selectedVisualizer -string "Default"

    log_success "KeyCastr setup complete"
    log_info ""
    log_info "Manual setup required:"
    log_info "  1. Launch KeyCastr"
    log_info "  2. Grant Input Monitoring permission when prompted"
    log_info "     (System Settings > Privacy & Security > Input Monitoring)"
    log_info "  3. Drag the overlay to reposition it on screen"
    log_info ""
    log_info "See apps/keycastr/README.md for detailed instructions."
}

do_show() {
    print_heading "Current KeyCastr Settings"

    if ! defaults read "${DOMAIN}" >/dev/null 2>&1; then
        log_warn "No KeyCastr preferences found. KeyCastr may not be installed or run yet."
        return 0
    fi

    echo "All settings:"
    defaults read "${DOMAIN}"
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

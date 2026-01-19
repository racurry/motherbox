#!/bin/bash
# ShortcutDetective - Keyboard shortcut conflict detector
# Detects which app receives a keyboard shortcut (hotkey)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage ShortcutDetective installation.

COMMANDS:
    setup       Install ShortcutDetective via Homebrew
    help        Show this help message

NOTES:
    - Requires Rosetta 2 on Apple Silicon Macs
    - No configuration needed - just launch and use
    - Grant Accessibility permission when prompted
EOF
}

install_rosetta() {
    log_info "Checking Rosetta 2 installation..."

    if check_rosetta; then
        log_success "Rosetta 2 is already installed"
        return 0
    fi

    log_info "Installing Rosetta 2 (required for ShortcutDetective on Apple Silicon)..."
    if softwareupdate --install-rosetta --agree-to-license; then
        log_success "Rosetta 2 installed successfully"
    else
        log_error "Failed to install Rosetta 2"
        return 1
    fi
}

do_setup() {
    print_heading "Setting up ShortcutDetective"

    # Check architecture and install Rosetta if needed
    if [[ "$(uname -m)" == "arm64" ]]; then
        install_rosetta
    fi

    # Install via Homebrew cask
    # Note: This cask is deprecated but still functional
    if ! brew list --cask shortcutdetective &>/dev/null; then
        log_info "Installing ShortcutDetective..."
        brew install --cask shortcutdetective
    else
        log_info "ShortcutDetective already installed"
    fi

    log_success "ShortcutDetective setup complete"
    log_info "Launch the app and grant Accessibility permission when prompted"
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

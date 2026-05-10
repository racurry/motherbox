#!/bin/bash
# Blender - free, open-source 3D creation suite
# Installs Blender via Homebrew cask

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

BLENDER_SUPPORT_DIR="${HOME}/Library/Application Support/Blender"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage Blender installation.

COMMANDS:
    setup       Install Blender via Homebrew
    maintain    Upgrade Blender to the latest cask version
    help        Show this help message

NOTES:
    - Per-version config lives in ~/Library/Application Support/Blender/<X.Y>/
    - On first launch of a new major version, Blender offers to copy settings
      from the previous version (config/ and scripts/).
    - The "blender" CLI is on PATH after install (cask wrapper).
EOF
}

do_setup() {
    print_heading "Setting up Blender"
    require_command brew

    if brew list --cask blender &>/dev/null; then
        log_success "Blender is already installed"
    else
        log_info "Installing Blender via Homebrew..."
        brew install --cask blender
        log_success "Blender installed"
    fi

    if command -v blender &>/dev/null; then
        log_info "blender CLI: $(command -v blender)"
        log_info "$(blender --version 2>&1 | head -1)"
    fi

    if [[ -d "${BLENDER_SUPPORT_DIR}" ]]; then
        local versions
        versions=$(find "${BLENDER_SUPPORT_DIR}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ')
        if [[ -n "${versions}" ]]; then
            log_info "Existing config versions: ${versions}"
        fi
    fi

    log_success "Blender setup complete"
}

do_maintain() {
    print_heading "Blender Maintenance"
    require_command brew

    if ! brew list --cask blender &>/dev/null; then
        log_warn "Blender not installed via Homebrew, run 'setup' first"
        return 0
    fi

    log_info "Checking for Blender updates..."
    local output
    output=$(brew upgrade --cask blender 2>&1 || true)
    if echo "${output}" | grep -q "already installed"; then
        log_success "Blender is already up to date"
    else
        echo "${output}"
        log_success "Blender updated"
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
        setup | maintain)
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
    maintain)
        do_maintain
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

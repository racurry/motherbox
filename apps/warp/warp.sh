#!/bin/bash
# Warp terminal emulator
# Installs Warp and links configuration files to ~/.warp/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

WARP_CONFIG_DIR="${HOME}/.warp"

# Config files linked from this repo into ~/.warp/.
# Warp reads settings.toml and keybindings.yaml as config input and writes
# back to them when settings change in the UI, so symlinks keep the repo and
# the live config in sync. tab_configs/ and worktrees/ are intentionally not
# managed — they hold machine/repo-specific transient state.
WARP_CONFIG_FILES=(
    settings.toml
    keybindings.yaml
)

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Install and configure Warp terminal.

Commands:
    setup       Run full setup (primary entry point)
    show        Display current Warp configuration
    help        Show this help message (also: -h, --help)

What this script does:
    - Installs Warp via Homebrew cask if not present
    - Links config from this repo to ~/.warp/
    - Creates config directory if it doesn't exist

Configuration files:
    - settings.toml: Main settings (appearance, terminal, agents, etc.)
    - keybindings.yaml: Custom key bindings
EOF
}

do_setup() {
    print_heading "Setting up Warp"

    # Install via Homebrew (cask)
    ensure_brew_package warp warp cask

    # Create config directory if needed
    if [[ ! -d "${WARP_CONFIG_DIR}" ]]; then
        log_info "Creating Warp config directory"
        mkdir -p "${WARP_CONFIG_DIR}"
    fi

    # Link configuration files
    for file in "${WARP_CONFIG_FILES[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            link_file "${SCRIPT_DIR}/${file}" "${WARP_CONFIG_DIR}/${file}" "warp"
        else
            log_info "No ${file} found in ${SCRIPT_DIR}"
            log_info "Create ${file} to have it linked during setup"
        fi
    done

    log_success "Warp configuration complete"
}

do_show() {
    print_heading "Current Warp Settings"

    echo "Config directory: ${WARP_CONFIG_DIR}"
    if [[ -d "${WARP_CONFIG_DIR}" ]]; then
        echo "  Status: exists"
        echo ""
        echo "Configuration files:"
        ls -la "${WARP_CONFIG_DIR}/" 2>/dev/null || echo "  (empty)"
    else
        echo "  Status: not created"
    fi

    echo ""
    if [[ -f "${WARP_CONFIG_DIR}/settings.toml" ]]; then
        echo "settings.toml preview (first 20 lines):"
        head -20 "${WARP_CONFIG_DIR}/settings.toml"
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

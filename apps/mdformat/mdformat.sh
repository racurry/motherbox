#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="mdformat"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Manage mdformat installation and configuration.

COMMANDS:
  setup         Install mdformat with plugins and symlink config
  help          Show this help message

INSTALLATION:
  Uses 'uv tool install' to install mdformat with GFM and frontmatter plugins.
  This approach is required because the Homebrew formula doesn't include plugins.
EOF
}

do_setup() {
    print_heading "Setup mdformat"

    # Install mdformat with plugins via uv
    # We use uv instead of brew because:
    # 1. Brew formula doesn't include plugins
    # 2. We need mdformat-gfm for table support
    # 3. We need mdformat-frontmatter for YAML front matter
    # 4. uv tool install creates an isolated environment independent of the system Python
    if command -v mdformat &>/dev/null; then
        log_info "mdformat already installed"
    else
        require_command uv
        log_info "Installing mdformat with plugins..."
        uv tool install mdformat --with mdformat-gfm --with mdformat-frontmatter
    fi

    # Symlink configuration to home directory
    link_home_dotfile "${SCRIPT_DIR}/.mdformat.toml" "${APP_NAME}"

    log_success "mdformat setup complete"
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

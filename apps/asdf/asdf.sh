#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="asdf"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Manage asdf plugins and runtime installations.

Commands:
    setup       Run full setup (add plugins, install runtimes)
    help        Show this help message (also: -h, --help)
EOF
}

link_config_files() {
    print_heading "Link asdf config files"
    link_home_dotfile "${SCRIPT_DIR}/.tool-versions" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.asdfrc" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.default-gems" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.default-python-packages" "${APP_NAME}"
}

add_plugins() {
    print_heading "Add asdf plugins"

    require_command asdf

    # Get plugin list from .tool-versions file
    local tool_versions="${SCRIPT_DIR}/.tool-versions"
    if [[ ! -f "${tool_versions}" ]]; then
        log_info "No .tool-versions file found"
        return 0
    fi
    plugin_list=$(awk '{print $1}' "${tool_versions}" || true)
    if [[ -z "${plugin_list}" ]]; then
        log_info "No tools configured for asdf"
        return 0
    fi

    while IFS= read -r plugin; do
        [[ -n "${plugin}" ]] || continue
        log_info "Adding '${plugin}'"
        asdf plugin add "${plugin}"
    done <<<"${plugin_list}"
}

install_runtimes() {
    print_heading "Install asdf runtimes"

    require_command asdf

    log_info "Running 'asdf install'"
    unset ASDF_RUBY_VERSION ASDF_NODEJS_VERSION ASDF_PYTHON_VERSION
    asdf install
}

do_setup() {
    link_config_files
    add_plugins
    install_runtimes
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

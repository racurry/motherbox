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
    update      Update all asdf plugins to their latest versions
    help        Show this help message (also: -h, --help)
EOF
}

link_config_files() {
    print_heading "Link asdf config files"
    link_home_dotfile "${SCRIPT_DIR}/.tool-versions" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.asdfrc" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.default-gems" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.default-npm-packages" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.default-python-packages" "${APP_NAME}"
}

add_plugins() {
    print_heading "Add asdf plugins"

    require_command asdf

    # Get plugin list from asdf's current command (relies on asdf finding .tool-versions)
    plugin_list=$(asdf current --no-header 2>/dev/null | awk '{print $1}' || true)
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

update_plugins() {
    print_heading "Update asdf plugins"

    require_command asdf

    log_info "Running 'asdf plugin update --all'"
    asdf plugin update --all
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
        update)
            command="update"
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
    update)
        update_plugins
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

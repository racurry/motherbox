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
    link_home_dotfile "${SCRIPT_DIR}/.default-npm-packages" "${APP_NAME}"
    link_home_dotfile "${SCRIPT_DIR}/.default-python-packages" "${APP_NAME}"
}

ensure_asdf_sourced() {
    if command -v asdf >/dev/null 2>&1; then
        return 0
    fi

    # Source Homebrew first (asdf is installed via Homebrew)
    local brew_path="/opt/homebrew/bin/brew"
    if [[ -x "${brew_path}" ]]; then
        eval "$(${brew_path} shellenv)"
    fi

    # Source asdf
    local brew_prefix
    brew_prefix="$(brew --prefix 2>/dev/null || true)"
    local asdf_sh="${brew_prefix}/opt/asdf/libexec/asdf.sh"
    if [[ -f "${asdf_sh}" ]]; then
        # shellcheck source=/dev/null
        . "${asdf_sh}"
        log_info "asdf sourced into current shell"
    fi
}

add_plugins() {
    print_heading "Add asdf plugins"

    ensure_asdf_sourced
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

    ensure_asdf_sourced
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

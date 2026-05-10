#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Link Gemini CLI global configuration.

Commands:
    setup       Run full setup (install + rules)
    rules       Link AGENTS.md file
    help        Show this help message (also: -h, --help)

Description:
    This script installs Gemini CLI and creates symbolic links for global configuration:
    - apps/_shared/AGENTS.global.md -> ~/AGENTS.md
EOF
}

do_rules() {
    print_heading "Link Gemini agent rules"

    # Link AGENTS.global.md to ~/AGENTS.md
    local agents_global_src="${REPO_ROOT}/apps/_shared/AGENTS.global.md"
    local agents_dest="${HOME}/AGENTS.md"
    require_file "${agents_global_src}"
    link_file "${agents_global_src}" "${agents_dest}" "shared"

    log_success "Gemini agent rules linked"
}

do_setup() {
    # Install via npm (not brew) to avoid node version conflicts with asdf
    npm install -g @google/gemini-cli
    do_rules
    log_success "Gemini CLI setup complete"
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup | rules)
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
    rules)
        do_rules
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

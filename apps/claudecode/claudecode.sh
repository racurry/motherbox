#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Link Claude Code global configuration to ~/.claude.

Commands:
    setup       Run full setup (rules + commands + statuslines + settings)
    rules       Link CLAUDE.md and AGENTS.md files
    commands    Sync commands to ~/.claude/commands
    statuslines Sync statuslines to ~/.claude/statuslines
    settings    Configure settings.json (includes hooks)
    help        Show this help message (also: -h, --help)

Description:
    This script creates symbolic links for Claude Code global configuration:
    - apps/claudecode/CLAUDE.global.md -> ~/.claude/CLAUDE.md
    - apps/_shared/AGENTS.global.md -> ~/AGENTS.md
    - apps/claudecode/commands/* -> ~/.claude/commands/* (each file separately)
    - apps/claudecode/statuslines/* -> ~/.claude/statuslines/* (each file separately)
EOF
}

do_rules() {
    print_heading "Link Claude Code rules"

    mkdir -p "${HOME}/.claude"

    # Link CLAUDE.global.md to ~/.claude/CLAUDE.md
    local claude_global_src="${REPO_ROOT}/apps/claudecode/CLAUDE.global.md"
    local claude_dest="${HOME}/.claude/CLAUDE.md"
    require_file "${claude_global_src}"
    link_file "${claude_global_src}" "${claude_dest}" "claudecode"

    # Link AGENTS.global.md to ~/AGENTS.md
    local agents_global_src="${REPO_ROOT}/apps/_shared/AGENTS.global.md"
    local agents_dest="${HOME}/AGENTS.md"
    require_file "${agents_global_src}"
    link_file "${agents_global_src}" "${agents_dest}" "shared"

    log_success "Claude Code rules linked"
}

do_commands() {
    print_heading "Sync Claude Code commands"

    local commands_src_dir="${REPO_ROOT}/apps/claudecode/commands"
    local commands_dest_dir="${HOME}/.claude/commands"

    if [[ ! -d "${commands_src_dir}" ]]; then
        log_info "No commands directory found, skipping"
        return 0
    fi

    mkdir -p "${commands_dest_dir}"

    for cmd_file in "${commands_src_dir}"/*; do
        if [[ -f "${cmd_file}" ]]; then
            local filename
            filename=$(basename "${cmd_file}")
            link_file "${cmd_file}" "${commands_dest_dir}/${filename}" "claudecode"
        fi
    done

    log_success "Claude Code commands synced"
}

do_statuslines() {
    print_heading "Sync Claude Code statuslines"

    local statuslines_src_dir="${REPO_ROOT}/apps/claudecode/statuslines"
    local statuslines_dest_dir="${HOME}/.claude/statuslines"

    if [[ ! -d "${statuslines_src_dir}" ]]; then
        log_info "No statuslines directory found, skipping"
        return 0
    fi

    mkdir -p "${statuslines_dest_dir}"

    for statusline_file in "${statuslines_src_dir}"/*; do
        if [[ -f "${statusline_file}" ]]; then
            local filename
            filename=$(basename "${statusline_file}")
            link_file "${statusline_file}" "${statuslines_dest_dir}/${filename}" "claudecode"
        fi
    done

    log_success "Claude Code statuslines synced"
}

do_settings() {
    print_heading "Configure Claude Code settings"

    require_command jq

    mkdir -p "${HOME}/.claude"
    local machine_settings="${HOME}/.claude/settings.json"
    local universal_settings="${SCRIPT_DIR}/settings.json"

    require_file "${universal_settings}"

    # Ensure machine settings file exists
    if [[ ! -f "${machine_settings}" ]]; then
        log_info "Creating new settings.json file"
        echo '{}' >"${machine_settings}"
    fi

    # Backup before modification
    backup_file "${machine_settings}" "claudecode"

    # Merge universal settings into machine settings (universal values take precedence)
    local tmp_file
    tmp_file=$(mktemp)
    jq -s '.[0] * .[1]' "${machine_settings}" "${universal_settings}" >"${tmp_file}"
    mv "${tmp_file}" "${machine_settings}"

    log_info "Merged settings from ${universal_settings}"
    log_success "Claude Code settings configured"
}

do_setup() {
    # Install via native installer for immediate updates
    curl -fsSL https://claude.ai/install.sh | bash

    do_rules
    do_commands
    do_statuslines
    do_settings
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup | rules | commands | statuslines | settings)
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
    commands)
        do_commands
        ;;
    statuslines)
        do_statuslines
        ;;
    settings)
        do_settings
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

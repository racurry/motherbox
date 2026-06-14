#!/bin/bash
# 1Password SSH agent configuration
# Copies the per-profile agent.toml and ssh_config into place.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APPS_DIR="${REPO_ROOT}/apps/1password"
CONFIG_DIR="${HOME}/.config/1password/ssh"
AGENT_TOML="${CONFIG_DIR}/agent.toml"
SSH_DIR="${HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"
AGENT_SOCK="${HOME}/.1password/agent.sock"
# The real socket exposed by the 1Password SSH agent.
P1_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Configure 1Password SSH agent and SSH client config.

Manages:
    ~/.1password/agent.sock              - symlink to the 1Password agent socket
    ~/.config/1password/ssh/agent.toml   - 1Password SSH agent keys
    ~/.ssh/config                        - SSH client configuration

agent.toml is sourced per-profile from apps/1password/<profile>/agent.toml.
ssh_config is shared (apps/1password/ssh_config), with an optional
machine-specific override at apps/1password/<profile>/<machine>/ssh_config.

Commands:
    setup       Run full setup (primary entry point)
    show        Display current agent.toml and SSH config
    help        Show this help message (also: -h, --help)

Options:
    --profile MODE     Set mode to 'firsthand', 'galileo', or 'personal'
    --machine MACHINE  Use a machine-specific SSH config if present
                       (<profile>/<machine>/ssh_config, e.g. the mini)
    --unattended    Skip prompts, fail if mode unknown
EOF
}

do_setup() {
    print_heading "Configuring 1Password SSH agent"

    local profile_dir="${APPS_DIR}/${PROFILE}"
    local agent_source="${profile_dir}/agent.toml"
    local ssh_config_source="${APPS_DIR}/ssh_config"

    # Prefer a machine-specific SSH config if one exists (e.g. the mini uses a
    # local on-disk key for GitHub instead of the 1Password agent).
    if [[ -n "${MACHINE:-}" && -f "${profile_dir}/${MACHINE}/ssh_config" ]]; then
        ssh_config_source="${profile_dir}/${MACHINE}/ssh_config"
        log_info "Using machine-specific SSH config for ${MACHINE}"
    fi

    require_file "${agent_source}"
    require_file "${ssh_config_source}"

    # Expose the 1Password agent socket at a stable path.
    mkdir -p "$(dirname "${AGENT_SOCK}")"
    link_file "${P1_SOCK}" "${AGENT_SOCK}" "1password"

    # Configure SSH client
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    link_file "${ssh_config_source}" "${SSH_CONFIG}" "1password"

    # Configure 1Password agent
    mkdir -p "${CONFIG_DIR}"
    link_file "${agent_source}" "${AGENT_TOML}" "1password"

    log_success "1Password SSH agent configured"
}

do_show() {
    if [[ -f "${AGENT_TOML}" ]]; then
        print_heading "1Password agent.toml"
        cat "${AGENT_TOML}"
    else
        log_warn "No agent.toml found at ${AGENT_TOML}"
    fi

    echo ""

    if [[ -f "${SSH_CONFIG}" ]]; then
        print_heading "SSH config"
        cat "${SSH_CONFIG}"
    else
        log_warn "No SSH config found at ${SSH_CONFIG}"
    fi
}

main() {
    local command=""
    local args=("$@")

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
        determine_profile "${args[@]}" || exit 1
        determine_machine "${args[@]}"
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

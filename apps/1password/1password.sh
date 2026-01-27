#!/bin/bash
# 1Password SSH agent configuration
# Copies the appropriate agent.toml based on mode (galileo or personal)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APPS_DIR="${REPO_ROOT}/apps/1password"
CONFIG_DIR="${HOME}/.config/1password/ssh"
AGENT_TOML="${CONFIG_DIR}/agent.toml"
SSH_DIR="${HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Configure 1Password SSH agent and SSH client config.

Manages:
    ~/.config/1password/ssh/agent.toml  - 1Password SSH agent keys
    ~/.ssh/config                        - SSH client configuration

The SSH config forces specific keys per host to avoid SAML SSO issues
with GitHub organizations. Requires public keys exported from 1Password:
    ~/.ssh/galileo_github.pub   (galileo mode)
    ~/.ssh/personal_github.pub  (both modes)

Commands:
    setup       Run full setup (primary entry point)
    show        Display current agent.toml and SSH config
    help        Show this help message (also: -h, --help)

Options:
    --mode MODE     Set mode to 'galileo' or 'personal'
    --unattended    Skip prompts, fail if mode unknown
EOF
}

do_setup() {
    print_heading "Configuring 1Password SSH agent"

    local agent_source="${APPS_DIR}/agent.${SETUP_MODE}.toml"
    local ssh_config_source="${APPS_DIR}/ssh_config.${SETUP_MODE}"

    require_file "${agent_source}"
    require_file "${ssh_config_source}"

    # Configure 1Password agent
    mkdir -p "${CONFIG_DIR}"
    link_file "${agent_source}" "${AGENT_TOML}" "1password"

    # Configure SSH client
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    link_file "${ssh_config_source}" "${SSH_CONFIG}" "1password"

    # Export public keys from 1Password
    export_public_keys

    log_success "1Password SSH agent configured"
}

export_public_keys() {
    if ! command -v op &>/dev/null; then
        log_warn "1Password CLI (op) not found, cannot export public keys"
        log_info "Install with: brew install 1password-cli"
        return 1
    fi

    if [[ "${SETUP_MODE}" == "galileo" ]]; then
        export_key "Galileo github ssh key" "Employee" "galileo.1password.com" "galileo_github.pub"
        export_key "Aaron's github ssh key" "Private" "my.1password.com" "personal_github.pub"
    else
        export_key "Aaron's github ssh key" "Private" "my.1password.com" "personal_github.pub"
    fi
}

export_key() {
    local item="$1"
    local vault="$2"
    local account="$3"
    local filename="$4"
    local dest="${SSH_DIR}/${filename}"

    if [[ -f "${dest}" ]]; then
        log_info "Public key already exists: ${filename}"
        return 0
    fi

    log_info "Exporting public key: ${filename}"
    if op item get "${item}" --vault "${vault}" --account "${account}" --fields "public key" >"${dest}" 2>/dev/null; then
        chmod 644 "${dest}"
        log_success "Exported ${filename}"
    else
        log_warn "Failed to export ${filename} - you may need to sign into 1Password CLI"
        rm -f "${dest}"
        return 1
    fi
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
        determine_setup_mode "${args[@]}" || exit 1
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

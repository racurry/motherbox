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
    ~/.ssh/firsthand_github.pub (firsthand mode)
    ~/.ssh/galileo_github.pub   (galileo/firsthand modes)
    ~/.ssh/personal_github.pub  (all modes)

On the mini, the GitHub key bypasses the 1Password agent, so its private key
is restored from 1Password too (~/.ssh/id_ed25519_mini), re-encrypted with its
stored passphrase and seeded into the macOS keychain.

Commands:
    setup       Run full setup (primary entry point)
    show        Display current agent.toml and SSH config
    help        Show this help message (also: -h, --help)

Options:
    --profile MODE     Set mode to 'firsthand', 'galileo', or 'personal'
    --machine MACHINE  Use a machine-specific SSH config if present
                       (ssh_config.<profile>.<machine>, e.g. the mini)
    --unattended    Skip prompts, fail if mode unknown
EOF
}

do_setup() {
    print_heading "Configuring 1Password SSH agent"

    local agent_source="${APPS_DIR}/agent.${PROFILE}.toml"
    local ssh_config_source="${APPS_DIR}/ssh_config.${PROFILE}"

    # Prefer a machine-specific SSH config if one exists (e.g. the mini uses a
    # local on-disk key for GitHub instead of the 1Password agent).
    if [[ -n "${MACHINE:-}" && -f "${APPS_DIR}/ssh_config.${PROFILE}.${MACHINE}" ]]; then
        ssh_config_source="${APPS_DIR}/ssh_config.${PROFILE}.${MACHINE}"
        log_info "Using machine-specific SSH config for ${MACHINE}"
    fi

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

    # Materialize machine-specific private keys (e.g. the mini's GitHub key)
    export_machine_keys

    log_success "1Password SSH agent configured"
}

export_public_keys() {
    if ! command -v op &>/dev/null; then
        log_warn "1Password CLI (op) not found, cannot export public keys"
        log_info "Install with: brew install 1password-cli"
        return 1
    fi

    if [[ "${PROFILE}" == "firsthand" ]]; then
        # TODO: Move to Firsthand company vault once account is set up
        export_key "Firsthand github ssh key" "Private" "my.1password.com" "firsthand_github.pub"
        export_key "Aaron's github ssh key" "Private" "my.1password.com" "personal_github.pub"
    elif [[ "${PROFILE}" == "galileo" ]]; then
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

# export_machine_keys materializes private keys specific to a machine.
# The mini bypasses the 1Password SSH agent for GitHub (IdentityAgent none) and
# reads a local on-disk key, so that private key must be restored from 1Password
# on a rebuild. Best-effort: failures warn but never abort setup.
export_machine_keys() {
    case "${MACHINE:-}" in
    mini)
        provision_private_key \
            "Headless mini SSH key" "Private" "my.1password.com" "id_ed25519_mini" || true
        ;;
    esac
    return 0
}

# provision_private_key restores a passphrase-protected private key from
# 1Password: export the (unencrypted) key and its public half, re-encrypt the
# key on disk with the stored passphrase, then seed the macOS keychain so
# `UseKeychain yes` can unlock it without a prompt. Idempotent: skips if present.
provision_private_key() {
    local item="$1"
    local vault="$2"
    local account="$3"
    local filename="$4"
    local dest="${SSH_DIR}/${filename}"
    local ref="op://${vault}/${item}"

    if [[ -f "${dest}" ]]; then
        log_info "Private key already exists: ${filename}"
        return 0
    fi

    if ! command -v op &>/dev/null; then
        log_warn "1Password CLI (op) not found, cannot export ${filename}"
        return 1
    fi

    log_info "Provisioning private key: ${filename}"

    # Export the unencrypted key, then write the public half alongside it.
    if ! op read "${ref}/private key?ssh-format=openssh" --account "${account}" >"${dest}" 2>/dev/null; then
        log_warn "Failed to export ${filename} - you may need to sign into 1Password CLI"
        rm -f "${dest}"
        return 1
    fi
    chmod 600 "${dest}"
    op read "${ref}/public key" --account "${account}" >"${dest}.pub" 2>/dev/null || true
    chmod 644 "${dest}.pub" 2>/dev/null || true

    # Re-encrypt on disk with the stored passphrase to match the secured state.
    local passphrase
    if passphrase="$(op read "${ref}/passphrase" --account "${account}" 2>/dev/null)" \
        && [[ -n "${passphrase}" ]]; then
        if ssh-keygen -p -f "${dest}" -P "" -N "${passphrase}" >/dev/null 2>&1; then
            seed_ssh_keychain "${dest}" "${ref}/passphrase" "${account}"
        else
            log_warn "Could not set passphrase on ${filename}; left unencrypted"
        fi
        unset passphrase
    else
        log_warn "No passphrase found for '${item}'; ${filename} left unencrypted"
    fi

    log_success "Provisioned ${filename}"
}

# seed_ssh_keychain stores a key's passphrase in the macOS login keychain so
# `UseKeychain yes` unlocks it without prompting (needed for headless git).
# Uses an askpass helper that fetches the passphrase from 1Password at runtime,
# so the secret is never written to a file by this script.
seed_ssh_keychain() {
    local keyfile="$1"
    local pass_ref="$2"
    local account="$3"

    if [[ "$(uname -s)" != "Darwin" ]]; then
        return 0
    fi

    local askpass
    askpass="$(mktemp)"
    cat >"${askpass}" <<EOF
#!/bin/bash
exec op read "${pass_ref}" --account "${account}" 2>/dev/null
EOF
    chmod 700 "${askpass}"

    if SSH_ASKPASS="${askpass}" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
        ssh-add --apple-use-keychain "${keyfile}" >/dev/null 2>&1; then
        log_info "Seeded macOS keychain for $(basename "${keyfile}")"
    else
        log_warn "Could not seed keychain; run once: ssh-add --apple-use-keychain ${keyfile}"
    fi

    rm -f "${askpass}"
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

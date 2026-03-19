#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="motherbox"
LOG_TAG="motherbox"
LOCAL_ZSHRC="$HOME/.local.zshrc"
TMP_DIR="${REPO_ROOT}/.tmp"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Sync ~/.local.zshrc secrets to/from 1Password.

Commands:
    pull        Pull secrets from 1Password to ~/.local.zshrc
    push        Push ~/.local.zshrc to 1Password
    diff        Show diff between local file and 1Password
    help        Show this help message (also: -h, --help)

Options:
    --profile MODE     Set mode to 'galileo' or 'personal'
    --unattended    Skip prompts, fail if mode unknown
EOF
}

# Set 1Password item/vault/account based on PROFILE
_configure_op_target() {
    case "${PROFILE}" in
    personal)
        OP_ITEM=".local.zshrc"
        OP_VAULT="Private"
        OP_ACCOUNT="my.1password.com"
        ;;
    galileo)
        OP_ITEM=".local.zshrc"
        OP_VAULT="Employee"
        OP_ACCOUNT="galileo.1password.com"
        ;;
    *)
        fail "Unknown setup mode: ${PROFILE}"
        ;;
    esac
}

do_pull() {
    require_command op
    _configure_op_target

    print_heading "Pulling secrets from 1Password (${PROFILE})"

    log_info "Fetching '${OP_ITEM}' from vault '${OP_VAULT}'"
    local content
    content="$(op item get "${OP_ITEM}" --vault "${OP_VAULT}" --account "${OP_ACCOUNT}" --fields notesPlain)" ||
        fail "Failed to fetch item from 1Password"

    if [[ -f "${LOCAL_ZSHRC}" ]]; then
        backup_file "${LOCAL_ZSHRC}" "${APP_NAME}"
    fi

    printf '%s\n' "${content}" >"${LOCAL_ZSHRC}"
    log_success "Written to ${LOCAL_ZSHRC}"
}

do_push() {
    require_command op
    _configure_op_target
    require_file "${LOCAL_ZSHRC}"

    print_heading "Pushing secrets to 1Password (${PROFILE})"

    log_info "Updating '${OP_ITEM}' in vault '${OP_VAULT}'"
    local file_content
    file_content="$(cat "${LOCAL_ZSHRC}")"
    op item edit "${OP_ITEM}" --vault "${OP_VAULT}" --account "${OP_ACCOUNT}" "notesPlain=${file_content}" >/dev/null ||
        fail "Failed to update item in 1Password"

    log_success "Pushed ${LOCAL_ZSHRC} to 1Password"
}

do_diff() {
    require_command op
    _configure_op_target
    require_file "${LOCAL_ZSHRC}"

    print_heading "Diffing local vs 1Password (${PROFILE})"

    mkdir -p "${TMP_DIR}"
    local tmp_file="${TMP_DIR}/local.zshrc.1password"

    log_info "Fetching '${OP_ITEM}' from vault '${OP_VAULT}'"
    op item get "${OP_ITEM}" --vault "${OP_VAULT}" --account "${OP_ACCOUNT}" --fields notesPlain >"${tmp_file}" ||
        {
            rm -f "${tmp_file}"
            fail "Failed to fetch item from 1Password"
        }

    # diff exits 1 if files differ, which would trip set -e
    diff "${LOCAL_ZSHRC}" "${tmp_file}" && log_info "No differences found" || true

    rm -f "${tmp_file}"
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
        pull | push | diff)
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
    pull | push | diff)
        determine_profile "${args[@]}" || exit 1
        "do_${command}"
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

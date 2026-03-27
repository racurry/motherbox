#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Install Mac App Store apps via mas CLI.

Commands:
    setup       Install apps from app list files
    list        Show which apps would be installed
    help        Show this help message (also: -h, --help)

Options:
    --profile MODE   Include profile-specific apps (galileo/personal)
    --unattended     Skip installation (mas apps require interactive auth)

App List Format:
    apps.txt              Common apps (all profiles)
    {profile}.txt         Profile-specific apps
EOF
}

# Parse app list file, returning app IDs (skips blanks and comments)
parse_app_list() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        return 0
    fi
    grep -v '^\s*#' "${file}" | grep -v '^\s*$' | awk '{print $1}'
}

# Get app name from comment in list file
get_app_name() {
    local file="$1"
    local app_id="$2"
    grep "^${app_id}" "${file}" | sed 's/.*# //' || echo "${app_id}"
}

install_apps() {
    local file="$1"
    local label="$2"

    if [[ ! -f "${file}" ]]; then
        log_warn "No app list found at ${file}"
        return 0
    fi

    local app_ids
    app_ids="$(parse_app_list "${file}")"
    if [[ -z "${app_ids}" ]]; then
        log_info "No apps in ${file}"
        return 0
    fi

    log_info "Installing ${label} Mac App Store apps"

    # Cache installed app list once to avoid running mas list per app
    local installed
    installed="$(mas list | awk '{print $1}')"

    local failed=0
    while IFS= read -r app_id; do
        [[ -n "${app_id}" ]] || continue
        local app_name
        app_name="$(get_app_name "${file}" "${app_id}")"

        # Check if already installed
        if echo "${installed}" | grep -q "^${app_id}$"; then
            log_info "Already installed: ${app_name}"
            continue
        fi

        log_info "Installing: ${app_name} (${app_id})"
        if ! mas install "${app_id}"; then
            log_warn "Failed to install: ${app_name} (${app_id})"
            failed=$((failed + 1))
        fi
    done <<<"${app_ids}"

    if [[ ${failed} -gt 0 ]]; then
        log_warn "${failed} app(s) failed to install from ${label}"
    fi
}

list_apps() {
    local main_list="${SCRIPT_DIR}/apps.txt"

    echo "=== Common apps ==="
    if [[ -f "${main_list}" ]]; then
        grep -v '^\s*#' "${main_list}" | grep -v '^\s*$' || true
    fi

    if [[ -n "${PROFILE:-}" ]]; then
        local profile_list="${SCRIPT_DIR}/${PROFILE}.txt"
        echo ""
        echo "=== ${PROFILE} apps ==="
        if [[ -f "${profile_list}" ]]; then
            grep -v '^\s*#' "${profile_list}" | grep -v '^\s*$' || true
        else
            echo "(no profile list found)"
        fi
    fi
}

do_setup() {
    print_heading "Mac App Store Apps"

    if [[ "${UNATTENDED:-false}" == "true" ]]; then
        log_warn "Skipping Mac App Store apps in unattended mode (requires interactive auth)"
        log_warn "Run './apps/mas/mas.sh setup --profile ${PROFILE:-personal}' interactively to install"
        return 0
    fi

    require_command mas

    # Check if signed in (mas account returns non-zero if not signed in on older versions,
    # but on newer macOS the App Store handles auth via system dialogs)
    log_info "Mac App Store apps may prompt for Apple ID authentication"

    install_apps "${SCRIPT_DIR}/apps.txt" "common"

    if [[ -n "${PROFILE:-}" ]]; then
        local profile_list="${SCRIPT_DIR}/${PROFILE}.txt"
        install_apps "${profile_list}" "${PROFILE}"
    fi

    log_success "Mac App Store app installation complete"
}

main() {
    local command=""
    local args=("$@")

    while [[ $# -gt 0 ]]; do
        case "$1" in
        setup)
            command="setup"
            shift
            ;;
        list)
            command="list"
            shift
            ;;
        help | --help | -h)
            show_help
            exit 0
            ;;
        *)
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
        determine_profile "${args[@]}" || true
        do_setup
        ;;
    list)
        determine_profile "${args[@]}" || true
        list_apps
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

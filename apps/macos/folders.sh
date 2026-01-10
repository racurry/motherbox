#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

# Paths used by this script
PATH_DOCUMENTS="${HOME}/Documents"
PATH_WORKSPACE="${HOME}/workspace"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Create organizational folder structure.

Commands:
    setup       Run full setup (primary entry point)
    help        Show this help message (also: -h, --help)

Options:
    --mode MODE     Set mode to 'galileo' or 'personal'
    --unattended    Skip prompts, fail if mode unknown

Folders created in ${PATH_WORKSPACE}:
    infra           Infrastructure projects (including this repo)
    sandbox         Experimental/throwaway projects

Additional folders created in galileo mode:
    galileo/        Galileo work projects
    galileo/sandbox Galileo experimental projects

Folders created in ${PATH_DOCUMENTS}:
    @auto           Automated/scripted content
    000_Inbox       Incoming items to be processed
    100_Life        Personal life organization
    150_Projects    Active projects
    200_People      People-related information
    400_Topics      Topic-based resources
    700_Libraries   Reference materials
    800_Posterity   Long-term archival
    999_Meta        Meta information about the system

Examples:
    $0 setup    # Create folder structure in Documents
EOF
}

ensure_folder() {
    local target="$1"
    if [[ -d "${target}" ]]; then
        log_info "Folder already exists: ${target}"
    else
        log_info "Creating folder: ${target}"
        mkdir -p "${target}"
    fi
}

do_setup() {
    print_heading "Make folders how I like em"

    # Workspace folders (always created)
    log_info "Creating workspace folders in ${PATH_WORKSPACE}"
    local workspace_folders=(
        "infra"
        "sandbox"
    )
    for folder in "${workspace_folders[@]}"; do
        ensure_folder "${PATH_WORKSPACE}/${folder}"
    done

    # Galileo-specific workspace folders
    if [[ "${SETUP_MODE}" == "galileo" ]]; then
        log_info "Creating galileo workspace folders"
        local galileo_folders=(
            "galileo"
            "galileo/sandbox"
        )
        for folder in "${galileo_folders[@]}"; do
            ensure_folder "${PATH_WORKSPACE}/${folder}"
        done
    fi

    # Documents folders
    log_info "Creating documents folders in ${PATH_DOCUMENTS}"
    local documents_folders=(
        "@auto"
        "000_Inbox"
        "100_Life"
        "150_Projects"
        "200_People"
        "400_Topics"
        "700_Libraries"
        "800_Posterity"
        "900_Sharing"
        "999_Meta"
    )
    for folder in "${documents_folders[@]}"; do
        ensure_folder "${PATH_DOCUMENTS}/${folder}"
    done

    log_info "Created the folders we like"
}

main() {
    local command=""
    local args=("$@")

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --mode) shift 2 ;;
        --unattended) shift ;;
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup)
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
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

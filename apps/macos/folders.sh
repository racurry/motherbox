#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

# Paths used by this script
PATH_DOCUMENTS="${HOME}/Documents"
PATH_CODE="${HOME}/code"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Create organizational folder structure.

Commands:
    setup       Run full setup (primary entry point)
    help        Show this help message (also: -h, --help)

Options:
    --profile MODE     Set mode to 'firsthand' or 'galileo'
    --unattended    Skip prompts, fail if mode unknown

Folders created in ${PATH_CODE}:
    me/             Personal projects
    me/_archive     Archived personal projects
    me/_scratch     Personal experiments/throwaway
    vendor/         Third-party/vendored repos

Additional folders created in firsthand mode:
    firsthand/          Firsthand work projects
    firsthand/_archive  Archived Firsthand projects
    firsthand/_scratch  Firsthand experiments
    galileo/            Galileo work projects (contracting)
    galileo/_archive    Archived Galileo projects
    galileo/_scratch    Galileo experiments

Additional folders created in galileo mode:
    galileo/            Galileo work projects
    galileo/_archive    Archived Galileo projects
    galileo/_scratch    Galileo experiments

Folders created in ${PATH_DOCUMENTS}:
    @auto           Automated/scripted content
    000_Inbox       Incoming items to be processed
    100_Areas       Areas of responsibility
    200_People      People-related information
    300_Time        Time-based records
    400_Topics      Topic-based resources
    500_Projects    Active projects
    600_Output      Published/output content
    800_Libraries   Reference materials
    900_Sharing     Shared content
    999_Meta        Meta information about the system

Folders created in ~/skynet:
    skynet/

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

    # Code folders (always created)
    log_info "Creating code folders in ${PATH_CODE}"
    local code_folders=(
        "me"
        "me/_archive"
        "me/_scratch"
        "vendor"
    )
    for folder in "${code_folders[@]}"; do
        ensure_folder "${PATH_CODE}/${folder}"
    done

    # Work-specific code folders
    if [[ "${PROFILE}" == "firsthand" ]]; then
        log_info "Creating firsthand code folders"
        local firsthand_folders=(
            "firsthand"
            "firsthand/_archive"
            "firsthand/_scratch"
            "galileo"
            "galileo/_archive"
            "galileo/_scratch"
        )
        for folder in "${firsthand_folders[@]}"; do
            ensure_folder "${PATH_CODE}/${folder}"
        done
    elif [[ "${PROFILE}" == "galileo" ]]; then
        log_info "Creating galileo code folders"
        local galileo_folders=(
            "galileo"
            "galileo/_archive"
            "galileo/_scratch"
        )
        for folder in "${galileo_folders[@]}"; do
            ensure_folder "${PATH_CODE}/${folder}"
        done
    fi

    # Documents folders
    log_info "Creating documents folders in ${PATH_DOCUMENTS}"
    local documents_folders=(
        "@auto"
        "000_Inbox"
        "100_Areas"
        "200_People"
        "300_Time"
        "400_Topics"
        "500_Projects"
        "600_Output"
        "800_Libraries"
        "900_Sharing"
        "999_Meta"
    )
    for folder in "${documents_folders[@]}"; do
        ensure_folder "${PATH_DOCUMENTS}/${folder}"
    done

    # Skynet folder
    log_info "Creating skynet folder"
    ensure_folder "${HOME}/skynet"

    log_info "Created the folders we like"
}

main() {
    local command=""
    local args=("$@")

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --profile) shift 2 ;;
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
        determine_profile "${args[@]}" || exit 1
        do_setup
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

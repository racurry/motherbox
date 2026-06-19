#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

# --- Paths --------------------------------------------------------------------
PATH_ICLOUD="${HOME}/iCloud"
PATH_ICLOUD_MOBILE_DOCUMENTS="${HOME}/Library/Mobile Documents/com~apple~CloudDocs"

# --- Constants ----------------------------------------------------------------
BRCTL="/System/Library/PrivateFrameworks/CloudDocs.framework/Versions/A/Resources/brctl"
DIAG_TMPDIR=""
DIAG_STATUS_FILE=""
DIAG_LOG_FILE=""

show_help() {
    cat <<EOF
Usage: $0 COMMAND [OPTIONS]

Manage iCloud Drive symlink and diagnose sync issues.

Commands:
    setup       Create ~/iCloud symlink (primary entry point)
    diagnose    Run iCloud Drive diagnostics
    help        Show this help message (also: -h, --help)

Diagnose Options:
    --all           Run all diagnostics (default)
    --processes     Show iCloud sync processes only
    --status        Show CloudDocs status and counters only
    --logs          Show recent error logs only
    --files         Check for problematic files only
    --permissions   Show iCloud Drive permissions only
    --tips          Show remediation tips only

Examples:
    $0 setup                  # Create ~/iCloud symlink
    $0 diagnose               # Run all diagnostics
    $0 diagnose --processes   # Check sync processes only

Description:
    Setup mode creates a convenient symlink from ~/iCloud to the actual
    iCloud Drive directory at ~/Library/Mobile Documents/com~apple~CloudDocs.
    If iCloud Drive is not available, the script will skip the operation.

    Diagnose mode helps troubleshoot iCloud Drive sync problems by:
    - Checking iCloud sync processes (bird, cloudd)
    - Parsing CloudDocs status for upload/download/error counts
    - Scanning recent logs for errors
    - Identifying files with problematic names or sizes
    - Showing permissions on iCloud Drive folders
EOF
}

# --- Symlink functions --------------------------------------------------------

do_setup() {
    print_heading "Set iCloud symlink"

    local target_link="${PATH_ICLOUD}"
    local icloud_source="${PATH_ICLOUD_MOBILE_DOCUMENTS}"

    if [[ ! -d "${icloud_source}" ]]; then
        log_warn "iCloud Drive not found at ${icloud_source}; skipping symlink"
        return 0
    fi

    if [[ -L "${target_link}" ]]; then
        local current_target
        current_target="$(readlink "${target_link}")"
        if [[ "${current_target}" == "${icloud_source}" ]]; then
            log_info "'~/iCloud' is already correctly symlinked"
            return 0
        else
            log_info "Updating existing symlink from ${current_target} to ${icloud_source}"
            ln -sf "${icloud_source}" "${target_link}"
            return 0
        fi
    fi

    if [[ -e "${target_link}" ]]; then
        fail "${target_link} exists and is not a symlink"
    fi

    log_info "Creating iCloud symlink ${target_link} -> ${icloud_source}"
    ln -s "${icloud_source}" "${target_link}"
    log_info "'~/iCloud' is correctly symlinked"
}

# --- Diagnostic temp file management ------------------------------------------

diag_init_temp() {
    DIAG_TMPDIR="$(mktemp -d -t iclouddiag)"
    DIAG_STATUS_FILE="${DIAG_TMPDIR}/status.txt"
    DIAG_LOG_FILE="${DIAG_TMPDIR}/log.txt"
}

diag_cleanup() {
    [[ -n "${DIAG_TMPDIR}" && -d "${DIAG_TMPDIR}" ]] && rm -rf "${DIAG_TMPDIR}"
}

# --- Diagnostic functions -----------------------------------------------------

diag_preflight() {
    print_heading "iCloud Drive Diagnostic"
    log_info "Time: $(date)"
    log_info "macOS: $(sw_vers 2>/dev/null | tr '\n' ' ' | sed 's/  / /g')"
    log_info "iCloud Drive root: ${PATH_ICLOUD_MOBILE_DOCUMENTS}"

    if [[ ! -x "${BRCTL}" ]]; then
        log_error "brctl not found at ${BRCTL} (macOS CloudDocs tool)"
        log_warn "This script expects macOS with iCloud Drive enabled"
        return 1
    fi

    if [[ ! -d "${PATH_ICLOUD_MOBILE_DOCUMENTS}" ]]; then
        log_warn "iCloud Drive root not found. If you just enabled iCloud Drive, try again after it initializes."
        return 1
    fi

    return 0
}

diag_processes() {
    print_heading "Processes (should see 'bird' and 'cloudd')"
    if ! pgrep -lf 'bird|cloudd'; then
        log_warn "No iCloud sync processes found (they will auto-launch if iCloud Drive is enabled)"
    fi
}

diag_status() {
    [[ ! -x "${BRCTL}" ]] && return 0

    print_heading "CloudDocs status (raw)"
    "${BRCTL}" status 2>&1 | tee "${DIAG_STATUS_FILE}" | tail -n 40

    print_heading "Quick counters from status"
    {
        printf "Uploading:   "
        grep -Eic 'upload(ing| pending)?' "${DIAG_STATUS_FILE}" || echo "0"
        printf "Downloading: "
        grep -Eic 'download(ing| pending)?' "${DIAG_STATUS_FILE}" || echo "0"
        printf "Conflicts:   "
        grep -Eic 'conflict' "${DIAG_STATUS_FILE}" || echo "0"
        printf "Errors:      "
        grep -Eic 'error|failed|denied|forbidden|nospace|quota' "${DIAG_STATUS_FILE}" || echo "0"
        printf "Evicted:     "
        grep -Eic 'evict(ed)?' "${DIAG_STATUS_FILE}" || echo "0"
        printf "Waiting:     "
        grep -Eic 'waiting|queued|pending' "${DIAG_STATUS_FILE}" || echo "0"
    } | column -t
}

diag_logs() {
    [[ ! -x "${BRCTL}" ]] && return 0

    print_heading "Recent CloudDocs log (last ~500 lines, error-filtered)"
    "${BRCTL}" log --shorten 2>&1 | tail -n 500 >"${DIAG_LOG_FILE}" || true

    if ! grep -Ei 'error|fail|denied|forbidden|quota|nospace|timeout|unreachable|auth' "${DIAG_LOG_FILE}" |
        sed 's/^/  * /'; then
        log_info "No obvious errors in recent brctl log"
    fi
}

diag_problem_files() {
    [[ ! -f "${DIAG_STATUS_FILE}" && ! -f "${DIAG_LOG_FILE}" ]] && return 0

    print_heading "Likely-problem files (from logs/status)"

    local found_files=false
    while IFS= read -r path; do
        if [[ -e "${path}" ]]; then
            echo "  * ${path}"
            found_files=true
        fi
    done < <(
        awk '
            match($0, /\/Users\/[^ ]*\/Library\/Mobile Documents\/com~apple~CloudDocs\/[^ ]+/, m) { print m[0] }
        ' "${DIAG_STATUS_FILE}" "${DIAG_LOG_FILE}" 2>/dev/null |
            sed 's/\\ / /g' |
            sed 's/^.*com~apple~CloudDocs\///' |
            sed "s|^|${PATH_ICLOUD_MOBILE_DOCUMENTS}/|" |
            sort -u
    )

    if [[ "${found_files}" == "false" ]]; then
        log_info "No file paths surfaced by brctl to inspect"
    fi
}

diag_filename_sanity() {
    [[ ! -d "${PATH_ICLOUD_MOBILE_DOCUMENTS}" ]] && return 0

    print_heading "Filename / path sanity checks (common iCloud gotchas)"

    log_info "Checking for very long names (> 200 chars):"
    find "${PATH_ICLOUD_MOBILE_DOCUMENTS}" -type f -print0 2>/dev/null |
        while IFS= read -r -d '' f; do
            base="$(basename "$f")"
            [[ ${#base} -gt 200 ]] && echo "  * $f"
        done || true

    log_info "Checking for suspicious temp/cache artifacts:"
    find "${PATH_ICLOUD_MOBILE_DOCUMENTS}" -type f \
        \( -name ".*.tmp" -o -name "*.tmp" -o -name "~*" -o -name "*.partial*" -o -name "*.crdownload" \) \
        -print 2>/dev/null | sed 's/^/  * /' || true

    log_info "Checking for huge files (> 15 GB) that can stall uploads:"
    find "${PATH_ICLOUD_MOBILE_DOCUMENTS}" -type f -size +15G -print 2>/dev/null |
        sed 's/^/  * /' || true

    log_info "Checking for files not yet downloaded locally (*.icloud stubs):"
    find "${PATH_ICLOUD_MOBILE_DOCUMENTS}" -type f -name "*.icloud" -print 2>/dev/null |
        sed 's/^/  * /' || true
}

diag_permissions() {
    [[ ! -d "${PATH_ICLOUD_MOBILE_DOCUMENTS}" ]] && return 0

    print_heading "Permissions sanity (drwx for folders; look for odd owners)"
    # shellcheck disable=SC2012
    ls -lO@ "${PATH_ICLOUD_MOBILE_DOCUMENTS}" | sed 's/^/  /'
}

diag_remediation_tips() {
    print_heading "If things look stuck (safe actions)"
    cat <<'EOF'
1) Restart iCloud agents (safe):
   killall bird cloudd 2>/dev/null; sleep 2; open -R "$HOME/Library/Mobile Documents/com~apple~CloudDocs"

2) Nudge a stuck item:
   - Move the problem file/folder OUT of iCloud Drive (e.g., to Desktop), wait 10-20s, then move it back.

3) Check space:
   - Ensure both local disk and iCloud storage have free space.

4) Rename suspicious files:
   - Shorten extremely long names; remove trailing spaces or odd symbols.

(Do NOT delete ~/Library/Mobile Documents or CloudDocs caches unless you have a full backup.)
EOF
}

diag_run_all() {
    diag_preflight || true
    diag_processes
    diag_status
    diag_logs
    diag_problem_files
    diag_filename_sanity
    diag_permissions
    diag_remediation_tips

    print_heading "Done"
    log_info "Temp files cleaned up on exit"
}

do_diagnose() {
    local run_all=true
    local run_processes=false
    local run_status=false
    local run_logs=false
    local run_files=false
    local run_permissions=false
    local run_tips=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --all)
            run_all=true
            shift
            ;;
        --processes)
            run_all=false
            run_processes=true
            shift
            ;;
        --status)
            run_all=false
            run_status=true
            shift
            ;;
        --logs)
            run_all=false
            run_logs=true
            shift
            ;;
        --files)
            run_all=false
            run_files=true
            shift
            ;;
        --permissions)
            run_all=false
            run_permissions=true
            shift
            ;;
        --tips)
            run_all=false
            run_tips=true
            shift
            ;;
        *)
            log_warn "Ignoring unknown argument: $1"
            shift
            ;;
        esac
    done

    diag_init_temp
    trap diag_cleanup EXIT

    if [[ "${run_all}" == "true" ]]; then
        diag_run_all
    else
        diag_preflight || true

        [[ "${run_processes}" == "true" ]] && diag_processes
        [[ "${run_status}" == "true" ]] && diag_status
        [[ "${run_logs}" == "true" ]] && diag_logs
        [[ "${run_files}" == "true" ]] && {
            diag_status >/dev/null 2>&1 || true
            diag_logs >/dev/null 2>&1 || true
            diag_problem_files
            diag_filename_sanity
        }
        [[ "${run_permissions}" == "true" ]] && diag_permissions
        [[ "${run_tips}" == "true" ]] && diag_remediation_tips

        print_heading "Done"
        log_info "Temp files cleaned up on exit"
    fi
}

# --- Main ---------------------------------------------------------------------

main() {
    local command=""
    local diagnose_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup)
            command="setup"
            shift
            ;;
        diagnose)
            command="diagnose"
            shift
            # Collect remaining args for diagnose
            diagnose_args=("$@")
            break
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
    diagnose)
        do_diagnose "${diagnose_args[@]}"
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"

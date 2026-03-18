#!/bin/bash
# Maintenance utilities for Mother Box
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../lib/bash/common.sh"

show_help() {
    local retention_days
    retention_days="$(get_config BACKUP_RETENTION_DAYS)"
    retention_days="${retention_days:-60}"

    cat <<EOF
Usage: $(basename "$0") <command> [args]

Maintenance utilities for Mother Box.

Commands:
    config [get|set]    View or modify configuration
    all                 Run all maintenance tasks
    brew                Update Homebrew and upgrade installed packages
    uv-upgrade          Upgrade all UV tools
    prune               Remove backups older than ${retention_days} days
    help                Show this help message (also: -h, --help)

Config subcommands:
    config              Show all config values
    config get <key>    Get a specific config value
    config set <key> <value>    Set a config value

Examples:
    $(basename "$0") config                              # Show all config
    $(basename "$0") config get BACKUP_RETENTION_DAYS    # Get retention days
    $(basename "$0") config set BACKUP_RETENTION_DAYS 90 # Set retention to 90 days
    $(basename "$0") prune                               # Clean up old backups
EOF
}

do_config() {
    local subcommand="${1:-}"
    shift || true

    case "${subcommand}" in
    "" | list)
        # Show all config values
        ensure_config
        print_heading "Configuration"
        log_info "File: ${PATH_MOTHERBOX_CONFIG_FILE}"
        echo ""
        cat "${PATH_MOTHERBOX_CONFIG_FILE}"
        ;;
    get)
        local key="${1:-}"
        if [[ -z "${key}" ]]; then
            fail "Usage: $(basename "$0") config get <key>"
        fi
        get_config "${key}"
        ;;
    set)
        local key="${1:-}"
        local value="${2:-}"
        if [[ -z "${key}" ]]; then
            fail "Usage: $(basename "$0") config set <key> <value>"
        fi
        set_config "${key}" "${value}"
        log_success "Set ${key}=${value}"
        ;;
    *)
        fail "Unknown config subcommand '${subcommand}'. Use 'get', 'set', or no argument to list."
        ;;
    esac
}

do_prune() {
    print_heading "Pruning old backups"

    local retention_days
    retention_days="$(get_config BACKUP_RETENTION_DAYS)"
    retention_days="${retention_days:-60}"

    if [[ ! -d "${PATH_MOTHERBOX_BACKUPS}" ]]; then
        log_info "No backups directory found at ${PATH_MOTHERBOX_BACKUPS}"
        return 0
    fi

    log_info "Retention period: ${retention_days} days"

    local count=0
    while IFS= read -r -d '' file; do
        log_warn "Pruning: ${file}"
        rm -f "$file"
        ((count++)) || true
    done < <(find "${PATH_MOTHERBOX_BACKUPS}" -type f -mtime "+${retention_days}" -print0 2>/dev/null)

    # Clean up empty directories
    find "${PATH_MOTHERBOX_BACKUPS}" -type d -empty -delete 2>/dev/null || true

    if [[ ${count} -eq 0 ]]; then
        log_info "No backups older than ${retention_days} days found"
    else
        log_success "Pruned ${count} backup(s)"
    fi
}

do_all() {
    print_heading "Running all maintenance tasks"
    do_brew
    do_uv_upgrade
    do_prune
}

do_uv_upgrade() {
    "${SCRIPT_DIR}/../apps/uv/uv.sh" upgrade
}

do_brew() {
    print_heading "Updating Homebrew"
    brew update
    print_heading "Upgrading packages"
    if ! brew upgrade; then
        log_warn "Some packages failed to upgrade"
    fi
}

main() {
    local cmd="${1:-}"
    shift || true

    case "${cmd}" in
    all)
        do_all
        ;;
    config)
        do_config "$@"
        ;;
    brew)
        do_brew
        ;;
    uv-upgrade)
        do_uv_upgrade
        ;;
    prune)
        do_prune
        ;;
    help | --help | -h | "")
        show_help
        exit 0
        ;;
    *)
        fail "Unknown command '${cmd}'. Run '$(basename "$0") help' for usage."
        ;;
    esac
}

main "$@"
